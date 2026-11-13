local _, A = ...
-- Public contract 4 only; never read baked metadata, backend rows or Questie internals.
local function safe(fn,...)
 if type(fn)~="function" then return nil end
 local ok,value=pcall(fn,...); if ok then return value end
end
local function copy(v)
 if type(v)~="table" then return v end
 local t={}; for k,x in pairs(v) do t[k]=copy(x) end; return t
end
local baseline={}
for id,n in pairs(A.walkthroughs) do baseline[id]=copy(n) end
for _,q in ipairs(A.quests) do
 baseline[q.id]=baseline[q.id] or copy(q)
 for k,v in pairs(q) do if baseline[q.id][k]==nil then baseline[q.id][k]=copy(v) end end
end
local db
local function get(entity,id,key) return safe(db[entity] and db[entity].Get,id,key) end
local function positive(v) return type(v)=="number" and v>0 and v or nil end
local function names(id,field)
 local links=get("Quest",id,field)
 if type(links)~="table" then return end
 local result,npcs={},{}
 for slot,entity in ipairs({"Npc","Object","Item"}) do
  for _,eid in ipairs(links[slot] or {}) do
   local title
   if entity=="Item" then title=safe(C_Item and C_Item.GetItemNameByID or GetItemInfo,eid) or ("Item "..eid)
   else title=get(entity,eid,"name") end
   if title then result[#result+1]=entity=="Item" and ("Use "..title) or title end
   if entity=="Npc" and title then npcs[#npcs+1]=title end
  end
 end
 if #result>0 then return table.concat(result," / "),npcs end
end
local mapping={name="name",level="questLevel",raceMask="requiredRaces",classMask="requiredClasses",
 all="preQuestGroup",any="preQuestSingle",exclusive="exclusiveTo",breadcrumbFor="breadcrumbForQuestId",
 maxLevel="requiredMaxLevel",availableUntilCompleted="availableUntilCompleted",
 availableStartingWith="availableStartingWith",disabledByQuest="disabledByQuest"}
local complex={"requiredSkill","requiredMinRep","requiredMaxRep","requiredSourceItems","requiredSpell","requiredSpecialization","requiredRanks","parentQuest"}
function A.LoadQuestData()
 db=LibQuestieDB
 if not db or not db.flavor or db.flavor.name~="Forever" or safe(db.RequireContract,4)~=true or not db.Quest or not db.Quest.Exists then
  A.providerError="Dungeon Questie requires QuestieDB for Forever (public API contract 4). Update QuestieDB and reload."
  return false
 end
 A.providerError=nil
 local visited={}
 local function hydrate(id)
  if visited[id] then return end; visited[id]=true
  local n=A.walkthroughs[id]
  local exists=safe(db.Quest.Exists,id)==true
  if not n and not exists then return end
  if not n then n={id=id,name="Quest "..id}; A.walkthroughs[id]=n end
  local fallback=baseline[id] or {id=id,name="Quest "..id}
  for k in pairs(n) do n[k]=nil end
  for k,v in pairs(fallback) do n[k]=copy(v) end
  n.providerFound=exists
  n.providerIncomplete=false
  for _,field in pairs(n.providerExpected or {}) do
   if not exists or get("Quest",id,field)==nil then n.providerIncomplete=true end
  end
  if exists then
   for key,field in pairs(mapping) do
    local value=get("Quest",id,field)
    if value~=nil then n[key]=copy(value) end
   end
   -- Zero is an API default, never a verified level requirement.
   n.minLevel=positive(get("Quest",id,"requiredLevel")) or positive(fallback.minLevel)
   n.level=positive(n.level); n.breadcrumbFor=positive(n.breadcrumbFor)
   -- The provider masks supersede inferred catalogue faction/class labels.
   if type(n.raceMask)=="number" and n.raceMask>0 then
    n.faction=nil; n.excludeRace=nil
    local masks=db.Enum and db.Enum.factionRaceMasks or {}
    if n.raceMask==masks.Alliance then n.faction="Alliance" elseif n.raceMask==masks.Horde then n.faction="Horde" end
   end
   if type(n.classMask)=="number" and n.classMask>0 then
    n.class=nil
    for class,mask in pairs(db.Enum and db.Enum.classKeys or {}) do if mask>0 and mask==n.classMask and ({WARRIOR=true,PALADIN=true,HUNTER=true,ROGUE=true,PRIEST=true,SHAMAN=true,MAGE=true,WARLOCK=true,DRUID=true})[class] then n.class=class end end
   end
   n.pickup,n.pickupNPCs=names(id,"startedBy")
   n.turnin,n.turninNPCs=names(id,"finishedBy")
   n.pickup=n.pickup or fallback.pickup; n.turnin=n.turnin or fallback.turnin
   n.pickupNPCs=n.pickupNPCs or copy(fallback.pickupNPCs)
   n.turninNPCs=n.turninNPCs or copy(fallback.turninNPCs)
   local objectives=get("Quest",id,"objectivesText")
   if type(objectives)=="table" and #objectives>0 then n.objectives=copy(objectives) end
   n.providerObjectives=get("Quest",id,"objectives")
   if (type(objectives)~="table" or #objectives==0) and type(n.providerObjectives)=="table" then
    local lines={}
    for slot,entity in ipairs({"Npc","Object","Item"}) do
     for _,o in ipairs(n.providerObjectives[slot] or {}) do
      local title=o[2]
      if not title or title=="" then
       if entity=="Item" then title=safe(C_Item and C_Item.GetItemNameByID or GetItemInfo,o[1])
       else title=get(entity,o[1],"name") end
      end
      if title then lines[#lines+1]=title..(positive(o[3]) and (" x"..o[3]) or "") end
     end
    end
    if #lines>0 then n.objectives=lines end
   end
   local flag=get("Quest",id,"specialFlags")
   if type(flag)=="number" and flag%2==1 then n.repeatable=true end
   n.providerRequirements={}
   for _,key in ipairs(complex) do
    local value=get("Quest",id,key)
    if (type(value)=="number" and value>0) or (type(value)=="table" and next(value)) then n.providerRequirements[key]=copy(value) end
   end
   -- Nil prerequisite arrays cannot erase known fallback links. Explicit empty
   -- arrays can, but an existing unresolved-chain guard remains unresolved.
   n.prereqs=copy(n.all or {})
  end
  local correction=A.providerCorrections and A.providerCorrections[id]
  if correction then
   for k,v in pairs(correction.values) do n[k]=copy(v) end
   for _,k in ipairs(correction.clear) do n[k]=nil end
   if correction.values.prereqs then n.all=copy(correction.values.prereqs) end
  end
  n.minLevel=positive(n.minLevel)
  for _,key in ipairs({"all","any","exclusive"}) do
   for _,prior in ipairs(n[key] or {}) do if prior>0 then hydrate(prior) end end
  end
  if n.breadcrumbFor then hydrate(n.breadcrumbFor) end
  local nextID=exists and positive(get("Quest",id,"nextQuestInChain"))
  if nextID then hydrate(nextID) end -- navigation hint, never invent a required edge
 end
 local ids={}; for id in pairs(baseline) do ids[#ids+1]=id end
 for _,id in ipairs(ids) do hydrate(id) end
 -- Optional breadcrumbs never become compulsory through a prerequisite list.
 for _,n in pairs(A.walkthroughs) do
  for _,field in ipairs({"all","any"}) do
   local filtered={}
   for _,id in ipairs(n[field] or {}) do
    local prior=A.walkthroughs[id]
    if not prior or prior.breadcrumbFor~=n.id then filtered[#filtered+1]=id end
   end
   n[field]=filtered
  end
 end
 for _,q in ipairs(A.quests) do
  local n=A.walkthroughs[q.id]
  for _,key in ipairs({"name","minLevel","level","faction","class","excludeRace","raceMask","classMask","pickup","turnin","pickupNPCs","turninNPCs","objectives","all","any","exclusive","breadcrumbFor","restrictionUnknown","requirementsNote","unverifiedChain","providerFound","repeatable","providerRequirements","maxLevel","availableUntilCompleted","availableStartingWith","disabledByQuest"}) do q[key]=copy(n[key]) end
  q.prereqs=copy(n.all or n.prereqs or {})
 end
 A.locationsLoaded=nil
 if A.RebuildSuccessors then A.RebuildSuccessors() end
 return true
end
-- A provider failure cannot turn old fallback records into newly ready quests.
function A.ProviderGate(n)
 if A.providerError then return A.providerError end
 if n.providerIncomplete then return "Quest requirements unavailable." end
 if n.restrictionUnknown then return "Character eligibility unavailable; check the quest giver." end
 if not n.minLevel then return "Minimum level: ?" end
 if n.providerRequirements and next(n.providerRequirements) then return "Check the quest giver's requirements." end
end
A.LoadQuestData()
