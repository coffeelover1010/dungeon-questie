local CreateFrame = ForeverButtonControls and ForeverButtonControls:Factory("DungeonGuideForever","Dungeon Questie","Window",false) or function(...) return _G.CreateFrame(...) end
local _, A = ...
A.labels={done="TURNED IN",ready="READY TO TURN IN",active="IN QUEST LOG",restricted="NOT ELIGIBLE",level="LEVEL TOO LOW",prereq="EARLIER QUEST LISTED IN GUIDE",unknown="SCAN UNAVAILABLE",todo="TO PICK UP"}
local colors={done={0.16,0.36,0.14},ready={0.48,0.27,0.04},active={0.12,0.29,0.43},restricted={0.38,0.34,0.28},level={0.55,0.16,0.10},prereq={0.40,0.24,0.38},unknown={0.55,0.16,0.10},todo={0.30,0.23,0.15}}
-- Presentation only: evidence and resolver gates stay in the source records.
local wording={
 {"Guide pickup: ","Pickup: "},
 {"Minimum level unknown","Minimum level: ?"},
 {"Its minimum level is not yet confirmed.",""},
 {"Right-click the Perfect Blackfathom Pearl to check whether you can accept this quest.","Right-click the Perfect Blackfathom Pearl to start the quest."},
 {"Check requirements","Quest details"},
 {"Quest data incomplete","Quest details"},
 {"Availability unknown","Quest details"},
 {"availability unknown","Quest details"},
 {"Pickup location unavailable.","Pickup: ?"},
 {"Pickup location not recorded in this guide.","Pickup: ?"},
 {"Pickup location not recorded.","Pickup: ?"},
 {"Pickup not recorded.","Pickup: ?"},
 {"Location not recorded.","?"},
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
 -- Hide research caveats throughout quest prose, without changing source data
 -- or claiming that an unseen quest offer has been confirmed.
 local caveats={"beta", "cache", "unverified", "unconfirmed", "not confirmed", "not verified", "not yet verified", "not fully recorded", "needs verification", "need verification", "needs confirmation", "need confirmation", "reference data", "reference facts", "may exist", "not in the installed", "not reverified"}
 local lines={}
 for line in result:gmatch("[^\n]+") do
  local parts={}
  for sentence in line:gmatch("[^.!?]+[.!?]*") do
   local lower=sentence:lower(); local hide=false
   for _,marker in ipairs(caveats) do if lower:find(marker,1,true) then hide=true; break end end
   if not hide then parts[#parts+1]=sentence end
  end
  local clean=table.concat(parts):match("^%s*(.-)%s*$")
  if clean~="" and clean~="-" then lines[#lines+1]=clean end
 end
 return table.concat(lines,"\n")
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
local function pickupSource(n)
 local known=A.byID[n.id] or n
 local record=(A.walkthroughs or {})[n.id] or n
 local value=n.itemPickup or record.itemPickup or known.itemPickup or n.pickup or record.pickup or known.pickup
 if n.pickupUnknown or record.pickupUnknown then return nil end
 return value
end
function A.DungeonActionBadge(q)
 if A.Completed(q.id)==true then return nil,"Quest completed" end
 if A.log[q.id] and A.log[q.id].complete then return "Interface\\GossipFrame\\ActiveQuestIcon","Ready to turn in" end
 if A.DungeonWorkFinished(q) then return "Interface\\GossipFrame\\ActiveQuestIcon","Ready to turn in" end
 if A.WalkStep then
  local step,phase=A.WalkStep(q)
  if phase=="ready" then return "Interface\\GossipFrame\\ActiveQuestIcon","Ready to turn in\n"..step.name end
  if phase=="active" and step and A.log[step.id] then
   return nil,"Objectives unfinished\n"..step.name,true
  end
  if step and (phase=="pickup" or phase=="inside" or (phase=="check" and pickupSource(step))) and not A.log[step.id] then
   return "Interface\\GossipFrame\\AvailableQuestIcon","Pick up quest\n"..step.name
  end
 end
 return nil
end
function A.DungeonReadinessBadge(q)
 if A.Completed(q.id)==true then return nil,"Quest completed" end
 local ready,reason=A.RunReadiness(q)
 if ready then return "Interface\\RaidFrame\\ReadyCheck-Ready","Ready for dungeon\n"..(reason or "Continue inside the dungeon.") end
 if A.DungeonWorkFinished(q) then return nil,"Dungeon objectives finished" end
 local stage=A.Preparation(q)
 if stage=="blocked" then return nil,"Not ready for dungeon\nQuest requirements are not met." end
 if stage=="skipped" then return nil,"Skipped\nOptional breadcrumb no longer needed." end
 return nil,"Not ready for dungeon\n"..(reason or "Follow the next quest step.")
end
function A.QuestTurnInSummary(q)
 if A.LoadLocations then A.LoadLocations() end
 local record=(A.walkthroughs or {})[q.id] or q
 local known=A.byID[q.id] or q
 local who=record.turnin or q.turnin or known.turnin
 local pin=record.turninPin or q.turninPin or known.turninPin
 local completed=A.Completed(q.id)==true
 return (completed and "Completed: " or "Turn In: ")..(q.name or record.name or known.name or "Quest")..(completed and " with hand in to " or " to ")..(who or (pin and pin.title) or (completed and "Unknown" or "the destination in your quest log")).."\nZone: "..(pin and pin.zone or (completed and "Unknown" or "See quest log"))
end
function A.DungeonInstruction(q)
 if A.Completed(q.id)==true then return "Completed", A.QuestTurnInSummary(q) end
 if A.log[q.id] and A.log[q.id].complete then return "Objectives finished", A.QuestTurnInSummary(q) end
 if A.DungeonWorkFinished(q) then return "Objectives finished", A.QuestTurnInSummary(q) end
 if A.log[q.id] then
  if A.RunReadiness(q) then return "Ready for dungeon", "Continue inside the dungeon." end
  return "Active", A.QuestTurnInSummary(q)
 end
 if not A.WalkStep then return "Readiness unknown", "Check the quest details before entering." end
 local n,phase,note=A.WalkStep(q)
 if phase=="pickup" or phase=="inside" or phase=="check" or phase=="unavailable" then
  if A.LoadLocations then A.LoadLocations() end
  local record=(A.walkthroughs or {})[n.id] or n
  local known=A.byID[n.id] or n
  local pin=n.pin or record.pin or known.pin
  local zone=n.pickupZone or record.pickupZone or known.pickupZone or (n.pickupInside and (known.dungeons or q.dungeons or {})[1]) or (pin and pin.zone)
  local pickup=pickupSource(n)
  local instruction=pickup and ("Accept: "..n.name.." from "..(pickup or "the quest giver")) or ("Pickup: "..(pickup or "See quest details."))
  if zone and zone~="" then instruction=instruction.."\nZone: "..zone end
  return A.RunReadiness(q) and "Ready for dungeon" or "Pick up quest",instruction
 end
 if phase=="active" then return n.id==q.id and "Active" or "Preparation needed", A.QuestTurnInSummary(n) end
 if phase=="ready" then return "Preparation needed", A.QuestTurnInSummary(n) end
 if phase=="blocked" then return "Preparation needed", note or "Check the quest requirements." end
 return "Readiness unknown", "Check the quest details before entering."
end
function A.DungeonSummary(c)
 local remaining=c.total-c.done-c.skipped-c.finished
 if c.total==0 then return "" end
 if remaining==0 then return c.finished>0 and "Dungeon work finished" or "Completed" end
 if c.ready==remaining then return "Ready for dungeon" end
 return "Preparation needed"
end
local statusLabels={
 ["SKIPPED BREADCRUMB"]="Skipped",
 ["AVAILABILITY UNKNOWN"]="Availability unknown",
 ["UNAVAILABLE"]="Unavailable",
 ["NOT ELIGIBLE NOW"]="Ineligible",
 ["READY FOR DUNGEON"]="Ready for dungeon",
 ["ALREADY COMPLETED"]="Completed",
 ["COLLECT BEFORE ENTERING"]="Pick up quest",
 ["PICK UP INSIDE"]="Inside",
 ["QUEST DETAILS"]="Details",
 ["STATUS UNAVAILABLE"]="Unknown",
 ["EARLIER QUEST"]="Prerequisite",
 ["PICKUP LOCATION UNKNOWN"]="Unknown",
 ["PICK UP FIRST"]="Pick up quest",
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
 local actionable,actionStep,actionPhase=A.ActionReadiness(q)
 if actionable then value=actionPhase=="ready" and (actionStep.id==q.id and "Objectives finished" or "Preparation needed") or "Pick up quest" end
 local prefix,quest=label:match("^([^:]+): (.+)$")
 local tip=(prefix or label):lower():gsub("^%l",string.upper)
 if quest then tip=tip..": "..quest end
 if stage=="blocked" and not A.Restriction(q) then
  if q.minLevel and UnitLevel("player")<q.minLevel then
   value="Level "..q.minLevel; tip="Requires level "..q.minLevel
  elseif A.WalkStep then
   local step,phase,reason=A.WalkStep(q)
   if phase=="blocked" and step.minLevel and reason=="Requires level "..step.minLevel.."." then
    value="Level "..step.minLevel; tip=step.name..": "..reason
   else tip=reason or tip end
  end
 end
 local icon
 if A.Completed(q.id)==true then
  value="Completed"
 elseif A.log[q.id] and A.log[q.id].complete then
  value="Objectives finished"
 elseif A.log[q.id] then value="Active"
 end
 -- Keep level numbers and uncertain/blocked labels explicit; the warning already has its own icon.
 return A.DisplayText(value),icon,A.DisplayText(tip)
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
-- Cards are a checklist; the selected quest panel owns directions and locations.
function A.QuestCardSummary(q)
 if not A.WalkStep then return "" end
 local n,phase=A.WalkStep(q)
 if n and n.id~=q.id then return "Next: "..n.name end
 if phase=="inside" then return "Pick up inside the dungeon." end
 return ""
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
 b:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(self.tip or label,1,0.82,0.35,true); GameTooltip:Show() end)
 b:SetScript("OnLeave",function() GameTooltip:Hide() end)
 b:SetScript("OnEnable",function(self) self:GetNormalTexture():SetDesaturated(false); self:SetAlpha(1) end)
 b:SetScript("OnDisable",function(self) self:GetNormalTexture():SetDesaturated(true); self:SetAlpha(0.4) end)
 return b
end
function A.UpdateTargetAction(f)
 -- Independent parent and absolute position keep the journal unprotected.
 local slot=f.targetButton
 local combat=InCombatLockdown()
 if f.targetCombat~=combat then
  f.targetCombat=combat; slot:SetEnabled(not combat and f.targetMacro~=nil)
  if combat then slot.tip="NPC targeting is unavailable in combat"
  else slot.tip=f.targetTip end
 end
 if combat then return end
 if not f.targetAction then
  local b=iconButton(UIParent,"Target quest giver","Interface\\Icons\\Ability_Hunter_SniperShot",0,0,nil,"SecureActionButtonTemplate,SecureHandlerStateTemplate")
  f.targetAction=b; b:RegisterForClicks("AnyUp","AnyDown"); b:SetAttribute("type","macro")
  b:SetAttribute("_onstate-combat",'if newstate == "combat" then self:Hide() end')
  RegisterStateDriver(b,"combat","[combat] combat; peace")
  b:Hide()
 end
 local b=f.targetAction
 if not f:IsShown() or not slot:IsShown() or (slot.IsVisible and not slot:IsVisible()) or not f.targetMacro then b:Hide(); return end
 local left,top=slot:GetLeft(),slot:GetTop()
 if not left or not top then b:Hide(); return end
 local viewport=f.detailScroll
 local viewportTop,viewportBottom,bottom=viewport:GetTop(),viewport:GetBottom(),slot:GetBottom()
 if not viewportTop or not viewportBottom or not bottom or top>viewportTop or bottom<viewportBottom then b:Hide(); return end
 local scale=slot:GetEffectiveScale()/UIParent:GetEffectiveScale()
 if b.layoutLeft~=left or b.layoutTop~=top or b.layoutScale~=scale then
  b:SetScale(scale); b:ClearAllPoints(); b:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top)
  b.layoutLeft,b.layoutTop,b.layoutScale=left,top,scale
 end
 if b.macro~=f.targetMacro then b:SetAttribute("macrotext",f.targetMacro); b.macro=f.targetMacro end
 b.tip=slot.tip; b:SetFrameStrata("DIALOG"); b:SetFrameLevel(f:GetFrameLevel()+10); b:Show()
end
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
-- Read by index without changing the player's selected quest-log entry.
function A.QuestLogWords(q)
 if not q or not A.log[q.id] then return end
 local index=A.Safe(C_QuestLog and C_QuestLog.GetLogIndexForQuestID,q.id) or A.log[q.id].index
 local description,summary
 if type(index)=="number" and index>0 and type(GetQuestLogQuestText)=="function" then
  local ok,d,o=pcall(GetQuestLogQuestText,index)
  if ok then description,summary=d,o end
 end
 local function readable(value)
  return not (issecretvalue and issecretvalue(value)) and type(value)=="string" and value~=""
 end
 local lines={q.name}
 if readable(summary) then lines[#lines+1]=summary end
 local objectives=A.Safe(C_QuestLog and C_QuestLog.GetQuestObjectives,q.id)
 if type(objectives)=="table" then
  for _,objective in ipairs(objectives) do
   if readable(objective.text) then
    lines[#lines+1]=objective.text..(objective.finished and " (Complete)" or "")
   end
  end
 end
 if readable(description) then lines[#lines+1]="\n|cff684018Description|r\n"..description end
 if #lines==1 then return end
 return lines
end
local function details()
 local f=A.window; local q=selected
 f.detailTitle:SetShown(not A.db.detailsCollapsed or f.compactQuestPage)
 for _,b in ipairs(rewardButtons) do b:Hide() end
 local instructions,target,heading
 if q then instructions,target,heading=A.PickupSteps(q) end
 f.pickupTarget=target
 local mapTarget,mapTip
 if A.MapLocation then mapTarget,mapTip=A.MapLocation(q) end
 f.mapTarget=A.MapLocation and mapTarget or target
 if A.MapLocation and not mapTarget then f.mapTarget=nil end
 f.mapButton:SetEnabled(f.mapTarget and f.mapTarget.pin~=nil or false)
 f.mapButton.tip=f.mapTarget and ("Navigate\n"..(mapTip or "Current quest destination")) or (mapTip or "Destination unavailable")
 local artworkHeight=A.UpdateLocationArtwork(f.locationArtwork,q,mapTarget,mapTip)
 for i,b in ipairs({f.mapButton,f.logButton,f.source,f.targetButton,f.chatButton}) do
  b:ClearAllPoints(); b:SetPoint("TOPLEFT",f.detailChild,"TOPLEFT",(i-1)*44,-artworkHeight)
 end
 if q then artworkHeight=artworkHeight+40 end
 f.goCurrent:SetShown(q~=nil)
 f.goCurrent:SetEnabled(f.mapTarget and f.mapTarget.pin~=nil or false)
 local destination=f.mapTarget and f.mapTarget.pin
 f.goCurrent.label:SetText(destination and ("> Go to "..destination.title) or "Destination unavailable")
 f.goCurrent.label:SetTextColor(destination and 0.22 or 0.45, destination and 0.15 or 0.4,0.09)
 f.goCurrent:ClearAllPoints(); f.goCurrent:SetPoint("TOPLEFT",0,-artworkHeight)
 if q then artworkHeight=artworkHeight+40 end
 f.detailText:ClearAllPoints(); f.detailText:SetPoint("TOPLEFT",0,-artworkHeight)
 local current,phase
 if q and A.WalkStep then current,phase=A.WalkStep(q) else current=q end
 f.warning.tip=A.DataWarning(q,current,phase); f.warning:SetShown(f.warning.tip~=nil)
 f.currentQuest=current
 local macro,names=A.QuestGiverMacro(current,phase)
 f.targetMacro=macro
 f.targetButton:SetEnabled(macro~=nil and not InCombatLockdown())
 f.targetButton.tip=InCombatLockdown() and "NPC targeting is unavailable in combat" or names and ("Target: "..names.."\nMust be within targeting range.") or "No NPC to target"
 f.targetTip=names and ("Target: "..names.."\nMust be within targeting range.") or "No NPC to target"
 f.source:SetEnabled(q~=nil); f.logButton:SetEnabled(current and A.log[current.id]~=nil or false)
 for _,b in ipairs({f.mapButton,f.logButton,f.source,f.targetButton,f.chatButton}) do b:SetShown(q~=nil) end
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
 f.detailTitle:SetText(f.compactQuestPage and ((A.db.dungeon or "Dungeon").." > "..q.name) or q.name)
 f.metadata:SetShown(not A.db.detailsCollapsed or f.compactQuestPage)
 f.levelBadge.label:SetText(q.minLevel and tostring(q.minLevel) or "?")
 local underLevel=q.minLevel and UnitLevel("player")<q.minLevel
 f.levelBadge.label:SetTextColor(underLevel and 0.7 or 0.18,underLevel and 0.12 or 0.38,0.08)
 f.levelBadge.tip=q.minLevel and ("Requires level "..q.minLevel) or "Minimum level unknown"
 f.factionBadge:SetShown(q.faction~=nil)
 if q.faction then
  f.factionBadge.icon:SetTexture("Interface\\PVPFrame\\PVP-Currency-"..q.faction)
  f.factionBadge.tip=q.faction.." only"
 end
 f.classBadge:SetShown(q.class~=nil)
 if q.class then
  f.classBadge.tip=((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[q.class]) or q.class).." only"
  local coords=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[q.class]
  f.classBadge.icon:SetTexture(coords and "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES" or "Interface\\Icons\\INV_Misc_QuestionMark")
  if coords then f.classBadge.icon:SetTexCoord(unpack(coords)) else f.classBadge.icon:SetTexCoord(0,1,0,1) end
 end
 local badgeWidth=28+(q.faction and 28 or 0)+(q.class and 28 or 0)
 f.warning:ClearAllPoints(); f.warning:SetPoint("RIGHT",f.metadata,"RIGHT",-badgeWidth,0)
 if f.warning.tip then badgeWidth=badgeWidth+22 end
 f.detailTitle:ClearAllPoints(); f.detailTitle:SetPoint("TOPLEFT",f.compactQuestPage and 230 or 604,-91)
 f.detailTitle:SetWidth(313-badgeWidth-8)
 f.classBadge:ClearAllPoints(); f.classBadge:SetPoint("RIGHT",q.faction and -56 or -28,0)
 local contentTop=91+math.max(24,f.detailTitle:GetStringHeight())+10
 f.detailScroll:ClearAllPoints(); f.detailScroll:SetPoint("TOPLEFT",f.compactQuestPage and 230 or 604,-contentTop); f.detailScroll:SetHeight(math.max(180,(f.compactQuestPage and 598 or 630)-contentTop))
 local lines=A.QuestLogWords(current)
 if not lines then
  lines={current.name}
  local db=LibQuestieDB
  local valid=db and db.flavor and db.flavor.name=="Forever" and A.Safe(db.RequireContract,4)==true
  local objectives=valid and A.Safe(db.Quest and db.Quest.Get,current.id,"objectivesText")
  if type(objectives)=="table" then
   for _,objective in ipairs(objectives) do
    if type(objective)=="string" and objective~="" then lines[#lines+1]=objective end
   end
  end
  if #lines==1 then lines[#lines+1]="Quest text unavailable." end
 end
 -- The map fallback promises directions. Keep them visible alongside the
 -- original quest text, including uncertain pickups that cannot be routed.
 if current and (not mapTarget or phase=="check" or phase=="blocked" or phase=="unavailable") then
  local guidance
  if A.WalkStep and A.StepContext and (phase=="check" or phase=="blocked" or phase=="unavailable") then
   local step,state,note=A.WalkStep(q)
   guidance=A.StepContext(q,step,state,note)
  elseif A.RouteInstruction then guidance=A.RouteInstruction(q)
  else guidance=instructions end
  if guidance and guidance~="" then lines[#lines+1]="|cff684018Current step|r\n"..guidance end
 end
 local shownRewards=current.rewards or {}
 if #shownRewards>0 then lines[#lines+1]="\n|cff684018Rewards|r" end
 -- Original text must bypass DQ's wording substitutions and sentence filters.
 f.detailText:SetText(table.concat(lines,"\n\n"))
 local y=-(artworkHeight+f.detailText:GetStringHeight()+10)
 for i,item in ipairs(shownRewards) do
  local b=rewardButtons[i]
  if not b then
   b=CreateFrame("Button",nil,f.detailChild); b:SetSize(298,32)
   b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetSize(26,26); b.icon:SetPoint("LEFT")
   b.label=text(b,12,34,-4,260); b:SetScript("OnEnter",itemTooltip); b:SetScript("OnLeave",function() GameTooltip:Hide() end); b:SetScript("OnClick",itemClick); rewardButtons[i]=b
  end
  b.item=item; b:ClearAllPoints(); b:SetPoint("TOPLEFT",0,y-(i-1)*34); b.label:SetText(A.Safe(C_Item and C_Item.GetItemNameByID or GetItemInfo,item.id) or item.name or ("Item "..item.id))
  local icon=A.Safe(C_Item and C_Item.GetItemIconByID or GetItemIcon,item.id)
  b.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark"); b:Show()
 end
 f.detailChild:SetHeight(math.max(1,-y+#shownRewards*34+10))
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
 -- Recorded requirements determine the current pickup; live offers override the guide.
 if step and step.id==q.id and phase=="pickup" then return 1 end
 if A.RunReadiness(q) then return 4 end
 return 5
end
local function rowBackground(row,chosen,index)
 row.bg:SetColorTexture(1,0.88,0.62,chosen and 0.90 or (index%2==0 and 0.70 or 0.55))
end
function A.QuestListProgress(quests)
 local ready=0
 for _,q in ipairs(quests) do
  if A.Completed(q.id)==true or A.DungeonWorkFinished(q) or A.RunReadiness(q) then ready=ready+1 end
 end
 return ready,#quests
end
function A.Refresh()
 local f=A.window; if not f or not f:IsShown() then return end
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

  end
 end
 local ready,total=A.QuestListProgress(visible)
 f.listedQuests=visible
 if A.UpdateQuestShare then A.UpdateQuestShare() end
 f.heading:SetText((A.db.dungeon or "Dungeon").." > "..ready.."/"..total)
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
   r.questAction=warningIcon(r)
   r.warning=warningIcon(r); r.warning:SetPoint("TOPRIGHT",-28,-8)
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
     GameTooltip:AddLine(self==r.general and "Draft a General message. Enter to send." or "Create a Custom group listing.",1,1,1,true)
     GameTooltip:Show()
    end)
    action:SetScript("OnLeave",function() GameTooltip:Hide() end)
   end
   r:SetScript("OnClick",function(self)
    if IsShiftKeyDown() then A.LinkQuestInChat(A.WalkStep and A.WalkStep(self.quest) or self.quest); return end
    selected=self.quest; f.detailScroll:SetVerticalScroll(0)
    -- Selection changes only the highlight and detail pane, not quest state.
    for index,row in ipairs(rows) do
     local chosen=row.quest==selected
     row.selection:SetShown(chosen)
     rowBackground(row,chosen,index)
    end
    if A.db.detailsCollapsed then A.ShowCompactQuestPage(true) else details() end
   end); rows[i]=r
  end
  local entry=entries[i] or {}
  local child=entry.parent~=nil
  local hasSteps=entry.group and #entry.group.steps>0
  r.hasSteps=hasSteps
  r.quest=q; r:ClearAllPoints(); r:SetPoint("TOPLEFT",child and 18 or 0,-listHeight)
  r:SetWidth(child and 316 or 334)
  r.title:ClearAllPoints(); r.title:SetPoint("TOPLEFT",10,-8)
  r.status:SetWidth((child and 296 or 314)-(hasSteps and 28 or 0)); r.meta:SetWidth((child and 296 or 314)-(hasSteps and 28 or 0))
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
  r.readiness.icon:SetTexture(readinessIcon); r.readiness.tip=A.DisplayText(readinessTip); r.readiness:SetShown(readinessIcon~=nil)
  local actionIcon,actionTip,actionGrey=A.DungeonActionBadge(q)
  r.questAction.icon:SetDesaturated(actionGrey==true)
  r.questAction.icon:SetTexture(actionIcon); r.questAction.tip=A.DisplayText(actionTip); r.questAction:SetShown(actionIcon~=nil)
  r.questAction:ClearAllPoints(); r.questAction:SetPoint("TOPRIGHT",-6-(readinessIcon and 24 or 0),-8)
  local iconWidth=(readinessIcon and 24 or 0)+(actionIcon and 24 or 0)
  r.warning:ClearAllPoints(); r.warning:SetPoint("TOPRIGHT",-6-iconWidth,-8)
  r.title:SetWidth(314-iconWidth-(r.warning.tip and 22 or 0)-(child and 18 or 0))
  local statusLabel,statusIcon,statusTip=A.QuestRowStatus(q)
  r.statusTip=statusTip
  r.title:SetText(q.name); r.status:SetText(A.DisplayText(statusLabel)); r.status:SetTextColor(unpack(colors[s]))
  r.meta:SetText(not A.NeedsPickup(q) and ((s=="done" and "Quest completed") or (q.id==1198 and "Find Argent Guard Thaelrid inside Blackfathom Deeps") or "See quest log for your next destination") or (q.pickup or (q.pickupInside and ("Get inside "..q.dungeons[1]) or "Pickup location not recorded")))
  if A.WalkStep and A.NeedsPickup(q) then
   local step,phase=A.WalkStep(q)
   if step.id~=q.id then r.meta:SetText(step.pickup or "Open the walkthrough for this step.") end
  end
  local actionReady,actionStep,actionPhase=A.ActionReadiness(q)
  if stage=="done" then
   r.status:SetText("Completed"); r.status:SetTextColor(0.16,0.36,0.14)
   r.meta:SetText("")
  elseif actionReady then
   r.status:SetText(statusLabel); r.status:SetTextColor(unpack(colors[s]))
   r.meta:SetText(actionStep.name)
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
   r.statusTip="Earlier step: "..future.name
   r.meta:SetText("Current step: "..future.name.."\n"..r.meta:GetText())
   statusIcon=nil
  end
  if breadcrumb then
   if unnecessary then
    r.status:SetText("Breadcrumb - not needed")
    r.status:SetTextColor(0.30,0.23,0.15)
    statusIcon=nil
    r.meta:SetText("You already have or completed a later quest in this chain.")
    r.statusTip="Optional introduction; already skipped."
   else
    r.status:SetText("Breadcrumb - "..r.status:GetText())
    r.statusTip="Optional introduction quest.\n"..(r.statusTip or "")
   end
  end
  if statusIcon then r.status:SetText("|T"..statusIcon..":14:14:0:0|t "..r.status:GetText()) end
  local summary=A.QuestCardSummary(q)
  if future then summary="Next: "..future.name end
  if not child and not future and not breadcrumb then
   local instruction,action=A.DungeonInstruction(q)
   r.status:SetText(instruction); summary=action
  end
  if breadcrumb and unnecessary then summary="" end
  if hasSteps then
   local current=A.WalkStep(q)
   local total,index=#entry.group.steps+1,nil
   for i,n in ipairs(entry.group.steps) do if n.id==current.id then index=i end end
   if current.id==q.id then index=total end
   local completed=A.Completed(q.id)==true
   r.title:SetText((index and not completed and (index.."/"..total.." - ") or "")..current.name)
   local instruction,action=A.DungeonInstruction(q)
   r.status:SetText(instruction)
   summary=action
  end
  local recovery,dropQuest
  if A.BreadcrumbRecovery then recovery,dropQuest=A.BreadcrumbRecovery(q) end
  if recovery then summary=summary~="" and (summary.."\n"..recovery) or recovery end
  if A.Completed(q.id)==true then summary=A.QuestTurnInSummary(q) end
  r.meta:SetText(summary)
  r.meta:SetShown(summary~="")
  if warningPhase=="check" and not future and not hasSteps and not breadcrumb then
   r.status:SetText("Pickup details")
  end
  local cardStatus=dropQuest and "Drop quest" or (A.DungeonInstruction(q)=="Ready for dungeon" and "Ready for dungeon" or "")
  r.status:SetText(cardStatus)
  r.status:SetShown(cardStatus~="")
  if dropQuest then r.status:SetTextColor(0.65,0.20,0.08) end
  -- Measure the final text, including readiness descriptions, before sizing.
  -- Round up scaled font measurements and leave room for wrapped descenders.
  local function lineHeight(label)
   return math.ceil(label:GetStringHeight())+4
  end
  local statusTop=8+lineHeight(r.title)+7
  r.status:ClearAllPoints(); r.status:SetPoint("TOPLEFT",10,-statusTop)
  local metaTop=cardStatus~="" and (statusTop+lineHeight(r.status)+5) or statusTop
  r.meta:ClearAllPoints(); r.meta:SetPoint("TOPLEFT",10,-metaTop)
  local rowHeight=math.max(66,summary~="" and (metaTop+lineHeight(r.meta)+14) or (metaTop+9))
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
 if A.PartyDiscovery then A.PartyDiscovery.Changed() end
 for _,b in ipairs(dungeonButtons) do
  local c=A.PreparationSummary(b.dungeon)
  local remaining=c.total-c.done-c.skipped
  local status=A.DungeonSummary(c)
  b:SetText(b.dungeon..(status~="" and ("\n"..status) or ""))
  b:GetFontString():SetTextColor(b.dungeon==A.db.dungeon and 1 or 0.8,b.dungeon==A.db.dungeon and 0.82 or 0.8,0.65)
 end
 details()
end
function A.SelectQuest(q)
 A.db.dungeon=q.dungeons[1]; A.db.search=""; selected=q
 if A.QuestChainGroups then
  local candidates={}; for _,n in ipairs(A.quests) do if A.Matches(n) then candidates[#candidates+1]=n end end
  for _,g in ipairs(A.QuestChainGroups(candidates)) do
   for _,n in ipairs(g.steps) do if n.id==q.id then selected=g.quest; break end end
  end
 end
 if not A.window then A.CreateWindow() end
 A.window.search:SetText(""); A.window:Show(); A.Scan()
 A.RevealSelectedDungeon()
end
-- Keep the journal's three-column layout proportional while resizing.
local function maxWindowScale()
 return math.min(1.5,(UIParent:GetWidth()-35)/960,(UIParent:GetHeight()-35)/650)
end
local function saveWindowPosition(f)
 local p,_,rp,x,y=f:GetPoint(); A.db.position={p,rp,x,y}
end
function A.SetWindowScale(scale)
 if not A.window then return end
 local maximum=maxWindowScale()
 scale=math.max(math.min(0.55,maximum),math.min(tonumber(scale) or math.min(1,maximum),maximum))
 A.window:SetScale(scale); A.db.windowScale=scale
end
function A.MinimizeWindow()
 if not A.window or not A.window:IsShown() then return end
 local f=A.window
 if f.search then f.search:ClearFocus() end
 if f.linkPanel then f.linkPanel:Hide() end
 GameTooltip:Hide(); f:Hide(); A.minimizedWindow:Show()
end
function A.RestoreWindow()
 if not A.window then return end
 A.minimizedWindow:Hide(); A.window:Show()
end
function A.ResetWindowGeometry()
 A.db.position=nil; A.db.windowScale=nil; A.db.minimizedPosition=nil
 if A.window then
  A.window:ClearAllPoints(); A.window:SetPoint("CENTER"); A.SetWindowScale(math.min(1,maxWindowScale()))
  A.minimizedWindow:ClearAllPoints(); A.minimizedWindow:SetPoint("TOP",UIParent,"TOP",0,-40)
 end
end
local function flatWindowControl(parent,glyph,label,action)
 local b=CreateFrame("Button",nil,parent); b:SetSize(30,28)
 local hover=b:CreateTexture(nil,"BACKGROUND"); hover:SetAllPoints(); hover:SetColorTexture(1,0.82,0.35,0.12); hover:Hide()
 local mark=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
 mark:SetFont("Fonts\\FRIZQT__.TTF",18,""); mark:SetPoint("CENTER",0,1); mark:SetText(glyph); mark:SetTextColor(1,0.82,0.35)
 b:SetScript("OnClick",action)
 b:SetScript("OnEnter",function(self) hover:Show(); GameTooltip:SetOwner(self,"ANCHOR_LEFT"); GameTooltip:AddLine(label,1,0.82,0.35); GameTooltip:Show() end)
 b:SetScript("OnLeave",function() hover:Hide(); GameTooltip:Hide() end)
 b.mark=mark
 return b
end
-- Acceptance can arrive before the quest log updates; finish after the next scan.
local acceptedQuestPage
function A.AcceptedQuestPage(id)
 local f=A.window
 if f and f:IsShown() and f.compactQuestPage and f.currentQuest and f.currentQuest.id==id then
  acceptedQuestPage={id=id,quest=selected}
 end
end
function A.FinishAcceptedQuestPage()
 local pending=acceptedQuestPage
 if not pending then return end
 local f=A.window
 if not f or not f:IsShown() or not f.compactQuestPage or selected~=pending.quest then
  acceptedQuestPage=nil; return
 end
 if not A.log[pending.id] then return end
 acceptedQuestPage=nil
 if not A.RunReadiness(selected) then A.ShowCompactQuestPage(false) end
end
function A.ShowCompactQuestPage(show)
 if not A.window then return end
 local f=A.window
 f.compactQuestPage=A.db.detailsCollapsed==true and show==true
 local visible=not A.db.detailsCollapsed or f.compactQuestPage
 f.listScroll:SetShown(not f.compactQuestPage)
 f.heading:SetShown(not f.compactQuestPage)
 f.listActions:SetShown(not f.compactQuestPage)
 f.detailScroll:SetShown(visible)
 f.detailTitle:SetShown(visible)
 f.metadata:SetShown(visible and selected~=nil)
 f.backToQuests:SetShown(f.compactQuestPage)
 local x=f.compactQuestPage and 230 or 604
 f.detailTitle:ClearAllPoints(); f.detailTitle:SetPoint("TOPLEFT",x,-91)
 f.metadata:ClearAllPoints(); f.metadata:SetPoint("TOPRIGHT",f,"TOPLEFT",x+313,-91)
 if f.linkPanel then f.linkPanel:Hide() end
 details()
end
function A.SetDetailsCollapsed(collapsed,keepPosition)
 if not A.window then return end
 local f=A.window
 if keepPosition then
  local left,top=f:GetLeft(),f:GetTop()
  f:ClearAllPoints(); f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top)
  saveWindowPosition(f)
 end
 A.db.detailsCollapsed=collapsed==true
 f:SetWidth(collapsed and 604 or 960)
 f.detailScroll:SetShown(not collapsed)
 f.detailTitle:SetShown(not collapsed)
 f.metadata:SetShown(not collapsed and selected~=nil)
 f.detailDivider:SetShown(not collapsed)
 if f.linkPanel then f.linkPanel:Hide() end
 f.detailsToggle.mark:SetText(collapsed and ">" or "<")
 f.headerTitle:SetFont("Fonts\\FRIZQT__.TTF",collapsed and 15 or 21,"")
 f.headerTitle:SetWidth(collapsed and 150 or 350)
 f.search:SetWidth(collapsed and 120 or 210)
 f.searchHint:SetWidth(collapsed and 130 or 220)
 f.searchHint:SetText(collapsed and "Search quests" or "Search quest, dungeon, NPC or ID")
 A.ShowCompactQuestPage(false)
end
function A.CreateWindow()
 if A.window then return end
 local f=CreateFrame("Frame","DungeonGuideForeverWindow",UIParent,"BackdropTemplate"); A.window=f
 -- Targeting uses an independent secure overlay; the journal stays unprotected.
 f:SetSize(960,650); f:SetPoint("CENTER"); A.SetWindowScale(A.db.windowScale); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
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
  if x==593 then f.detailDivider=divider end
 end
 f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
 f:SetScript("OnDragStart",function(self) self:StartMoving() end); f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing(); local p,_,rp,x,y=self:GetPoint(); A.db.position={p,rp,x,y} end)
 if A.db.position then local p=A.db.position; f:ClearAllPoints(); f:SetPoint(p[1],UIParent,p[2],p[3],p[4]) end
 tinsert(UISpecialFrames,"DungeonGuideForeverWindow")
 local title=text(f,21,23,-27,402); title:SetText("Dungeon Questie"); title:SetTextColor(1,0.82,0.35); title:SetShadowOffset(1,-1)
 f.headerTitle=title
 local close=flatWindowControl(f,"×","Close Dungeon Questie",function() f:Hide() end)
 f.close=close
 close:SetPoint("TOPRIGHT",-20,-21)
 f.close=close
 f.minimize=flatWindowControl(f,"−","Minimize Dungeon Questie",function() A.MinimizeWindow() end)
 f.minimize:SetPoint("RIGHT",close,"LEFT",-1,0)
 f.detailsToggle=flatWindowControl(f,"<","Collapse / expand quest panel",function()
  A.SetDetailsCollapsed(not A.db.detailsCollapsed,true); GameTooltip:Hide()
 end)
 f.detailsToggle:SetPoint("RIGHT",f.minimize,"LEFT",-1,0)
 local mini=CreateFrame("Frame",nil,UIParent,"BackdropTemplate"); A.minimizedWindow=mini
 mini:SetSize(220,34); mini:SetPoint("TOP",UIParent,"TOP",0,-40); mini:SetFrameStrata("DIALOG"); mini:SetClampedToScreen(true)
 mini:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
 mini:EnableMouse(true); mini:SetMovable(true); mini:RegisterForDrag("LeftButton")
 mini:SetScript("OnDragStart",function(self) self:StartMoving() end)
 mini:SetScript("OnDragStop",function(self) self:StopMovingOrSizing(); local p,_,rp,x,y=self:GetPoint(); A.db.minimizedPosition={p,rp,x,y} end)
 if A.db.minimizedPosition then local p=A.db.minimizedPosition; mini:ClearAllPoints(); mini:SetPoint(p[1],UIParent,p[2],p[3],p[4]) end
 -- A title-bar hit area avoids stretching a decorative button across the strip.
 mini.restore=CreateFrame("Button",nil,mini)
 mini.restore:SetPoint("TOPLEFT",7,-4); mini.restore:SetPoint("BOTTOMRIGHT",-34,4)
 local miniTitle=mini.restore:CreateFontString(nil,"OVERLAY","GameFontNormal")
 miniTitle:SetPoint("LEFT",5,0); miniTitle:SetFont("Fonts\\FRIZQT__.TTF",13,"")
 miniTitle:SetText("Dungeon Questie"); miniTitle:SetTextColor(1,0.82,0.35); miniTitle:SetShadowOffset(1,-1)
 local restoreMark=mini.restore:CreateTexture(nil,"OVERLAY")
 restoreMark:SetColorTexture(1,0.82,0.35,1); restoreMark:SetSize(10,2); restoreMark:SetPoint("RIGHT",-6,0)
 local restoreStem=mini.restore:CreateTexture(nil,"OVERLAY")
 restoreStem:SetColorTexture(1,0.82,0.35,1); restoreStem:SetSize(2,10); restoreStem:SetPoint("CENTER",restoreMark,"CENTER")
 mini.restore:SetScript("OnClick",function() A.RestoreWindow() end)
 mini.restore:SetScript("OnEnter",function(self)
  miniTitle:SetTextColor(1,0.95,0.65)
  GameTooltip:SetOwner(self,"ANCHOR_BOTTOM"); GameTooltip:AddLine("Restore Dungeon Questie",1,0.82,0); GameTooltip:AddLine("Drag to move",0.8,0.8,0.8); GameTooltip:Show()
 end)
 mini.restore:SetScript("OnLeave",function() miniTitle:SetTextColor(1,0.82,0.35); GameTooltip:Hide() end)
 mini.restore:RegisterForDrag("LeftButton"); mini.restore:SetScript("OnDragStart",function() mini:StartMoving() end)
 mini.restore:SetScript("OnDragStop",function() mini:GetScript("OnDragStop")(mini) end)
 local miniClose=flatWindowControl(mini,"×","Close minimized journal",function() mini:Hide() end); miniClose:SetPoint("TOPRIGHT",-4,-3)
 miniClose:SetScript("OnClick",function() mini:Hide() end); mini:Hide()
 f.resize=CreateFrame("Button",nil,f); f.resize:SetSize(22,22); f.resize:SetPoint("BOTTOMRIGHT",-5,5)
 f.resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
 f.resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
 f.resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
 f.resize:SetScript("OnMouseDown",function(self,mouse)
  if mouse~="LeftButton" then return end
  local parentScale=UIParent:GetEffectiveScale()
  local left,top=f:GetLeft()*f:GetScale(),f:GetTop()*f:GetScale()
  f:ClearAllPoints(); f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left/f:GetScale(),top/f:GetScale())
  self:SetScript("OnUpdate",function()
   local x,y=GetCursorPosition(); x=x/parentScale; y=y/parentScale
   A.SetWindowScale(math.max((x-left)/f:GetWidth(),(top-y)/650))
   f:ClearAllPoints(); f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left/f:GetScale(),top/f:GetScale())
  end)
 end)
 f.resize:SetScript("OnMouseUp",function(self) self:SetScript("OnUpdate",nil); saveWindowPosition(f) end)
 f:SetScript("OnHide",function() f.resize:SetScript("OnUpdate",nil); if f.targetAction and not InCombatLockdown() then f.targetAction:Hide() end end)

 f.search=CreateFrame("EditBox",nil,f,"InputBoxTemplate"); f.search:SetSize(210,24); f.search:SetPoint("TOPLEFT",480,-23); f.search:SetAutoFocus(false); f.search:SetMaxLetters(100)
 f.search:SetText(A.db.search or ""); f.search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
 f.search:SetScript("OnTextChanged",function(self) A.db.search=self:GetText(); f.listScroll:SetVerticalScroll(0); A.Refresh(); A.RefreshPins() end)
 local hint=text(f,10,480,-51,220); hint:SetText("Search quest, dungeon, NPC or ID"); hint:SetTextColor(0.82,0.77,0.65)
 f.export=iconButton(f,"Export quest progress","Interface\\Icons\\INV_Misc_Note_01",754,-20,function() A.ShowProgressExport(selected) end)
 local ds,dc=scroll(f,16,-81,183,551)
 f.dungeonScroll=ds; f.dungeonChild=dc
 local names={}; for _,d in ipairs(A.dungeons) do names[#names+1]=d.name end
 for i,d in ipairs(names) do
  local b=button(dc,d:gsub("^Scarlet Monastery %- ","SM - "),178,0,-(i-1)*86,function() A.ShowCompactQuestPage(false); A.db.dungeon=d; f.listScroll:SetVerticalScroll(0); f.detailScroll:SetVerticalScroll(0); A.Refresh(); A.RefreshPins() end)
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
  b.findGroup=button(dc,"Find Group",178,0,-(i-1)*86-55,function() A.FindGroup(d) end)
  b.findGroup:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine("Find players for "..d,1,0.82,0.35,true); GameTooltip:Show() end)
  b.findGroup:SetScript("OnLeave",function() GameTooltip:Hide() end)
 end
 dc:SetHeight(#names*86)
 f.routeToggle=iconButton(f,"Plan quest collection route","Interface\\Icons\\Ability_Tracking",798,-20,function() A.OpenNavigation() end)
 f.locationsToggle=iconButton(f,"Browse quest locations","Interface\\Icons\\INV_Misc_Map_01",842,-20,function() A.OpenNavigation(selected,true) end)
 f.heading=text(f,14,232,-83,334)
 f.listActions=CreateFrame("Frame",nil,f); f.listActions:SetPoint("TOPLEFT",230,-105); f.listActions:SetSize(334,24)
 f.runStatus=CreateFrame("Button",nil,f.listActions); f.runStatus:SetPoint("TOPLEFT",0,0); f.runStatus:SetSize(130,24)
 f.runStatus.label=text(f.runStatus,10,0,-6,130); f.runStatus.label:SetText("")
 f.runStatus:Hide()
 f.runStatus:SetScript("OnClick",function() if A.PartyDiscovery then A.PartyDiscovery.ToggleAvailable() end end)
 f.runStatus:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine("Click to change your availability"); GameTooltip:Show() end)
 f.runStatus:SetScript("OnLeave",function() GameTooltip:Hide() end)
 for i,entry in ipairs({
  {mode="quests",icon="INV_Misc_Note_01",tip="Share listed quest links"},
  {mode="guild",icon="INV_Shirt_GuildTabard_01",tip="Ask guild: collect quests + dungeon"},
  {mode="LFG",icon="INV_Misc_GroupLooking",tip="LFG: find a dungeon group"},
  {mode="LFM",icon="INV_Misc_GroupNeedMore",tip="LFM: recruit for this dungeon"},
  {mode="matches",icon="INV_Misc_Spyglass_03",tip="Recent LFG/LFM chat matches"},
  {mode="settings",icon="Trade_Engineering",tip="Chat and recruitment settings"}}) do
  local mode=entry.mode
  local b=iconButton(f.listActions,entry.tip,"Interface\\Icons\\"..entry.icon,(i-1)*35,0,function(self) GameTooltip:Hide(); A.OpenDungeonChatAction(mode,self) end)
  if mode=="quests" then
   f.questShareButton=b
   b.count=b:CreateFontString(nil,"OVERLAY")
   b.count:SetFont("Fonts\\FRIZQT__.TTF",9,"OUTLINE")
   b.count:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",1,-1)
   b.count:SetTextColor(1,0.9,0.65)
  end
  b:SetSize(24,24)
  b:ClearAllPoints(); b:SetPoint("TOPRIGHT",f.listActions,"TOPRIGHT",-(6-i)*35,0)
 end
 f.listScroll,f.listChild=scroll(f,230,-133,334,498)
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
 f.locationArtwork=A.CreateLocationArtwork(f.detailChild)
 f.detailText=text(f.detailChild,12,0,0,300)
 f.goCurrent=CreateFrame("Button",nil,f.detailChild); f.goCurrent:SetSize(300,36)
 f.goCurrent.label=text(f.goCurrent,12,4,-5,292)
 local goHover=f.goCurrent:CreateTexture(nil,"BACKGROUND"); goHover:SetAllPoints(); goHover:SetColorTexture(0.45,0.25,0.05,0.14); goHover:Hide()
 f.goCurrent:SetScript("OnEnter",function(self)
  goHover:Show(); GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
  GameTooltip:AddLine(f.mapButton.tip or "Destination unavailable",1,0.82,0.35,true); GameTooltip:Show()
 end)
 f.goCurrent:SetScript("OnLeave",function() goHover:Hide(); GameTooltip:Hide() end)
 f.goCurrent:SetScript("OnClick",function()
  local destination=selected and A.MapLocation(selected)
  if destination then A.Navigate(destination) end
 end)
 f.mapButton=iconButton(f.detailChild,"Navigate to quest location","Interface\\Icons\\INV_Misc_Map_01",604,-600,function() if f.mapTarget then A.Navigate(f.mapTarget) end end)
 f.logButton=iconButton(f.detailChild,"Open quest log","Interface\\Icons\\INV_Misc_Book_09",648,-600,function()
  if InCombatLockdown() then A.Print("Open the game quest log after combat."); return end
  if not selected then return end
  local current=f.currentQuest or selected
  if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(current.id)
  elseif ShowQuestLog then ShowQuestLog(A.log[current.id] and A.log[current.id].index) end
 end)
 f.source=iconButton(f.detailChild,"Show quest source link","Interface\\Icons\\INV_Misc_Spyglass_03",692,-600,function()
  if not selected then return end
  local url=(f.currentQuest and f.currentQuest.source) or selected.source
  if not url or url=="" then return end
  if not f.link then
   f.linkPanel=CreateFrame("Frame",nil,f,"BackdropTemplate")
   f.linkPanel:SetSize(313,90); f.linkPanel:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-30,25)
   f.linkPanel:SetFrameStrata("DIALOG")
   f.linkPanel:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
   text(f.linkPanel,13,14,-12,250):SetText("Source link")
   text(f.linkPanel,10,14,-67,285):SetText("Ctrl+C to copy. Enter or Escape to close.")
   local close=CreateFrame("Button",nil,f.linkPanel,"UIPanelCloseButton")
   close:SetPoint("TOPRIGHT",0,0); close:SetScript("OnClick",function() f.linkPanel:Hide() end)
   f.link=CreateFrame("EditBox",nil,f.linkPanel,"InputBoxTemplate")
   f.link:SetSize(280,27); f.link:SetPoint("TOPLEFT",18,-33); f.link:SetAutoFocus(false)
   f.link:SetScript("OnEscapePressed",function() f.linkPanel:Hide() end)
   f.link:SetScript("OnEnterPressed",function() f.linkPanel:Hide() end)
   f.linkPanel:SetScript("OnHide",function() f.link:ClearFocus() end)
  end
  GameTooltip:Hide()
  f.linkPanel:Show(); f.link:Show(); f.link:SetText(url); f.link:SetFocus(); f.link:HighlightText()

 end)
 f.chatButton=iconButton(f.detailChild,"Choose chat for quest link\nShift-click: insert into current chat","Interface\\Icons\\INV_Misc_Note_01",780,-600,function() A.OpenQuestChatMenu(f.currentQuest or selected,f.chatButton) end)
 f.targetButton=iconButton(f.detailChild,"Target quest giver","Interface\\Icons\\Ability_Hunter_SniperShot",736,-600,nil)
 local function backToList()
  if not f.compactQuestPage then return end
  A.ShowCompactQuestPage(false); GameTooltip:Hide()
  f.backToQuests.label:SetTextColor(0.22,0.15,0.09)
 end
 f.backToQuests=CreateFrame("Button",nil,f)
 f.backToQuests:SetAllPoints(f.detailTitle)
 f.backToQuests.label=f.detailTitle
 f.backToQuests:SetScript("OnClick",backToList)
 f.backToQuests:SetScript("OnEnter",function(self)
  f.backToQuests.label:SetTextColor(0.40,0.25,0.10)
  GameTooltip:SetOwner(self,"ANCHOR_LEFT"); GameTooltip:AddLine("Back to quest list"); GameTooltip:Show()
 end)
 f.backToQuests:SetScript("OnLeave",function() f.backToQuests.label:SetTextColor(0.22,0.15,0.09); GameTooltip:Hide() end)
 f.backToQuests:Hide()
 -- Global mouse events also reach us when a child (map, reward, or scroll area) owns the click.
 f.backMouseWatcher=CreateFrame("Frame")
 f.backMouseWatcher:RegisterEvent("GLOBAL_MOUSE_UP")
 f.backMouseWatcher:SetScript("OnEvent",function(_,_,mouseButton)
  if mouseButton=="RightButton" and f:IsShown() and f.compactQuestPage and f:IsMouseOver() then backToList() end
 end)
 f:SetScript("OnUpdate",function() A.UpdateTargetAction(f) end)
 f:SetScript("OnShow",function() A.minimizedWindow:Hide(); A.Scan(); A.RevealSelectedDungeon(); f.listScroll:SetVerticalScroll(0) end)
 local previous=f.detailsToggle
 for _,control in ipairs({f.locationsToggle,f.routeToggle,f.export}) do
  control:ClearAllPoints(); control:SetPoint("RIGHT",previous,"LEFT",-8,0); previous=control
 end
 f.search:ClearAllPoints(); f.search:SetPoint("RIGHT",previous,"LEFT",-16,0)
 f.searchHint=hint; hint:ClearAllPoints(); hint:SetPoint("TOPLEFT",f.search,"BOTTOMLEFT",0,-3)
 A.SetDetailsCollapsed(A.db.detailsCollapsed)
 f:Hide()
end
function A.Toggle()
 if not A.db then return end
 if not A.window then A.CreateWindow() end
 if A.minimizedWindow:IsShown() then A.RestoreWindow() else A.window:SetShown(not A.window:IsShown()) end
end
