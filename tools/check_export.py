"""Verify shared prerequisite exports preserve unknown and observed states."""
import runpy
from pathlib import Path
root = Path(__file__).resolve().parents[1]
lua = runpy.run_path(str(root / 'tools/check.py'))['lua']
lua.execute((root / 'Export.lua').read_text(encoding='utf-8'), 'DungeonGuideForever', lua.globals().A)
lua.execute('''
A.db.dungeon="Export test"
A.quests={{id=900001,name="First",dungeons={"Export test"}},{id=900002,name="Second",dungeons={"Export test"}}}
A.walkthroughs={
 [900001]={id=900001,name="First",all={900003}},
 [900002]={id=900002,name="Second",all={900003}},
 [900003]={id=900003,name="Shared",all={900001},pickup="Test NPC"}}
A.byID={}; for _,q in ipairs(A.quests) do A.byID[q.id]=q end
A.Restriction=function() end
A.WalkRestriction=function() end
A.WalkStep=function() return A.walkthroughs[900003],"pickup" end
A.Completed=function(id) if id==900001 then return true elseif id==900002 then return false end end
A.log={[900002]={complete=true}}; A.offers={[900003]=false}
local report=A.BuildProgressExport(A.quests[1])
assert(report:find("Selected quest: First [900001]",1,true))
assert(report:find("Turned in: true; log: absent; observed offer: unknown",1,true))
assert(report:find("Turned in: false; log: objectives finished",1,true))
assert(report:find("Turned in: unknown; log: absent; observed offer: false",1,true))
local _,count=report:gsub("pickup: Test NPC","")
assert(count==1,"Shared prerequisite must appear once, even with cyclic data")
assert(report:find("all: 900003",1,true))
print("PASS: export shared steps, cycles, selection, completion, log and offer states")
''')
