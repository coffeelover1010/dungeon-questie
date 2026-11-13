local _, A = ...
-- Required public QuestieDB reads. No provider rows are copied into this addon.
local provider, zones, areaMaps, parents
local aliases={Deadmines="The Deadmines",["Stormwind Stockade"]="The Stockade",["Sunken Temple"]="The Temple of Atal'Hakkar",["Lower Blackrock Spire"]="Blackrock Spire",["Upper Blackrock Spire"]="Blackrock Spire"}
local function tableValue(value)
 if type(value)=="table" then return value end
 if type(value)=="string" then
  local fn=loadstring(value)
  if fn then local ok,t=pcall(fn); if ok and type(t)=="table" then return t end end
 end
 return {}
end
local function connect()
 local db=LibQuestieDB
 if not db or not db.RequireContract or not db.flavor or db.flavor.name~="Forever" or A.Safe(db.RequireContract,4)~=true then return false end
 if provider~=db then
  provider=db
  local support=A.Safe(db.Support and db.Support.Get,"ZoneDB")
  zones=support and support.private or {}
  areaMaps={}; parents={}
  for k,v in pairs(tableValue(zones.areaIdToUiMapId)) do areaMaps[k]=v end
  for k,v in pairs(tableValue(zones.areaIdToUiMapIdOverride)) do areaMaps[k]=v end
  for k,v in pairs(tableValue(zones.subZoneToParentZone)) do parents[k]=v end
  for k,v in pairs(tableValue(zones.subZoneToParentZoneOverride)) do parents[k]=v end
 end
 return true
end
local function read(entity,id,key)
 return A.Safe(provider[entity] and provider[entity].Get,id,key)
end
local function point(area,x,y,title,kind)
 local map=areaMaps and areaMaps[area]
 if not map or map<=0 or type(x)~="number" or type(y)~="number" or x<=0 or x>=100 or y<=0 or y>=100 then return end
 local info=A.Safe(C_Map and C_Map.GetMapInfo,map)
 if not info then return end
 return {map=map,x=x,y=y,zone=info.name,title=title,kind=kind,source="QuestieDB Forever"}
end
local function entrance(area)
 local seen={}
 while area and not seen[area] do
  seen[area]=true
  local dungeon=(zones.dungeons or {})[area]
  if dungeon then
   local p=dungeon[4] and dungeon[4][1]
   if p then return point(p[1],p[2],p[3],dungeon[1].." entrance / approach","entrance") end
  end
  area=parents[area]
 end
end
function A.DungeonEntrance(name)
 if name=="The Drowned City" then
  -- Approximate underwater entrance, checked 2026-11-10:
  -- https://www.warcrafttavern.com/forever/guides/the-drowned-city
  return {map=1434,x=21.4,y=27.9,zone="Stranglethorn Vale",title="The Drowned City underwater entrance (approximate)",kind="entrance",source="Warcraft Tavern dungeon guide"}
 end
 if not connect() then return end
 local wanted=aliases[name] or name
 local ids={}; for id,d in pairs(zones.dungeons or {}) do if d[1]==wanted then ids[#ids+1]=id end end
 table.sort(ids)
 for _,id in ipairs(ids) do local p=entrance(id); if p then return p end end
end
local function entityPin(entity,id,kind)
 local spawns=read(entity,id,"spawns")
 if type(spawns)~="table" then return end
 local name=read(entity,id,"name") or (entity.." "..id)
 local areas={}; for area in pairs(spawns) do if type(area)=="number" then areas[#areas+1]=area end end
 table.sort(areas)
 local fallback
 for _,area in ipairs(areas) do
  -- Dungeon coordinates are not outdoor coordinates. Mark its approach instead.
  local door=entrance(area)
  if door then fallback=fallback or door
  else
   for _,xy in ipairs(spawns[area]) do
    local p=point(area,xy[1],xy[2],name..(kind=="drop" and " - item drop area" or ""),kind)
    if p then return p end
   end
  end
 end
 return fallback
end
local function relationPin(id,field)
 local links=read("Quest",id,field)
 if type(links)~="table" then return end
 local kind=field=="finishedBy" and "hand-in" or "pickup"
 for slot,entity in ipairs({"Npc","Object"}) do
  for _,entityID in ipairs(links[slot] or {}) do
   local p=entityPin(entity,entityID,kind); if p then return p end
  end
 end
 for _,item in ipairs(links[3] or {}) do
  for _,entry in ipairs({{"Npc","npcDrops"},{"Object","objectDrops"}}) do
   for _,entityID in ipairs(read("Item",item,entry[2]) or {}) do
    local p=entityPin(entry[1],entityID,"drop"); if p then return p end
   end
  end
 end
end
-- Only a single structured objective can supply an unambiguous destination.
-- Multiple objectives and event-only tasks require explicit routing data.
local function objectivePin(id)
 local objectives=read("Quest",id,"objectives")
 if type(objectives)~="table" then return end
 local entity,ident,count=nil,nil,0
 for slot,entries in pairs(objectives) do
  for _,entry in ipairs(entries) do
   count=count+1
   if slot==1 or slot==2 then entity=slot==1 and "Npc" or "Object"; ident=entry[1] end
  end
 end
 if count==1 and entity then return entityPin(entity,ident,"objective") end
end
-- Match by entity name, never by the provider's grouped objective order.
-- A live unmatched/event objective remains a gap rather than a guessed trip.
function A.LiveObjectivePin(id)
 local live=A.Safe(C_QuestLog and C_QuestLog.GetQuestObjectives,id)
 if type(live)~="table" or #live==0 or not connect() then return nil,false end
 local objectives=read("Quest",id,"objectives")
 if type(objectives)~="table" then return nil,false end
 for _,objective in ipairs(live) do
  if not objective.finished then
   local matches={}
   for slot,entity in ipairs({"Npc","Object","Item"}) do
    for _,entry in ipairs(objectives[slot] or {}) do
     local name=read(entity,entry[1],"name")
     if type(name)=="string" and name~="" and (objective.text or ""):lower():find(name:lower(),1,true) then
      matches[#matches+1]={entity=entity,id=entry[1]}
     end
    end
   end
   if #matches~=1 then return nil,true end
   local match=matches[1]
   if match.entity~="Item" then return entityPin(match.entity,match.id,"objective"),true end
   for _,source in ipairs({{"Npc","npcDrops"},{"Object","objectDrops"}}) do
    for _,entityID in ipairs(read("Item",match.id,source[2]) or {}) do
     local p=entityPin(source[1],entityID,"objective"); if p then return p,true end
    end
   end
   return nil,true
  end
 end
 return nil,true
end
function A.LoadLocations()
 if not connect() or A.locationsLoaded==provider then return end
 local function fill(q)
  local correction=A.providerCorrections and A.providerCorrections[q.id]
  local values=correction and correction.values or {}
  local cleared={}; for _,k in ipairs(correction and correction.clear or {}) do cleared[k]=true end
  if not q.objectivePin then q.objectivePin=objectivePin(q.id) end
  if not values.pin and not cleared.pin then q.pin=relationPin(q.id,"startedBy") or q.pin end
  if not values.turninPin and not cleared.turninPin then q.turninPin=relationPin(q.id,"finishedBy") or q.turninPin end
 end
 for _,n in pairs(A.walkthroughs or {}) do fill(n) end
 for _,q in ipairs(A.quests) do
  local n=(A.walkthroughs or {})[q.id]
  if not q.pin and n then q.pin=n.pin end
  if not q.turninPin and n then q.turninPin=n.turninPin end
  fill(q)
 end
 A.locationsLoaded=provider
end
function A.MapLocation(q)
 if not q then return end
 A.LoadLocations()
 local n,phase=q,nil
 if A.WalkStep then n,phase=A.WalkStep(q) end
 local record=(A.walkthroughs or {})[n.id] or n
 local known=A.byID[n.id] or n
 local p
 if phase=="ready" or phase=="done" or ((phase=="active" or phase=="packed") and record.breadcrumbFor) then
  p=n.turninPin or record.turninPin or known.turninPin
 elseif phase=="active" or phase=="packed" then
  p=n.objectivePin or record.objectivePin or known.objectivePin
  -- Curated mechanic destinations take precedence over generic spawn matching.
  if not record.objectiveInstructions then
   local live,available=A.LiveObjectivePin(n.id)
   if available then p=live end
  end
 elseif phase=="pickup" or phase=="inside" or phase==nil then
  p=n.pin or record.pin or known.pin
 end
 -- Association is not a destination. Only a current, dungeon-ready step can
 -- use the associated entrance when its exact objective location is absent.
 if not p and A.RunReadiness and A.RunReadiness(q) then
  local dungeon=A.db and A.db.dungeon
  if not dungeon or not A.InDungeon(q,dungeon) then dungeon=q.dungeons and q.dungeons[1] end
  p=A.DungeonEntrance(dungeon)
 end
 if not p then return nil,"Current destination is not mapped. Follow the current quest instructions or quest log." end
 local kind=p.kind or "pickup"
 local tip=kind=="objective" and "Current quest objective" or (kind=="entrance" and "Dungeon entrance / approach\nNot an exact quest-giver or objective pin." or (kind=="hand-in" and "Recorded hand-in location" or (kind=="drop" and "Recorded quest-item drop area" or "Recorded pickup location")))
 return {id=n.id,name=n.name or q.name,pin=p,mapOnly=true,origin=q},tip.."\n"..p.title.."\n"..p.zone.." "..p.x..", "..p.y
end
function A.RouteInstruction(q)
 local n,phase=A.WalkStep(q)
 local record=(A.walkthroughs or {})[n.id] or n
 if phase=="active" or phase=="packed" then
  if record.objectiveInstructions then return record.objectiveInstructions end
 elseif phase=="ready" then
  return record.turninInstructions or ("Turn in to: "..(record.turnin or n.turnin or "the destination in your quest log"))
 end
 if phase=="done" then return "Completed: this quest has been turned in." end
 local target=A.MapLocation(q)
 local where=target and (target.pin.title.." - "..target.pin.zone) or "Current destination is not mapped."
 if phase=="pickup" or phase=="inside" then
  return where.."\nAccept "..n.name.." from "..(record.pickup or n.pickup or "the quest giver listed in your quest log").."."
 end
 if phase=="active" or phase=="packed" then
  local live=A.Safe(C_QuestLog and C_QuestLog.GetQuestObjectives,n.id)
  for _,o in ipairs(type(live)=="table" and live or {}) do
   if not o.finished and o.text then return where.."\n"..o.text end
  end
  local objectives=record.objectives or n.objectives or {}
  return where.."\n"..(#objectives>0 and table.concat(objectives,"; ") or "Follow the current instructions in your quest log.")
 end
 return where.."\n".."Check the current prerequisite and quest requirements below."
end
