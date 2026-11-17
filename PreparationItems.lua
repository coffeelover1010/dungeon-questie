local _, A = ...
-- Reviewed preparation tools, not dungeon drops or inferred quest objectives.
-- Quest wording: https://wowforevertalents.com/quests/blueleaf-tubers-1221/
-- Item IDs: https://classicdb.com/?quest=1221 (reviewed 2026-11-16).
A.preparationItems={
 -- Reviewed 2026-11-17: https://db.icy-veins.com/wow-forever/quests/92749
 [92749]={
  instruction="A Dynamite Plan: bring 10 Rough Dynamite to Sprite Jumpsprocket. Craft them, trade with another player, or buy them at the auction house.",
  items={{id=4358,name="Rough Dynamite",count=10}},
  objective=true,
 },
 [1221]={
  instruction="Before entering Razorfen Kraul, collect the Crate With Holes and Snufflenose Command Stick beside Mebok Mizzyrix in Ratchet. Pick up and read the Snufflenose Owner's Manual there too. Inside, use the crate to summon a gopher, then use the stick on it to search for tubers.",
  items={{id=5880,name="Crate With Holes",count=1},{id=6684,name="Snufflenose Command Stick",count=1},
   {id=5897,name="Snufflenose Owner's Manual",count=1,reminder=true}},
 },
}
function A.PreparationItemStatus(q)
 -- Keep the parallel explosives task visible while waiting for the return quest.
 if q and q.id==92752 and not A.log[92752] and A.Completed(92752)~=true and A.Completed(92749)==false then
  q={id=92749}
 end
 local record=q and A.preparationItems[q.id]
 if not record or A.Completed(q.id)==true then return end
 local lines,missing={},{}
 for _,item in ipairs(record.items) do
  -- Exclude bank, charges and reagent bank: supplies must be carried.
  local count=A.Safe(C_Item and C_Item.GetItemCount or GetItemCount,item.id,false,false,false)
  local known=type(count)=="number" and count>=0
  lines[#lines+1]=(known and count>=item.count and "[x] " or "[ ] ")..item.name.." - "..(known and (math.min(count,item.count).."/"..item.count.." in bags") or "bag count unavailable")..(item.reminder and " (read before entering)" or "")
  if not item.reminder and (not known or count<item.count) then missing[#missing+1]=item.name end
 end
 return table.concat(lines,"\n").."\n"..record.instruction,missing
end
function A.MissingPreparationItems(q)
 if not q or not A.log[q.id] or A.log[q.id].complete then return end
 if A.preparationItems[q.id] and A.preparationItems[q.id].objective then return end
 local _,missing=A.PreparationItemStatus(q)
 if missing and #missing>0 then return "Bring before entering: "..table.concat(missing,", ") end
end
function A.PreparationItemTarget(q)
 if not A.MissingPreparationItems(q) then return end
 local record=(A.walkthroughs or {})[q.id] or q
 local p=record.pin or q.pin
 if not p then return end
 local pin={}; for k,v in pairs(p) do pin[k]=v end
 pin.kind="pickup"; pin.title="Quest supplies near "..(p.title or "the quest giver")
 return {id=q.id,name=q.name,pin=pin,mapOnly=true,origin=q}
end
