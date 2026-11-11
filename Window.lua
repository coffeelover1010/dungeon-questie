local _, A = ...
A.labels={done="TURNED IN",ready="READY TO TURN IN",active="IN QUEST LOG",restricted="NOT ELIGIBLE",level="LEVEL TOO LOW",prereq="EARLIER QUEST LISTED IN GUIDE",unknown="SCAN UNAVAILABLE",todo="TO PICK UP"}
local colors={done={0.16,0.36,0.14},ready={0.48,0.27,0.04},active={0.12,0.29,0.43},restricted={0.38,0.34,0.28},level={0.55,0.16,0.10},prereq={0.40,0.24,0.38},unknown={0.55,0.16,0.10},todo={0.30,0.23,0.15}}
-- Presentation only: evidence and resolver gates stay in the source records.
local wording={
 {"Classic reference facts; current Forever rewards and availability have not been checked in game.",""},
 {" (Classic reference pin)",""},
 {"Related quest (requirement unverified)","Related quest"},
 {" (Forever guide; no verified pin)",""},
 {"; exact minimum level is not reverified.","."},
 {"Pickup location not verified; check the source before travelling.","Pickup location unavailable."},
 {"Pickup location not yet verified. Check the source and quest notes.","Pickup location unavailable."},
 {"Additional or conditional requirements need checking in your quest log or at the quest giver.",""},
 {"; the exact starting NPC is not verified.","."},
 {"; the exact starting NPC and earlier requirements are unverified.","."},
 {"; the exact Horde pickup still needs client confirmation.","."},
 {" (quest-text report; exact pickup unverified)",""},
 {" NPC name and map pin remain unverified.",""},
 {" Exact location unverified.",""},
 {" Exact drop location unverified.",""},
 {" Interior map coordinates not verified.",""},
 {"; Forever eligibility needs confirmation.","."},
 {"Several quests share that title; no unverified Horde prerequisite ID is enforced.",""},
 {"Check Prate Cloudseer", "Visit Prate Cloudseer"},
 {"Check Caitlin directly", "Visit Caitlin"},
 {"Classic reference: check Thundris", "Visit Thundris"},
 {"Glowing Shard variant; check the current quest offered by the item.","Use the Glowing Shard to view its quest."},
 {"Open your quest log for the current destination. No verified destination pin is recorded here.","Open your quest log for the current destination."},
 {"Already in your log; check its objectives.","Already in your quest log."},
}
function A.DisplayText(value)
 local result=value or ""
 for _,pair in ipairs(wording) do
  local start=1
  while true do
   local a,b=result:find(pair[1],start,true); if not a then break end
   result=result:sub(1,a-1)..pair[2]..result:sub(b+1); start=a+#pair[2]
  end
 end
 return result
end
function A.DataWarning(q,n,phase)
 -- Source confidence stays in research records; quest state and readiness supply guidance.
 return nil
end
local function warningIcon(parent)
 local b=CreateFrame("Button",nil,parent); b:SetSize(18,18)
 b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetAllPoints()
 b.icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
 b:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(self.tip or "Source details",1,0.75,0.25,true); GameTooltip:Show() end)
 b:SetScript("OnLeave",function() GameTooltip:Hide() end)
 return b
end
local selected,rows,dungeonButtons,rewardButtons=nil,{},{},{}
local expandedChains,chainDisplay={},{ }
function A.DungeonReadinessBadge(q)
 local ready,reason=A.RunReadiness(q)
 if ready then return "Interface\\RaidFrame\\ReadyCheck-Ready","Ready for dungeon\n"..(reason or "Continue inside the dungeon.") end
 if A.Completed(q.id)==true then return "Interface\\Buttons\\UI-CheckBox-Check","Completed\nQuest already turned in." end
 local stage=A.Preparation(q)
 if stage=="blocked" then return "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew","Not ready for dungeon\nQuest requirements are not met." end
 if stage=="skipped" then return "Interface\\Buttons\\UI-GroupLoot-Pass-Up","Skipped\nOptional breadcrumb no longer needed." end
 return "Interface\\Icons\\INV_Misc_PocketWatch_01","Not ready for dungeon\n"..(reason or "Finish preparation or check availability. See the quest's next step.")
end
local statusLabels={
 ["SKIPPED BREADCRUMB"]="Skipped",
 ["AVAILABILITY UNKNOWN"]="Availability unknown",
 ["UNAVAILABLE"]="Unavailable",
 ["NOT ELIGIBLE NOW"]="Ineligible",
 ["READY FOR DUNGEON"]="Ready",
 ["ALREADY COMPLETED"]="Completed",
 ["COLLECT BEFORE ENTERING"]="Collect",
 ["PICK UP INSIDE"]="Inside",
 ["QUEST DETAILS"]="Details",
 ["STATUS UNAVAILABLE"]="Unknown",
 ["EARLIER QUEST"]="Prerequisite",
 ["PICKUP LOCATION UNKNOWN"]="Unknown",
 ["PICK UP FIRST"]="Collect",
 ["TURN IN FIRST"]="Turn in",
 ["IN YOUR LOG"]="Active",
}
local function readableStatus(label)
 local prefix,quest=label:match("^([^:]+): (.+)$")
 local value=statusLabels[prefix or label]
 if not value then
  value=(prefix or label):lower():gsub("^%l",string.upper)
 end
 return value
end
function A.QuestRowStatus(q)
 local stage,label=A.Preparation(q)
 local value=readableStatus(label)
 if stage=="check" and A.StepContext then
  local n,phase,note=A.WalkStep(q)
  local _,title=A.StepContext(q,n,phase,note); value=title
 end
 local actionable,_,actionPhase=A.ActionReadiness(q)
 if actionable then value=actionPhase=="ready" and "Turn in" or "Collect" end
 local prefix,quest=label:match("^([^:]+): (.+)$")
 local tip=(prefix or label):lower():gsub("^%l",string.upper)
 if quest then tip=tip..": "..quest end
 if stage=="blocked" and not A.Restriction(q) then
  if q.minLevel and UnitLevel("player")<q.minLevel then
   value="Level "..q.minLevel; tip="Requires level "..q.minLevel.." to accept this quest."
  elseif A.WalkStep then
   local step,phase,reason=A.WalkStep(q)
   if phase=="blocked" and step.minLevel and reason=="Requires level "..step.minLevel.."." then
    value="Level "..step.minLevel; tip=step.name..": "..reason
   else tip=reason or tip end
  end
 end
 local icon
 if stage=="turnin" or (A.ActionReadiness and A.ActionReadiness(q)) then icon="Interface\\Buttons\\UI-CheckBox-Check"
 elseif stage=="done" then icon="Interface\\Buttons\\UI-CheckBox-Check"
 elseif stage=="pickup" or stage=="inside" then icon="Interface\\GossipFrame\\AvailableQuestIcon"
 elseif stage=="packed" then icon="Interface\\GossipFrame\\ActiveQuestIcon"
 elseif stage=="chain" then icon="Interface\\Icons\\INV_Misc_Note_01"
 end
 -- Keep level numbers and uncertain/blocked labels explicit; the warning already has its own icon.
 return value,icon,tip
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
local function iconButton(parent,label,icon,x,y,fn,template)
 local b=CreateFrame("Button",nil,parent,template); b:SetSize(32,32); b:SetPoint("TOPLEFT",x,y)
 b:SetNormalTexture(icon); b:SetPushedTexture(icon)
 b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
 if fn then b:SetScript("OnClick",fn) end
 b:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(self.tip or label); GameTooltip:Show() end)
 b:SetScript("OnLeave",function() GameTooltip:Hide() end)
 b:SetScript("OnEnable",function(self) self:GetNormalTexture():SetDesaturated(false); self:SetAlpha(1) end)
 b:SetScript("OnDisable",function(self) self:GetNormalTexture():SetDesaturated(true); self:SetAlpha(0.4) end)
 return b
end
-- Only structured creature records can produce a secure target macro.
-- Never parse item/object/prose locations as NPC names.
function A.QuestGiverMacro(q,phase)
 if not q or (phase~="pickup" and phase~="inside" and phase~="ready") then return nil end
 local n=(A.walkthroughs or {})[q.id] or q
 local field=phase=="ready" and "turnin" or "pickup"
 local location=n[field] or q[field] or ""
 local names=n[field.."NPCs"] or {}
 local commands,labels={},{}
 for _,name in ipairs(names) do
  if type(name)=="string" and name~="" and not name:find("[%c%[%]/;]") and location:find(name,1,true) then
   commands[#commands+1]="/targetexact "..name; labels[#labels+1]=name
  end
 end
 local macro=table.concat(commands,"\n")
 if #commands==0 or #macro>255 then return nil end
 return macro,table.concat(labels," / ")
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
 if InCombatLockdown() then return end
 local f=A.window; local q=selected
 for _,b in ipairs(rewardButtons) do b:Hide() end
 local instructions,target,heading
 if q then instructions,target,heading=A.PickupSteps(q) end
 f.pickupTarget=target
 local mapTarget,mapTip
 if A.MapLocation then mapTarget,mapTip=A.MapLocation(q) end
 f.mapTarget=mapTarget or target
 f.mapButton:SetEnabled(f.mapTarget and f.mapTarget.pin~=nil or false)
 f.mapButton.tip=mapTip or "Show recorded location on map"
 local current,phase
 if q and A.WalkStep then current,phase=A.WalkStep(q) else current=q end
 f.warning.tip=A.DataWarning(q,current,phase); f.warning:SetShown(f.warning.tip~=nil)
 f.currentQuest=current
 local macro,names=A.QuestGiverMacro(current,phase)
 f.targetButton:SetAttribute("macrotext",macro)
 f.targetButton:SetEnabled(macro~=nil)
 f.targetButton.tip=names and ("Target step NPC: "..names.."\nOnly targets an NPC within targeting range.") or "No targetable quest giver name recorded."
 f.source:SetEnabled(q~=nil); f.logButton:SetEnabled(current and A.log[current.id]~=nil or false)
 for _,b in ipairs({f.mapButton,f.logButton,f.source,f.targetButton}) do b:SetShown(q~=nil) end
 if not q then
  f.detailTitle:SetText("Select a quest"); f.metadata:Hide()
  local note="Select a quest from the list to see where to pick it up, its requirements and rewards."
  local hasQuests=false
  for _,quest in ipairs(A.quests) do
   for _,dungeon in ipairs(quest.dungeons) do if dungeon==A.db.dungeon then hasQuests=true; break end end
   if hasQuests then break end
  end
  if not hasQuests then note="This guide does not have quests for this dungeon yet." end
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
 f.warning:ClearAllPoints(); f.warning:SetPoint("RIGHT",f.metadata,"RIGHT",-badgeWidth,0)
 if f.warning.tip then badgeWidth=badgeWidth+22 end
 f.detailTitle:SetWidth(313-badgeWidth-8)
 f.classBadge:ClearAllPoints(); f.classBadge:SetPoint("RIGHT",q.faction and -56 or -28,0)
 local contentTop=91+math.max(24,f.detailTitle:GetStringHeight())+10
 f.detailScroll:ClearAllPoints(); f.detailScroll:SetPoint("TOPLEFT",604,-contentTop); f.detailScroll:SetHeight(math.max(180,630-contentTop))
 local lines={"|cff684018"..(heading or "Where to pick it up").."|r",instructions}
 local chainLabel,chainDetails
 if A.ChainProgress then chainLabel,chainDetails=A.ChainProgress(q) end
 if chainLabel then table.insert(lines,1,"|cff684018"..chainLabel.."|r\n") end
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
  for _,c in ipairs(q.chain or {}) do table.insert(lines,c.role..": "..c.name..(c.id and (" ("..c.id..")") or " [ID unavailable]")) end
 end
 if current==q and A.log[q.id] and q.routeNote then table.insert(lines,"\n|cff684018Quest directions|r\n"..q.routeNote) end
 if chainDetails then table.insert(lines,"\n|cff684018Quest chain|r\n"..chainDetails) end
 if q.repeatable then table.insert(lines,"Repeatable; excluded from the one-time completion total.") end
 if #(q.rewards or {})>0 then table.insert(lines,"\n|cff684018Rewards|r") end
 f.detailText:SetText(A.DisplayText(table.concat(lines,"\n")))
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
 for i,b in ipairs({f.mapButton,f.logButton,f.source,f.targetButton}) do
  b:ClearAllPoints(); b:SetPoint("TOPLEFT",f.detailChild,"TOPLEFT",(i-1)*44,actionsY)
 end
 f.detailChild:SetHeight(math.max(1,-actionsY+44))
end
function A.QuestRowPriority(q)
 local stage=A.Preparation(q)
 if stage=="skipped" then return 9 end
 if A.FutureQuestStep and A.FutureQuestStep(q) then return 7 end
 if stage=="blocked" then return 8 end
 if A.Completed(q.id)==true then return 6 end
 if A.log[q.id] then return A.log[q.id].complete and 2 or 3 end
 local step,phase
 if A.WalkStep then step,phase=A.WalkStep(q) end
 -- Only an actual offer is a pickup now. Unknown availability is not an offer.
 if step and step.id==q.id and phase=="pickup" then return 1 end
 if A.RunReadiness(q) then return 4 end
 return 5
end
local function rowBackground(row,chosen,index)
 row.bg:SetColorTexture(1,0.88,0.62,chosen and 0.90 or (index%2==0 and 0.70 or 0.55))
end
function A.Refresh()
 if InCombatLockdown() then return end
 local f=A.window; if not f or not f:IsShown() then return end
 local prep=A.PreparationSummary(A.db.dungeon)
 local remaining=prep.total-prep.done-prep.skipped
 f.progress:SetText((remaining==0 and prep.done==prep.total and prep.total>0 and "Completed" or (prep.ready.." / "..remaining.." ready")).."\n"..prep.done.." completed | "..prep.pickup.." collect | "..(prep.chain+prep.check).." preparing | "..prep.blocked.." blocked | "..prep.skipped.." skipped")
 f.heading:SetText(A.db.dungeon)
 local visible={}
 for _,q in ipairs(A.quests) do if A.Matches(q) then visible[#visible+1]=q end end
 table.sort(visible,function(a,b)
  local ap,bp=A.QuestRowPriority(a),A.QuestRowPriority(b)
  if ap~=bp then return ap<bp end
  local _,_,ar=A.Preparation(a); local _,_,br=A.Preparation(b)
  if ar~=br then return ar<br end
  local az=a.pin and a.pin.zone or a.pickup or ""; local bz=b.pin and b.pin.zone or b.pickup or ""
  if az~=bz then return az<bz end
  if (a.minLevel or 0)==(b.minLevel or 0) then return a.id<b.id end
  return (a.minLevel or 0)<(b.minLevel or 0)
 end)
 local entries={}
 if A.QuestChainGroups then
  local groups=A.QuestChainGroups(visible)
  table.sort(groups,function(a,b)
   local function priority(g)
    local rank=A.QuestRowPriority(g.quest)
    for _,n in ipairs(g.steps) do rank=math.min(rank,A.QuestRowPriority(n)) end
    return rank
   end
   local ar,br=priority(a),priority(b)
   if ar~=br then return ar<br end
   return a.quest.id<b.quest.id
  end)
  visible={}
  for _,g in ipairs(groups) do
   visible[#visible+1]=g.quest; entries[#visible]={group=g}
   if expandedChains[g.quest.id] then
    for _,n in ipairs(g.steps) do
     local child=n
     if not n.dungeons then
      child=chainDisplay[n.id] or {}; chainDisplay[n.id]=child
      for k,v in pairs(n) do child[k]=v end
      child.dungeons=g.quest.dungeons; child.rewards=child.rewards or {}; child.objectives=child.objectives or {}
     end
     visible[#visible+1]=child; entries[#visible]={parent=g.quest}
    end
   end
  end
 end
 local found=false; for _,q in ipairs(visible) do if selected and q.id==selected.id then selected=q; found=true; break end end
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
   r.readiness=warningIcon(r); r.readiness:SetPoint("TOPRIGHT",-6,-8)
   r.warning=warningIcon(r); r.warning:SetPoint("TOPRIGHT",-28,-8)
   r.expand=CreateFrame("Button",nil,r); r.expand:SetSize(20,20); r.expand:SetPoint("TOPLEFT",8,-6)
   local expandText=r.expand:CreateFontString(nil,"OVERLAY")
   expandText:SetFont("Fonts\\FRIZQT__.TTF",17,""); expandText:SetPoint("CENTER",0,0)
   expandText:SetTextColor(0.32,0.23,0.12); r.expand.label=expandText
   r.expand:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
   r.expand:GetHighlightTexture():SetVertexColor(0.40,0.29,0.13,0.12)
   r.expand:SetScript("OnClick",function()
    local id=r.quest.id; expandedChains[id]=not expandedChains[id]
    selected=r.quest; A.Refresh()
   end)
   r:SetScript("OnEnter",function(self)
    if self.statusTip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(self.statusTip,1,1,1,true); GameTooltip:Show() end
   end)
   r:SetScript("OnLeave",function() GameTooltip:Hide() end)
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
    if self.hasSteps then
     expandedChains[self.quest.id]=not expandedChains[self.quest.id]
     A.Refresh(); return
    end
    -- Selection changes only the highlight and detail pane, not quest state.
    for index,row in ipairs(rows) do
     local chosen=row.quest==selected
     row.selection:SetShown(chosen)
     rowBackground(row,chosen,index)
    end
    details()
   end); rows[i]=r
  end
  local entry=entries[i] or {}
  local child=entry.parent~=nil
  local hasSteps=entry.group and #entry.group.steps>0
  r.hasSteps=hasSteps
  r.quest=q; r:ClearAllPoints(); r:SetPoint("TOPLEFT",child and 18 or 0,-listHeight)
  r:SetWidth(child and 316 or 334)
  r.expand:SetShown(hasSteps or false)
  r.expand.label:SetText("...")
  r.title:ClearAllPoints(); r.title:SetPoint("TOPLEFT",hasSteps and 38 or 10,-8)
  r.status:SetWidth(child and 296 or 314); r.meta:SetWidth(child and 296 or 314)
  local s=A.state[q.id] or A.Status(q)
  local stage,prepLabel=A.Preparation(q)
  local breadcrumb=((A.walkthroughs or {})[q.id] or q).breadcrumbFor~=nil
  local unnecessary=breadcrumb and stage=="skipped"
  local future=A.FutureQuestStep and A.FutureQuestStep(q)
  r:SetAlpha(1)
  r.title:SetTextColor(0.12,0.075,0.035)
  r.meta:SetTextColor(0.19,0.12,0.06)
  local warningStep,warningPhase
  if A.WalkStep then warningStep,warningPhase=A.WalkStep(q) end
  r.warning.tip=A.DataWarning(q,warningStep,warningPhase); r.warning:SetShown(r.warning.tip~=nil)
  local readinessIcon,readinessTip=A.DungeonReadinessBadge(q)
  r.readiness.icon:SetTexture(readinessIcon); r.readiness.tip=readinessTip; r.readiness:Show()
  r.title:SetWidth((r.warning.tip and 268 or 290)-(child and 18 or 0)-(hasSteps and 28 or 0))
  local statusLabel,statusIcon,statusTip=A.QuestRowStatus(q)
  r.statusTip=statusTip
  r.title:SetText(q.name); r.status:SetText(statusLabel); r.status:SetTextColor(unpack(colors[s]))
  r.meta:SetText(not A.NeedsPickup(q) and ((s=="done" and "Quest completed") or (q.id==1198 and "Find Argent Guard Thaelrid inside Blackfathom Deeps") or "See quest log for your next destination") or (q.pickup or (q.pickupInside and ("Get inside "..q.dungeons[1]) or "Pickup location not recorded")))
  if A.WalkStep and A.NeedsPickup(q) then
   local step,phase=A.WalkStep(q)
   if step.id~=q.id then r.meta:SetText(step.pickup or "Open the walkthrough for this step.") end
  end
  local actionReady,actionStep,actionPhase=A.ActionReadiness(q)
  if stage=="done" then
   r.status:SetText("Completed"); r.status:SetTextColor(0.16,0.36,0.14)
   r.meta:SetText("Quest turned in.")
  elseif actionReady then
   r.status:SetText(actionPhase=="ready" and "Turn in" or "Collect"); r.status:SetTextColor(0.12,0.38,0.08)
   r.meta:SetText(actionStep.name)
   statusIcon="Interface\\Buttons\\UI-CheckBox-Check"
  end
  if warningPhase=="check" or warningPhase=="skipped" or warningPhase=="unavailable" or warningPhase=="blocked" then
   local step,phase,reason=A.WalkStep(q)
   if phase=="skipped" then r.meta:SetText(reason or "See quest details.")
   else r.meta:SetText((A.StepContext(q,step,phase,reason))) end
  elseif warningPhase=="active" then r.meta:SetText("Complete objectives: "..warningStep.name)
  end
  if future then
   r.status:SetText("Later step")
   r.status:SetTextColor(0.30,0.23,0.15)
   r.statusTip="This quest comes later in the chain. Current step: "..future.name..".\n"..(r.statusTip or "")
   r.meta:SetText("Current step: "..future.name.."\n"..r.meta:GetText())
   statusIcon="Interface\\Icons\\INV_Misc_PocketWatch_01"
  end
  if breadcrumb then
   if unnecessary then
    r.status:SetText("Breadcrumb - not needed")
    r.status:SetTextColor(0.30,0.23,0.15)
    statusIcon="Interface\\Buttons\\UI-GroupLoot-Pass-Up"
    r.meta:SetText("You already have or completed a later quest in this chain.")
    r.statusTip="Optional breadcrumb: not needed for dungeon preparation because you have progressed beyond it."
   else
    r.status:SetText("Breadcrumb - "..r.status:GetText())
    r.statusTip="Optional introduction quest.\n"..(r.statusTip or "")
   end
  end
  if hasSteps then
   local current=A.WalkStep(q)
   r.status:SetText("Quest chain - "..#entry.group.steps.." earlier steps")
   r.meta:SetText("Current step: "..current.name.."\n"..(expandedChains[q.id] and "Click this box to collapse steps." or "Click this box to expand steps."))
   statusIcon=nil
  end
  if statusIcon then r.status:SetText("|T"..statusIcon..":14:14:0:0|t "..r.status:GetText()) end
  r.meta:SetText(A.DisplayText(r.meta:GetText()))
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
  rowBackground(r,q==selected,i); r.selection:SetShown(q==selected); r:Show()
 end
 for i=#visible+1,#rows do rows[i]:Hide() end
 f.listChild:SetHeight(math.max(1,listHeight)); f.empty:SetShown(#visible==0)
 f.empty:SetText(A.EmptyQuestMessage())
 for _,b in ipairs(dungeonButtons) do
  local c=A.PreparationSummary(b.dungeon)
  local remaining=c.total-c.done-c.skipped
  b:SetText(b.dungeon.."\n"..(remaining==0 and c.done==c.total and c.total>0 and "Completed" or (c.ready.." / "..remaining.." ready")))
  b:GetFontString():SetTextColor(b.dungeon==A.db.dungeon and 1 or 0.8,b.dungeon==A.db.dungeon and 0.82 or 0.8,0.65)
 end
 f.pinsToggle.tip="Map pins: "..(A.db.pins and "On" or "Off").." - click to toggle"
 for _,texture in ipairs({f.pinsToggle:GetNormalTexture(),f.pinsToggle:GetPushedTexture()}) do texture:SetDesaturated(not A.db.pins) end
 f.pinsToggle:SetAlpha(A.db.pins and 1 or 0.45)
 details()
end
function A.SelectQuest(q)
 if InCombatLockdown() then return end
 A.db.dungeon=q.dungeons[1]; A.db.search=""; selected=q
 if A.QuestChainGroups then
  local candidates={}; for _,n in ipairs(A.quests) do if A.Matches(n) then candidates[#candidates+1]=n end end
  for _,g in ipairs(A.QuestChainGroups(candidates)) do
   for _,n in ipairs(g.steps) do if n.id==q.id then expandedChains[g.quest.id]=true end end
  end
 end
 if not A.window then A.CreateWindow() end
 A.window.search:SetText(""); A.window:Show(); A.Scan()
 A.RevealSelectedDungeon()
end
function A.CreateWindow()
 if InCombatLockdown() then return end
 if A.window then return end
 local f=CreateFrame("Frame","DungeonGuideForeverWindow",UIParent,"BackdropTemplate,SecureHandlerStateTemplate"); A.window=f
 -- Secure targeting protects the containing window. Close it securely on
 -- combat entry, and leave reopening to the player after combat.
 f:SetAttribute("_onstate-combat","if newstate == 'combat' then self:Hide() end")
 RegisterStateDriver(f,"combat","[combat] combat; peace")
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
 local title=text(f,21,23,-27,402); title:SetText("Dungeon Questie"); title:SetTextColor(1,0.82,0.35); title:SetShadowOffset(1,-1)
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
  b.art=b:CreateTexture(nil,"OVERLAY"); b.art:SetSize(42,42); b.art:SetPoint("LEFT",5,0)
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
 f.warning=warningIcon(f.metadata)
 f.detailScroll,f.detailChild=scroll(f,604,-124,313,452)
 f.detailText=text(f.detailChild,12,0,0,300)
 f.mapButton=iconButton(f.detailChild,"Show location on map","Interface\\Icons\\INV_Misc_Map_01",604,-600,function() if f.mapTarget then A.Navigate(f.mapTarget) end end)
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
 f.targetButton=iconButton(f.detailChild,"Target quest giver","Interface\\Icons\\Ability_Hunter_SniperShot",736,-600,nil,"SecureActionButtonTemplate")
 f.targetButton:RegisterForClicks("AnyUp","AnyDown")
 f.targetButton:SetAttribute("type","macro")
 f:SetScript("OnShow",function() A.Scan(); A.RevealSelectedDungeon(); f.listScroll:SetVerticalScroll(0) end)
 f:Hide()
end
function A.Toggle()
 if InCombatLockdown() then A.Print("Dungeon Questie can be opened after combat."); return end
 if not A.db then return end
 if not A.window then A.CreateWindow() end
 A.window:SetShown(not A.window:IsShown())
end
