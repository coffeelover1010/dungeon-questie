local _, A = ...
-- Optional public QuestieDB reads. No provider rows are copied into this addon.
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
function A.LoadLocations()
 if not connect() or A.locationsLoaded==provider then return end
 local function fill(q)
  if not q.pin then q.pin=relationPin(q.id,"startedBy") end
  if not q.turninPin then q.turninPin=relationPin(q.id,"finishedBy") end
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
 if phase=="ready" or phase=="done" or ((phase=="active" or phase=="packed") and record.breadcrumbFor) then p=n.turninPin or record.turninPin or known.turninPin
 elseif phase~="active" and phase~="packed" then p=n.pin or record.pin or known.pin end
 -- Active dungeon quests lead to the run; active outdoor prerequisites retain
 -- their recorded giver as a reference, not as a claimed objective coordinate.
 if not p and n.id~=q.id then p=n.pin or record.pin or known.pin end
 if not p and (phase=="done" or phase=="ready") then p=n.pin or record.pin or known.pin end
 if not p then
  local dungeon=A.db and A.db.dungeon
  if not dungeon or not A.InDungeon(q,dungeon) then dungeon=q.dungeons and q.dungeons[1] end
  p=A.DungeonEntrance(dungeon)
 end
 if not p then p=q.pin or q.turninPin end
 if not p then return end
 local kind=p.kind or "pickup"
 local tip=(kind=="entrance" and "Dungeon entrance / approach\nNot an exact quest-giver or objective pin." or (kind=="hand-in" and "Recorded hand-in location" or (kind=="drop" and "Recorded quest-item drop area" or "Recorded pickup location")))
 return {id=n.id,name=n.name or q.name,pin=p,mapOnly=true,origin=q},tip.."\n"..p.title.."\n"..p.zone.." "..p.x..", "..p.y
end
