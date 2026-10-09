local _, A = ...
A.labels={done="TURNED IN",ready="READY TO TURN IN",active="IN QUEST LOG",restricted="CHECK ELIGIBILITY",level="LEVEL TOO LOW",prereq="EARLIER QUEST LISTED IN GUIDE",unknown="SCAN UNAVAILABLE",todo="TO PICK UP"}
local colors={done={0.16,0.36,0.14},ready={0.48,0.27,0.04},active={0.12,0.29,0.43},restricted={0.38,0.34,0.28},level={0.55,0.16,0.10},prereq={0.40,0.24,0.38},unknown={0.55,0.16,0.10},todo={0.30,0.23,0.15}}
local selected,rows,dungeonButtons,rewardButtons=nil,{},{},{}
local function readableStatus(label)
 local prefix,quest=label:match("^([^:]+): (.+)$")
 local value=(prefix or label):lower()
 value=value:gsub("^%l",string.upper)
 return quest and (value..": "..quest) or value
end
function A.RevealSelectedDungeon()
 local f=A.window
 if not f or not f.dungeonScroll then return end
 for i,b in ipairs(dungeonButtons) do
  if b.dungeon==A.db.dungeon then
   local height=f.dungeonScroll:GetHeight()
   local offset=(i-1)*86-(height-80)/2
   f.dungeonScroll:SetVerticalScroll(math.max(0,math.min(offset,math.max(0,f.dungeonChild:GetHeight()-height))))
   return
  end
 end
end
local function text(parent,size,x,y,w)
 local t=parent:CreateFontString(nil,"OVERLAY"); t:SetFont("Fonts\\FRIZQT__.TTF",size,"")
 t:SetPoint("TOPLEFT",x,y); t:SetWidth(w); t:SetJustifyH("LEFT"); t:SetJustifyV("TOP"); t:SetTextColor(0.22,0.15,0.09)
 return t
end
local function button(parent,label,w,x,y,fn)
 local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetSize(w,25); b:SetPoint("TOPLEFT",x,y); b:SetText(label)
 b:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up"); b:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
 b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight"); b:SetDisabledTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
 for _,texture in ipairs({b:GetNormalTexture(),b:GetPushedTexture(),b:GetHighlightTexture(),b:GetDisabledTexture()}) do texture:SetTexCoord(0,0.625,0,0.6875) end
 b:SetScript("OnClick",fn); return b
end
local function iconButton(parent,label,icon,x,y,fn)
 local b=CreateFrame("Button",nil,parent); b:SetSize(32,32); b:SetPoint("TOPLEFT",x,y)
 b:SetNormalTexture(icon); b:SetPushedTexture(icon)
 b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
 b:SetScript("OnClick",fn)
 b:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(self.tip or label); GameTooltip:Show() end)
 b:SetScript("OnLeave",function() GameTooltip:Hide() end)
 b:SetScript("OnEnable",function(self) self:GetNormalTexture():SetDesaturated(false); self:SetAlpha(1) end)
 b:SetScript("OnDisable",function(self) self:GetNormalTexture():SetDesaturated(true); self:SetAlpha(0.4) end)
 return b
end
local function scroll(parent,x,y,w,h)
 local s=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate"); s:SetPoint("TOPLEFT",x,y); s:SetSize(w,h)
 local child=CreateFrame("Frame",nil,s); child:SetSize(w,1); s:SetScrollChild(child); return s,child
end
local function itemTooltip(self)
 GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:"..self.item.id); GameTooltip:Show()
end
local function itemClick(self)
 local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
 local link
 if fn then local _,l=fn(self.item.id); link=l end
 if IsShiftKeyDown() and link and ChatEdit_InsertLink then ChatEdit_InsertLink(link)
 elseif DressUpItemLink then DressUpItemLink(link or ("item:"..self.item.id)) end
end
local function questName(id, owner)
 local q=A.byID[id]
 if q then return q.name end
 for _,c in ipairs(owner.chain or {}) do if c.id==id then return c.name end end
 return A.Safe(C_QuestLog and C_QuestLog.GetTitleForQuestID,id) or ("Quest "..id)
end
function A.PickupSteps(q)
 if A.WalkInstructions then
  local instructions,target,heading=A.WalkInstructions(q)
  if instructions then return instructions,target,heading end
 end
 if not A.NeedsPickup(q) then
  if A.Completed(q.id)==true or A.state[q.id]=="done" then return "You have turned in this quest.",nil,"Completed" end
  if q.id==1198 then return "Collected for your run. You do not need to visit the pickup NPC again.\nOnce inside Blackfathom Deeps, seek out Argent Guard Thaelrid.",nil,"Collected for your run" end
  local ready=A.log[q.id] and A.log[q.id].complete
  local lines={"Already in your quest log.",ready and "The quest log marks this ready to turn in." or "Follow the objectives in your quest log during your run."}
  if ready then
   for _,person in ipairs(q.people or {}) do
    if person:find("Turned in to:",1,true)==1 then table.insert(lines,"Guide lists: "..person:sub(15)) end
   end
  end
  table.insert(lines,"Open your quest log for the current destination. No verified destination pin is recorded here.")
  return table.concat(lines,"\n"),nil,"Collected for your run"
 end
 local lines={}
 if q.preparationNote then table.insert(lines,q.preparationNote) end
 if A.Restriction(q) then table.insert(lines,A.Restriction(q)) end
 if q.minLevel and UnitLevel("player")<q.minLevel then table.insert(lines,"Guide minimum level: "..q.minLevel..".") end
 if q.pickupInside then table.insert(lines,"Get inside "..q.dungeons[1]..".") end
 table.insert(lines,"Pick up this quest from:")
 table.insert(lines,q.pickup or "Pickup location not recorded in this guide.")
 if q.pin then
  table.insert(lines,string.format("%s: %.1f, %.1f",q.pin.zone,q.pin.x,q.pin.y))
  table.insert(lines,"Click Show pickup on map.")
 end
 local earlier={}
 for _,id in ipairs(q.prereqs or {}) do
  if A.Completed(id)~=true then table.insert(earlier,questName(id,q)) end
 end
 if #earlier>0 then
  table.insert(lines,"\nIf the quest is not offered: the guide lists these earlier quests, but they may not be required in Forever:")
  for _,title in ipairs(earlier) do table.insert(lines,"- "..title) end
  for _,id in ipairs(q.prereqs or {}) do
   local prior=A.byID[id]
   if prior and A.Completed(id)~=true then
    table.insert(lines,prior.name..": "..(A.log[id] and "Already in your log; check its objectives." or prior.pickup or "Pickup not recorded."))
   end
  end
 end
 return table.concat(lines,"\n"),q
end
local function details()
 local f=A.window; local q=selected
 for _,b in ipairs(rewardButtons) do b:Hide() end
 local instructions,target,heading
 if q then instructions,target,heading=A.PickupSteps(q) end
 f.pickupTarget=target
 f.mapButton:SetEnabled(target and target.pin~=nil or false)
 local current=q and A.WalkStep and A.WalkStep(q) or q
 f.currentQuest=current
 f.source:SetEnabled(q~=nil); f.logButton:SetEnabled(current and A.log[current.id]~=nil or false)
 for _,b in ipairs({f.mapButton,f.logButton,f.source}) do b:SetShown(q~=nil) end
 if not q then
  f.detailTitle:SetText("Select a quest"); f.metadata:Hide()
  local note="Choose a dungeon, then select a quest from the list."
  for _,d in ipairs(A.dungeons) do if d.name==A.db.dungeon then note=d.note end end
  f.detailText:SetText(note); f.detailChild:SetHeight(480); return
 end
 local s=A.state[q.id] or "unknown"
 f.detailTitle:SetText(q.name)
 f.metadata:Show()
 f.levelBadge.label:SetText(q.minLevel and tostring(q.minLevel) or "?")
 local underLevel=q.minLevel and UnitLevel("player")<q.minLevel
 f.levelBadge.label:SetTextColor(underLevel and 0.7 or 0.18,underLevel and 0.12 or 0.38,0.08)
 f.levelBadge.tip=q.minLevel and ("Minimum level: "..q.minLevel) or "Minimum level unknown"
 f.factionBadge:SetShown(q.faction~=nil)
 if q.faction then
  f.factionBadge.icon:SetTexture("Interface\\PVPFrame\\PVP-Currency-"..q.faction)
  f.factionBadge.tip=q.faction.." only"
 end
 f.classBadge:SetShown(q.class~=nil)
 if q.class then
  f.classBadge.tip=q.class.." only"
  local coords=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[q.class]
  f.classBadge.icon:SetTexture(coords and "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES" or "Interface\\Icons\\INV_Misc_QuestionMark")
  if coords then f.classBadge.icon:SetTexCoord(unpack(coords)) else f.classBadge.icon:SetTexCoord(0,1,0,1) end
 end
 local badgeWidth=28+(q.faction and 28 or 0)+(q.class and 28 or 0)
 f.detailTitle:SetWidth(313-badgeWidth-8)
 f.classBadge:ClearAllPoints(); f.classBadge:SetPoint("RIGHT",q.faction and -56 or -28,0)
 local contentTop=91+math.max(24,f.detailTitle:GetStringHeight())+10
 f.detailScroll:ClearAllPoints(); f.detailScroll:SetPoint("TOPLEFT",604,-contentTop); f.detailScroll:SetHeight(math.max(180,630-contentTop))
 local lines={"|cff684018"..(heading or "Where to pick it up").."|r",instructions}
 local live=A.Safe(C_QuestLog and C_QuestLog.GetQuestObjectives,q.id)
 if current==q and A.log[q.id] and type(live)=="table" and #live>0 then
  table.insert(lines,"\n|cff684018Objectives|r")
  for _,o in ipairs(live) do table.insert(lines,(o.finished and "[x] " or "[ ] ")..(o.text or "Objective")) end
 elseif current==q and A.log[q.id] and #(q.objectives or {})>0 then
  table.insert(lines,"\n|cff684018Objectives|r")
  for _,o in ipairs(q.objectives) do table.insert(lines,"- "..o) end
 end
 if not A.WalkStep and (#(q.prereqs or {})>0 or #(q.chain or {})>0) then
  table.insert(lines,"\n|cff684018Quest chain|r")
  for _,id in ipairs(q.prereqs or {}) do
   local prior=A.byID[id]; local title=prior and prior.name or A.Safe(C_QuestLog and C_QuestLog.GetTitleForQuestID,id) or ("Quest "..id)
   table.insert(lines,(A.Completed(id)==true and "[x] " or "[ ] ")..title.." ("..id..")")
  end
  for _,c in ipairs(q.chain or {}) do table.insert(lines,c.role..": "..c.name..(c.id and (" ("..c.id..")") or " [ID unverified]")) end
 end
 if current==q and A.log[q.id] and q.routeNote then table.insert(lines,"\n|cff684018Quest directions|r\n"..q.routeNote) end
 if q.repeatable then table.insert(lines,"Repeatable; excluded from the one-time completion total.") end
 if #(q.rewards or {})>0 then table.insert(lines,"\n|cff684018Rewards|r") end
 f.detailText:SetText(table.concat(lines,"\n"))
 local y=-(f.detailText:GetStringHeight()+10)
 for i,item in ipairs(q.rewards or {}) do
  local b=rewardButtons[i]
  if not b then
   b=CreateFrame("Button",nil,f.detailChild); b:SetSize(298,32)
   b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetSize(26,26); b.icon:SetPoint("LEFT")
   b.label=text(b,12,34,-4,260); b:SetScript("OnEnter",itemTooltip); b:SetScript("OnLeave",function() GameTooltip:Hide() end); b:SetScript("OnClick",itemClick); rewardButtons[i]=b
  end
  b.item=item; b:ClearAllPoints(); b:SetPoint("TOPLEFT",0,y-(i-1)*34); b.label:SetText(item.name)
  local icon=A.Safe(C_Item and C_Item.GetItemIconByID or GetItemIcon,item.id)
  b.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark"); b:Show()
 end
 local actionsY=y-#(q.rewards or {})*34
 for i,b in ipairs({f.mapButton,f.logButton,f.source}) do
  b:ClearAllPoints(); b:SetPoint("TOPLEFT",f.detailChild,"TOPLEFT",(i-1)*44,actionsY)
 end
 f.detailChild:SetHeight(math.max(1,-actionsY+44))
end
function A.Refresh()
 local f=A.window; if not f or not f:IsShown() then return end
 local prep=A.PreparationSummary(A.db.dungeon)
 local remaining=prep.total-prep.done
 f.progress:SetText((remaining==0 and prep.total>0 and "All known quests completed" or (prep.collected.." / "..remaining.." ready for dungeon")).."\n"..prep.done.." completed | "..prep.pickup.." to collect | "..(prep.chain+prep.check).." to check | "..prep.blocked.." not eligible")
 f.heading:SetText(A.db.dungeon)
 local visible={}
 for _,q in ipairs(A.quests) do if A.Matches(q) then visible[#visible+1]=q end end
 table.sort(visible,function(a,b)
  local _,_,ar=A.Preparation(a); local _,_,br=A.Preparation(b)
  if ar~=br then return ar<br end
  local az=a.pin and a.pin.zone or a.pickup or ""; local bz=b.pin and b.pin.zone or b.pickup or ""
  if az~=bz then return az<bz end
  if (a.minLevel or 0)==(b.minLevel or 0) then return a.id<b.id end
  return (a.minLevel or 0)<(b.minLevel or 0)
 end)
 local found=false; for _,q in ipairs(visible) do if q==selected then found=true end end
 if not found then selected=visible[1]; f.detailScroll:SetVerticalScroll(0) end
 local listHeight=0
 for i,q in ipairs(visible) do
  local r=rows[i]
  if not r then
   r=CreateFrame("Button",nil,f.listChild); r:SetSize(334,66)
   r.bg=r:CreateTexture(nil,"BACKGROUND"); r.bg:SetAllPoints()
   for _,edge in ipairs({"TOP","BOTTOM"}) do
    local line=r:CreateTexture(nil,"BORDER"); line:SetColorTexture(0.34,0.22,0.10,0.55); line:SetHeight(1); line:SetPoint(edge.."LEFT"); line:SetPoint(edge.."RIGHT")
   end
   r.selection=r:CreateTexture(nil,"ARTWORK"); r.selection:SetColorTexture(0.65,0.35,0.04,1); r.selection:SetWidth(4); r.selection:SetPoint("TOPLEFT"); r.selection:SetPoint("BOTTOMLEFT")
   r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight"); r:GetHighlightTexture():SetAlpha(0.25)
   r.title=text(r,15,10,-8,314); r.status=text(r,12,10,-36,314); r.meta=text(r,11,10,-54,314)
   r.title:SetTextColor(0.12,0.075,0.035); r.meta:SetTextColor(0.19,0.12,0.06)
   r.general=button(r,"General",94,8,0,function() A.QuestGeneral(r.groupQuest) end)
   r.createGroup=button(r,"Create Group",124,108,0,function() A.QuestCreateGroup(r.groupQuest) end)
   for _,action in ipairs({r.general,r.createGroup}) do
    action:SetScript("OnEnter",function(self)
     GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
     GameTooltip:AddLine(r.groupQuest and r.groupQuest.name or "Group quest")
     GameTooltip:AddLine(self==r.general and "Prepare a General chat message; Enter sends it." or "Open Custom; type the description and click Post.",1,1,1,true)
     GameTooltip:Show()
    end)
    action:SetScript("OnLeave",function() GameTooltip:Hide() end)
   end
   r:SetScript("OnClick",function(self)
    selected=self.quest; f.detailScroll:SetVerticalScroll(0)
    -- Selection changes only the highlight and detail pane, not quest state.
    for index,row in ipairs(rows) do
     local chosen=row.quest==selected
     row.selection:SetShown(chosen)
     row.bg:SetColorTexture(1,0.88,0.62,chosen and 0.90 or (index%2==0 and 0.70 or 0.55))
    end
    details()
   end); rows[i]=r
  end
  r.quest=q; r:ClearAllPoints(); r:SetPoint("TOPLEFT",0,-listHeight)
  local s=A.state[q.id] or "unknown"
  local stage,prepLabel=A.Preparation(q)
  r.title:SetText(q.name); r.status:SetText(readableStatus(prepLabel)); r.status:SetTextColor(unpack(colors[s]))
  r.meta:SetText(not A.NeedsPickup(q) and ((s=="done" and "Quest completed") or (q.id==1198 and "Find Argent Guard Thaelrid inside Blackfathom Deeps") or "See quest log for your next destination") or (q.pickupInside and ("Get inside "..q.dungeons[1]) or (q.pickup or "Pickup location not recorded")))
  if A.WalkStep and A.NeedsPickup(q) then
   local step,phase=A.WalkStep(q)
   if step.id~=q.id then r.meta:SetText(step.pickup or "Open the walkthrough for this step.") end
  end
  local runReady,runReason=A.RunReadiness(q)
  if stage=="done" then
   r.status:SetText("Completed"); r.status:SetTextColor(0.16,0.36,0.14)
   r.meta:SetText("Quest turned in.")
  elseif runReady then
   r.status:SetText("Ready for dungeon"); r.status:SetTextColor(0.12,0.38,0.08)
   r.meta:SetText(runReason)
  end
  -- Measure the final text, including readiness descriptions, before sizing.
  -- Round up scaled font measurements and leave room for wrapped descenders.
  local function lineHeight(label)
   return math.ceil(label:GetStringHeight())+4
  end
  local statusTop=8+lineHeight(r.title)+7
  r.status:ClearAllPoints(); r.status:SetPoint("TOPLEFT",10,-statusTop)
  local metaTop=statusTop+lineHeight(r.status)+5
  r.meta:ClearAllPoints(); r.meta:SetPoint("TOPLEFT",10,-metaTop)
  local rowHeight=math.max(66,metaTop+lineHeight(r.meta)+14)
  local current=A.WalkStep and A.WalkStep(q) or q
  r.groupQuest=current
  local group=A.IsGroupQuest and A.IsGroupQuest(current) and A.Completed(current.id)~=true and not (A.log[current.id] and A.log[current.id].complete) or false
  r.general:SetShown(group); r.createGroup:SetShown(group)
  if group then
   r.general:ClearAllPoints(); r.general:SetPoint("TOPLEFT",8,-rowHeight)
   r.createGroup:ClearAllPoints(); r.createGroup:SetPoint("TOPLEFT",108,-rowHeight)
   rowHeight=rowHeight+30
  end
  r:SetHeight(rowHeight); listHeight=listHeight+rowHeight+8
  r.bg:SetColorTexture(1,0.88,0.62,q==selected and 0.90 or (i%2==0 and 0.70 or 0.55)); r.selection:SetShown(q==selected); r:Show()
 end
 for i=#visible+1,#rows do rows[i]:Hide() end
 f.listChild:SetHeight(math.max(1,listHeight)); f.empty:SetShown(#visible==0)
 f.empty:SetText("No quests match.\nClear the search or choose your dungeon.\n\nNo recorded quests does not mean you have every quest.")
 for _,b in ipairs(dungeonButtons) do
  local c=A.PreparationSummary(b.dungeon)
  local remaining=c.total-c.done
  b:SetText(b.dungeon.."\n"..(remaining==0 and c.total>0 and "Completed" or (c.collected.." / "..remaining.." ready")))
  b:GetFontString():SetTextColor(b.dungeon==A.db.dungeon and 1 or 0.8,b.dungeon==A.db.dungeon and 0.82 or 0.8,0.65)
 end
 f.pinsToggle.tip="Map pins: "..(A.db.pins and "On" or "Off").." - click to toggle"
 for _,texture in ipairs({f.pinsToggle:GetNormalTexture(),f.pinsToggle:GetPushedTexture()}) do texture:SetDesaturated(not A.db.pins) end
 f.pinsToggle:SetAlpha(A.db.pins and 1 or 0.45)
 details()
end
function A.SelectQuest(q)
 A.db.dungeon=q.dungeons[1]; A.db.search=""; selected=q
 if not A.window then A.CreateWindow() end
 A.window.search:SetText(""); A.window:Show(); A.Scan()
 A.RevealSelectedDungeon()
end
function A.CreateWindow()
 if A.window then return end
 local f=CreateFrame("Frame","DungeonGuideForeverWindow",UIParent,"BackdropTemplate"); A.window=f
 f:SetSize(960,650); f:SetPoint("CENTER"); f:SetScale(math.min(1,(UIParent:GetWidth()-35)/960,(UIParent:GetHeight()-35)/650)); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
 f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
 local parchment=f:CreateTexture(nil,"BACKGROUND",nil,1)
 parchment:SetPoint("TOPLEFT",12,-70); parchment:SetPoint("BOTTOMRIGHT",-12,12); parchment:SetAtlas("QuestBG-Parchment")
 local headerBase=f:CreateTexture(nil,"BACKGROUND",nil,2)
 headerBase:SetPoint("TOPLEFT",12,-12); headerBase:SetPoint("TOPRIGHT",-12,-12); headerBase:SetHeight(58); headerBase:SetColorTexture(0.055,0.035,0.02,1)
 local header=f:CreateTexture(nil,"BACKGROUND",nil,3)
 header:SetAllPoints(headerBase); header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background"); header:SetVertexColor(0.65,0.48,0.3,1)
 local headerLine=f:CreateTexture(nil,"ARTWORK")
 headerLine:SetPoint("TOPLEFT",12,-69); headerLine:SetPoint("TOPRIGHT",-12,-69); headerLine:SetHeight(1); headerLine:SetColorTexture(0.65,0.44,0.16,0.85)
 for _,x in ipairs({218,593}) do
  local divider=f:CreateTexture(nil,"ARTWORK"); divider:SetColorTexture(0.35,0.23,0.10,0.35); divider:SetSize(1,556); divider:SetPoint("TOPLEFT",x,-75)
 end
 f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
 f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing(); local p,_,rp,x,y=self:GetPoint(); A.db.position={p,rp,x,y} end)
 if A.db.position then local p=A.db.position; f:ClearAllPoints(); f:SetPoint(p[1],UIParent,p[2],p[3],p[4]) end
 tinsert(UISpecialFrames,"DungeonGuideForeverWindow")
 local crest=f:CreateTexture(nil,"ARTWORK")
 crest:SetSize(40,40); crest:SetPoint("TOPLEFT",23,-20); crest:SetTexture(A.dungeonArtwork["The Hall of Thanes"])
 local crestBorder=f:CreateTexture(nil,"OVERLAY")
 crestBorder:SetSize(52,52); crestBorder:SetPoint("CENTER",crest,"CENTER"); crestBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
 local title=text(f,21,75,-27,350); title:SetText("Dungeon Questie"); title:SetTextColor(1,0.82,0.35); title:SetShadowOffset(1,-1)
 local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-3,-3)
 f.search=CreateFrame("EditBox",nil,f,"InputBoxTemplate"); f.search:SetSize(210,24); f.search:SetPoint("TOPLEFT",480,-23); f.search:SetAutoFocus(false); f.search:SetMaxLetters(100)
 f.search:SetText(A.db.search or ""); f.search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
 f.search:SetScript("OnTextChanged",function(self) A.db.search=self:GetText(); f.listScroll:SetVerticalScroll(0); A.Refresh(); A.RefreshPins() end)
 local hint=text(f,10,480,-51,220); hint:SetText("Search quest, dungeon, NPC or ID"); hint:SetTextColor(0.82,0.77,0.65)
 f.pinsToggle=iconButton(f,"Map pins","Interface\\Icons\\INV_Misc_Map_01",710,-20,function() A.db.pins=not A.db.pins; A.Refresh(); A.RefreshPins() end)
 local ds,dc=scroll(f,16,-81,183,551)
 f.dungeonScroll=ds; f.dungeonChild=dc
 local names={}; for _,d in ipairs(A.dungeons) do names[#names+1]=d.name end
 for i,d in ipairs(names) do
  local b=button(dc,d,178,0,-(i-1)*86,function() A.db.dungeon=d; f.listScroll:SetVerticalScroll(0); f.detailScroll:SetVerticalScroll(0); A.Refresh(); A.RefreshPins() end)
  b:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
  b:SetPushedTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
  b.art=b:CreateTexture(nil,"ARTWORK"); b.art:SetSize(42,42); b.art:SetPoint("LEFT",5,0)
  b.art:SetTexture(A.dungeonArtwork[d]); b.art:SetTexCoord(0,1,0,1)
  b:GetNormalTexture():SetTexCoord(0,1,0.2,0.8); b:GetPushedTexture():SetTexCoord(0,1,0.2,0.8)
  b:GetNormalTexture():SetVertexColor(0.55,0.55,0.55); b:GetPushedTexture():SetVertexColor(0.8,0.7,0.5)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  b:GetFontString():SetShadowOffset(1,-1)
  b:SetHeight(54); b:GetFontString():SetFont("Fonts\\FRIZQT__.TTF",11,""); b:GetFontString():SetWidth(122)
  b:GetFontString():ClearAllPoints(); b:GetFontString():SetPoint("RIGHT",-5,0)
  b.dungeon=d; dungeonButtons[i]=b
  b.findGroup=button(dc,d=="Scarlet Monastery" and "All SM dungeons" or "Find Group",178,0,-(i-1)*86-55,function() A.FindGroup(d) end)
  b.findGroup:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine("Browse players for "..d); GameTooltip:AddLine("Select a player, then click Invite.",1,1,1); GameTooltip:Show() end)
  b.findGroup:SetScript("OnLeave",function() GameTooltip:Hide() end)
 end
 dc:SetHeight(#names*86)
 f.heading=text(f,14,232,-83,334); f.progress=text(f,11,232,-107,334)
 f.listScroll,f.listChild=scroll(f,230,-143,334,488)
 f.empty=text(f.listChild,13,12,-25,302)
 f.detailTitle=text(f,16,604,-91,313)
 f.metadata=CreateFrame("Frame",nil,f); f.metadata:SetSize(100,24); f.metadata:SetPoint("TOPRIGHT",f,"TOPLEFT",917,-91)
 local function badge(x)
  local b=CreateFrame("Button",nil,f.metadata); b:SetSize(24,24); b:SetPoint("RIGHT",x,0)
  b:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(self.tip or ""); GameTooltip:Show() end)
  b:SetScript("OnLeave",function() GameTooltip:Hide() end)
  b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetAllPoints(); return b
 end
 f.levelBadge=badge(0); f.levelBadge.label=text(f.levelBadge,16,0,-3,24)
 f.factionBadge=badge(-28); f.classBadge=badge(-56)
 f.detailScroll,f.detailChild=scroll(f,604,-124,313,452)
 f.detailText=text(f.detailChild,12,0,0,300)
 f.mapButton=iconButton(f.detailChild,"Show pickup on map","Interface\\Icons\\INV_Misc_Map_01",604,-600,function() if f.pickupTarget then A.Navigate(f.pickupTarget) end end)
 f.logButton=iconButton(f.detailChild,"Open quest log","Interface\\Icons\\INV_Misc_Book_09",648,-600,function()
  if not selected then return end
  local current=f.currentQuest or selected
  if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(current.id)
  elseif ShowQuestLog then ShowQuestLog(A.log[current.id] and A.log[current.id].index) end
 end)
 f.source=iconButton(f.detailChild,"Source link","Interface\\Icons\\INV_Misc_Spyglass_03",692,-600,function()
  if not selected then return end
  if not f.link then
   f.link=CreateFrame("EditBox",nil,f,"InputBoxTemplate"); f.link:SetSize(650,27); f.link:SetPoint("BOTTOM",0,65); f.link:SetAutoFocus(false)
   f.link:SetScript("OnEscapePressed",function(self) self:Hide() end); f.link:SetScript("OnEnterPressed",function(self) self:Hide() end)
  end
  f.link:Show(); f.link:SetText((f.currentQuest and f.currentQuest.source) or selected.source); f.link:SetFocus(); f.link:HighlightText(); A.Print("Ctrl+C copies the source link; Escape closes the box.")
 end)
 f:SetScript("OnShow",function() A.Scan(); A.RevealSelectedDungeon(); f.listScroll:SetVerticalScroll(0) end)
 f:Hide()
end
function A.Toggle()
 if not A.db then return end
 if not A.window then A.CreateWindow() end
 A.window:SetShown(not A.window:IsShown())
end
