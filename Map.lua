local _, A = ...
local pins={}
local function valid(p)
 local info=A.Safe(C_Map and C_Map.GetMapInfo,p.map)
 if not info then return false end
 local locale=GetLocale()
 return (locale~="enUS" and locale~="enGB") or info.name==p.zone
end
function A.ClearWaypoint()
 if A.tomtom and TomTom and TomTom.RemoveWaypoint then A.Safe(TomTom.RemoveWaypoint,TomTom,A.tomtom) end
 A.tomtom=nil
 -- Only clear the native waypoint if it still matches the one we placed.
 local now=A.Safe(C_Map and C_Map.GetUserWaypoint)
 if now and A.waypoint and now.uiMapID==A.waypoint.map and now.position then
  -- Forever can return a plain coordinate table without Vector2D methods.
  local x,y=now.position.x,now.position.y
  if type(now.position.GetXY)=="function" then
   local ok,vx,vy=pcall(now.position.GetXY,now.position)
   if ok then x,y=vx,vy end
  end
  if type(x)=="number" and type(y)=="number" and math.abs(x-A.waypoint.x/100)<0.00001 and math.abs(y-A.waypoint.y/100)<0.00001 then A.Safe(C_Map and C_Map.ClearUserWaypoint) end
 end
 A.waypoint=nil
end
function A.Navigate(q)
 if not A.NeedsPickup(q) then A.Print("You already have or completed "..q.name..". Open its quest log for the next destination."); return end
 local p=q.pin
 if not p then A.Print("No verified pickup pin for "..q.name..". See its pickup directions."); return end
 if InCombatLockdown() then A.Print("Set a waypoint after combat."); return end
 if not valid(p) then A.Print("Map does not match this client: "..p.zone.." "..p.x..", "..p.y); return end
 A.ClearWaypoint()
 local set=false
 if UiMapPoint and C_Map and A.Safe(C_Map.CanSetUserWaypointOnMap,p.map) then
  set=A.Safe(C_Map.SetUserWaypoint,UiMapPoint.CreateFromCoordinates(p.map,p.x/100,p.y/100))==true
  if set then A.waypoint=p end
 end
 if TomTom and TomTom.AddWaypoint then
  A.tomtom=A.Safe(TomTom.AddWaypoint,TomTom,p.map,p.x/100,p.y/100,{title=q.name.." - "..p.title..(p.reference and " (Classic reference)" or ""),persistent=false,minimap=true,world=true})
  set=set or A.tomtom~=nil
 end
 A.target=q.id
 A.db.pins=true
 if OpenWorldMap then OpenWorldMap(p.map)
 elseif WorldMapFrame then WorldMapFrame:Show() end
 if WorldMapFrame and WorldMapFrame:IsShown() then
  if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(p.map) end
  -- The guide uses DIALOG strata and would otherwise cover the world map.
  if A.window then A.window:Hide() end
 end
 local drawn=A.RefreshPins()
 A.Print(q.name..": "..p.zone.." "..p.x..", "..p.y..(set and " (waypoint set)" or (drawn and drawn>0 and " (pickup marked on world map)" or " (coordinates; map marker unavailable)")))
 if p.reference then A.Print("Classic reference pin - approximate; not verified in Forever.") end
end
function A.RefreshPins()
 local map=WorldMapFrame
 if not A.db or not A.db.pins or not map or not map:IsShown() or not map.GetCanvas or not map.GetMapID then for _,p in ipairs(pins) do p:Hide() end; return 0 end
 local canvas=map:GetCanvas(); if not canvas then for _,p in ipairs(pins) do p:Hide() end; return 0 end
 local mapID=map:GetMapID(); local groups={}; local order={}
 local candidates={}
 for _,q in ipairs(A.quests) do candidates[#candidates+1]=q end
 local step=A.walkthroughs and A.walkthroughs[A.target]
 if step and not A.byID[step.id] then candidates[#candidates+1]=step end
 for _,q in ipairs(candidates) do
  local p=q.pin; local s=A.state[q.id]
  if p and A.NeedsPickup(q) and p.map==mapID and valid(p) and (q.id==A.target or (A.Preparation(q)=="pickup" and A.Matches(q))) then
   local key=p.x..":"..p.y
   if not groups[key] then groups[key]={p=p,quests={}}; order[#order+1]=key end
   table.insert(groups[key].quests,q)
  end
 end
 for i,key in ipairs(order) do
  local group=groups[key]; local b=pins[i]
  if not b then
   b=CreateFrame("Button",nil,canvas); b:SetSize(24,24)
   b.icon=b:CreateTexture(nil,"OVERLAY"); b.icon:SetAllPoints(); b.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
   b.icon:SetDesaturated(true); b.icon:SetVertexColor(0.2,1,0.3)
   b:SetScript("OnEnter",function(self)
    GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine("Dungeon Questie - pickup",0.2,1,0.3)
    GameTooltip:AddLine(self.group.p.title,1,1,1)
    if self.group.p.reference then GameTooltip:AddLine("Classic reference - approximate; not verified in Forever.",1,0.8,0.3,true) end
    for _,q in ipairs(self.group.quests) do GameTooltip:AddLine(q.name.." - "..(A.labels[A.state[q.id]] or ""),0.8,0.9,1) end
    GameTooltip:AddLine("Click to open the quest. Shift-click to set a waypoint.",0.7,0.7,0.7,true); GameTooltip:Show()
   end)
   b:SetScript("OnLeave",function() GameTooltip:Hide() end)
   b:SetScript("OnClick",function(self)
    local q=self.group.quests[1]
    if IsShiftKeyDown() then A.Navigate(q) else A.SelectQuest(q) end
   end)
   pins[i]=b
  end
  b:SetParent(canvas); b:SetFrameLevel(canvas:GetFrameLevel()+30); b.group=group
  b:ClearAllPoints(); b:SetPoint("CENTER",canvas,"TOPLEFT",canvas:GetWidth()*group.p.x/100,-canvas:GetHeight()*group.p.y/100); b:Show()
 end
 for i=#order+1,#pins do pins[i]:Hide() end
 return #order
end
local watcher=CreateFrame("Frame")
local elapsed=0
watcher:SetScript("OnUpdate",function(_,delta)
 elapsed=elapsed+delta; if elapsed<0.5 then return end; elapsed=0
 if WorldMapFrame and WorldMapFrame:IsShown() then A.RefreshPins() end
end)
