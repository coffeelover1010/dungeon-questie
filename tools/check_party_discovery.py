"""Offline hidden discovery contract and abuse/performance checks."""
from pathlib import Path
import runpy
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check_chat_recruitment.py'))['lua']
lua.execute((root/'PartyDiscovery.lua').read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
lua.execute(r'''
local D=A.PartyDiscovery
local clock=1000
GetTime=function() return clock end
local timers={}
C_Timer.NewTimer=function(delay,fn)
 local timer={delay=delay,fn=fn,Cancel=function(self) self.cancelled=true end}; timers[#timers+1]=timer; return timer
end
A.db={dungeon="Zul'Farrak",chatRecruit={autoInvite=false}}; A.logAvailable=true; A.providerError=nil; A.collection=nil
A.quests={{id=1,name="First"},{id=2,name="Second"}}
A.InDungeon=function() return true end; A.ChecklistVisible=function() return true end; A.Restriction=function() return false end
A.Completed=function() return false end; A.DungeonWorkFinished=function() return false end; A.QuestChainGroups=nil
local ready=false
A.RunReadiness=function() return ready end
GetNumGroupMembers=function() return 1 end; IsInRaid=function() return false end
UnitIsGroupLeader=function() return true end; IsInGuild=function() return true end
UnitGroupRolesAssigned=function() return "TANK" end; UnitFactionGroup=function() return "Alliance" end
UnitLevel=function() return 48 end; UnitName=function() return "Scribble" end; GetNormalizedRealmName=function() return "TestRealm" end
UnitInParty=function() return false end; UnitInRaid=function() return false end
local channel=0; local joins,sends=0,{}
GetChannelName=function(name) assert(name==D.channel); return channel end
JoinTemporaryChannel=function(name) joins=joins+1; channel=7 end
LeaveChannelByName=function() channel=0 end
C_ChatInfo={RegisterAddonMessagePrefix=function(prefix) assert(prefix==D.prefix); return 0 end,
 SendAddonMessage=function(prefix,payload,kind,target) sends[#sends+1]={payload=payload,kind=kind,target=target}; return 0 end}
SendChatMessage=function() error("Discovery must not send visible chat") end
InviteUnit=function() error("Discovery must not invite automatically") end
D.Tick(); assert(#sends==0 and joins==0 and A.db.chatRecruit.findPlayers==true and D.status=="Collecting quests")
ready=true; D.Tick(); assert(#sends==2 and joins==1 and D.status=="Ready to run")
local originalCompleted,originalFinished=A.Completed,A.DungeonWorkFinished
A.Completed=function() return true end
assert(not D.Ready(A.db.dungeon),"All completed quests must not advertise a run")
A.Completed=originalCompleted
A.DungeonWorkFinished=function() return true end
assert(not D.Ready(A.db.dungeon),"All finished objectives must not advertise a run")
A.DungeonWorkFinished=originalFinished
assert(D.Ready(A.db.dungeon))
local statusText,statusHidden
A.window={runStatus={label={SetText=function(_,value) statusText=value end},Hide=function() statusHidden=true end}}
D.Tick()
assert(statusText=="" and statusHidden)
A.window=nil
for i=1,100 do D.Changed() end
local live=0; for _,timer in ipairs(timers) do if not timer.cancelled then live=live+1 end end
assert(live==1)
D.Tick(); assert(#sends==2)
clock=1066; D.Tick(); assert(#sends==4)
local packet="1|Zul'Farrak|48|HEALER|1|Alliance"
D.Receive(D.prefix,packet,"CHANNEL","Scribble-TestRealm",nil,nil,7,D.channel); assert(#D.List(A.db.dungeon)==0)
D.Receive(D.prefix,packet,"CHANNEL","Healer-TestRealm",nil,nil,7,D.channel)
assert(#D.List(A.db.dungeon)==1 and #sends==4)
local at=D.peers['Healer-TestRealm'].at
clock=1067; D.Receive(D.prefix,packet,"GUILD","Healer-TestRealm"); assert(D.peers['Healer-TestRealm'].at==at)
D.Receive(D.prefix,packet,"WHISPER","Bad")
D.Receive(D.prefix,packet,"CHANNEL","WrongChannel",nil,nil,8,"Other")
D.Receive(D.prefix,"1|Uldaman|48|HEALER|1|Alliance","GUILD","WrongDungeon")
D.Receive(D.prefix,"1|Zul'Farrak|48|HEALER|1|Horde","GUILD","OtherFaction")
D.Receive(D.prefix,"1|Zul'Farrak|48|HEALER|5|Alliance","GUILD","Full")
D.Receive(D.prefix,"1|Zul'Farrak|999|HEALER|1|Alliance","GUILD","BadLevel")
D.Receive(D.prefix,string.rep('x',200),"GUILD","Oversize")
D.Receive(D.prefix,packet,"GUILD","Bad|Name")
assert(#D.List(A.db.dungeon)==1 and #sends==4)
for round=1,4 do
 clock=clock+11
 for i=1,100 do D.Receive(D.prefix,packet,"GUILD","Peer"..round.."x"..i) end
 assert(D.received<=30 and #D.List(A.db.dungeon)<=50)
end
assert(#sends==4)
clock=clock+181; assert(#D.List(A.db.dungeon)==0)
D.ToggleAvailable(); D.Tick(); assert(D.status=="Not available" and #sends==4)
D.ToggleAvailable(); ready=false; D.Tick(); assert(#sends==4)
ready=true; GetNumGroupMembers=function() return 5 end; D.Tick(); assert(#sends==4 and D.status=="Party full")
GetNumGroupMembers=function() return 1 end
D.SetEnabled(false); D.Tick(); assert(#sends==4 and channel==0)
D.SetEnabled(true)
-- Toggling cannot bypass the five-minute join retry budget.
local before=joins
D.Tick(); assert(joins==before)
clock=clock+301
C_ChatInfo.SendAddonMessage=function(_,_,kind) if kind=="CHANNEL" then return 4 end; return 0 end
D.lastSend=nil; D.Tick(); assert(D.channelUnsupported)
assert(channel==0 and not D.joined)
-- Fresh non-leaders must register and join, but never send a packet.
clock=clock+301; D.registered=nil; D.channelUnsupported=nil
GetNumGroupMembers=function() return 2 end
UnitIsGroupLeader=function() return false end
local sent=#sends
D.Tick(); assert(D.registered and channel==7 and #sends==sent)
D.Receive(D.prefix,packet,"CHANNEL","ListenerPeer",nil,nil,7,D.channel)
assert(D.peers.ListenerPeer)
-- Disabling cancels the timer and avoids all readiness scans on later events.
D.SetEnabled(false)
A.RunReadiness=function() error("Disabled discovery must not scan readiness") end
for i=1,100 do D.Changed() end
D.Tick(); assert(not D.timer and D.status=="Discovery off" and #sends==sent)
''')
print('PASS: opt-out defaults, readiness/availability/full-party gates, hidden-only transport, bounded single timer and send cadence, self/wrong-channel/malformed rejection, flood/cache limits, expiry, no automated responses or invites, unsupported-channel fallback')
