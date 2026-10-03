"""Integration/regression checks using the existing Lua 5.1 client mocks."""
import runpy,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
ctx=runpy.run_path(str(root/'tools/check.py'))
lua=ctx['lua']
for f in ('WalkthroughData.lua','Walkthrough.lua'):
    lua.execute((root/f).read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
lua.execute('''
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
assert(text:find("From: Motley Garmason",1,true))
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
assert(target==q and instructions:find("approximate pin unverified in Forever",1,true))
assert(not A.byID[168].pin.reference) -- curated location wins
C_Map.GetMapInfo=function() return {name="Duskwood"} end
function WorldMapFrame:GetMapID() return 1431 end
A.Navigate(q)
assert(A.target==377 and A.RefreshPins()>0)
log={{questID=377,title=q.name,complete=false}}; A.Scan()
assert(not A.NeedsPickup(q)) -- fallback must not become a turn-in pin
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
