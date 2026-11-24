local CreateFrame = ForeverButtonControls and ForeverButtonControls:Factory("DungeonGuideForever","Dungeon Questie","NavigationWindow",false) or function(...) return _G.CreateFrame(...) end
local _, A = ...
local N,R=A.Navigation,A.RoutePlanner
local panel,mode,entries,page
local function label(parent,size,x,y,width)
 local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
 t:SetFont("Fonts\\FRIZQT__.TTF",size,""); t:SetPoint("TOPLEFT",x,y); t:SetWidth(width); t:SetJustifyH("LEFT")
 t:SetTextColor(0.22,0.15,0.09)
 return t
end
local function button(parent,title,width,x,y,action)
 local b=CreateFrame("Button",nil,parent)
 b:SetSize(width,24); b:SetPoint("TOPLEFT",x,y)
 local caption=label(b,12,0,-4,width); caption:SetJustifyH("CENTER")
 b.SetText=function(_,value) caption:SetText(value) end
 b:SetText(title); b:SetScript("OnClick",action)
 local hover=b:CreateTexture(nil,"BACKGROUND"); hover:SetAllPoints(); hover:SetColorTexture(0.45,0.25,0.05,0.16); hover:Hide()
 b:SetScript("OnEnter",function() hover:Show() end)
 b:SetScript("OnLeave",function() hover:Hide() end)
 return b
end
local function locationEntries(q)
 local result,seen={},{}
 local p=A.DungeonEntrance(A.db.dungeon)
 if p then result[#result+1]={destination=N.Destination({name=A.db.dungeon,pin=p,mapOnly=true},A.db.dungeon)} end
 local function visit(n)
  if not n or seen[n.id] then return end; seen[n.id]=true
  for _,target in ipairs(A.QuestLocations(n)) do result[#result+1]={destination=N.Destination(target,A.db.dungeon)} end
  for _,field in ipairs({"all","prereqs","any"}) do
   for _,id in ipairs(n[field] or {}) do visit(A.walkthroughs[id] or A.byID[id]) end
  end
 end
 if q then visit(q); visit(A.walkthroughs[q.id] or q)
 else for _,quest in ipairs(A.quests) do if A.InDungeon(quest,A.db.dungeon) then visit(quest) end end end
 return result
end
function A.RefreshRouteWindow()
 if not panel or not panel:IsShown() then return end
 local plan=A.collection
 entries={}
 if mode=="locations" then
  entries=locationEntries(panel.quest)
  panel.title:SetText("Navigate")
  panel.note:SetText("Choose a location and click Navigate. Quest availability is shown in the main journal.")
 elseif mode=="quests" then
  for _,q in ipairs(plan and plan.quests or {}) do entries[#entries+1]={quest=q} end
  panel.title:SetText("Choose quests")
  panel.note:SetText("Exclude quests you do not want to prepare. Shared prerequisites remain when another included quest needs them.")
 else
  panel.title:SetText("Quest route")
  panel.note:SetText(R.busy and "Finding destinations..." or "Click Navigate to set your destination.")
  for _,d in ipairs(plan and plan.stops or {}) do entries[#entries+1]={destination=d} end
  for _,reason in ipairs(plan and plan.blocked or {}) do entries[#entries+1]={blocked=reason} end
 end
 panel.note:SetText(R.busy and "Finding destinations..." or (A.db.dungeon or ""))
 page=math.max(1,math.min(page or 1,math.max(1,math.ceil(#entries/8))))
 for i,row in ipairs(panel.rows) do
  local entry=entries[(page-1)*8+i]
  row.entry=entry
  if entry then
   row:Show(); row.action:Show()
   if entry.destination then
    local d=entry.destination
    local names=d.actions or {}; if not d.actions then for _,q in ipairs(d.roots or {}) do names[#names+1]=q.name end end
    local actions={}
    for j=1,math.min(3,#names) do
     actions[#actions+1]=names[j]:gsub("^pickup: ","Pick up: "):gsub("^turnin: ","Turn in: "):gsub("^objective: ","Objective: ")
    end
    if #names>3 then actions[#actions+1]="+"..(#names-3).." more quests" end
    row.tip="Navigate to "..d.title
    if #actions>0 then row.tip=row.tip.."\n"..table.concat(actions,"\n") end
    if d.kind=="dungeon" then row.tip=row.tip.."\nEntrance approach; not an interior quest location." end
    row.text:SetText(d.title)
    local kinds={pickup="Pick up",turnin="Turn in",objective="Objective",dungeon="Entrance"}
    row.subtitle:SetText((kinds[d.kind] or "Location").."  |  "..(d.target.pin.zone or "")..(d.seconds and ("  |  ~"..math.ceil(d.seconds/60).." min") or ""))
    local icons={pickup="AvailableQuestIcon",turnin="ActiveQuestIcon"}
    row.icon:SetTexture(icons[d.kind] and ("Interface\\GossipFrame\\"..icons[d.kind]) or "Interface\\Icons\\INV_Misc_Map_01")
    row.action:SetText(">")
   elseif entry.quest then
    row.tip=(plan.excluded[entry.quest.id] and "Include in route: " or "Exclude from route: ")..entry.quest.name
    row.text:SetText(entry.quest.name)
    row.subtitle:SetText(plan.excluded[entry.quest.id] and "Excluded" or "Included")
    row.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    row.action:SetText(plan.excluded[entry.quest.id] and "+" or "-")
   else row.tip=entry.blocked; row.text:SetText("Unavailable"); row.subtitle:SetText(entry.blocked); row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); row.action:Hide() end
  else row:Hide() end
 end
 panel.paging:SetText(page.." / "..math.max(1,math.ceil(#entries/8)))
 local multiple=#entries>8
 local footer=panel.expanded and 84 or 48
 if multiple then footer=footer+32 end
 panel:SetHeight(105+math.max(1,math.min(8,#entries))*59+footer)
 panel.previous:SetShown(multiple); panel.next:SetShown(multiple); panel.paging:SetShown(multiple)
 for _,control in ipairs({panel.previous,panel.next,panel.paging}) do control:ClearAllPoints() end
 panel.previous:SetPoint("BOTTOMLEFT",18,footer-28)
 panel.paging:SetPoint("BOTTOMLEFT",110,footer-22)
 panel.next:SetPoint("BOTTOMLEFT",198,footer-28)
 for _,b in ipairs(panel.advanced) do b:SetShown(panel.expanded==true) end
 panel.more:SetText(panel.expanded and "Options -" or "Options +")
 panel.start:SetShown(mode=="route" and plan and #plan.stops>1)

end
local function create()
 if panel then return end
 panel=CreateFrame("Frame","DungeonQuestieNavigation",UIParent,"BackdropTemplate")
 A.navigationWindow=panel
 panel:SetSize(700,670); panel:SetPoint("CENTER"); panel:SetFrameStrata("DIALOG"); panel:SetClampedToScreen(true)
 panel:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
 local parchment=panel:CreateTexture(nil,"BACKGROUND",nil,1)
 parchment:SetPoint("TOPLEFT",12,-72); parchment:SetPoint("BOTTOMRIGHT",-12,12); parchment:SetAtlas("QuestBG-Parchment")
 local line=panel:CreateTexture(nil,"ARTWORK"); line:SetPoint("TOPLEFT",12,-71); line:SetPoint("TOPRIGHT",-12,-71); line:SetHeight(1); line:SetColorTexture(0.65,0.44,0.16,0.85)
 panel:EnableMouse(true); panel:SetMovable(true); panel:RegisterForDrag("LeftButton")
 panel:SetScript("OnDragStart",function(self) self:StartMoving() end); panel:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
 panel:SetFrameLevel(200)
 local close=button(panel,"x",28,652,-18,function() panel:Hide() end)
 close:SetText("|cffffd259x|r")
 panel.title=label(panel,17,18,-18,635); panel.note=label(panel,11,22,-48,635)
 panel.title:SetTextColor(1,0.82,0.35); panel.note:SetTextColor(0.82,0.77,0.65)
 panel.rows={}
 for i=1,8 do
  local row=CreateFrame("Button",nil,panel); row:SetSize(660,55); row:SetPoint("TOPLEFT",18,-105-(i-1)*59)
  row:RegisterForClicks("LeftButtonUp")
  local bg=row:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1,0.88,0.56,i%2==0 and 0.22 or 0.4)
  row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(28,28); row.icon:SetPoint("LEFT",10,0)
  row.text=label(row,13,50,-7,495); row.text:SetHeight(19)
  row.subtitle=label(row,10,50,-30,495); row.subtitle:SetHeight(16)
  row:EnableMouse(true)
  local hover=row:CreateTexture(nil,"HIGHLIGHT"); hover:SetAllPoints(); hover:SetColorTexture(0.45,0.25,0.05,0.16)
  row:SetScript("OnEnter",function(self)
   GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(self.tip or self.text:GetText() or "",1,1,1,true); GameTooltip:Show()
  end)
  row:SetScript("OnLeave",function() GameTooltip:Hide() end)
  row.action=label(row,12,610,-19,40); row.action:SetJustifyH("CENTER"); row.action:SetText(">")
  row:SetScript("OnClick",function()
   local e=row.entry
   if not e or (not e.destination and not e.quest) then return end
   if e.destination then
    if A.collection then A.collection.running=false end
    N.Go(e.destination)
   elseif e.quest then
    local plan=A.collection; plan.excluded[e.quest.id]=not plan.excluded[e.quest.id]; R.Recalculate(false)
   end
   A.RefreshRouteWindow()
  end)
  panel.rows[i]=row
 end
 panel.previous=button(panel,"<",80,18,-583,function() page=math.max(1,page-1); A.RefreshRouteWindow() end)
 panel.paging=label(panel,12,110,-589,90)
 panel.next=button(panel,">",80,198,-583,function() page=page+1; A.RefreshRouteWindow() end)
 panel.advanced={}
 local function option(title,width,x,action)
  local b=button(panel,title,width,x,-583,action); b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT",x,46)
  panel.advanced[#panel.advanced+1]=b
 end
 option("Quest icons",110,513,function() A.ShowRaidMarks() end)
 option("Route",75,18,function() mode="route"; page=1; A.RefreshRouteWindow() end)
 option("Quests",75,98,function() mode="quests"; page=1; A.RefreshRouteWindow() end)
 option("Locations",95,178,function() mode="locations"; panel.quest=nil; page=1; A.RefreshRouteWindow() end)
 option("Skip stop",100,283,function() R.Skip() end)
 option("Recalculate",110,393,function() R.Recalculate(true) end)
 panel.more=button(panel,"Options +",120,18,-624,function() panel.expanded=not panel.expanded; A.RefreshRouteWindow() end)
 panel.more:ClearAllPoints(); panel.more:SetPoint("BOTTOMLEFT",18,14)
 local cancel=button(panel,"Stop",155,148,-624,function() R.Cancel() end)
 cancel:ClearAllPoints(); cancel:SetPoint("BOTTOMLEFT",148,14)
 panel.start=button(panel,"Collect quests",130,313,-624,function() R.Start(); mode="route"; A.RefreshRouteWindow() end)
 panel.start:ClearAllPoints(); panel.start:SetPoint("BOTTOMLEFT",313,14)
 if UISpecialFrames then table.insert(UISpecialFrames,"DungeonQuestieNavigation") end
end
function A.OpenNavigation(q,locations)
 create()
 if not A.collection or A.collection.dungeon~=A.db.dungeon then
  R.Cancel(); A.collection={dungeon=A.db.dungeon,quests={},stops={},blocked={},excluded={},skipped={}}; R.Recalculate(false)
 end
 mode=locations and "locations" or "route"; panel.quest=q; page=1
 panel:Show(); A.RefreshRouteWindow()
end
