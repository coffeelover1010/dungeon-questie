"""Audit all visible pickup cards against installed Forever quest data."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
loader=(root/'tools/check_provider.py').read_text()
loader=loader[:loader.index("lua.execute("+chr(39)*3+"\nassert(not A.providerError")]
context={'__file__':str(root/'tools/check_provider.py')}
exec(loader,context)
lua=context['lua']
lua.execute(r'''
completed={}; A.log={}; A.db.confirmed={}; A.offers={}; A.logAvailable=true; level=60
A.LoadLocations()
local count=0
for _,q in ipairs(A.quests) do
 if A.ChecklistVisible(q) then
  local n=A.walkthroughs[q.id]
  local pickup=n.itemPickup or n.pickup
  assert(pickup and pickup~="",q.id.." missing pickup")
  for _,marker in ipairs({"not verified","not recorded","confirmation","unverified","check the quest source"}) do
   assert(not pickup:lower():find(marker,1,true),q.id..": "..pickup)
  end
  count=count+1
 end
end
for _,id in ipairs({94969,95056}) do
 local q=A.byID[id]
 assert(not A.ChecklistVisible(q),"Non-live escort listed")
 A.log[id]={complete=false}; assert(A.ChecklistVisible(q),"Accepted escort hidden"); A.log={}
 completed[id]=true; assert(A.ChecklistVisible(q),"Completed escort hidden"); completed={}
 A.offers[id]=true; assert(A.ChecklistVisible(q),"Live offer hidden"); A.offers={}
end
local cards=0
for _,profile in ipairs({{"Alliance","Human","WARRIOR"},{"Horde","Orc","WARRIOR"},{"Alliance","Human","PALADIN"},{"Horde","Orc","SHAMAN"}}) do
 faction,race,class=unpack(profile)
 for _,q in ipairs(A.quests) do
  if A.ChecklistVisible(q) and not A.Restriction(q) then
   local _,text=A.DungeonInstruction(q)
   for _,marker in ipairs({"not verified","unverified","check the quest source","Pickup: Pickup:"}) do
    assert(not text:lower():find(marker:lower(),1,true),q.id..": "..text)
   end
   local step,phase=A.WalkStep(q)
   if phase=="pickup" or phase=="inside" then
    assert(text:find("Accept: ",1,true)==1,q.id..": "..text)
    assert(A.DungeonActionBadge(q)=="Interface\\GossipFrame\\AvailableQuestIcon",q.id)
   end
   cards=cards+1
  end
 end
end
local q=A.byID[92067]
local _,text=A.DungeonInstruction(q)
assert(text=="Accept: Feeding Time! from Flesh-Eating Lasher\nZone: Blackmaw Hold",text)
assert(A.DungeonReadinessBadge(q)=="Interface\\RaidFrame\\ReadyCheck-Ready")
faction="Alliance"; race="Human"; class="PALADIN"
local kor=A.byID[1442]
assert(A.ProviderGate(A.walkthroughs[1442]):find("Requires active quest:",1,true))
A.log[1654]={complete=false}
assert(A.ProviderGate(A.walkthroughs[1442])==nil,"Active parent requirement not satisfied")
A.log={}; completed[1654]=true
assert(A.ProviderGate(A.walkthroughs[1442])~=nil,"Completed parent incorrectly treated as active")
completed={}
print("PASS: "..count.." visible source records, "..cards.." rendered card cases, pickup icons and non-live escort overrides")
''')
