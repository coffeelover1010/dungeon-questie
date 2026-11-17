"""Bag-only preparation checks; does not prove live bag events or item use."""
from pathlib import Path
import runpy
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
for name in ('WalkthroughData.lua','Walkthrough.lua','Locations.lua','PreparationItems.lua'):
 lua.execute((root/name).read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
lua.execute(r'''
local q=A.byID[1221]
assert(q)
completed={}; A.db.confirmed={}; A.log={[1221]={complete=false}}; A.offers={}
local bags={}; C_Item=C_Item or {}
C_Item.GetItemCount=function(id,bank,charges,reagent)
 assert(bank==false and charges==false and reagent==false)
 return bags[id] or 0
end
local text,missing=A.PreparationItemStatus(q)
assert(#missing==2 and text:find("Crate With Holes",1,true) and text:find("Ratchet",1,true))
assert(not A.RunReadiness(q))
assert(A.Preparation(q)=="chain")
q.pin={map=1413,x=62.4,y=37.6,title="Mebok Mizzyrix",zone="The Barrens"}
A.walkthroughs[1221].pin=q.pin
local target=A.MapLocation(q)
assert(target.pin.map==1413 and target.pin.title:find("supplies"))
assert(A.RouteInstruction(q):find("Crate With Holes",1,true))
bags[5880]=1; text,missing=A.PreparationItemStatus(q); assert(#missing==1)
bags[6684]=1; assert(not A.MissingPreparationItems(q)); assert(A.RunReadiness(q))
-- Manual is a read reminder, not a false guarantee of having read it.
assert(not bags[5897]); text,missing=A.PreparationItemStatus(q); assert(#missing==0 and text:find("read before entering",1,true))
bags[5880]=0; assert(not A.RunReadiness(q))
C_Item.GetItemCount=function() error("unavailable") end
text,missing=A.PreparationItemStatus(q); assert(#missing==2 and text:find("unavailable"))
A.log[1221].complete=true; assert(not A.MissingPreparationItems(q))
A.log={}; assert(not A.MissingPreparationItems(q))
completed[1221]=true; assert(not A.PreparationItemStatus(q))
assert(not A.PreparationItemStatus({id=999999}))
print("PASS: crate/stick instructions, bag-only counts, missing/owned/unknown supplies, preparation readiness, pickup routing, manual reminder, complete/abandoned/turned-in quests")

A.Completed=function() return false end
A.log={}
C_Item.GetItemCount=function(id) return id==4358 and 4 or 0 end
local dynamite=A.PreparationItemStatus({id=92749})
assert(dynamite:find("4/10 in bags",1,true) and dynamite:find("Rough Dynamite",1,true))
assert(A.PreparationItemStatus({id=92752}):find("4/10 in bags",1,true))
A.log[92752]={complete=false}
assert(A.PreparationItemStatus({id=92752})==nil)
print("PASS: Rough Dynamite quantity and conditional return-step reminder")
''')
