"""Readiness transitions for the reviewed inside pickups and entire catalogue."""
import json,runpy
from pathlib import Path
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
for f in ('WalkthroughData.lua','Walkthrough.lua'):
 lua.execute((root/f).read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
report=json.loads((root/'data/inside-readiness-review-2026-11-10.json').read_text())
lua.globals().reviewed=lua.table_from(report['resolved'])
lua.execute('''
C_QuestLog.IsQuestFlaggedCompleted=function(id) return completed[id] or false end
local function reset(q)
 completed={}; A.db.confirmed={}; A.log={}; A.offers={}; A.logAvailable=true
 faction=q.faction or "Alliance"; race=faction=="Horde" and "Orc" or "Human"; class=q.class or "WARRIOR"; level=60
end
for _,id in ipairs(reviewed) do
 local q=A.byID[id]; local n=A.walkthroughs[id]; reset(q)
 for _,prior in ipairs(n.all or {}) do completed[prior]=true end
 assert(A.RunReadiness(q),id.." eligible inside pickup")
 assert(A.ActionReadiness(q) and A.Availability(id)==nil,id.." guide pickup without fabricated offer")
 local saved=level; level=(n.minLevel or q.minLevel or 1)-1
 assert(not A.RunReadiness(q),id.." underlevel")
 level=saved; A.offers[id]=false; assert(not A.RunReadiness(q),id.." known absent offer")
 A.offers={}; A.log[id]={complete=false}
 assert(not not A.RunReadiness(q)==(n.dungeonObjective~=false),id.." active objective location")
 A.log[id].complete=true
 assert(not not A.RunReadiness(q)==(n.turninInside==true),id.." hand-in location")
 completed[id]=true; A.log={}; assert(not A.RunReadiness(q),id.." completed")
 completed[id]=nil; assert(A.RunReadiness(q),id.." abandoned/uncompleted inside pickup")
end
-- Outdoor precursor blocks Heartwoven; accepted dungeon precursor then allows it.
local heart=A.byID[95809]; reset(heart)
assert(not A.RunReadiness(heart))
A.log[95647]={complete=false}; assert(A.RunReadiness(heart))
A.log[95647].complete=true; assert(A.RunReadiness(heart))
completed[95647]=true; A.log={}; assert(A.RunReadiness(heart))
completed={}; assert(not A.RunReadiness(heart))
-- Both faction ring chains stay ready throughout their inside cleanup steps.
for _,id in ipairs({2947,2949}) do
 local q=A.byID[id]; reset(q)
 assert(A.RunReadiness(q))
 A.log[2945]={complete=false}; assert(A.RunReadiness(q))
 A.log[2945].complete=true; assert(A.RunReadiness(q))
 completed[2945]=true; A.log={}; assert(A.RunReadiness(q))
 A.log[id]={complete=false}; assert(not A.RunReadiness(q),"Return to city no longer needs run")
end
for _,id in ipairs({3366,78916,78917}) do
 local q=A.byID[id]; reset(q); assert(not A.RunReadiness(q))
 assert(A.walkthroughs[id].requirementsNote)
 A.offers[id]=true; assert(A.RunReadiness(q),"Real item offer overrides uncertain source")
end
-- General catalogue invariants: completed quests never inflate readiness and
-- an authoritative inside hand-in is recognized even without dungeon tags.
local count=0
for _,q in ipairs(A.quests) do
 reset(q); completed[q.id]=true; assert(not A.RunReadiness(q),q.id)
 completed={}; A.log[q.id]={complete=true}
 local n=A.walkthroughs[q.id] or q
 if n.turninInside then assert(A.RunReadiness(q),q.id) end
 count=count+1
end
print("PASS: 13 reviewed pickups, 3 unresolved records, inside/outside transitions, both ring branches, Heartwoven advancement/abandonment and "..count.." catalogue invariants")
''')
