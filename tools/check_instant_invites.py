"""Immediate opt-in recruitment without replies, retry loops or duplicate invites."""
from pathlib import Path
import runpy
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check_party_discovery.py'))['lua']
lua.execute(r'''
local R,D=A.ChatRecruitment,A.PartyDiscovery
local clock=10000; GetTime=function() return clock end
A.db={dungeon="Zul'Farrak",chatRecruit={watch=true,autoInvite=false,findPlayers=true,available=true}}
GetNumGroupMembers=function() return 1 end; IsInGroup=function() return false end
IsInRaid=function() return false end; InCombatLockdown=function() return false end
R.pending={}; R.autoAttempts={}; R.autoWindow=nil; R.matches={}
local invites={}; InviteUnit=function(name) invites[#invites+1]=name end; C_PartyInfo=nil
R.Observe("CHAT_MSG_CHANNEL","LFG ZF healer","PublicOne")
assert(#invites==0 and R.matches[1].name=="PublicOne")
R.Settings().autoInvite=true
R.Observe("CHAT_MSG_CHANNEL","LFG ZF healer","PublicOne"); assert(#invites==1)
clock=clock+61; R.pending={}
R.Observe("CHAT_MSG_WHISPER","inv","PublicOne"); assert(#invites==1) -- Cross-channel cooldown.
R.Observe("CHAT_MSG_CHANNEL","LFM ZF healer","Leader")
R.Observe("CHAT_MSG_CHANNEL","LFG BRD healer","WrongDungeon")
R.Observe("CHAT_MSG_CHANNEL","we LFG ZF","Pair")
R.Observe("CHAT_MSG_CHANNEL","not LFG ZF","Negative")
assert(#invites==1)
R.Observe("CHAT_MSG_WHISPER","inv","WhisperOne"); assert(#invites==2)
R.Settings().watch=false
R.Observe("CHAT_MSG_GUILD","LFG ZF tank","GuildOne"); assert(#invites==3)
D.readyDungeon=A.db.dungeon; D.peers={}; D.receiveWindow=nil
D.Receive(D.prefix,"1|Zul'Farrak|48|HEALER|1|Alliance","GUILD","HiddenOne")
assert(#invites==4)
D.Receive(D.prefix,"1|Zul'Farrak|48|HEALER|2|Alliance","GUILD","HiddenGroup")
assert(#invites==4)
R.Settings().autoInvite=false
D.Receive(D.prefix,"1|Zul'Farrak|48|HEALER|1|Alliance","GUILD","HiddenOff")
assert(#invites==4 and D.peers.HiddenOff)
-- Even failed attempts have a bounded global budget; nothing queues a retry.
R.Settings().autoInvite=true; R.autoWindow=nil; R.pending={}
local attempts=0; R.Invite=function() attempts=attempts+1; return false end
for i=1,1000 do R.TryAutoInvite("Flood"..i,A.db.dungeon) end
assert(attempts==5)
''')
print('PASS: immediate enabled whisper/public/guild/discovery invitations, disabled match-only behaviour, cross-channel cooldown, LFM/group/negative/wrong-dungeon rejection and flood budget')
