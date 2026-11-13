"""Regression checks for researched Forever mappings and runtime status gates."""
from pathlib import Path
import json,runpy
root=Path(__file__).resolve().parents[1]
review=json.loads((root/'data/forever-review-2026-11-13.json').read_text(encoding='utf-8'))
catalogue=json.loads((root/'data/catalogue.json').read_text(encoding='utf-8'))
by={q['id']:q for q in catalogue}
assert len(by)==len(catalogue)
for q in review['catalogue']:
 assert by[q['id']]['dungeons']==q['dungeons']
 assert all(item['id']>0 for item in q.get('rewards',[]))
assert not any(q['id'] in (6031,6032) and 'Blackmaw Hold' in q['dungeons'] for q in catalogue)
scope=runpy.run_path(str(root/'tools/check_provider.py'))
lua=scope['lua'];A=lua.globals().A
lua.execute('''
completed={}; A.db.confirmed={}; A.log={}; A.offers={}; A.logAvailable=true
C_QuestLog.IsQuestFlaggedCompleted=function(id) return completed[id] or false end
level=60; class="WARRIOR"; faction="Alliance"; race="Human"
''')
for q in review['catalogue']:
 actual=A.byID[q['id']]
 if q.get('minLevel'):assert actual.minLevel==q['minLevel'],q['id']
 if 'faction' in q:
  for side,race in [('Alliance','Human'),('Horde','Orc')]:
   lua.globals().faction=side;lua.globals().race=race
   for player_class in ['WARRIOR','PALADIN','HUNTER','ROGUE','PRIEST','SHAMAN','MAGE','WARLOCK','DRUID']:
    lua.globals()['class']=player_class
    assert bool(A.Restriction(actual))==bool(q['faction'] and q['faction']!=side),(q['id'],side,player_class)
lua.execute('''
faction="Alliance"; race="Human"; level=60
-- An unresolved source remains visible, with no invented readiness or offer.
local uncertain=A.byID[95056]
faction="Horde"; race="Orc"; A.db.dungeon="Krol'dok Stronghold"; A.db.search=""
assert(A.Matches(uncertain) and not A.RunReadiness(uncertain))
assert(select(2,A.WalkStep(uncertain))=="check")
assert(A.QuestRowStatus(uncertain)=="Data incomplete")
-- Exact known prerequisite links: an unturned-in quest cannot satisfy a gate.
local q=A.byID[95775]
completed={}; A.log={[95770]={complete=true}}
local step,phase=A.WalkStep(q)
assert(step.id==95770 and phase=="ready" and not A.RunReadiness(q))
A.log={}; completed[95770]=true
step,phase=A.WalkStep(q); assert(step.id==95775 and phase=="pickup")
-- Both recorded requirements for Brinescale must be turned in.
q=A.byID[95776]; A.log={[95773]={complete=false}}
step,phase=A.WalkStep(q); assert(step.id==95773 and phase=="active")
A.log={}; completed[95773]=true
step,phase=A.WalkStep(q); assert(step.id==95776 and phase=="pickup")
-- Alliance preparation requires the actual Southshore handoff, not a name match.
faction="Alliance"; race="Human"; completed={}; A.log={[95786]={complete=true}}
step,phase=A.WalkStep(A.byID[95788]); assert(step.id==95786 and phase=="ready")
completed[95786]=true; A.log={}
step,phase=A.WalkStep(A.byID[95788]); assert(step.id==95788 and phase=="pickup")
-- Corrected zero provider levels use independently verified minima.
assert(A.byID[92065].minLevel==47 and A.byID[97327].minLevel==55)
-- Temporary requirements do not disappear under character filtering.
local n={id=999990,name="Gate test",dungeons={"Gate test"},minLevel=1,
 availableStartingWith=999991,all={},any={}}
A.walkthroughs[n.id]=n; A.byID[n.id]=n; A.db.dungeon="Gate test"
assert(not A.Restriction(n) and A.Matches(n))
assert(select(2,A.WalkStep(n))=="blocked")
n.availableStartingWith=nil; n.restrictionUnknown=true
assert(A.Matches(n) and select(2,A.WalkStep(n))=="check")
A.offers[n.id]=true; assert(select(2,A.WalkStep(n))=="pickup")
A.offers={}; A.log[n.id]={complete=false}; assert(A.Status(n)=="active")
A.log[n.id].complete=true; assert(A.Status(n)=="ready")
A.log={}; completed[n.id]=true; assert(A.Status(n)=="done")
A.walkthroughs[n.id]=nil; A.byID[n.id]=nil
-- Verified sequential stages keep one checklist slot, including reward handoffs.
completed={}; A.log={}; faction="Alliance"; race="Human"; level=60
assert(A.ChecklistVisible(A.byID[95788]) and not A.ChecklistVisible(A.byID[95798]))
completed[95788]=true
assert(not A.ChecklistVisible(A.byID[95788]) and A.ChecklistVisible(A.byID[95798]))
assert(A.Preparation(A.byID[95798])~="done")
completed[95798]=true; assert(A.Preparation(A.byID[95798])=="done")
-- Level-1 characters still see nonzero known totals for higher-level dungeons.
completed={}; level=1
for _,side in ipairs({"Alliance","Horde"}) do
 faction=side; race=side=="Alliance" and "Human" or "Orc"
 for _,d in ipairs({"The Drowned City","Krol'dok Stronghold","Alcaz Prison","Blackmaw Hold","The Shaper's Terrace"}) do
  local counts=A.PreparationSummary(d); assert(counts.total>0,d)
 end
end
''')
print('PASS: Forever mappings, source minima, both factions, AND prerequisites, handoffs, unknown data, temporary gates, live states and level-independent totals')
