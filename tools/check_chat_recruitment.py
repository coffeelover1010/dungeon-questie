"""Offline recruitment contracts. Never sends real chat or invitations."""
from pathlib import Path
import runpy
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check_quest_groups.py'))['lua']
lua.execute((root/'RecruitmentChat.lua').read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
from lupa.lua51 import LuaRuntime
catalog=LuaRuntime()
catalog.execute('A={}')
catalog.execute((root/'LocalData.lua').read_text(encoding='utf-8'),'DungeonGuideForever',catalog.globals().A)
for dungeon in catalog.globals().A.dungeons.values():
    name=dungeon['name']
    short=lua.globals().A.DungeonChatName(name)
    assert short != name, name
    assert lua.globals().A.ChatRecruitment.MatchesDungeon('LFG '+short,name), name
lua.execute(r'''
local R=A.ChatRecruitment
A.db={dungeon="Zul'Farrak"}
local clock=100
GetTime=function() return clock end
local members=3
GetNumGroupMembers=function() return members end
IsInGroup=function() return members>1 end
IsInRaid=function() return false end
UnitIsGroupLeader=function() return true end
InCombatLockdown=function() return false end
UnitName=function() return "Scribble" end
UnitInParty=function() return false end
UnitInRaid=function() return false end
local roles={player="TANK",party1="DAMAGER",party2="DAMAGER"}
UnitGroupRolesAssigned=function(unit) return roles[unit] end
local slots,needed=R.GroupNeeds(); assert(slots==2 and needed=="Healer and DPS")
assert(A.DungeonRunMessage(A.db.dungeon,"LFM",false,false)=="LFM +2 Healer and DPS - ZF")
roles.party2="NONE"; assert(select(2,R.GroupNeeds())=="players")
R.Settings().roles="Healer and DPS"; assert(select(2,R.GroupNeeds())=="Healer and DPS")
R.Settings().LFM="{dungeon} needs +{slots} {roles}{plan}{full}"
assert(A.DungeonRunMessage(A.db.dungeon,"LFM",true,false):find("+ Quest Pickup - Full Run",1,true))
assert(R.MatchesDungeon("LFG ZF healer",A.db.dungeon))
assert(not R.MatchesDungeon("LFG azf",A.db.dungeon))
local invites={}
InviteUnit=function(name) invites[#invites+1]=name end
assert(R.Settings().autoInvite==false)
R.Start(A.db.dungeon)
R.Observe("CHAT_MSG_WHISPER","inv","PlayerOne"); assert(#invites==0 and #R.matches==1)
R.Settings().autoInvite=true
R.Observe("CHAT_MSG_WHISPER","inv","PlayerOne"); assert(#invites==1)
R.Observe("CHAT_MSG_WHISPER","inv","PlayerOne"); assert(#invites==1)
R.Observe("CHAT_MSG_CHANNEL","ZF inv","PublicPlayer"); assert(#invites==1)
R.Observe("CHAT_MSG_WHISPER","do not invite me to zf","Negative"); assert(#invites==1)
R.Observe("CHAT_MSG_WHISPER","LFM ZF healer","GroupLeader"); assert(#invites==1 and R.matches[1].kind=="group")
R.Observe("CHAT_MSG_WHISPER","ZF invite pls","PlayerTwo"); assert(#invites==2)
R.Observe("CHAT_MSG_WHISPER","inv","PlayerThree"); assert(#invites==2) -- Pending slots reserved.
clock=clock+61; members=5
R.Observe("CHAT_MSG_WHISPER","inv","Full"); assert(#invites==2)
members=3; UnitIsGroupLeader=function() return false end
R.Observe("CHAT_MSG_WHISPER","inv","NotLeader"); assert(#invites==2)
UnitIsGroupLeader=function() return true end; InCombatLockdown=function() return true end
R.Observe("CHAT_MSG_WHISPER","inv","Combat"); assert(#invites==2)
InCombatLockdown=function() return false end
clock=2000
R.Observe("CHAT_MSG_WHISPER","inv","StillEnabled"); assert(#invites==3)
R.Start(A.db.dungeon); A.db.dungeon="Uldaman"
R.Observe("CHAT_MSG_WHISPER","ZF invite pls","WrongDungeon"); assert(#invites==3)
A.db.dungeon="Zul'Farrak"
R.Observe("CHAT_MSG_CHANNEL","LFG ZF DPS","Candidate"); assert(R.matches[1].name=="Candidate")
R.Settings().watch=false; local count=#R.matches
R.Observe("CHAT_MSG_CHANNEL","LFG ZF DPS","Hidden"); assert(#R.matches==count)
R.ShowSettings()
local template="LFM +{slots} {roles} - {dungeon}{plan}{full} {unknown}"
local coloured=R.ColorTemplate(template)
assert(coloured:find("|cff185783{dungeon}|r",1,true))
assert(R.PlainTemplate(coloured)==template)
assert(R.ColorTemplate(coloured)==coloured,"Formatting must not accumulate colour codes")
assert(R.PlainTemplate(R.ColorTemplate(string.rep("x",180).."{dungeon}{plan}{full}"))==string.rep("x",180).."{dungeon}{plan}{full}")
-- A final gsub return must not become a second queued message (its match count).
local notices,sent,timers={},{},{}
A.Print=function(text) notices[#notices+1]=text end
SendChatMessage=function(text) sent[#sent+1]=text end
C_ChatInfo=nil
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
A.pendingDungeonMessages=nil
for _,mode in ipairs({"LFG","LFM","guild"}) do
 for _,preset in ipairs({{false,false},{false,true},{true,true}}) do
  local messages={A.DungeonRunMessage(A.db.dungeon,mode,preset[1],preset[2])}
  assert(#messages==1 and type(messages[1])=="string")
  A.SendDungeonMessages(messages,{label="Say",kind="SAY",prefix="/s "})
 end
end
assert(#sent==9 and #timers==0 and #notices==0 and A.pendingDungeonMessages==nil)
''')
print('PASS: group-aware shorthand, unknown roles, overrides/templates, dungeon matching, default-off auto-invite, explicit whisper-only consent, capacity/pending/leader/combat guards and persistent enablement, chat matches and settings construction')
