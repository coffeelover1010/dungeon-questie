local _, A = ...
local chatNames={
 ["The Hall of Thanes"]="HoT",["Ragefire Chasm"]="RFC",["Ruins of Lordaeron"]="RoL",
 ["Wailing Caverns"]="WC",["Deadmines"]="VC",["The Deadmines"]="VC",
 ["Shadowfang Keep"]="SFK",["Stormwind Stockade"]="Stocks",["The Stockade"]="Stocks",
 ["Excavation Site: Wetlands"]="ESW",["Blackfathom Deeps"]="BFD",["City of Dalaran"]="CoD",
 ["Scarlet Monastery - Graveyard"]="SM GY",["Scarlet Monastery - Library"]="SM Lib",
 ["Scarlet Monastery - Armory"]="SM Arm",["Scarlet Monastery - Cathedral"]="SM Cath",
 ["Gnomeregan"]="Gnomer",["Razorfen Kraul"]="RFK",["The Drowned City"]="DC",
 ["Krol'dok Stronghold"]="KS",["Razorfen Downs"]="RFD",["Uldaman"]="Ulda",
 ["Zul'Farrak"]="ZF",["Maraudon"]="Mara",["Alcaz Prison"]="AP",["Sunken Temple"]="ST",
 ["Blackrock Depths"]="BRD",["Blackmaw Hold"]="BH",["Lower Blackrock Spire"]="LBRS",
 ["The Shaper's Terrace"]="ShT",["Upper Blackrock Spire"]="UBRS",["Dire Maul"]="DM",
 ["Scholomance"]="Scholo",["Stratholme"]="Strat",
}
function A.DungeonChatName(dungeon) return chatNames[dungeon] or dungeon end
function A.QuestChatLink(q)
 if not q or not tonumber(q.id) then return end
 local link=A.Safe(C_QuestLog and C_QuestLog.GetQuestLink,q.id) or A.Safe(GetQuestLink,q.id)
 if type(link)=="string" and link~="" then return link end
 -- Use Questie's own chat-safe representation for quests outside the log.
 -- Do not fabricate native hyperlinks that the client may reject in chat.
 local module=QuestieLoader and A.Safe(QuestieLoader.ImportModule,QuestieLoader,"QuestieLink")
 link=module and A.Safe(module.GetQuestLinkStringById,q.id)
 if type(link)=="string" and link~="" then return link end
end
function A.LinkQuestInChat(q)
 local link=A.QuestChatLink(q)
 if not link then if q then A.Print("Quest link unavailable. Accept the quest or enable Questie.") end; return end
 local insert=ChatFrameUtil and ChatFrameUtil.InsertLink or ChatEdit_InsertLink
 if insert and insert(link) then return end
 local open=ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
 if open then open(link) else A.Print("Chat input is unavailable.") end
end
function A.QuestChatDestinations()
 local choices={{label="Say",kind="SAY",prefix="/s "},{label="Yell",kind="YELL",prefix="/y "}}
 if A.Safe(IsInGuild) then choices[#choices+1]={label="Guild",kind="GUILD",prefix="/g "} end
 if A.Safe(IsInRaid) then choices[#choices+1]={label="Raid",kind="RAID",prefix="/raid "}
 elseif A.Safe(IsInGroup) then choices[#choices+1]={label="Party",kind="PARTY",prefix="/p "} end
 if LE_PARTY_CATEGORY_INSTANCE and A.Safe(IsInGroup,LE_PARTY_CATEGORY_INSTANCE) then
  choices[#choices+1]={label="Instance",kind="INSTANCE_CHAT",prefix="/i "}
 end
 if GetChannelList then
  local channels={GetChannelList()}
  for i=1,#channels,3 do
   local id,name,disabled=channels[i],channels[i+1],channels[i+2]
   if type(id)=="number" and id>0 and type(name)=="string" and not disabled and name~="DungeonQuestie" then
    choices[#choices+1]={label=name:lower()=="world" and "World" or (id..". "..name),kind="CHANNEL",target=id,name=name,prefix="/"..id.." "}
   end
  end
 end
 return choices
end
local sendingQuestLink,questLinkBlocked=false,false
local chatGuard=CreateFrame("Frame")
chatGuard:RegisterEvent("ADDON_ACTION_BLOCKED"); chatGuard:RegisterEvent("ADDON_ACTION_FORBIDDEN")
chatGuard:SetScript("OnEvent",function() if sendingQuestLink then questLinkBlocked=true end end)
function A.SendQuestChatMessage(link,destination)
 if type(link)~="string" or link=="" or #link>255 or link:find("[\r\n]") then A.Print("Use one message of up to 255 bytes."); return false end
 -- Recheck membership and channel identity at click time.
 local available=false
 for _,choice in ipairs(A.QuestChatDestinations()) do
  if choice.kind==destination.kind and choice.target==destination.target and choice.name==destination.name then available=true; break end
 end
 if not available then A.Print("Chat destination changed. Choose it again."); return end
 local send=C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
 sendingQuestLink,questLinkBlocked=true,false
 local ok,result=false,nil
 if send then ok,result=pcall(send,link,destination.kind,nil,destination.target) end
 sendingQuestLink=false
 if not ok or result==false or questLinkBlocked then
  local open=ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
  if open then open(destination.prefix..link); A.Print("Chat send blocked. Press Enter to send the draft."); return false,"draft"
  else A.Print("Chat send unavailable.") end
  return false
 end
 return true
end
function A.SendQuestLink(q,destination)
 local link=A.QuestChatLink(q)
 if not link then A.Print("Quest link unavailable. Accept the quest or enable Questie."); return end
 return A.SendQuestChatMessage(link,destination)
end
function A.OpenQuestChatMenu(q,owner)
 if not q then return end
 if IsShiftKeyDown and IsShiftKeyDown() then A.LinkQuestInChat(q); return end
 if not MenuUtil or not MenuUtil.CreateContextMenu then A.LinkQuestInChat(q); return end
 local choices=A.QuestChatDestinations()
 MenuUtil.CreateContextMenu(owner,function(_,root)
  root:CreateTitle("Send quest link to")
  for _,destination in ipairs(choices) do
   local choice=destination
   root:CreateButton(choice.label,function() A.SendQuestLink(q,choice) end)
  end
  root:CreateDivider()
  root:CreateButton("Insert into current chat",function() A.LinkQuestInChat(q) end)
 end)
end
function A.DungeonRunMessage(dungeon,mode,collect,full)
 if A.ChatRecruitment then return A.ChatRecruitment.Message(dungeon,mode,collect,full) end
 dungeon=A.DungeonChatName(dungeon)
 if mode=="guild" then return "Anyone up for "..dungeon.." - Quest Pickup + Full Run?" end
 return mode.." "..dungeon.." - "..(collect and "Quest Pickup" or "Dungeon Only")..((full or collect) and " - Full Run" or "")
end
function A.DungeonQuestMessages(dungeon,quests)
 local messages,seen={},{}
 local prefix=A.DungeonChatName(dungeon).." quests: "
 local line=prefix
 for _,q in ipairs(quests or {}) do
  if not seen[q.id] then
   seen[q.id]=true
   local link=A.QuestChatLink(q)
   if not link then return nil,"No chat link for "..q.name..". Accept it or enable Questie." end
   if #prefix+#link>255 then return nil,"Quest link is too long for chat: "..q.name end
   if #line+#link+1>255 then messages[#messages+1]=line; prefix=""; line=prefix end
   line=line..(line==prefix and "" or " ")..link
  end
 end
 if line~=prefix then messages[#messages+1]=line end
 if #messages==0 then return nil,"No quests in the current list." end
 return messages
end
function A.SendDungeonMessages(messages,destination,onSent)
 if #messages==0 then return end
 -- Each chat send stays on the user's click; timers lose that authorization.
 local ok,reason=A.SendQuestChatMessage(messages[1],destination)
 local first=(ok or reason=="draft") and 2 or 1
 local remaining={}
 for i=first,#messages do remaining[#remaining+1]=messages[i] end
 if #remaining>0 then
  A.pendingDungeonMessages={messages=remaining,destination=destination}
 end
 if ok and onSent then onSent() end
end
function A.UpdateQuestShare()
 local messages,reason=A.DungeonQuestMessages(A.db.dungeon or "Dungeon",A.window and A.window.listedQuests or {})
 local key=messages and table.concat(messages,"\n") or ""
 local state=A.questShare
 if not state or state.key~=key then
  state={key=key,messages=messages,index=1}; A.questShare=state
 end
 local button=A.window and A.window.questShareButton
 if button and button.count then
  button.count:SetText(messages and state.index>1 and (state.index.."/"..#messages) or "")
 end
 return state,reason
end
function A.SendQuestShare(state,destination)
 -- Ignore a stale menu if the selected dungeon or quest list has changed.
 if A.UpdateQuestShare()~=state then return end
 local ok=A.SendQuestChatMessage(state.messages[state.index],destination)
 if not ok then return end
 state.destination=destination
 state.index=state.index+1
 if state.index>#state.messages then state.index=1; state.destination=nil end
 A.UpdateQuestShare()
end
function A.OpenDungeonChatAction(mode,owner)
 if mode=="settings" then A.ChatRecruitment.ShowSettings(); return end
 if mode=="matches" then A.ChatRecruitment.ShowMatches(owner); return end
 if mode=="quests" then
  local state,reason=A.UpdateQuestShare()
  if not state.messages then A.Print(reason); return end
  if state.destination then A.SendQuestShare(state,state.destination); return end
  if not MenuUtil or not MenuUtil.CreateContextMenu then A.Print("Chat menu unavailable."); return end
  MenuUtil.CreateContextMenu(owner,function(_,root)
   root:CreateTitle("Share listed quests")
   for _,destination in ipairs(A.QuestChatDestinations()) do
    local choice=destination
    root:CreateButton(choice.label,function() A.SendQuestShare(state,choice) end)
   end
  end)
  return
 end
 local dungeon=A.db.dungeon
 if mode=="LFM" and A.ChatRecruitment then
  local slots=A.ChatRecruitment.GroupNeeds()
  if slots==0 or A.Safe(IsInRaid) then A.Print("Your dungeon party is full or is a raid."); return end
 end
 local quests={}; for _,q in ipairs(A.window and A.window.listedQuests or {}) do quests[#quests+1]=q end
 if mode=="guild" then
  if not A.Safe(IsInGuild) then A.Print("You are not in a guild."); return end
  A.SendDungeonMessages({A.DungeonRunMessage(dungeon,"guild",true,false)},{label="Guild",kind="GUILD",prefix="/g "},function() if A.ChatRecruitment then A.ChatRecruitment.Start(dungeon) end end); return
 end
 if not MenuUtil or not MenuUtil.CreateContextMenu then A.Print("Chat menu unavailable."); return end
 local messages
 if mode=="quests" then
  local reason; messages,reason=A.DungeonQuestMessages(dungeon,quests)
  if not messages then A.Print(reason); return end
 end
 MenuUtil.CreateContextMenu(owner,function(_,root)
  root:CreateTitle(mode=="quests" and "Share listed quests" or (mode.." "..dungeon))
  local function destinations(parent,collect,full)
   for _,destination in ipairs(A.QuestChatDestinations()) do
    local choice=destination
    parent:CreateButton(choice.label,function()
     A.SendDungeonMessages(messages or {A.DungeonRunMessage(dungeon,mode,collect,full)},choice,function() if mode=="LFM" and A.ChatRecruitment then A.ChatRecruitment.Start(dungeon) end end)
    end)
   end
  end
  if mode=="quests" then
   if A.pendingDungeonMessages then root:CreateButton("Send remaining links ("..#A.pendingDungeonMessages.messages..")",function()
    local pending=A.pendingDungeonMessages; A.pendingDungeonMessages=nil
    A.SendDungeonMessages(pending.messages,pending.destination)
   end) end
   destinations(root)
  else
   for _,preset in ipairs({{label="Dungeon Only"},{label="Full Run",full=true},{label="Quest Pickup + Full Run",collect=true,full=true}}) do
    destinations(root:CreateButton(preset.label),preset.collect,preset.full)
   end
  end
 end)
end
local instanceTags={[62]=true,[81]=true,[85]=true,[88]=true,[89]=true}
function A.IsGroupQuest(q)
 if not q then return false end
 local api=C_QuestLog or {}
 local tag=A.Safe(api.GetQuestTagInfo,q.id)
 -- Dungeon/raid quests can also suggest multiple players. Exclude them first.
 local record=A.byID and A.byID[q.id]
 if (tag and instanceTags[tag.tagID]) or q.pickupInside or (record and record.pickupInside) then return false end
 local size=A.Safe(api.GetSuggestedGroupSize,q.id)
 return (tag and tag.tagID==1) or (type(size)=="number" and size>1) or false
end
function A.QuestGroupMessage(q, linked)
 local title=linked and A.QuestChatLink(q) or nil
 return "LFG "..(title or ("["..q.name.."]")).." - anyone up for it?"
end
function A.QuestGeneral(q)
 if not A.IsGroupQuest(q) then return end
 local channel=A.Safe(GetChannelName,GENERAL or "General")
 if type(channel)~="number" or channel<1 then A.Print("Join your zone's General channel first."); return end
 local open=ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
 if not open then A.Print("Chat input is unavailable."); return end
 open("/"..channel.." "..A.QuestGroupMessage(q,true))
end
function A.QuestCreateGroup(q)
 if not A.IsGroupQuest(q) then return end
 if InCombatLockdown() then A.Print("Leave combat before creating a group."); return end
 if not A.Safe(C_LFGInfo and C_LFGInfo.CanPlayerUsePremadeGroup) then A.Print("The Group Browser is unavailable right now."); return end
 if IsInGroup() and not UnitIsGroupLeader("player") then A.Print("Your party leader must create the listing."); return end
 if not LFGListingFrame and GroupFinderVanillaStyle_LoadUI then GroupFinderVanillaStyle_LoadUI() end
 local listing=LFGListingFrame
 if not listing or not listing.SetCategorySelection or not LFGVanilla_ShowFrame then A.Print("The listing form is unavailable."); return end
 if A.Safe(C_LFGList and C_LFGList.HasActiveEntryInfo) then A.Print("You already have a listing. Edit or remove it in the Group Browser first."); return end
 -- Category 120 is Custom in the Forever client. Verify it is available.
 local found=false
 for _,id in ipairs(A.Safe(C_LFGList and C_LFGList.GetAvailableCategories) or {}) do if id==120 then found=true end end
 if not found then A.Print("Custom groups are unavailable to this character."); return end
 LFGVanilla_ShowFrame(1)
 listing:SetCategorySelection(120)
 -- The native comment box forbids addon SetText and paste. Keep it secure.
 if not A.questListingHint then
  local hint=CreateFrame("Frame",nil,listing,"BackdropTemplate")
  hint:SetSize(310,74); hint:SetPoint("TOPLEFT",listing,"BOTTOMLEFT",0,-4)
  hint:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background"})
  hint.text=hint:CreateFontString(nil,"OVERLAY","GameFontNormal")
  hint.text:SetPoint("TOPLEFT",10,-8); hint.text:SetWidth(290)
  A.questListingHint=hint
  if listing.HookScript then listing:HookScript("OnHide",function() hint:Hide() end) end
 end
 A.questListingHint.text:SetText("Type your description, then click Post:\n"..A.QuestGroupMessage(q,false))
 A.questListingHint:Show()
end
