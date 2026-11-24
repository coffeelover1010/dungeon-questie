local _,A=...
local R={matches={},pending={},autoAttempts={}}; A.ChatRecruitment=R
local defaults={LFG="LFG {dungeon}{plan}{full}",LFM="LFM +{slots} {roles} - {dungeon}{plan}{full}",guild="Anyone for {dungeon}{plan}{full}?"}
function R.Settings()
 A.db.chatRecruit=A.db.chatRecruit or {}
 local s=A.db.chatRecruit
 if s.guild=="Anyone for {dungeon}? Collect quests together, then dungeon{full}." then s.guild=defaults.guild end
 if s.watch==nil then s.watch=true end
 if s.autoInvite==nil then s.autoInvite=false end
 for key,value in pairs(defaults) do if not s[key] or s[key]=="" then s[key]=value end end
 return s
end
local function now() return GetTime and GetTime() or 0 end
function R.GroupNeeds()
 local count=math.max(1,A.Safe(GetNumGroupMembers) or 0)
 local slots=math.max(0,5-count)
 local roles={TANK=0,HEALER=0,DAMAGER=0}; local unknown=false
 for i=1,count do
  local role=A.Safe(UnitGroupRolesAssigned,i==1 and "player" or "party"..(i-1))
  if roles[role] then roles[role]=roles[role]+1 else unknown=true end
 end
 local manual=R.Settings().roles
 if manual and manual~="" then return slots,manual end
 if unknown then return slots,"players" end
 local needed={}
 if roles.TANK<1 then needed[#needed+1]="Tank" end
 if roles.HEALER<1 then needed[#needed+1]="Healer" end
 if roles.DAMAGER<3 then needed[#needed+1]="DPS" end
 return slots,table.concat(needed," and ")
end
function R.Message(dungeon,mode,collect,full)
 local slots,roles=R.GroupNeeds()
 local values={dungeon=A.DungeonChatName(dungeon),slots=tostring(slots),roles=roles,plan=collect and " + Quest Pickup" or "",full=(full or collect) and " - Full Run" or ""}
 local message=(R.Settings()[mode] or defaults.LFG):gsub("{(%w+)}",function(key) return values[key] or ("{"..key.."}") end):gsub(" +"," ")
 return message
end
function R.Start(dungeon)
 R.active=dungeon
end
local aliases={ ["Zul'Farrak"]={"zf"},["The Deadmines"]={"vc","deadmines"},["Wailing Caverns"]={"wc"},["Ragefire Chasm"]={"rfc"},["Shadowfang Keep"]={"sfk"},["Blackfathom Deeps"]={"bfd"},["Razorfen Kraul"]={"rfk"},["Razorfen Downs"]={"rfd"},["Uldaman"]={"ulda"},["Maraudon"]={"mara"},["Sunken Temple"]={"st"},["Blackrock Depths"]={"brd"},["Lower Blackrock Spire"]={"lbrs"},["Upper Blackrock Spire"]={"ubrs"},["Scholomance"]={"scholo"},["Stratholme"]={"strat"}}
local function normalized(text) return " "..text:lower():gsub("['â€™]",""):gsub("[^%w]+"," ").." " end
function R.MatchesDungeon(message,dungeon)
 if not dungeon then return false end
 local text=normalized(message)
 if text:find(normalized(dungeon),1,true) then return true end
 if text:find(normalized(A.DungeonChatName(dungeon)),1,true) then return true end
 for _,alias in ipairs(aliases[dungeon] or {}) do if text:find(normalized(alias),1,true) then return true end end
 return false
end
function R.Invite(name)
 if A.Safe(InCombatLockdown) or A.Safe(IsInRaid) then return false end
 if A.Safe(IsInGroup) and not A.Safe(UnitIsGroupLeader,"player") then return false end
 if A.Safe(UnitInParty,name) or A.Safe(UnitInRaid,name) then return false end
 local slots=R.GroupNeeds(); local pending=0
 for player,expiry in pairs(R.pending) do
  if expiry<=now() or A.Safe(UnitInParty,player) then R.pending[player]=nil else pending=pending+1 end
 end
 if slots<=pending or R.pending[name] then return false end
 local invite=C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit
 if not invite then return false end
 R.inviting,R.blocked=true,false
 local ok,result=pcall(invite,name)
 R.inviting=false
 if ok and result~=false and not R.blocked then R.pending[name]=now()+60; return true end
 return false
end
function R.TryAutoInvite(name,dungeon)
 if not A.db or not R.Settings().autoInvite or A.db.dungeon~=dungeon then return false end
 local time=now()
 for player,at in pairs(R.autoAttempts) do if time-at>=300 then R.autoAttempts[player]=nil end end
 local identity=name:lower()
 if R.autoAttempts[identity] then return false end
 if not R.autoWindow or time-R.autoWindow>=10 then R.autoWindow=time; R.autoCount=0 end
 if R.autoCount>=5 then return false end
 local count=0; for _ in pairs(R.autoAttempts) do count=count+1 end
 if count>=100 then return false end
 R.autoAttempts[identity]=time; R.autoCount=R.autoCount+1
 return R.Invite(name)
end
function R.Observe(event,message,sender)
 if issecretvalue and (issecretvalue(message) or issecretvalue(sender)) then return end
 if not A.db or type(message)~="string" or type(sender)~="string" or sender=="" or sender:find("[|%s]") then return end
 local selfName=A.Safe(UnitName,"player")
 if selfName and sender:match("^[^-]+") == selfName then return end
 local s=R.Settings(); local whisper=event=="CHAT_MSG_WHISPER"
 local dungeon=A.db.dungeon
 if not s.watch and not s.autoInvite then return end
 if #message>1024 or #sender>80 then return end
 local words=normalized(message)
 local request=words==" inv " or words==" invite " or words==" inv pls " or words==" invite please "
 local explicit=R.MatchesDungeon(message,dungeon) and (words:find(" inv ",1,true) or words:find(" invite ",1,true)) and not words:find(" dont ",1,true) and not words:find(" no ",1,true) and not words:find(" not ",1,true)
 local negative=words:find(" dont ",1,true) or words:find(" no ",1,true) or words:find(" not ",1,true)
 local recruiting=words:find(" lfm ",1,true)
 local looking=words:find(" lfg ",1,true)
 local groupRequest=words:find(" we ",1,true) or words:find(" us ",1,true) or words:find(" group ",1,true)
  or words:match(" %d+ dps ") or words:match(" %d+ players ") or words:match(" %d+ friends ")
 if groupRequest then looking=nil end
 if s.autoInvite and not negative and not recruiting then
  if whisper and (request or explicit or looking and R.MatchesDungeon(message,dungeon))
   or event=="CHAT_MSG_CHANNEL" and looking and R.MatchesDungeon(message,dungeon)
   or event=="CHAT_MSG_GUILD" and looking and R.MatchesDungeon(message,dungeon)
   or (event=="CHAT_MSG_SAY" or event=="CHAT_MSG_YELL") and looking and R.MatchesDungeon(message,dungeon) then
   R.TryAutoInvite(sender,dungeon)
  end
 end
 if not s.watch then return end
 local kind=words:find(" lfm ",1,true) and "group" or words:find(" lfg ",1,true) and "player" or whisper and (request or explicit) and "player"
 if not kind or not (R.MatchesDungeon(message,dungeon) or whisper and request) then return end
 for i=#R.matches,1,-1 do if R.matches[i].name==sender or R.matches[i].time<now()-600 then table.remove(R.matches,i) end end
 table.insert(R.matches,1,{name=sender,message=message,kind=kind,dungeon=dungeon,time=now()})
 while #R.matches>30 do table.remove(R.matches) end
end
local watcher=CreateFrame("Frame")
for _,event in ipairs({"CHAT_MSG_CHANNEL","CHAT_MSG_GUILD","CHAT_MSG_SAY","CHAT_MSG_YELL","CHAT_MSG_WHISPER","ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN"}) do watcher:RegisterEvent(event) end
watcher:SetScript("OnEvent",function(_,event,message,sender)
 if event=="ADDON_ACTION_BLOCKED" or event=="ADDON_ACTION_FORBIDDEN" then if R.inviting then R.blocked=true end; return end
 R.Observe(event,message,sender)
end)
function R.ShowMatches(owner)
 if not MenuUtil then return end
 MenuUtil.CreateContextMenu(owner,function(_,root)
  root:CreateTitle("Recent matches: "..A.db.dungeon)
  if A.PartyDiscovery then A.PartyDiscovery.AddMenu(root,A.db.dungeon); root:CreateDivider() end
  local count=0
  for _,entry in ipairs(R.matches) do
   if entry.dungeon==A.db.dungeon and entry.time>now()-600 then
    count=count+1; local match=entry
    local sub=root:CreateButton(match.name..(match.kind=="group" and " - LFM" or " - LFG"))
    sub:CreateTitle(match.message)
    sub:CreateButton("Whisper",function()
     local open=ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
     if open then open("/w "..match.name.." Hi, interested in "..A.DungeonChatName(match.dungeon).."?") end
    end)
    if match.kind=="player" then sub:CreateButton("Invite",function() if match.dungeon~=A.db.dungeon or match.time<=now()-600 or not R.Invite(match.name) then A.Print("Cannot invite: check party space, leadership, combat, or refresh matches.") end end) end
   end
  end
  if count==0 then root:CreateTitle("No recent matching chat messages") end
  root:CreateButton("Stop auto-invites",function() R.Settings().autoInvite=false; R.active=nil end)
 end)
end
-- Colour is presentation only; templates and outgoing messages remain plain text.
local fieldColors={dungeon="ff185783",slots="ff8a3e16",roles="ff356329",plan="ff226963",full="ff796015"}
local darkFieldColors={dungeon="ff79c8ff",slots="ffffbd78",roles="ffa7dc8b",plan="ff7ed6c5",full="ffe8d17b"}
function R.PlainTemplate(text)
 return (text or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
end
function R.ColorTemplate(text,dark)
 local palette=dark and darkFieldColors or fieldColors
 return (R.PlainTemplate(text):gsub("{(%w+)}",function(key)
  local token="{"..key.."}"
  return palette[key] and ("|c"..palette[key]..token.."|r") or token
 end))
end
local function displayTemplate(box)
 local text=R.PlainTemplate(box:GetText())
 box:SetMaxLetters(0); box:SetText(R.ColorTemplate(text,true))
end
local settingsFrame
function R.ShowSettings()
 local s=R.Settings()
 if not settingsFrame then
  local f=CreateFrame("Frame","DungeonQuestieChatSettings",UIParent,"BackdropTemplate"); settingsFrame=f; R.settingsFrame=f
  f:SetSize(560,480); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(200)
  f:EnableMouse(true); f:SetClampedToScreen(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart",function(self) self:StartMoving() end); f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
  f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
  local parchment=f:CreateTexture(nil,"BACKGROUND",nil,1); parchment:SetPoint("TOPLEFT",12,-72); parchment:SetPoint("BOTTOMRIGHT",-12,12); parchment:SetAtlas("QuestBG-Parchment")
  local line=f:CreateTexture(nil,"ARTWORK"); line:SetPoint("TOPLEFT",12,-71); line:SetPoint("TOPRIGHT",-12,-71); line:SetHeight(1); line:SetColorTexture(0.65,0.44,0.16,0.85)
  local function label(value,y,size,light)
   local t=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); t:SetPoint("TOPLEFT",22,y); t:SetWidth(516)
   t:SetFont("Fonts\\FRIZQT__.TTF",size or 12,""); t:SetJustifyH("LEFT"); t:SetText(value)
   if light then t:SetTextColor(1,0.82,0.35) else t:SetTextColor(0.22,0.15,0.09) end
   return t
  end
  label("Chat and recruitment",-23,17,true)
  label("Dungeon Questie",-49,11,true):SetTextColor(0.82,0.77,0.65)
  label("Message fields: "..R.ColorTemplate("{dungeon} {slots} {roles} {plan} {full}"),-87,11)
  f.boxes={}
  for i,key in ipairs({"LFG","LFM","guild","roles"}) do
   local y=-115-(i-1)*47
   local names={LFG="Looking for group",LFM="Looking for more",guild="Guild invitation",roles="Needed roles (blank = automatic)"}
   label(names[key],y)
   local box=CreateFrame("EditBox",nil,f); box:SetSize(510,26); box:SetPoint("TOPLEFT",25,y-17)
   box:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE"); box:SetTextColor(1,0.94,0.80); box:SetTextInsets(9,9,2,2)
   box:SetAutoFocus(false); box:SetMaxLetters(220)
   box:SetScript("OnTextChanged",function(self,userInput)
    if userInput then R.Settings()[key]=R.PlainTemplate(self:GetText()) end
   end)
   local bg=box:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.16,0.11,0.065,0.94)
   box:SetScript("OnEscapePressed",function(self) self:ClearFocus(); f:Hide() end)
   box:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
   box:SetScript("OnEditFocusGained",function(self)
    local text=R.PlainTemplate(self:GetText()); self:SetText(text); self:SetMaxLetters(220)
    bg:SetColorTexture(0.24,0.17,0.095,1)
   end)
   box:SetScript("OnEditFocusLost",function(self)
    bg:SetColorTexture(0.16,0.11,0.065,0.94); displayTemplate(self)
   end)
   f.boxes[key]=box
  end
  local function button(value,x,y,width,fn,light)
   local b=CreateFrame("Button",nil,f,"BackdropTemplate"); b:SetSize(width,28); b:SetPoint("TOPLEFT",x,y)
   b:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
   b:SetBackdropBorderColor(0.54,0.38,0.17,1)
   local fill=b:CreateTexture(nil,"BACKGROUND"); fill:SetPoint("TOPLEFT",3,-3); fill:SetPoint("BOTTOMRIGHT",-3,3)
   fill:SetColorTexture(0.13,0.08,0.035,light and 0.95 or 0.12)
   local caption=b:CreateFontString(nil,"OVERLAY","GameFontNormal"); caption:SetAllPoints(); caption:SetFont("Fonts\\FRIZQT__.TTF",12,"")
   caption:SetTextColor(light and 1 or 0.22,light and 0.82 or 0.15,light and 0.35 or 0.09); caption:SetText(value)
   b.SetText=function(_,text) caption:SetText(text) end
   local hover=b:CreateTexture(nil,"HIGHLIGHT"); hover:SetAllPoints(); hover:SetColorTexture(0.65,0.44,0.16,0.18)
   b:SetScript("OnClick",fn); return b
  end
  local function section(title,y)
   local rule=f:CreateTexture(nil,"ARTWORK"); rule:SetPoint("TOPLEFT",25,y); rule:SetSize(510,1); rule:SetColorTexture(0.42,0.28,0.12,0.5)
   label(title,y-9,12)
  end
  local function checkbox(text,x,y,width,fn)
   local b=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")
   b:SetSize(26,26); b:SetPoint("TOPLEFT",x,y)
   b:SetHitRectInsets(0,-(width-26),0,0)
   local caption=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
   caption:SetPoint("LEFT",b,"RIGHT",4,0); caption:SetWidth(width-32)
   caption:SetFont("Fonts\\FRIZQT__.TTF",12,""); caption:SetJustifyH("LEFT")
   caption:SetTextColor(0.22,0.15,0.09); caption:SetText(text)
   b:SetScript("OnClick",fn)
   return b
  end
  section("CHAT AND INVITATIONS",-307)
  f.watch=checkbox("Chat matches",25,-334,247,function() local opts=R.Settings(); opts.watch=not opts.watch; f.refresh() end)
  f.auto=checkbox("Auto-invite matching players",282,-334,253,function() local opts=R.Settings(); opts.autoInvite=not opts.autoInvite; if opts.autoInvite then R.Start(A.db.dungeon) else R.active=nil end; f.refresh() end)
  label("Invites matching whispers, LFG chat and ready players while enabled.",-367,10)
  section("READY-PLAYER DISCOVERY",-390)
  f.findPlayers=checkbox("Find ready players",25,-417,247,function() if A.PartyDiscovery then A.PartyDiscovery.SetEnabled(R.Settings().findPlayers==false); f.refresh() end end)
  f.available=checkbox("Advertise when ready",282,-417,253,function() if A.PartyDiscovery then A.PartyDiscovery.ToggleAvailable(); f.refresh() end end)
  label("Advertising waits until all included quest chains are dungeon-ready.",-450,10)
  button("x",510,-21,28,function() f:Hide() end,true)
  f:SetScript("OnHide",function() for _,box in pairs(f.boxes) do box:ClearFocus() end end)
  f.refresh=function()
   local opts=R.Settings()
   f.watch:SetChecked(opts.watch==true); f.auto:SetChecked(opts.autoInvite==true)
   f.findPlayers:SetChecked(opts.findPlayers~=false)
   f.available:SetChecked(opts.available~=false)
  end
  if UISpecialFrames then table.insert(UISpecialFrames,"DungeonQuestieChatSettings") end
 end
 for key,box in pairs(settingsFrame.boxes) do box:SetMaxLetters(0); box:SetText(R.ColorTemplate(s[key] or "",true)) end
 if A.window then settingsFrame:SetScale(A.window:GetScale()) end
 settingsFrame.refresh(); settingsFrame:Show(); settingsFrame:Raise()
end
