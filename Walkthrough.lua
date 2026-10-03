local _, A = ...
local nodes=A.walkthroughs or {}
-- Keep curated Forever locations; fill gaps with labelled Classic reference pins.
for _,q in ipairs(A.quests) do
 local n=nodes[q.id]
 if not q.pin and not q.pickupInside and n and n.pin then
  q.pin=n.pin
  q.pickup=n.pickup.." (Classic reference pin)"
 end
end
local classBits={WARRIOR=1,PALADIN=2,HUNTER=4,ROGUE=8,PRIEST=16,SHAMAN=64,MAGE=128,WARLOCK=256,DRUID=1024}
local raceBits={Human=1,Orc=2,Dwarf=4,NightElf=8,Scourge=16,Tauren=32,Gnome=64,Troll=128}
local function contains(mask,flag) return not mask or mask==0 or not flag or math.floor(mask/flag)%2==1 end
function A.WalkRestriction(n)
 local _,class=UnitClass("player"); local _,race=UnitRace("player")
 if not contains(n.classMask,classBits[class]) then return "This reference step is for another class." end
 if not contains(n.raceMask,raceBits[race]) then return "This reference step is for another race or faction." end
 if n.faction and n.faction~=UnitFactionGroup("player") then return n.faction.." only." end
 if n.class and n.class~=class then return n.class.." only." end
 if n.minLevel and UnitLevel("player")<n.minLevel then return "Requires level "..n.minLevel.."." end
end
local function resolve(id,path)
 if A.Completed(id)==true then return nil end
 local n=nodes[id] or A.byID[id]
 if not n then return {id=id,name="Quest "..id},"check","This prerequisite has no walkthrough record." end
 if A.log[id] then return n,A.log[id].complete and "ready" or "active" end
 if path[id] then return n,"check","Conflicting chain links; check the source." end
 local restriction=A.WalkRestriction(n)
 if restriction then return n,"blocked",restriction end
 for _,other in ipairs(n.exclusive or {}) do
  if A.Completed(other)==true then return nil end
  if A.log[other] then
   local alternative=nodes[other] or A.byID[other]
   if alternative then return alternative,A.log[other].complete and "ready" or "active","This is the alternative quest already in your log." end
  end
 end
 if A.Completed(id)==nil then return n,"check","Completion information is unavailable. Open your quest log and try again." end
 path[id]=true
 for _,prior in ipairs(n.all or n.prereqs or {}) do
  local step,phase,note=resolve(prior,path)
  if step then path[id]=nil; return step,phase,note end
 end
 local alternatives=n.any or {}
 local fulfilled=false
 for _,prior in ipairs(alternatives) do if A.Completed(prior)==true then fulfilled=true end end
 if #alternatives>0 and not fulfilled then
  local fallback,fp,fn
  for _,prior in ipairs(alternatives) do
   local step,phase,note=resolve(prior,path)
   if not step then fulfilled=true; break end
   if phase~="blocked" and phase~="check" then path[id]=nil; return step,phase,note end
   fallback,fp,fn=step,phase,note
  end
  if not fulfilled then path[id]=nil; return fallback,fp,fn end
 end
 path[id]=nil
 if n.requirementsNote then return n,"check",n.requirementsNote end
 if n.unverifiedChain then return n,"check","The full Forever prerequisite chain has not been verified. Check the quest source before travelling." end
 return n,"pickup"
end
function A.WalkStep(q)
 if A.Completed(q.id)==true then return q,"done" end
 if A.log[q.id] then return q,"packed" end
 if A.Restriction(q) then return q,"blocked",A.Restriction(q) end
 local root=nodes[q.id]
 if root then
  for _,other in ipairs(root.exclusive or {}) do
   if A.Completed(other)==true or A.log[other] then return q,"blocked","An alternative quest is already accepted or completed." end
  end
 end
 if not A.logAvailable then return q,"check","Quest-log scan unavailable." end
 local n,phase,note=resolve(q.id,{})
 if not n then return q,"done" end
 if phase=="pickup" and (n.pickupInside or (n.id==q.id and q.pickupInside)) then phase="inside" end
 return n,phase,note
end
function A.WalkInstructions(q)
 local n,phase,note=A.WalkStep(q)
 if phase=="packed" or phase=="done" then return nil end
 local label=(phase=="pickup" or phase=="inside") and "Pick up: " or ((phase=="active" or phase=="ready") and "In quest log: " or "Check: ")
 local lines={label..n.name}
 if n.id~=q.id then table.insert(lines,"Prerequisite for: "..q.name) end
 if note then table.insert(lines,note) end
 if n.preparationNote and (phase=="pickup" or phase=="inside") then table.insert(lines,n.preparationNote) end
 if n.routeNote and (phase=="active" or phase=="ready") then table.insert(lines,n.routeNote) end
 local target
 if phase=="pickup" then
  table.insert(lines,"From: "..(n.pickup or (n.id==q.id and q.pickup) or "Location not recorded."))
  local known=A.byID[n.id]
  if known and known.pin then target=known end
  if not target and n.pin then target=n end
 elseif phase=="active" then
  table.insert(lines,"Complete and turn in this prerequisite.")
  local live=A.Safe(C_QuestLog and C_QuestLog.GetQuestObjectives,n.id)
  if type(live)=="table" and #live>0 then
   for _,o in ipairs(live) do table.insert(lines,(o.finished and "[x] " or "[ ] ")..(o.text or "Objective")) end
  else for _,o in ipairs(n.objectives or {}) do table.insert(lines,o) end end
  table.insert(lines,"Turn in to: "..(n.turnin or "See your quest log."))
 elseif phase=="ready" then
  table.insert(lines,"Turn in to: "..(n.turnin or "See your quest log."))
 elseif phase=="inside" then
  table.insert(lines,"Collect this during the dungeon run: "..(n.pickup or (n.id==q.id and q.pickup) or "See the quest source."))
 end
 local referencePin=target and target.pin and target.pin.reference
 if n.referenceDetails then table.insert(lines,n.referenceDetails) end
 if n.evidence=="Classic reference" or referencePin then
  local referenceNote=n.evidence=="Classic reference" and "requirements may differ in Forever" or nil
  if referencePin then referenceNote=(referenceNote and referenceNote.."; " or "").."approximate pin unverified in Forever" end
  table.insert(lines,"Classic reference: "..referenceNote..".")
 end
 for i,line in ipairs(lines) do lines[i]="- "..line end
 local headings={pickup="Accept quest",active="Complete prerequisite",ready="Turn in prerequisite",inside="Accept inside the dungeon",blocked="Requirement to check",check="Step to check"}
 return table.concat(lines,"\n"),target,headings[phase] or "Next step",n,phase
end
