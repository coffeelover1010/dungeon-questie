local _, A = ...
local N=A.Navigation
local R={}; A.RoutePlanner=R
function R.Build(dungeon,excluded,skipped,yieldWork)
 local plan={dungeon=dungeon,stops={},blocked={},quests={},excluded=excluded or {},skipped=skipped or {}}
 local candidates={}
 A.LoadLocations()
 for _,q in ipairs(A.quests) do
  if A.InDungeon(q,dungeon) and not A.Restriction(q) and (not A.ChecklistVisible or A.ChecklistVisible(q)) then
   plan.quests[#plan.quests+1]=q
   if not plan.excluded[q.id] and A.Completed(q.id)~=true then
    local step,phase,note=A.WalkStep(q)
    local ready=A.RunReadiness(q)
    -- Already collected dungeon quests and inside pickups are for the run.
    if not ready and phase~="done" and phase~="skipped" then
     local target
     if phase=="pickup" or phase=="active" or phase=="packed" or phase=="ready" then target=A.MapLocation(q) end
     if target and target.pin.kind~="entrance" then
      local d=N.Destination(target,dungeon)
      if d and not plan.skipped[d.key] then
       d.roots={q}; candidates[#candidates+1]=d
      elseif d then plan.blocked[#plan.blocked+1]=q.name..": stop skipped (Recalculate restores skipped stops)."
      else plan.blocked[#plan.blocked+1]=q.name..": recorded coordinates are invalid." end
     else
      plan.blocked[#plan.blocked+1]=q.name..": "..(note or (phase=="inside" and "Collect inside the dungeon." or "Current step has no reliable actionable location; see quest details."))
     end
    end
   end
  end
 end
 -- Greedy travel-time ordering of currently eligible steps only. Future steps
 -- unlock after actual quest progress, never simulated acceptance/turn-in.
 local from=N.Position()
 while #candidates>0 do
  local best,bestCost,bestReason=1,nil,nil
  local localBest,localDistance,localReason
  for i,d in ipairs(candidates) do
   if yieldWork then yieldWork() end
   local chosen,cost,reason=N.Best(from,d,yieldWork)
   candidates[i]=chosen
   if cost and (not bestCost or cost<bestCost) then best,bestCost,bestReason=i,cost,nil
   elseif i==1 and not bestCost then bestReason=reason end
   -- Without travel estimates, finish nearby actions on this map first.
   -- Map percentages are only comparable within the same map; this is an
   -- approximate proximity order, never an invented travel-time estimate.
   if not cost and reason~="unreachable" and reason~="invalid" and from and chosen.map==from.map then
    local distance=(chosen.x-from.x)^2+(chosen.y-from.y)^2
    if not localDistance or distance<localDistance then
     localBest,localDistance,localReason=i,distance,reason
    end
   end
  end
  if not bestCost and localBest then best,bestReason=localBest,localReason end
  local d=table.remove(candidates,best)
  d.seconds=bestCost; d.estimateReason=bestReason
  if bestReason=="unreachable" or bestReason=="invalid" then
   plan.blocked[#plan.blocked+1]=d.quest..": "..bestReason
  else
   -- Co-located actions share one stop and retain all associated quests.
   d.keys={d.key}; d.actions={d.kind..": "..d.quest}
   for i=#candidates,1,-1 do
    local other=candidates[i]
    if other.map==d.map and other.x==d.x and other.y==d.y then
     for _,q in ipairs(other.roots) do d.roots[#d.roots+1]=q end
     d.mixed=d.mixed or other.kind~=d.kind
     d.keys[#d.keys+1]=other.key; d.actions[#d.actions+1]=other.kind..": "..other.quest
     table.remove(candidates,i)
    end
   end
   plan.stops[#plan.stops+1]=d; from=d
  end
 end
 local p=A.DungeonEntrance(dungeon)
 if p then
  local d=N.Destination({name=dungeon,pin=p,mapOnly=true,explicit=true},dungeon)
  if not d then plan.blocked[#plan.blocked+1]="Dungeon entrance coordinates are invalid."; return plan end
  d.seconds,d.estimateReason=N.Estimate(from,d); d.deferred=#plan.blocked>0 or #plan.stops>0
  if d.estimateReason=="unreachable" or d.estimateReason=="invalid" then
   plan.blocked[#plan.blocked+1]="Dungeon entrance: "..d.estimateReason; d.deferred=true
  end
  plan.entrance=d
  plan.stops[#plan.stops+1]=d
 else plan.blocked[#plan.blocked+1]="Dungeon entrance coordinates unavailable." end
 return plan
end
function R.Recalculate(reset)
 local old=A.collection; if not old then return end
 R.generation=(R.generation or 0)+1; local generation=R.generation
 R.busy=true
 local count=0
 local job=coroutine.create(function()
  return R.Build(old.dungeon,old.excluded,reset and {} or old.skipped,function()
   count=count+1
   if count%8==0 and C_Timer and C_Timer.After then coroutine.yield() end
  end)
 end)
 local function resume()
  if generation~=R.generation then return end
  local ok,plan=coroutine.resume(job)
  if not ok then R.busy=false; old.running=false; A.Print("Route planning failed; try Recalculate."); return end
  if coroutine.status(job)~="dead" then C_Timer.After(0,resume); return end
  R.busy=false; plan.running=old.running; A.collection=plan
  if plan.running then R.Advance() end
  if A.RefreshRouteWindow then A.RefreshRouteWindow() end
 end
 resume()
end
function R.Advance()
 local plan=A.collection; if not plan or not plan.running then return end
 local d=plan.stops[1]
 if not d or (d.kind=="dungeon" and #plan.blocked>0) then
  N.Stop(); plan.running=false; A.Print("Preparation is blocked. Review the route preview."); return
 end
 if N.current and N.current.key==d.key and N.current.map==d.map and N.current.x==d.x and N.current.y==d.y
  and (N.provider~="spf" or N.held or d.kind=="dungeon") then return end
 if not N.Go(d,d.kind~="dungeon") then plan.running=false end
end
function R.Start()
 if not A.collection then return end
 A.collection.running=true; R.Recalculate(false)
end
function R.Skip()
 local plan=A.collection; if not plan then return end
 local d=plan.stops[1]; if not d then return end
 for _,key in ipairs(d.keys or {d.key}) do plan.skipped[key]=true end
 N.Stop(); R.Recalculate(false)
end
function R.Cancel()
 R.generation=(R.generation or 0)+1; R.busy=false
 if A.collection then A.collection.running=false end
 N.Stop()
 if A.RefreshRouteWindow then A.RefreshRouteWindow() end
end
-- Called after the existing debounced quest scan. A signature prevents repeated
-- log notifications from doing route searches without a meaningful change.
function R.Progress()
 N.Progress()
 local plan=A.collection; if not plan then return end
 local parts={tostring(A.Safe(UnitLevel,"player"))}
 for _,q in ipairs(plan.quests) do
  local n,phase,note=A.WalkStep(q)
  local t=A.MapLocation(q); local d=N.Destination(t)
  parts[#parts+1]=q.id..":"..n.id..":"..phase..":"..(note or "")..":"..(d and d.key or "")
 end
 local signature=table.concat(parts,"|")
 if signature==R.signature then return end
 R.signature=signature; R.Recalculate(false)
end
-- Yield to another guide or a user cancellation; never steal its route back.
local function subscribe()
 if R.subscribed then return end
 local api=N.API(); if not api or type(api.Subscribe)~="function" then return end
 local unsub=N.Call("Subscribe",function(changes)
  if not changes.ended and not changes.stop then return end
  local reason=N.Call("Ended",N.owner)
  if reason=="replaced" or reason=="cleared" or reason=="arrived" then
   if A.collection then A.collection.running=false end
   N.current=nil
   if A.RefreshRouteWindow then A.RefreshRouteWindow() end
  end
 end)
 R.subscribed=type(unsub)=="function"
end
local watcher=CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN"); watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent",subscribe)
