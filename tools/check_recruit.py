"""Offline recruitment contracts and UI construction; never sends real messages."""
from pathlib import Path
import runpy

root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
lua.execute('''
StaticPopupDialogs={}; sent={}; invites={}; actions={}
local originalCreate=CreateFrame
frames={}
function CreateFrame(...)
 local f=originalCreate(...)
 function f:SetNumeric() end
 function f:SetWordWrap() end
 frames[#frames+1]=f; return f
end
function StaticPopup_Show(key,name,message,data) popup={key=key,name=name,message=message,data=data} end
combat=false; partyCount=0; leader=true; raid=false
function InCombatLockdown() return combat end
function IsInRaid() return raid end
function IsInGroup() return partyCount>0 end
function UnitIsGroupLeader() return leader end
function GetNumGroupMembers() return partyCount end
function UnitExists(unit) return unit=="player" end
function GetUnitName(unit) return "My Mage-Realm" end
function UnitInParty(name) return name=="Already Here-Realm" end
function UnitIsUnit(name) return name=="My Mage-Realm" end
LFGParentFrame=CreateFrame()
LFGBrowseFrame={ActivityDropdown={selectedValues={10}},searching=false}
results={
 [1]={leaderName="First Last-Realm",numMembers=1,activityIDs={10}},
 [2]={leaderName="Low Player",numMembers=1,activityIDs={10}},
 [3]={leaderName="High Player",numMembers=1,activityIDs={10}},
 [4]={leaderName="Other Dungeon",numMembers=1,activityIDs={11}},
 [5]={leaderName="Group Leader",numMembers=2,activityIDs={10}},
 [6]={leaderName="Gone Player",numMembers=1,activityIDs={10},isDelisted=true},
 [7]={leaderName="My Mage-Realm",numMembers=1,activityIDs={10}},
 [8]={leaderName="Already Here-Realm",numMembers=1,activityIDs={10}},
 [9]={leaderName="Next Warrior",numMembers=1,activityIDs={10}},
 [10]={leaderName="Unknown Level",numMembers=1,activityIDs={10}},
 [11]={leaderName="First Last-Realm",numMembers=1,activityIDs={10}},
}
members={}
for id in pairs(results) do members[id]={level=25,classFilename="WARRIOR",lfgRoles={tank=true,dps=true}} end
members[2].level=19; members[3].level=31; members[10].level=nil
C_LFGList={
 GetSearchResultInfo=function(id) return results[id] end,
 GetSearchResultPlayerInfo=function(id) return members[id] end,
 GetFilteredSearchResults=function() return 11,{1,2,3,4,5,6,7,8,9,10,11} end,
 GetActivityInfoTable=function(id) if id==10 then return {minLevelSuggestion=20,maxLevelSuggestion=30} end return {} end,
}
C_ChatInfo={SendChatMessage=function(message,channel,language,name)
 assert(channel=="WHISPER" and name=="First Last-Realm")
 sent[#sent+1]={message=message,name=name}; actions[#actions+1]="whisper"
end}
C_PartyInfo={InviteUnit=function(name) invites[#invites+1]=name; actions[#actions+1]="invite" end}
''')
lua.execute((root/'Recruit.lua').read_text(),'DungeonGuideForever',lua.globals().A)
lua.execute('''
local R=A.recruit
A.OpenRecruit("Stormwind Stockade",{10})
assert(R.low==20 and R.high==30 and R.frame:IsShown())
assert(R:Party().MAGE==1)
local list=R:Candidates().WARRIOR
assert(#list==2 and list[1].name=="First Last-Realm")
assert(R.frame.rows.WARRIOR.candidate.name=="First Last-Realm")
R.frame.rows.WARRIOR.next:OnClick()
assert(R.frame.rows.WARRIOR.candidate.name=="Next Warrior")
R:Confirm(list[1]); assert(#sent==0 and #invites==0)
assert(popup.message:find("Stormwind Stockade",1,true) and popup.name:find("First Last-Realm",1,true))
StaticPopupDialogs[popup.key].OnAccept(nil,popup.data)
assert(actions[1]=="whisper" and actions[2]=="invite" and invites[1]=="First Last-Realm")
assert(#R:Candidates().WARRIOR==1)
R:Send(popup.data); assert(#sent==1 and #invites==1) -- duplicate click
R.contacted={}; actions={}; sent={}; invites={}
R:Confirm(list[1]); results[1].leaderName="Changed Player"; R:Send(popup.data)
assert(#sent==0 and #invites==0); results[1].leaderName="First Last-Realm"
R:Confirm(list[1]); members[1].level=99; R:Send(popup.data)
assert(#sent==0); members[1].level=25
for _,condition in ipairs({"combat","full","nonleader","raid","busy","failed","filters"}) do
 combat=condition=="combat"; partyCount=condition=="full" and 5 or (condition=="nonleader" and 2 or 0)
 leader=condition~="nonleader"; raid=condition=="raid"
 LFGBrowseFrame.searching=condition=="busy"; LFGBrowseFrame.searchFailed=condition=="failed"
 LFGBrowseFrame.ActivityDropdown.selectedValues={condition=="filters" and 11 or 10}
 assert(R:Gate()); R:Send(popup.data); assert(#sent==0 and #invites==0)
end
combat=false; partyCount=0; leader=true; raid=false; LFGBrowseFrame.searching=false; LFGBrowseFrame.searchFailed=false
LFGBrowseFrame.ActivityDropdown.selectedValues={10}
local originalSend=C_ChatInfo.SendChatMessage
C_ChatInfo.SendChatMessage=function() error("blocked") end
R:Send(popup.data); assert(#invites==0 and R.contacted["first last-realm"])
R.contacted={}
C_ChatInfo.SendChatMessage=function() return false end
R:Send(popup.data); assert(#invites==0)
R.contacted={}
C_ChatInfo.SendChatMessage=function() R.blocked=true end
R:Send(popup.data); assert(#invites==0)
C_ChatInfo.SendChatMessage=originalSend; R.contacted={}
R.frame.low:SetText("26"); assert(#R:Candidates().WARRIOR==0)
R.frame.low:SetText("20"); R.frame.high:SetText("19"); assert(R:Gate())
R.frame.high:SetText("30"); assert(not R:Gate())
R:Confirm(list[1]); A.OpenRecruit("Deadmines",{11}); R:Send(popup.data)
assert(#sent==0 and #invites==0 and not R.low and not R.high)
''')
print('PASS: class and level filtering, exact spaced names, native results, party coverage, candidate cycling, confirmation, whisper-before-invite, stale targets, duplicate attempts, failed whispers, dungeon changes and manual range controls (mocked).')
