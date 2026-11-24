local _,A=...
local L={offered={}}; A.ReadyListing=L
local function safe(fn,...)
 if type(fn)~="function" then return nil end
 local ok,value=pcall(fn,...)
 if ok and not (issecretvalue and issecretvalue(value)) then return value end
end
function L.Candidate(dungeon)
 local api=C_LFGList
 if not A.db or A.db.dungeon~=dungeon or safe(InCombatLockdown)~=false or safe(IsInGroup)~=false or safe(IsInRaid)~=false then return end
 if not api or not api.CreateListing or not api.ClearCreationTextFields or not api.SetEntryTitle or not api.GetActiveEntryInfo then return end
 if safe(api.HasActiveEntryInfo)~=false or safe(C_LFGInfo and C_LFGInfo.CanPlayerUsePremadeGroup)~=true then return end
 local style=Enum and Enum.LFGEntryGeneralPlaystyle and Enum.LFGEntryGeneralPlaystyle.FunRelaxed
 local none=Enum and Enum.LFGEntryPlaystyle and Enum.LFGEntryPlaystyle.None
 if not style or not none then return end
 local roles=safe(C_LFGListRoles and C_LFGListRoles.GetRoles)
 if type(roles)~="table" or not (roles.tank or roles.healer or roles.dps) then return end
 if not A.PartyDiscovery or not A.PartyDiscovery.Ready(dungeon) then return end
 -- Inside pickups count as remaining work even before they enter the log.
 -- A completed catalogue alone is not a reason to offer another quest run.
 local unfinished=false
 for _,q in ipairs(A.quests or {}) do
  local plan=A.collection
  local excluded=plan and plan.dungeon==dungeon and plan.excluded[q.id]
  if A.InDungeon(q,dungeon) and A.ChecklistVisible(q) and not excluded and not A.Restriction(q)
   and A.Completed(q.id)~=true and not A.DungeonWorkFinished(q) then unfinished=true; break end
 end
 if not unfinished then return end
 local ids=safe(A.GroupActivities,dungeon)
 if type(ids)~="table" or #ids~=1 then return end
 local info=safe(api.GetActivityInfoTable,ids[1])
 local level=safe(UnitLevel,"player")
 if not info or type(level)~="number" or type(info.minLevel)~="number" or level<info.minLevel then return end
 if info.categoryID~=2 or type(info.maxNumPlayers)~="number" or info.maxNumPlayers<=1 then return end
 local category=safe(api.GetLfgCategoryInfo,info.categoryID)
 if not category or category.autoChooseActivity then return end
 -- Do not discard a listing the player is currently composing.
 if LFGListingFrame and LFGListingFrame.IsShown and LFGListingFrame:IsShown() then return end
 return {dungeon=dungeon,id=ids[1],group=info.groupFinderActivityGroupID or 0,style=style,none=none}
end
local function finish(message)
 if L.timeout then L.timeout:Cancel(); L.timeout=nil end
 L.pending=nil
 A.Print(message)
end
function L.Confirm()
 local pending=L.pending; if not pending then return end
 local entry=safe(C_LFGList.GetActiveEntryInfo)
 if not entry then return end
 if entry.activityIDs and #entry.activityIDs==1 and entry.activityIDs[1]==pending.id
  and entry.generalPlaystyle==pending.style and entry.comment=="" then
  finish("Listed for "..pending.dungeon.." - relaxed, no comment.")
 else
  finish("A listing exists, but its settings do not match the request. Check the Group Browser.")
 end
end
function L.Accept(dungeon)
 if L.pending then return end
 local candidate=L.Candidate(dungeon)
 if not candidate then A.Print("Cannot list now: readiness or Group Browser requirements changed."); return end
 L.pending=candidate; L.blocked=false; L.sending=true
 local ok,result=pcall(function()
  C_LFGList.ClearCreationTextFields()
  C_LFGList.SetEntryTitle(candidate.id,candidate.group,candidate.none,candidate.style)
  if L.blocked then return false end
  return C_LFGList.CreateListing({activityIDs={candidate.id},generalPlaystyle=candidate.style,playstyle=candidate.none,
   isAutoAccept=false,isPrivateGroup=false,newPlayerFriendly=false})
 end)
 L.sending=false
 if not ok or result~=true or L.blocked then finish("Listing was not confirmed. Check the Group Browser; no automatic retry."); return end
 L.Confirm()
 if L.pending then
  L.timeout=C_Timer.NewTimer(10,function()
   L.timeout=nil; L.Confirm()
   if L.pending then finish("Listing was not confirmed by the server. Check the Group Browser; no automatic retry.") end
  end)
 end
end
function L.Check()
 if L.pending or not A.db or not StaticPopup_Show then return end
 local dungeon=A.db.dungeon
 if L.offered[dungeon] or not L.Candidate(dungeon) then return end
 L.offered[dungeon]=true
 StaticPopup_Show("DGF_READY_LISTING",dungeon,nil,dungeon)
end
function L.Changed()
 if L.timer or not C_Timer or not C_Timer.NewTimer then return end
 L.timer=C_Timer.NewTimer(2,function() L.timer=nil; L.Check() end)
end
StaticPopupDialogs["DGF_READY_LISTING"]={
 text="Your quests are ready for %s.\n\nList yourself as relaxed with no comment?",
 button1="List me",button2="Not now",timeout=0,whileDead=false,hideOnEscape=true,preferredIndex=3,
 OnAccept=function(_,dungeon) L.Accept(dungeon) end,
}
local frame=CreateFrame("Frame")
for _,event in ipairs({"LFG_LIST_ACTIVE_ENTRY_UPDATE","LFG_LIST_AVAILABILITY_UPDATE","LFG_LIST_ROLE_UPDATE","GROUP_ROSTER_UPDATE","PLAYER_REGEN_ENABLED","ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN"}) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent",function(_,event)
 if event=="ADDON_ACTION_BLOCKED" or event=="ADDON_ACTION_FORBIDDEN" then if L.sending then L.blocked=true end; return end
 if event=="LFG_LIST_ACTIVE_ENTRY_UPDATE" then
  if not L.sending then L.Confirm() end
 else L.Changed() end
end)
