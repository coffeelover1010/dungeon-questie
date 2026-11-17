local _, A = ...
A.Navigation={owner="DungeonGuideForever"}
local N=A.Navigation
function N.API()
 local api=ShortestPathForever and ShortestPathForever.API
 if type(api)=="table" and (api.version==1 or api.version==2) then return api end
end
function N.Call(method,...)
 local api=N.API()
 if not api or type(api[method])~="function" then return nil,"unsupported" end
 local ok,value,reason=pcall(api[method],...)
 if not ok then return nil,"API error" end
 return value,reason
end
function N.Destination(target,dungeon)
 local p=target and target.pin
 if not p or type(p.map)~="number" or p.map<=0 or p.map%1~=0 or type(p.x)~="number" or type(p.y)~="number"
  or p.x~=p.x or p.y~=p.y or p.x<0 or p.x>100 or p.y<0 or p.y>100 then return end
 local kind=target.destinationKind or p.kind or "pickup"
 kind=({["hand-in"]="turnin",entrance="dungeon",drop="objective"})[kind] or kind
 return {map=p.map,x=p.x/100,y=p.y/100,title=p.title or target.name,kind=kind,
  questID=target.id,npc=p.npcID,dungeon=dungeon,quest=target.name,target=target,
  key=kind..":"..p.map..":"..p.x..":"..p.y..":"..(target.id or 0)}
end
function N.Position()
 local map=A.Safe(C_Map and C_Map.GetBestMapForUnit,"player")
 local p=map and A.Safe(C_Map.GetPlayerMapPosition,map,"player")
 if not p then return end
 local x,y=p.x,p.y
 if type(p.GetXY)=="function" then local ok,a,b=pcall(p.GetXY,p); if ok then x,y=a,b end end
 if type(x)=="number" and type(y)=="number" then return {map=map,x=x,y=y} end
end
function N.Estimate(from,to)
 if not from or not to then return nil,"Player position unavailable" end
 -- SPF owns its five-second cache and character/transport restrictions.
 -- Do not retain estimates across progression, movement or transport changes.
 local seconds,reason=N.Call("Estimate",from.map,from.x,from.y,to.map,to.x,to.y)
 if type(seconds)=="number" and seconds>=0 and seconds<math.huge then return seconds end
 return nil,reason or "Estimate unavailable"
end
function N.Best(from,d,yieldWork)
 local best,cost,reason=d,N.Estimate(from,d)
 local api=N.API()
 if not api or type(api.Estimate)~="function" then return best,cost,reason end
 local p=d.target.pin
 if p.entity and p.entityID then
  for _,pin in ipairs(A.EntityLocations(p.entity,p.entityID,p.kind)) do
   if yieldWork then yieldWork() end
   local candidate=N.Destination({id=d.questID,name=d.quest,pin=pin,mapOnly=true,explicit=true,destinationKind=d.kind},d.dungeon)
   local seconds=N.Estimate(from,candidate)
   if seconds and (not cost or seconds<cost) then best,cost,reason=candidate,seconds,nil end
  end
 end
 best.roots=d.roots
 best.key=d.key
 best.origin=d.origin or d.target.origin
 return best,cost,reason
end
function N.Stop()
 N.Call("Cancel",N.owner)
 A.ClearWaypoint()
 N.current=nil
 A.locationTarget=nil; A.target=nil
end
function N.Go(d,held)
 if not d then A.Print("No recorded coordinates for this location."); return false end
 if A.Safe(InCombatLockdown) then A.Print("Start navigation after combat."); return false end
 -- A destination click should hand straight to the user's TomTom arrow.
 if TomTom and type(TomTom.AddWaypoint)=="function" then
  N.Stop()
  local waypoint=A.Safe(TomTom.AddWaypoint,TomTom,d.map,d.x,d.y,{title=d.title,persistent=false,minimap=true,world=true,crazy=true,from=N.owner})
  if waypoint then
   A.tomtom=waypoint
   A.Safe(TomTom.SetCrazyArrow,TomTom,waypoint,15,d.title)
   N.current=d; N.provider="tomtom"; N.held=held
   if A.window then A.window:Hide() end
   if A.navigationWindow then A.navigationWindow:Hide() end
   return true
  end
  A.Print("TomTom could not set this destination."); return false
 end
 local api=N.API()
 if api and (type(api.NavigateRoute)=="function" or type(api.Navigate)=="function") then
  local ok
  if type(api.NavigateRoute)=="function" then
   local stop={map=d.map,x=d.x,y=d.y,title=d.title,kind=d.kind,npc=d.npc,
    questID=d.questID,hold=held or nil,tooltip=d.quest}
   if d.kind=="turnin" and d.questID then stop.handins={d.questID} end
   ok=N.Call("NavigateRoute",N.owner,{stop})
  else ok=N.Call("Navigate",N.owner,d.map,d.x,d.y,d.title,d.kind) end
  if ok~=true then A.Print("Shortest Path could not start this journey (loading, combat, disabled journeys or unavailable location). Try again."); return false end
  A.ClearWaypoint(); A.locationTarget=nil; A.target=nil; N.current=d; N.provider="spf"; N.held=held
  return true
 end
 N.current=d; N.provider="map"
 return A.NavigateMap(d.target)==true
end
function A.Navigate(q)
 if A.collection then A.collection.running=false end
 if q and q.mapOnly and q.origin then q=A.MapLocation(q.origin) end
 local d=N.Destination(q,A.db and A.db.dungeon)
 if d and not q.explicit then d=N.Best(N.Position(),d) end
 return N.Go(d)
end
function N.Progress()
 local d=N.current
 if not d then return end
 if N.provider=="spf" then
  local reason=N.Call("Ended",N.owner)
  if reason=="replaced" or reason=="cleared" or reason=="arrived" then
   N.current=nil
   if A.collection then A.collection.running=false end
   return
  end
 end
 if A.collection and A.collection.running then return end
 if d.origin or d.target.origin then
  local target=A.MapLocation(d.origin or d.target.origin)
  local nextDestination=N.Destination(target,d.dungeon)
  if not nextDestination then N.Stop()
  elseif nextDestination.key~=d.key then N.Go(nextDestination) end
 end
end
