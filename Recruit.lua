local _, A = ...
local R={classes={"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE","WARLOCK","DRUID"},contacted={},offsets={}}
A.recruit=R
local function plain(v) return not (issecretvalue and issecretvalue(v)) end
local function safe(fn,...)
 if type(fn)~="function" then return nil end
 local ok,value=pcall(fn,...); if ok and plain(value) then return value end
end
local function identity(name) return type(name)=="string" and name:lower() or "" end
local function validRange(low,high)
 return type(low)=="number" and type(high)=="number" and low>=1 and high>=low and low%1==0 and high%1==0
end
function R:Party()
 local classes,names={},{}
 for i=0,4 do
  local unit=i==0 and "player" or "party"..i
  if UnitExists(unit) then
   local _,class=UnitClass(unit); if class then classes[class]=(classes[class] or 0)+1 end
   local name=GetUnitName(unit,true); if name then names[identity(name)]=true end
  end
 end
 return classes,names
end
function R:SuggestedRange(ids)
 local low,high
 for _,id in ipairs(ids) do
  local info=safe(C_LFGList.GetActivityInfoTable,id)
  if info and plain(info.minLevelSuggestion) and plain(info.maxLevelSuggestion) then
   local a,b=info.minLevelSuggestion,info.maxLevelSuggestion
   if validRange(a,b) then low=math.min(low or a,a); high=math.max(high or b,b) end
  end
 end
 return low,high
end
function R:BrowserMatches()
 local selected=LFGBrowseFrame and LFGBrowseFrame.ActivityDropdown and LFGBrowseFrame.ActivityDropdown.selectedValues
 if type(selected)~="table" or #selected~=#(self.activities or {}) then return false end
 for _,id in ipairs(selected) do if not self.activitySet[id] then return false end end
 return true
end
function R:Gate()
 if InCombatLockdown() then return "Leave combat to recruit." end
 if IsInRaid() then return "Use a party to recruit for this dungeon." end
 if IsInGroup() and not UnitIsGroupLeader("player") then return "Your party leader chooses whom to invite." end
 if GetNumGroupMembers()>=5 then return "Your party is full." end
 if not validRange(self.low,self.high) then return "Enter a minimum and maximum level." end
 if not self:BrowserMatches() then return "Click Find Group again to search this dungeon." end
 if LFGBrowseFrame.searching then return "Searching for players..." end
 if LFGBrowseFrame.searchFailed then return "Search failed. Use Refresh to try again." end
end
function R:Candidate(id)
 local api=C_LFGList
 local info=safe(api.GetSearchResultInfo,id)
 local member=safe(api.GetSearchResultPlayerInfo,id,1)
 if not info or not member then return end
 if not plain(info.numMembers) or not plain(info.leaderName) or not plain(member.level) or not plain(member.classFilename) then return end
 if not plain(info.isDelisted) or not plain(info.hasSelf) or not plain(info.activityIDs) then return end
 if info.numMembers~=1 or info.isDelisted or info.hasSelf or type(info.leaderName)~="string" or info.leaderName=="" then return end
 if type(member.level)~="number" or type(member.classFilename)~="string" or not validRange(self.low,self.high) then return end
 if member.level<self.low or member.level>self.high or self.contacted[identity(info.leaderName)] then return end
 local matches=false
 for _,activity in ipairs(info.activityIDs or {}) do if plain(activity) and self.activitySet[activity] then matches=true end end
 if not matches then return end
 local _,names=self:Party()
 if names[identity(info.leaderName)] or safe(UnitInParty,info.leaderName) or safe(UnitIsUnit,info.leaderName,"player") then return end
 local roles={}; local r=member.lfgRoles
 if plain(r) and type(r)=="table" then
  if plain(r.tank) and r.tank then roles[#roles+1]="Tank" end
  if plain(r.healer) and r.healer then roles[#roles+1]="Healer" end
  if plain(r.dps) and r.dps then roles[#roles+1]="DPS" end
 end
 return {id=id,name=info.leaderName,class=member.classFilename,level=member.level,roles=table.concat(roles," / ")}
end
function R:Candidates()
 local groups={}; for _,class in ipairs(self.classes) do groups[class]={} end
 if self:Gate() then return groups end
 local ok,_,ids=pcall(C_LFGList.GetFilteredSearchResults)
 if not ok or not plain(ids) or type(ids)~="table" then return groups end
 local seen={}
 for _,id in ipairs(ids) do
  local candidate=plain(id) and self:Candidate(id)
  if candidate and groups[candidate.class] and not seen[identity(candidate.name)] then
   seen[identity(candidate.name)]=true; table.insert(groups[candidate.class],candidate)
  end
 end
 for _,list in pairs(groups) do table.sort(list,function(a,b) if a.level~=b.level then return a.level>b.level end return a.name<b.name end) end
 return groups
end
function R:Whisper(dungeon)
 return "Hi! I'm putting together a group for "..dungeon..". Would you like to join? Sending you an invite."
end
function R:Confirm(candidate)
 local reason=self:Gate(); if reason then A.Print(reason); return end
 local fresh=self:Candidate(candidate.id)
 if not fresh or fresh.name~=candidate.name or fresh.class~=candidate.class then A.Print("That player is no longer available. Refresh the browser."); return end
 local data={id=fresh.id,name=fresh.name,class=fresh.class,dungeon=self.dungeon,message=self:Whisper(self.dungeon)}
 StaticPopup_Show("DGF_RECRUIT_INVITE",fresh.name.." (level "..fresh.level..")",data.message,data)
end
function R:Send(data)
 local reason=self:Gate(); if reason then A.Print(reason); return end
 if data.dungeon~=self.dungeon then A.Print("Dungeon changed. Choose the player again."); return end
 local fresh=self:Candidate(data.id)
 if not fresh or fresh.name~=data.name or fresh.class~=data.class then A.Print("That player is no longer available. Refresh the browser."); return end
 local send=C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
 local invite=C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit
 if type(send)~="function" or type(invite)~="function" then A.Print("Whisper or invite controls are unavailable."); return end
 -- Record the attempt before either call; no automatic repeats or batch invites.
 self.contacted[identity(data.name)]=true
 self.blocked=false; self.sending=true
 local ok,result=pcall(send,data.message,"WHISPER",nil,data.name)
 self.sending=false
 if not ok or result==false or self.blocked then
  A.Print("Whisper could not be confirmed for "..data.name.."; invite skipped."); self:Refresh(); return
 end
 self.sending=true
 ok,result=pcall(invite,data.name)
 self.sending=false
 A.Print((ok and result~=false and not self.blocked) and ("Whisper and invite requested for "..data.name..". Waiting for their response.") or ("Invite could not be confirmed for "..data.name..". Check the Group Browser."))
 self:Refresh()
end
StaticPopupDialogs["DGF_RECRUIT_INVITE"]={
 text="Whisper and invite %s?\n\n%s",button1="Whisper + Invite",button2="Cancel",
 OnAccept=function(_,data) R:Send(data) end,timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
}
local function label(parent,size,x,y,width)
 local t=parent:CreateFontString(nil,"OVERLAY"); t:SetFont("Fonts\\FRIZQT__.TTF",size,"")
 t:SetPoint("TOPLEFT",x,y); t:SetWidth(width); t:SetJustifyH("LEFT"); t:SetJustifyV("TOP"); return t
end
local function button(parent,title,width,x,y,fn)
 local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetSize(width,23); b:SetPoint("TOPLEFT",x,y); b:SetText(title); b:SetScript("OnClick",fn); return b
end
function R:Create()
 if self.frame then return end
 local f=CreateFrame("Frame",nil,LFGBrowseFrame,"BackdropTemplate"); self.frame=f
 f:SetSize(440,610); f:SetPoint("TOPLEFT",LFGParentFrame,"TOPRIGHT",8,0); f:SetClampedToScreen(true); f:SetFrameStrata("DIALOG")
 f:SetScale(math.min(1,(UIParent:GetHeight()-35)/610))
 f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=24,insets={left=6,right=6,top=6,bottom=6}})
 f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
 f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",f.StopMovingOrSizing)
 label(f,16,16,-16,375):SetText("Build your group")
 f.title=label(f,12,16,-41,405)
 local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-4,-4)
 label(f,11,16,-78,48):SetText("Levels")
 local function levelBox(x)
  local box=CreateFrame("EditBox",nil,f,"InputBoxTemplate"); box:SetSize(40,23); box:SetPoint("TOPLEFT",x,-72); box:SetAutoFocus(false); box:SetNumeric(true); box:SetMaxLetters(3)
  box:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
  box:SetScript("OnTextChanged",function() R.low=tonumber(f.low:GetText()); R.high=tonumber(f.high:GetText()); R:Refresh() end)
  return box
 end
 f.low=levelBox(70); f.high=levelBox(126)
 label(f,11,116,-78,10):SetText("-")
 button(f,"Refresh",90,185,-73,function() A.FindGroup(R.dungeon) end)
 f.rangeNote=label(f,10,16,-103,405)
 f.status=label(f,11,16,-123,405)
 f.rows={}
 for i,class in ipairs(self.classes) do
  local row={}; f.rows[class]=row; local y=-158-(i-1)*43
  row.title=label(f,11,16,y,240); row.name=label(f,10,16,y-16,240); row.name:SetWordWrap(false)
  row.next=button(f,"Next",50,264,y-3,function() R.offsets[class]=(R.offsets[class] or 1)+1; R:Refresh() end)
  row.invite=button(f,"Invite...",100,320,y-3,function() if row.candidate then R:Confirm(row.candidate) end end)
  row.invite:SetScript("OnEnter",function(b)
   GameTooltip:SetOwner(b,"ANCHOR_RIGHT"); GameTooltip:AddLine(row.candidate and row.candidate.name or "No matching player")
   if row.candidate then GameTooltip:AddLine("Level "..row.candidate.level.." | "..row.candidate.roles,1,1,1) end
   GameTooltip:AddLine("Review the dungeon whisper, then invite.",1,1,1); GameTooltip:Show()
  end)
  row.invite:SetScript("OnLeave",function() GameTooltip:Hide() end)
 end
 label(f,10,16,-554,405):SetText("Solo LFG players only. Classes and chosen roles are shown.\nInvites are manual; contacted players stay hidden until reload.")
 f:SetScript("OnShow",function() R:Refresh() end)
end
function R:Refresh()
 local f=self.frame; if not f or not self.dungeon then return end
 local groups=self:Candidates(); local represented=self:Party()
 f.title:SetText(self.dungeon)
 f.status:SetText(self:Gate() or "Pick a player to review the whisper and invite.")
 for _,class in ipairs(self.classes) do
  local row=f.rows[class]; local list=groups[class]; local index=((self.offsets[class] or 1)-1)%math.max(1,#list)+1
  self.offsets[class]=index; row.candidate=list[index]
  local className=(LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
  row.title:SetText(className..(represented[class] and (" - "..represented[class].." in party") or " - missing"))
  local c=RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]; if c then row.title:SetTextColor(c.r,c.g,c.b) end
  local p=row.candidate
  row.name:SetText(p and (p.name.." | "..p.level..(p.roles~="" and (" | "..p.roles) or "")) or "No matching player listed")
  row.name:SetHeight(24)
  row.next:SetEnabled(#list>1); row.invite:SetEnabled(p~=nil)
 end
end
function A.OpenRecruit(dungeon,activities)
 local changed=R.dungeon~=dungeon
 R.dungeon=dungeon; R.activities=activities; R.activitySet={}
 for _,id in ipairs(activities) do R.activitySet[id]=true end
 R:Create()
 if changed then
  R.low,R.high=R:SuggestedRange(activities); R.offsets={}
  local low,high=R.low,R.high
  R.frame.low:SetText(low and tostring(low) or ""); R.frame.high:SetText(high and tostring(high) or "")
  R.frame.rangeNote:SetText(low and "Client-suggested levels; change them here if needed." or "No suggested range available. Enter suitable levels.")
 end
 R.frame:Show(); R:Refresh()
end
local events=CreateFrame("Frame")
for _,event in ipairs({"LFG_LIST_SEARCH_RESULTS_RECEIVED","LFG_LIST_SEARCH_RESULT_UPDATED","LFG_LIST_SEARCH_FAILED","GROUP_ROSTER_UPDATE","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
 if R.sending and (event=="ADDON_ACTION_BLOCKED" or event=="ADDON_ACTION_FORBIDDEN") then R.blocked=true end
 -- Run after Blizzard has updated the browser's search state.
 if R.frame and R.frame:IsShown() then C_Timer.After(0,function() R:Refresh() end) end
end)
