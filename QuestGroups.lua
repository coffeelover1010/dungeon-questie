local _, A = ...
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
 local title=linked and A.Safe(GetQuestLink,q.id) or nil
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
 if A.window then A.window:Hide() end
end
