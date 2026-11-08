"""Chain detail regression checks in the Lua 5.1 UI fixture."""
import runpy
from pathlib import Path
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
for f in ('WalkthroughData.lua','Walkthrough.lua'):
 lua.execute((root/f).read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
lua.execute(''' 
completed={}; A.db.confirmed={}; A.log={}; A.logAvailable=true
class="MAGE"; race="Gnome"; faction="Alliance"; level=30
local function node(id,parents)
 local n={id=id,name="Step quest "..id,all=parents or {},any={},dungeons={"Wailing Caverns"}}
 A.walkthroughs[id]=n; return n
end
local first=node(990801); local dungeon=node(990802,{990801})
local returnTrip=node(990803,{990802}); local finale=node(990804,{990803})
local label,text,x,y=A.ChainProgress(dungeon)
assert(x==1 and y==4 and label=="Step 1 of 4")
completed[first.id]=true
label,text,x,y=A.ChainProgress(dungeon); assert(x==2 and y==4)
A.log[dungeon.id]={complete=false}
label,text,x,y=A.ChainProgress(dungeon); assert(x==2 and text:find("In quest log",1,true))
A.log[dungeon.id].complete=true
assert(select(2,A.ChainProgress(dungeon)):find("Ready to turn in",1,true))
completed[dungeon.id]=true; A.log={}
label,text,x,y=A.ChainProgress(returnTrip); assert(x==3 and y==4)
completed[returnTrip.id]=true; completed[finale.id]=true
label,text,x,y=A.ChainProgress(finale); assert(x==4 and y==4)
-- Abandonment and absent history do not invent completed steps.
completed={}; A.log={}; label,text,x,y=A.ChainProgress(dungeon); assert(x==1)
-- Shared prerequisites count once, and all required branches are retained.
local left=node(990811,{990801}); local right=node(990812,{990801})
local join=node(990813,{990811,990812})
label,text,x,y=A.ChainProgress(join); assert(y==4)
-- Alternative prerequisites count one route, not both faction/class branches.
local other=node(990821); other.classMask=2
local own=node(990822); own.classMask=128
local either=node(990823); either.any={990821,990822}
label,text,x,y=A.ChainProgress(either)
assert(y==2 and text:find(own.name,1,true) and not text:find(other.name,1,true))
assert(label:find("selected route",1,true))
-- Missing records and cycles never produce infinite recursion or exact claims.
local missing=node(990831,{990822,990999})
label=A.ChainProgress(missing); assert(label:find("known route",1,true))
local cycle=node(990841,{990842}); node(990842,{990841}); A.ChainProgress(cycle)
assert(A.ChainProgress(node(990851))==nil)
-- Real return-to-dungeon sequence and UI integration.
completed={}; A.log={}; A.db.confirmed={}
local q=A.byID[92753]
label,text,x,y=A.ChainProgress(q)
assert(label and text:find(A.byID[92819].name,1,true))
A.SelectQuest(q)
assert(A.window.detailText:GetText():find(label,1,true))
assert(A.window.detailText:GetText():find("Quest chain",1,true))
''')
print('PASS: chain numbering, return trips, accepted/turn-in/completed states, abandonment, AND/OR branches, missing data, cycles and detail UI.')

