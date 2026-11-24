local _,A=...
local D={peers={},prefix="DQuestieParty1",channel="DungeonQuestie",status="Collecting quests"}; A.PartyDiscovery=D
local function now() return GetTime() end
local function settings()
 local s=A.ChatRecruitment.Settings()
 if s.findPlayers==nil then s.findPlayers=true end
 if s.available==nil then s.available=true end
 return s
end
local function secret(value) return issecretvalue and issecretvalue(value) end
local function selfName(name)
 local player=A.Safe(UnitName,"player")
 local realm=A.Safe(GetNormalizedRealmName)
 if not player then return false end
 return name==player or realm and name==player.."-"..realm
end
local function success(value,registration)
 return value==true or value==0 or registration and value==1
end
function D.Ready(dungeon)
 if not dungeon or not A.logAvailable or A.providerError then return false end
 local candidates={}
 for _,q in ipairs(A.quests or {}) do
  if A.InDungeon(q,dungeon) and A.ChecklistVisible(q) and not A.Restriction(q) then
   local plan=A.collection
   if not (plan and plan.dungeon==dungeon and plan.excluded[q.id]) then candidates[#candidates+1]=q end
  end
 end
 if A.QuestChainGroups then
  local roots={}; for _,g in ipairs(A.QuestChainGroups(candidates)) do roots[#roots+1]=g.quest end; candidates=roots
 end
 local remaining=0
 for _,q in ipairs(candidates) do
  if A.Completed(q.id)~=true and not A.DungeonWorkFinished(q) then
   remaining=remaining+1
   if not A.RunReadiness(q) then return false end
  end
 end
 return remaining>0
end
function D.Schedule(delay)
 if not C_Timer or not C_Timer.NewTimer then return end
 local due=now()+delay
 if D.timer and D.due<=due then return end
 if D.timer then D.timer:Cancel() end
 D.due=due
 D.timer=C_Timer.NewTimer(delay,function() D.timer=nil; D.due=nil; D.Tick() end)
end
function D.Changed()
 if A.db and settings().findPlayers then D.Schedule(2) end
end
local function clean()
 for name,peer in pairs(D.peers) do if now()-peer.at>180 then D.peers[name]=nil end end
end
function D.List(dungeon)
 clean(); local result={}
 if not settings().findPlayers then return result end
 for name,peer in pairs(D.peers) do
  if peer.dungeon==dungeon and not A.Safe(UnitInParty,name) and not A.Safe(UnitInRaid,name) then result[#result+1]=peer end
 end
 table.sort(result,function(a,b) return a.at>b.at end)
 return result
end
local function renderStatus()
 local button=A.window and A.window.runStatus
 if button then button.label:SetText(""); button:Hide() end
end
function D.Tick()
 if not A.db then return end
 clean()
 local s=settings(); local dungeon=A.db.dungeon
 if not s.findPlayers then
  D.readyDungeon=nil; D.status="Discovery off"; renderStatus(); return
 end
 local ready=D.Ready(dungeon)
 local members=math.max(1,A.Safe(GetNumGroupMembers) or 0)
 local leader=members==1 or A.Safe(UnitIsGroupLeader,"player")
 D.status=not s.available and "Not available" or not ready and "Collecting quests" or members>=5 and "Party full" or "Ready to run"
 D.readyDungeon=ready and s.available and members<5 and not A.Safe(IsInRaid) and dungeon or nil
 renderStatus()
 if not s.findPlayers or not D.readyDungeon then return end
 local api=C_ChatInfo
 if not api or not api.RegisterAddonMessagePrefix or not api.SendAddonMessage then return end
 if not D.registered then
  local ok,result=pcall(api.RegisterAddonMessagePrefix,D.prefix)
  D.registered=ok and success(result,true)
  if not D.registered then return end
 end
 -- Register and join for listeners too, before the leader-only send gate.
 local id
 if not D.channelUnsupported then
  id=A.Safe(GetChannelName,D.channel)
  if (not id or id==0) and (not D.lastJoin or now()-D.lastJoin>=300) then
   D.lastJoin=now()
   -- No chat frame: discovery is not a visible chat feed.
   if JoinTemporaryChannel then local ok=pcall(JoinTemporaryChannel,D.channel); D.joined=ok or D.joined end
   id=A.Safe(GetChannelName,D.channel)
  end
 end
 -- Non-leaders receive candidates but never advertise an independent party.
 if not leader then D.Schedule(65+math.random(0,5)); return end
 local wait=65-(now()-(D.lastSend or -1000))
 if wait>0 then D.Schedule(wait); return end
 local role=A.Safe(UnitGroupRolesAssigned,"player")
 if role~="TANK" and role~="HEALER" and role~="DAMAGER" then role="NONE" end
 local faction=A.Safe(UnitFactionGroup,"player")
 if faction~="Alliance" and faction~="Horde" then return end
 local level=A.Safe(UnitLevel,"player")
 if type(level)~="number" or level<1 or level>100 then return end
 local payload=table.concat({"1",dungeon,level,role,members,faction},"|")
 if #payload>160 or dungeon:find("|",1,true) then return end
 D.lastSend=now()
 if A.Safe(IsInGuild) then pcall(api.SendAddonMessage,D.prefix,payload,"GUILD") end
 if not D.channelUnsupported and type(id)=="number" and id>0 then
  local ok,result=pcall(api.SendAddonMessage,D.prefix,payload,"CHANNEL",tostring(id))
  if not ok or result==4 then
   D.channelUnsupported=true
   if D.joined and LeaveChannelByName then pcall(LeaveChannelByName,D.channel); D.joined=nil end
  end
 end
 D.Schedule(65+math.random(0,5))
end
function D.Receive(prefix,payload,channel,sender,_,_,localID,channelName)
 if secret(prefix) or secret(payload) or secret(sender) or secret(channel) or secret(localID) or secret(channelName) then return end
 if prefix~=D.prefix or not A.db or not settings().findPlayers or not settings().available or not D.readyDungeon then return end
 if channel~="GUILD" and channel~="CHANNEL" then return end
 if channel=="GUILD" and not A.Safe(IsInGuild) then return end
 if channel=="CHANNEL" and channelName~=D.channel then
  local id=A.Safe(GetChannelName,D.channel)
  if not id or id==0 or localID~=id then return end
 end
 -- Global budget bounds work even when many different senders flood the prefix.
 local time=now()
 if not D.receiveWindow or time-D.receiveWindow>=10 then D.receiveWindow=time; D.received=0 end
 if D.received>=30 then return end
 D.received=D.received+1
 if type(sender)~="string" or #sender>80 or sender=="" or sender:find("[^%w%-\128-\255]") or selfName(sender) then return end
 if type(payload)~="string" or #payload>160 then return end
 local dungeon,level,role,members,faction=payload:match("^1|([^|]+)|(%d+)|(%u+)|(%d)|(%a+)$")
 if dungeon~=D.readyDungeon or faction~=A.Safe(UnitFactionGroup,"player") then return end
 level,members=tonumber(level),tonumber(members)
 if not level or level<1 or level>100 or not members or members<1 or members>4 then return end
 if role~="TANK" and role~="HEALER" and role~="DAMAGER" and role~="NONE" then return end
 local old=D.peers[sender]
 if old and time-old.at<30 then return end
 clean()
 local count=0; for _ in pairs(D.peers) do count=count+1 end
 if not old and count>=50 then return end
 D.peers[sender]={name=sender,dungeon=dungeon,level=level,role=role,members=members,at=time}
 if not old and (not D.lastOffer or time-D.lastOffer>=120) then
  D.lastOffer=time; A.Print("Ready players found for "..dungeon..". Open Ready players in Find Group or chat matches.")
 end
 -- Only explicitly enabled recruitment may invite a matching solo player.
 if members==1 and A.ChatRecruitment.TryAutoInvite then A.ChatRecruitment.TryAutoInvite(sender,dungeon) end
 -- Never reply to discovery packets or send automatic whispers.
end
function D.SetEnabled(enabled)
 settings().findPlayers=enabled
 if enabled then D.channelUnsupported=nil end
 if not enabled then
  D.peers={}; D.readyDungeon=nil
  if D.timer then D.timer:Cancel(); D.timer=nil; D.due=nil end
  if D.joined and LeaveChannelByName then pcall(LeaveChannelByName,D.channel); D.joined=nil end
 end
 if enabled then D.Changed() else D.status="Discovery off"; renderStatus() end
end
function D.ToggleAvailable()
 local s=settings(); s.available=not s.available; D.Changed()
end
function D.AddMenu(root,dungeon)
 local peers=D.List(dungeon)
 if #peers==0 then root:CreateTitle("No ready players found yet"); return end
 root:CreateTitle("Ready players")
 for i=1,math.min(20,#peers) do
  local peer=peers[i]
  local role=({TANK="Tank",HEALER="Healer",DAMAGER="DPS",NONE="Role unknown"})[peer.role]
  local sub=root:CreateButton(peer.name.." - "..role.." ("..peer.level..")")
  sub:CreateTitle(peer.members>1 and ("Group: "..peer.members.."/5") or "Ready to run")
  sub:CreateButton("Whisper",function()
   if not settings().findPlayers or D.peers[peer.name]~=peer or now()-peer.at>180 then A.Print("Player availability changed. Refresh the list."); return end
   local open=ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
   if open then open("/w "..peer.name.." Hi, ready for "..A.DungeonChatName(peer.dungeon).."?") end
  end)
  if peer.members==1 then sub:CreateButton("Invite",function()
   if not settings().findPlayers or D.peers[peer.name]~=peer or now()-peer.at>180 or A.db.dungeon~=peer.dungeon or not A.ChatRecruitment.Invite(peer.name) then A.Print("Cannot invite. Refresh players or check party space.") end
  end) end
 end
end
function D.Show(owner,dungeon)
 if MenuUtil then MenuUtil.CreateContextMenu(owner,function(_,root) D.AddMenu(root,dungeon or A.db.dungeon) end) end
end
local frame=CreateFrame("Frame")
for _,event in ipairs({"CHAT_MSG_ADDON","PLAYER_LOGIN","GROUP_ROSTER_UPDATE","PLAYER_ROLES_ASSIGNED","PLAYER_GUILD_UPDATE"}) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent",function(_,event,...)
 if event=="CHAT_MSG_ADDON" then D.Receive(...) else D.Changed() end
end)
