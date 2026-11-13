local _, A = ...
local nodes=A.walkthroughs or {}
-- Keep curated Forever locations; fill gaps from the walkthrough records.
for _,q in ipairs(A.quests) do
 local n=nodes[q.id]
 if not q.pin and not q.pickupInside and n and n.pin then
  q.pin=n.pin
  q.pickup=n.pickup
 end
end
local classBits={WARRIOR=1,PALADIN=2,HUNTER=4,ROGUE=8,PRIEST=16,SHAMAN=64,MAGE=128,WARLOCK=256,DRUID=1024}
local raceBits={Human=1,Orc=2,Dwarf=4,NightElf=8,Scourge=16,Tauren=32,Gnome=64,Troll=128}
local function contains(mask,flag) return not mask or mask==0 or not flag or math.floor(mask/flag)%2==1 end
function A.WalkRestriction(n,ignoreLevel)
 local _,class=UnitClass("player"); local _,race=UnitRace("player")
 if not contains(n.classMask,classBits[class]) then return "This reference step is for another class." end
 if not contains(n.raceMask,raceBits[race]) then return "This reference step is for another race or faction." end
 -- Character filtering only excludes known race/class/faction restrictions.
 -- Temporary gates remain visible and are evaluated by the step resolver.
 if not ignoreLevel then
  if n.maxLevel and n.maxLevel>0 and UnitLevel("player")>n.maxLevel then return "Above the maximum level." end
  if n.availableUntilCompleted and n.availableUntilCompleted>0 and A.Completed(n.availableUntilCompleted)==true then return "No longer available." end
  if n.disabledByQuest and n.disabledByQuest>0 and A.log[n.disabledByQuest] then return "Another active quest prevents pickup." end
  if n.availableStartingWith and n.availableStartingWith>0 and not A.log[n.availableStartingWith] and A.Completed(n.availableStartingWith)~=true then return "Requires an earlier quest." end
 end
 if n.faction and n.faction~=UnitFactionGroup("player") then return n.faction.." only." end
 if n.class and n.class~=class then return n.class.." only." end
 if not ignoreLevel and n.minLevel and UnitLevel("player")<n.minLevel then return "Requires level "..n.minLevel.."." end
end
-- Reference successors help detect progress beyond the direct destination too.
local successors={}
function A.RebuildSuccessors()
 successors={}
for id,n in pairs(nodes) do
 for _,field in ipairs({"all","any"}) do
  for _,prior in ipairs(n[field] or {}) do
   successors[prior]=successors[prior] or {}; table.insert(successors[prior],id)
  end
 end
end
end
A.RebuildSuccessors()
local function progressed(id,seen)
 if seen[id] then return end; seen[id]=true
 if A.log[id] or A.Completed(id)==true then return id end
 for _,nextID in ipairs(successors[id] or {}) do
  local found=progressed(nextID,seen); if found then return found end
 end
 local n=nodes[id] or A.byID[id]
 if n and n.breadcrumbFor then return progressed(n.breadcrumbFor,seen) end
end
-- A breadcrumb is optional, never a required predecessor. Live acceptance wins.
function A.BreadcrumbSuccessor(id)
 local n=nodes[id] or A.byID[id]
 if n and n.breadcrumbFor then return progressed(n.breadcrumbFor,{[id]=true}) end
end
local function resolve(id,path)
 if A.Completed(id)==true then return nil end
 local n=nodes[id] or A.byID[id]
 if not n then return {id=id,name="Quest "..id},"check","This prerequisite has no walkthrough record." end
 if A.log[id] then return n,A.log[id].complete and "ready" or "active" end
 if A.BreadcrumbSuccessor(id) and A.Availability(id)~=true then return nil end
 if A.offers[id]==true then return n,"pickup" end
 if path[id] then return n,"check","Conflicting chain links; check the source." end
 local restriction=A.WalkRestriction(n)
 local levelBlocked=n.minLevel and UnitLevel("player")<n.minLevel and restriction=="Requires level "..n.minLevel.."."
 if restriction and not levelBlocked then return n,"blocked",restriction end
 for _,other in ipairs(n.exclusive or {}) do
  if A.Completed(other)==true then return nil end
  if A.log[other] then
   local alternative=nodes[other] or A.byID[other]
   if alternative then return alternative,A.log[other].complete and "ready" or "active","This is the alternative quest already in your log." end
  end
 end
 if A.Completed(id)==nil then return n,"check","Completion information is unavailable. Open your quest log and try again." end
 if n.restrictionUnknown then return n,"check","Character eligibility unavailable; check the quest giver." end
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
 if levelBlocked then return n,"blocked",restriction end
 if A.ProviderGate then local gate=A.ProviderGate(n); if gate then return n,"check",gate end end
 if n.requirementsNote then return n,"check",n.requirementsNote end
 if n.unverifiedChain then return n,"check","Earlier quest requirements are not fully recorded." end
 if n.pickupUnknown then return n,"check","Pickup source is not verified." end
 if A.Availability(id)==false then return n,"unavailable","Not offered by the current NPC." end
 -- Known requirements suffice for guide pickup; a live offer is not required.
 return n,"pickup"
end
-- Share useful guide context between uncertain list cards and the walkthrough.
-- This is presentation only; it never promotes a step to pickup/readiness.
function A.StepContext(q,n,phase,note)
 local known=A.byID[n.id] or {}
 local lines={}
 if n.id~=q.id then lines[#lines+1]="Next recorded step: "..n.name end
 local pickup=n.pickup or known.pickup
 lines[#lines+1]=pickup and ("Guide pickup: "..pickup) or "Pickup location is not recorded. Check the quest source."
 local prep=n.preparationNote or known.preparationNote
 if prep then lines[#lines+1]=prep end
 if n.minLevel and UnitLevel("player")>=n.minLevel then
  lines[#lines+1]="Recorded level requirement met ("..n.minLevel..")."
 end
 local required=n.all or n.prereqs or {}
 local count=0
 for _,id in ipairs(required) do if A.Completed(id)==true then count=count+1 end end
 if #required>0 then lines[#lines+1]="Recorded prerequisites completed: "..count.."/"..#required.."." end
 local alternatives=n.any or {}
 for _,id in ipairs(alternatives) do
  if A.Completed(id)==true then lines[#lines+1]="A recorded alternative prerequisite is completed."; break end
 end
 if note and not (phase=="check" and (n.requirementsNote or n.unverifiedChain)) then lines[#lines+1]=note end
 local title="Quest details"
 if phase=="check" then
  title="Data incomplete"
  if n.unverifiedChain or n.requirementsNote then
   lines[#lines+1]="Prerequisite information is incomplete. Confirm availability with the quest giver."
  elseif n.pickupUnknown then
   lines[#lines+1]="Pickup information is incomplete."
  end
 end
 return table.concat(lines,"\n"),title
end
function A.WalkStep(q)
 if A.Completed(q.id)==true then return q,"done" end
 if A.log[q.id] then return q,A.log[q.id].complete and "ready" or "packed" end
 if A.offers[q.id]==true then return q,q.pickupInside and "inside" or "pickup" end
 local successor=A.BreadcrumbSuccessor(q.id)
 if successor and A.Availability(q.id)~=true then return q,"skipped","Optional breadcrumb skipped: a later quest is already collected or completed. This is not a quest completion. The breadcrumb link is reference data; a live offer takes precedence." end
 if A.Restriction(q) then return q,"blocked",A.Restriction(q) end
 if not nodes[q.id] and q.minLevel and UnitLevel("player")<q.minLevel then return q,"blocked","Requires level "..q.minLevel.."." end
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
-- Build the recorded route, keeping AND prerequisites and one OR branch.
-- Presentation follows the same resolver as the walkthrough, including branches
-- and live offers. Missing availability alone does not make a quest a later step.
function A.FutureQuestStep(q)
 if A.Completed(q.id)==true or A.log[q.id] or A.Availability(q.id)==true then return nil end
 local n,phase=A.WalkStep(q)
 if n and n.id~=q.id and phase~="done" and phase~="skipped" then return n end
end

-- Group by visible final destinations. Shared prerequisites may appear under
-- more than one destination; they still have one live quest state.
function A.QuestChainGroups(visible)
 local routes,covered={},{}
 for _,q in ipairs(visible) do
  local route,seen,path={},{},{}
  local function visit(id)
   if seen[id] or path[id] then return end
   local n=nodes[id] or A.byID[id]; if not n then return end
   path[id]=true
   for _,prior in ipairs(n.all or n.prereqs or {}) do visit(prior) end
   local choice
   for _,prior in ipairs(n.any or {}) do
    local _,phase=resolve(prior,{})
    if A.Completed(prior)==true or A.log[prior] then choice=prior; break end
    if not choice and phase~="blocked" then choice=prior end
   end
   if choice then visit(choice) end
   -- Optional introductions are labelled separately, not enforced prerequisites.
   for bid,b in pairs(nodes) do if b.breadcrumbFor==id and not A.WalkRestriction(b) then visit(bid) end end
   path[id]=nil; seen[id]=true
   if id~=q.id then route[#route+1]=A.byID[id] or n end
  end
  visit(q.id); routes[q.id]=route
  for _,n in ipairs(route) do covered[n.id]=true end
 end
 local groups={}
 for _,q in ipairs(visible) do
  if not covered[q.id] then groups[#groups+1]={quest=q,steps=routes[q.id]} end
 end
 -- Malformed cyclic source links must never hide every box.
 if #groups==0 then for _,q in ipairs(visible) do groups[#groups+1]={quest=q,steps={}} end end
 return groups
end

-- Extend past the selected dungeon quest only along an unambiguous follow-up.
function A.ChainProgress(q)
 local function record(id) return nodes[id] or A.byID[id] end
 local partial,branched=false,false
 local function alternative(n)
  local choices=n.any or {}
  if #choices==0 then return end
  branched=true
  for _,id in ipairs(choices) do if A.Completed(id)==true then return id end end
  for _,id in ipairs(choices) do if A.log[id] then return id end end
  for _,id in ipairs(choices) do
   local _,phase=resolve(id,{})
   if phase~="blocked" and phase~="check" then return id end
  end
  return choices[#choices]
 end
 local function dependencies(n)
  local ids={}
  for _,id in ipairs(n.all or n.prereqs or {}) do ids[#ids+1]=id end
  local choice=alternative(n); if choice then ids[#ids+1]=choice end
  return ids
 end
 local endpoint=q.id; local extended={}
 local _,class=UnitClass("player"); local _,race=UnitRace("player")
 local faction=UnitFactionGroup("player")
 while not extended[endpoint] do
  extended[endpoint]=true
  local successors={}
  for id,n in pairs(nodes) do
   -- Exclude other characters' branches, but not future level requirements.
   local eligible=contains(n.classMask,classBits[class]) and contains(n.raceMask,raceBits[race])
    and (not n.class or n.class==class) and (not n.faction or n.faction==faction)
   if eligible then
    local linked=false
    for _,prior in ipairs(n.all or n.prereqs or {}) do if prior==endpoint then linked=true end end
    for _,prior in ipairs(n.any or {}) do
     if prior==endpoint and alternative(n)==endpoint then linked=true end
    end
    if linked then successors[#successors+1]=id end
   end
  end
  if #successors~=1 then
   if #successors>1 then partial=true end
   break
  end
  endpoint=successors[1]
 end
 local route,seen,path={},{},{}
 local function visit(id)
  if path[id] then partial=true; return end
  if seen[id] then return end
  local n=record(id)
  if not n then partial=true; return end
  if n.unverifiedChain or n.requirementsNote then partial=true end
  path[id]=true
  for _,prior in ipairs(dependencies(n)) do visit(prior) end
  path[id]=nil; seen[id]=true; route[#route+1]=n
 end
 visit(endpoint)
 if #route<2 then return end
 local current=A.WalkStep(q)
 local index
 for i,n in ipairs(route) do if n.id==current.id then index=i end end
 if not index then return end
 local label="Step "..index.." of "..#route
 if partial then label=label.." (known route)" elseif branched then label=label.." (selected route)" end
 local lines={}
 for i,n in ipairs(route) do
  local state=A.Completed(n.id)==true and "Completed" or
   (A.log[n.id] and (A.log[n.id].complete and "Ready to turn in" or "In quest log") or (A.BreadcrumbSuccessor(n.id) and "Skipped breadcrumb" or "Not collected"))
  lines[#lines+1]=(i==index and "> " or "")..i..". "..n.name.." — "..state
 end
 if partial then lines[#lines+1]="Only recorded steps are counted; further or branching steps may exist." end
 return label,table.concat(lines,"\n"),index,#route
end

function A.WalkInstructions(q)
 if A.RunReadiness and A.NeedsPickup(q) then
  local ready,reason=A.RunReadiness(q)
  if ready then
   local step,phase=A.WalkStep(q)
   if phase=="inside" then
    reason=reason.."\n"..(step.pickup or "")
    if step.preparationNote then reason=reason.."\n"..step.preparationNote end
   end
   return reason,nil,"Ready for dungeon"
  end
 end
 local n,phase,note=A.WalkStep(q)
 if phase=="packed" or phase=="done" then return nil end
 local label=(phase=="pickup" or phase=="inside") and "Pick up: " or ((phase=="active" or phase=="ready") and "In quest log: " or "Quest: ")
 local lines={label..n.name}
 if n.id~=q.id then table.insert(lines,"Prerequisite for: "..q.name) end
 if phase=="check" or phase=="blocked" or phase=="unavailable" then
  table.insert(lines,(A.StepContext(q,n,phase,note)))
 elseif note then table.insert(lines,note) end
 if n.preparationNote and (phase=="pickup" or phase=="inside") then table.insert(lines,n.preparationNote) end
 if n.routeNote and (phase=="active" or phase=="ready") then table.insert(lines,n.routeNote) end
 local target
 if phase=="pickup" then
  table.insert(lines,"From: "..(n.pickup or (n.id==q.id and q.pickup) or "Location not recorded."))
  local known=A.byID[n.id]
  if phase=="pickup" and known and known.pin then target=known end
  if phase=="pickup" and not target and n.pin then target=n end
 elseif phase=="active" then
  table.insert(lines,"Complete and turn in this prerequisite.")
  local live=A.Safe(C_QuestLog and C_QuestLog.GetQuestObjectives,n.id)
  if type(live)=="table" and #live>0 then
   for _,o in ipairs(live) do table.insert(lines,(o.finished and "[x] " or "[ ] ")..(o.text or "Objective")) end
  else for _,o in ipairs(n.objectives or {}) do table.insert(lines,o) end end
  table.insert(lines,"Turn in to: "..(n.turnin or (nodes[n.id] and nodes[n.id].turnin) or "See your quest log."))
 elseif phase=="ready" then
  table.insert(lines,"Turn in to: "..(n.turnin or (nodes[n.id] and nodes[n.id].turnin) or "See your quest log."))
 elseif phase=="inside" then
  table.insert(lines,"Collect this during the dungeon run: "..(n.pickup or (n.id==q.id and q.pickup) or "See the quest source."))
 end
 for i,line in ipairs(lines) do lines[i]="- "..line end
 local headings={skipped="Skipped breadcrumb",unavailable="Unavailable",pickup="Accept quest",active="Complete prerequisite",ready="Turn in prerequisite",inside="Accept inside the dungeon",blocked="Requirements",check="Quest details"}
 return table.concat(lines,"\n"),target,(phase=="ready" and n.id==q.id and "Turn in quest" or headings[phase]) or "Next step",n,phase
end
