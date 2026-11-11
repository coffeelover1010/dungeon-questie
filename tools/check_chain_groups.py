"""Chain grouping and expandable row integration using the Lua 5.1 UI fixture."""
import runpy
from pathlib import Path
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
for f in ('WalkthroughData.lua','Walkthrough.lua'):
 lua.execute((root/f).read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
lua.execute('''
completed={}; A.db.confirmed={}; A.log={}; A.offers={}; A.logAvailable=true
level=60; faction="Alliance"; race="Human"; class="WARRIOR"
local checked=0
for _,profile in ipairs({{"Alliance","Human","WARRIOR"},{"Horde","Orc","SHAMAN"}}) do
 faction,race,class=unpack(profile)
 for _,d in ipairs(A.dungeons) do
  A.db.dungeon=d.name; A.db.search=""
  local visible={}; for _,q in ipairs(A.quests) do if A.Matches(q) then visible[#visible+1]=q end end
  local groups=A.QuestChainGroups(visible); local represented={}
  for _,g in ipairs(groups) do
   represented[g.quest.id]=true; local seen={}
   for _,n in ipairs(g.steps) do
    assert(n.id~=g.quest.id and not seen[n.id]); seen[n.id]=true; represented[n.id]=true
   end
  end
  for _,q in ipairs(visible) do assert(represented[q.id],q.id); checked=checked+1 end
 end
end
faction="Alliance"; race="Human"; class="WARRIOR"
local groups=A.QuestChainGroups({A.byID[95809],A.byID[95647],A.byID[95737]})
assert(#groups==1 and groups[1].quest.id==95809)
local ids={}; for _,n in ipairs(groups[1].steps) do ids[n.id]=true end
assert(ids[95647] and ids[95737])
-- Every child (including non-catalogue prerequisites) can populate the detail pane.
local tested={}
for _,q in ipairs(A.quests) do
 for _,g in ipairs(A.QuestChainGroups({q})) do
  for _,n in ipairs(g.steps) do
   if not tested[n.id] then
    tested[n.id]=true
    local display={}; for k,v in pairs(n) do display[k]=v end
    display.dungeons=q.dungeons; display.rewards=display.rewards or {}; display.objectives=display.objectives or {}
    A.SelectQuest(display)
   end
  end
 end
end
print("PASS: grouped coverage across "..checked.." eligible quest/dungeon entries; final parents, breadcrumbs, unique children and prerequisite detail rendering")
''')
