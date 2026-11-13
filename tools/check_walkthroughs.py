"""Integration/regression checks using the existing Lua 5.1 client mocks."""
import runpy,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
ctx=runpy.run_path(str(root/'tools/check.py'))
lua=ctx['lua']
for f in ('WalkthroughData.lua','Walkthrough.lua'):
    lua.execute((root/f).read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
lua.execute('''
-- These route tests supply positive availability; unknown/negative evidence is tested separately.
A.Availability=function() return true end
completed={}; log={}; A.db.confirmed={}; faction="Alliance"; class="MAGE"; race="Gnome"; level=30
C_QuestLog.GetNumQuestLogEntries=function() return #log end
C_QuestLog.GetInfo=function(i) return log[i] end
C_QuestLog.IsQuestFlaggedCompleted=function(id) return completed[id] or false end
A.Scan()
local q=A.byID[92753]
local n,p=A.WalkStep(q); assert(n.id==92742 and p=="pickup")
assert(A.ChecklistVisible(q) and not A.ChecklistVisible(A.byID[92819]))
local instructions=A.WalkInstructions(q)
assert(instructions:find("Pick up: Testing the Wells",1,true))
assert(not instructions:find("provided sample kit",1,true))
assert(not instructions:find("Current quest:",1,true))
local _,label=A.Preparation(q); assert(label=="PICK UP FIRST: Testing the Wells")
log={{questID=92742,title="Testing the Wells",complete=false}}; A.Scan()
n,p=A.WalkStep(q); assert(n.id==92742 and p=="active")
instructions=A.WalkInstructions(q); assert(instructions:find("provided sample kit",1,true))
log[1].complete=true; A.Scan(); n,p=A.WalkStep(q); assert(n.id==92742 and p=="ready")
completed[92742]=true; log={}; A.Scan(); n,p=A.WalkStep(q); assert(n.id==92744 and p=="pickup")
-- Later acceptance overrides a missing earlier completion and optional steps.
log={{questID=92750,title="Detonation at a Distance",complete=false}}; A.Scan()
n,p=A.WalkStep(q); assert(n.id==92750 and p=="active")
A.SelectQuest(q); assert(A.window.currentQuest.id==92750)
assert(A.window.detailText:GetText():find("Detonation at a Distance",1,true))
log={{questID=92753,title=q.name,complete=false}}; A.Scan()
n,p=A.WalkStep(q); assert(p=="packed")
A.SelectQuest(q)
assert(A.window.detailText:GetText():find("rear exit",1,true))
-- The second identically named quest must remain available after planting.
completed[92753]=true; log={}; A.Scan()
local finale=A.byID[92819]
assert(not A.ChecklistVisible(q) and A.ChecklistVisible(finale))
n,p=A.WalkStep(finale); assert(n.id==92819 and p=="pickup")
log={{questID=92819,title=finale.name,complete=false}}; A.Scan()
A.SelectQuest(finale)
assert(A.window.detailText:GetText():find("detonator",1,true))
completed[92819]=true; log={}; A.Scan()
n,p=A.WalkStep(finale); assert(p=="done")
completed[92753]=nil; completed[92819]=nil
A.db.confirmed[92753]=nil; A.db.confirmed[92819]=nil
-- Abandonment restores the earliest unfinished step.
log={}; A.Scan(); n,p=A.WalkStep(q); assert(n.id==92744)
local function node(id,extra)
 local n={id=id,name="Mock "..id,pickup="Test NPC",all={},any={}}
 for k,v in pairs(extra or {}) do n[k]=v end
 A.walkthroughs[id]=n; return n
end
local root=node(990100,{all={990101,990102}}); node(990101); node(990102)
n,p=A.WalkStep(root); assert(n.id==990101)
completed[990101]=true; n,p=A.WalkStep(root); assert(n.id==990102)
completed[990102]=true; n,p=A.WalkStep(root); assert(n.id==990100)
root.all={}; root.any={990103,990104}; node(990103,{classMask=2}); node(990104,{classMask=128})
n,p=A.WalkStep(root); assert(n.id==990104 and p=="pickup")
completed[990104]=true; n,p=A.WalkStep(root); assert(n.id==990100)
root.any={}; root.all={990105}; node(990105,{all={990100}})
n,p=A.WalkStep(root); assert(p=="check")
root.all={990999}; n,p=A.WalkStep(root); assert(p=="check")
root.all={990106}; node(990106,{exclusive={990107}}); node(990107)
completed[990107]=true; n,p=A.WalkStep(root); assert(n.id==root.id and p=="pickup")
root.all={}; root.exclusive={990107}; n,p=A.WalkStep(root); assert(p=="blocked")
A.logAvailable=false; n,p=A.WalkStep(q); assert(p=="check"); A.logAvailable=true
-- A known class-specific goal never routes a mage through paladin prerequisites.
n,p=A.WalkStep(A.byID[1654]); assert(p=="blocked")
-- Eligible catalogue details render with the real resolver; restricted ones stay hidden.
for _,quest in ipairs(A.quests) do
 A.SelectQuest(quest)
 if not A.Restriction(quest) and A.ChecklistVisible(quest) then assert(A.window.detailTitle:GetText()==quest.name)
 else assert(not A.Matches(quest)) end
end
''')
data=json.loads((root/'data/walkthroughs.json').read_text(encoding='utf-8'))
lua.execute('''
completed={}; log={}; A.db.confirmed={}; faction="Alliance"; race="Human"; class="WARRIOR"; level=60; A.Scan()
local goal=A.byID[378]
local step,phase=A.WalkStep(goal)
assert(step.id==303 and phase=="pickup")
A.SelectQuest(goal)
local text=A.window.detailText:GetText()
assert(text:find("Who offers this step|r",1,true) and text:find("Motley Garmason",1,true))
assert(text:find("|cff684018Rewards|r",1,true))
assert(not text:find("not the current prerequisite",1,true))
log={{questID=303,title="The Dark Iron War",complete=false}}; A.Scan()
local instructions,target,heading=A.WalkInstructions(goal)
assert(heading=="Complete prerequisite" and not target)
assert(instructions:find("Turn in to:",1,true) and not instructions:find("Accept from:",1,true))
log[1].complete=true; A.Scan()
instructions,target,heading=A.WalkInstructions(goal)
assert(heading=="Turn in prerequisite" and instructions:find("In quest log: The Dark Iron War",1,true))
completed[303]=true; log={}; A.Scan()
step,phase=A.WalkStep(goal); assert(step.id==378 and phase=="pickup")
-- Show a compact reward heading only when there are known items.
for _,q in ipairs(A.quests) do
 A.SelectQuest(q)
 if not A.Restriction(q) and A.ChecklistVisible(q) then
  local hasHeading=A.window.detailText:GetText():find("|cff684018Rewards|r",1,true)~=nil
  assert(hasHeading==(#(q.rewards or {})>0))
 end
end
''')
lua.execute('''
completed={}; log={}; faction="Alliance"; race="Human"; class="WARRIOR"; level=60; A.Scan()
local q=A.byID[377]
assert(q.pin and q.pin.reference and q.pin.map==1431)
local instructions,target=A.WalkInstructions(q)
assert(target==q)
local warning=A.DataWarning(q,A.walkthroughs[q.id]) or ""
assert(not warning:find("Classic reference",1,true))
assert(not A.byID[168].pin.reference) -- curated location wins
C_Map.GetMapInfo=function() return {name="Duskwood"} end
function WorldMapFrame:GetMapID() return 1431 end
A.Navigate(q)
assert(A.target==377 and A.RefreshPins()>0)
log={{questID=377,title=q.name,complete=false}}; A.Scan()
assert(not A.NeedsPickup(q)) -- fallback must not become a turn-in pin
''')
lua.execute('''
-- Horde Dalaran needs both the patrol route and the key; late acceptance wins.
A.offers={}; A.Availability=function(id) return A.offers[id] end
completed={}; log={}; A.db.confirmed={}; level=30; faction="Horde"; class="SHAMAN"; race="Orc"; A.Scan()
local q=A.byID[96984]
local n,phase=A.WalkStep(q); assert(n.id==544 and phase=="pickup")
completed[544]=true; n,phase=A.WalkStep(q); assert(n.id==545 and phase=="pickup")
completed[545]=true; n,phase=A.WalkStep(q); assert(n.id==93680 and phase=="pickup")
completed[93680]=true; n,phase=A.WalkStep(q); assert(n.id==92434 and phase=="pickup")
completed[92434]=true; n,phase=A.WalkStep(q); assert(n.id==96984 and phase=="pickup")
assert(n.pickup:find("Modera",1,true) and n.turnin:find("Voidglare",1,true))
completed={}; log={{questID=92434,title="Blood in the Streets",complete=false}}; A.Scan()
n,phase=A.WalkStep(q); assert(n.id==92434 and phase=="active")
log={{questID=96984,title=q.name,complete=false}}; A.Scan()
n,phase=A.WalkStep(q); assert(n.id==96984 and phase=="packed")
-- Alliance breadcrumbs and disputed Wetlands requirements cannot force detours.
completed={}; log={}; faction="Alliance"; race="Dwarf"; class="SHAMAN"; A.Scan()
n,phase=A.WalkStep(A.byID[95647]); assert(n.id==95647 and phase=="pickup")
n,phase=A.WalkStep(A.byID[98815]); assert(n.id==484 and phase=="pickup")
completed[484]=true; n,phase=A.WalkStep(A.byID[98815]); assert(n.id==98815 and phase=="pickup")
n,phase=A.WalkStep(A.byID[92458]); assert(n.id==92458)
assert(not A.Restriction(A.byID[96264]))
n,phase=A.WalkStep(A.byID[96264]); assert(n.id==94789 and phase=="check")
completed[94789]=true; n,phase=A.WalkStep(A.byID[96264]); assert(n.id==96264 and phase=="pickup")
class="WARRIOR"; A.Scan(); assert(A.Restriction(A.byID[96264]))
faction="Horde"; race="Orc"; class="SHAMAN"; A.Scan(); assert(not A.Restriction(A.byID[79360]))
class="MAGE"; A.Scan(); assert(A.Restriction(A.byID[79360]))
''')

# Missing journal entries: follow-ups remain distinct and breadcrumbs optional.
for quest_id, prior in ((2948,2947),(2950,2949),(1806,1654),(1394,6628)):
    assert data[str(quest_id)]['all']==[prior], quest_id
assert data['6628']['all']==[1160]
assert data['1806']['classMask']==2 and data['1806']['raceMask']==5
assert data['2948']['raceMask']==77 and data['2950']['raceMask']==178
assert not data['1275']['all'] and not data['276']['all']
assert data['463']['name']=='The Greenwarden'
lua.execute('''
completed={}; log={}; A.db.confirmed={}; level=60; faction="Alliance"; race="Dwarf"; class="PALADIN"; A.Scan()
completed[1654]=true
local n,phase=A.WalkStep(A.byID[1806]); assert(n.id==1806 and phase=="pickup")
completed[1806]=true
n,phase=A.WalkStep(A.byID[1806]); assert(phase=="done")
completed={}; faction="Horde"; race="Orc"; class="WARRIOR"; A.Scan()
completed[6628]=true
n,phase=A.WalkStep(A.byID[1394]); assert(n.id==1394 and phase=="pickup")
''')

cycles=[]
lua.execute('''
completed={}; log={}; A.db.confirmed={}; level=30; faction="Alliance"; class="MAGE"; race="Gnome"; A.Scan()
local q=A.byID[2951]
local n,phase=A.WalkStep(q)
assert(phase=="inside" and n.id==2951)
local text=A.WalkInstructions(q)
assert(text:find("Clean Zone",1,true) and text:find("3 silver",1,true))
assert(not text:find("requirements may differ",1,true))
assert(not q.repeatable)
A.SelectQuest(q)
assert(not A.window.detailText:GetText():find("Repeatable; excluded",1,true))
''')
catalogue=json.loads((root/'data/catalogue.json').read_text(encoding='utf-8'))
overrides=json.loads((root/'data/walkthrough-overrides.json').read_text(encoding='utf-8'))
for q in catalogue:
    if q.get('evidence')=='Classic reference':continue
    n=data[str(q['id'])]
    o=overrides.get(str(q['id']),{})
    for key in ('pickup','minLevel','objectives','preparationNote'):
        if key in q and q[key] not in (None,'',[]) and key not in o:
            assert n.get(key)==q[key],(q['id'],key)
def walk(i,path):
    if i in path:
        cycles.append(path+[i]); return
    n=data[str(i)]
    for p in n.get('all',[])+n.get('any',[]):
        assert str(p) in data, (i,p)
        walk(p,path+[i])
for i in data:walk(int(i),[])
assert not cycles,cycles[:5]
print(f'PASS: {len(data)} chain records, all edges resolve, no cycles; step advancement, late acceptance, abandonment, AND/OR branches, class restrictions, missing data, API failure and all detail panels.')

lua.execute('''
completed={}; log={}; A.db.confirmed={}; faction="Alliance"; class="MAGE"; race="Gnome"; level=30; A.Scan()
A.SelectQuest(A.byID[92458])
assert(not A.window.warning:IsShown())
local text=A.window.detailText:GetText():lower()
assert(not text:find("needs checking",1,true) and not text:find("not been verified",1,true))
assert(A.window.detailTitle:GetText()==A.byID[92458].name) -- uncertainty prose is omitted
assert(text:find("shade of the archmage",1,true))
assert(text:find("return to",1,true))
assert(not A.RunReadiness(A.byID[92458]))
for _,id in ipairs({92456,92457,92489}) do
 local step,phase=A.WalkStep(A.byID[id]); assert(step.id==id and phase=="pickup")
 A.SelectQuest(A.byID[id])
 local detail=A.window.detailText:GetText():lower()
 assert(detail:find("objectives",1,true) and detail:find("return to",1,true))
end
A.SelectQuest(A.byID[92456])
assert(A.window.detailText:GetText():find("Fel Ancient",1,true))
A.SelectQuest(A.byID[95647]); assert(not A.window.warning:IsShown())
assert(A.DisplayText("Melisara in Tarren Mill (quest-text report; exact pickup unverified).") == "Melisara in Tarren Mill.")
assert(not A.DataWarning({id=990999,evidence="Classic reference",pin={reference=true}}))
''')
print('PASS: hidden source warnings, concise directions and unchanged readiness gates')
lua.execute('''
local oldLevel,oldFaction=level,faction
level=30; faction="Alliance"
local title,icon=A.QuestRowStatus(A.byID[2846])
assert(title=="Level 40" and icon==nil)
local q={id=990081,name="Level test",minLevel=42,dungeons={"Test"}}
assert(A.QuestRowStatus(q)=="Level 42")
q.faction="Horde"
assert(A.QuestRowStatus(q)=="Ineligible", "Faction restrictions must not be reported as level restrictions")
q.faction=nil; q.minLevel=1
A.walkthroughs[q.id]={id=q.id,name=q.name,minLevel=1,all={990082}}
A.walkthroughs[990082]={id=990082,name="Earlier step",minLevel=42,all={}}
local label,_,tip=A.QuestRowStatus(q)
assert(label=="Level 42" and tip:find("Earlier step",1,true))
level=42
assert(A.QuestRowStatus(q)~="Level 42", "Level label must clear when eligible")
A.log[q.id]={complete=false}; level=30
assert(A.QuestRowStatus(q)=="Active", "Accepted quests must not be blocked by reference level data")
A.log[q.id]=nil; completed[q.id]=true
local done,doneIcon=A.QuestRowStatus(q)
assert(done=="Completed" and doneIcon)
completed[q.id]=nil; A.walkthroughs[q.id]=nil; A.walkthroughs[990082]=nil
level=oldLevel; faction=oldFaction
''')
print('PASS: exact level status, prerequisite level, other restrictions, accepted/completed precedence and status icons')

lua.execute('''
completed={}; log={}; A.db.confirmed={}; level=60; class="WARRIOR"; race="Human"; faction="Alliance"; A.Scan()
assert(not A.Restriction(A.byID[95795]), "Fallen in the Fen is available to the recorded faction")
assert(A.Restriction(A.byID[95663]), "Dragonmaw Rumors remains Horde-only")
assert(A.Restriction(A.byID[95775]), "Drowned City records must not appear for Alliance")
faction="Horde"; race="Orc"; A.Scan()
assert(not A.Restriction(A.byID[95663]))
assert(A.Restriction(A.byID[95795]))
for _,id in ipairs({95775,95776,96774}) do
 assert(not A.Restriction(A.byID[id]))
 assert(not A.RunReadiness(A.byID[id]), "Missing pickup/chain data must not imply readiness")
end
assert(A.Restriction(A.byID[7668]), "The Darkreaver Menace still requires a shaman")
class="SHAMAN"; assert(not A.Restriction(A.byID[7668]))
assert(A.byID[96800].pickup:find("Magus Olvek",1,true))
assert(A.byID[92456].pin.map==1453 and A.byID[92456].pin.x==31.3)
''')
print('PASS: reviewed faction eligibility, class preservation, Drowned City readiness and named/logged pickups')

lua.execute('''
for _,records in ipairs({A.quests,A.walkthroughs}) do
 for _,q in pairs(records) do
  for _,key in ipairs({"pickup","preparationNote","routeNote"}) do
   local v=A.DisplayText(q[key]):lower()
   assert(not v:find("unverified",1,true) and not v:find("needs checking",1,true) and not v:find("not verified",1,true),q.id..":"..key)
  end
 end
end
''')

lua.execute('''
completed={}; log={}; A.db.confirmed={}; level=60; faction="Alliance"; class="WARRIOR"; race="Human"; A.Scan()
A.Availability=function() return nil end
A.offers={}
local q=A.byID[95810]
local n,p,note=A.WalkStep(q)
assert(p=="inside")
local text,title=A.StepContext(q,n,p,note)
assert(text:find("Titan Relic",1,true) and text:find("Recorded level requirement met",1,true))
assert(A.ActionReadiness(q))
assert(A.WalkInstructions(q):find("Titan Relic",1,true))
assert(A.QuestRowStatus(q)=="Collect quest")
q=A.byID[95795]; n,p,note=A.WalkStep(q)
text,title=A.StepContext(q,n,p,note)
assert(n.id==95772 and text:find("Dorin",1,true) and title=="Data incomplete")
completed[95810]=true
q=A.byID[98824]; n,p,note=A.WalkStep(q)
text=A.StepContext(q,n,p,note)
assert(n.id==98824 and text:find("1/1",1,true) and text:find("Whelgar",1,true))
assert(p=="pickup" and A.ActionReadiness(q))
A.Availability=function() return false end
n,p,note=A.WalkStep(q)
text=A.StepContext(q,n,p,note)
assert(p=="unavailable" and text:find("Not offered by the current NPC",1,true))
A.offers[q.id]=true
assert(select(2,A.WalkStep(q))=="pickup")
''')
print('PASS: uncertain steps retain pickup directions, level and completion progress without claiming availability; live offers still win')
