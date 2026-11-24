"""Offline listing gates, one-shot offers and server-confirmed success."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
StaticPopupDialogs={}; offers=0; sends=0; notices={}; timers={}
function StaticPopup_Show(...) offers=offers+1 end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function(self,_,fn) eventHandler=fn end} end
C_Timer={NewTimer=function(_,fn) local t={fn=fn,Cancel=function(self) self.cancelled=true end}; timers[#timers+1]=t; return t end}
combat=false; grouped=false; ready=true; active=nil; result=true; roles={dps=true}
function InCombatLockdown() return combat end
function IsInGroup() return grouped end
function IsInRaid() return false end
function UnitLevel() return 48 end
Enum={LFGEntryGeneralPlaystyle={FunRelaxed=2},LFGEntryPlaystyle={None=0}}
C_LFGInfo={CanPlayerUsePremadeGroup=function() return true end}
C_LFGListRoles={GetRoles=function() return roles end}
A={db={dungeon="ZF"},log={[1]={complete=false}},quests={{id=1}},
 Print=function(s) notices[#notices+1]=s end,InDungeon=function() return true end,Restriction=function() return false end,
 ChecklistVisible=function() return true end,Completed=function() return false end,
 DungeonWorkFinished=function(q) return A.log[q.id] and A.log[q.id].complete end,
 GroupActivities=function() return {10} end,PartyDiscovery={Ready=function() return ready end}}
C_LFGList={HasActiveEntryInfo=function() return active~=nil end,GetActiveEntryInfo=function() return active end,
 GetActivityInfoTable=function() return {categoryID=2,minLevel=40,maxNumPlayers=5,groupFinderActivityGroupID=7} end,
 GetLfgCategoryInfo=function() return {autoChooseActivity=false} end,
 ClearCreationTextFields=function() cleared=true end,
 SetEntryTitle=function(id,group,none,style) assert(cleared and id==10 and group==7 and none==0 and style==2) end,
 CreateListing=function(data) assert(data.activityIDs[1]==10 and data.generalPlaystyle==2 and not data.isAutoAccept); sends=sends+1; return result end}
''')
lua.execute((root/'ReadyListing.lua').read_text(),'DungeonGuideForever',lua.globals().A)
lua.execute('''
local L=A.ReadyListing
ready=false; L.Check(); assert(offers==0)
ready=true; roles={}; L.Check(); assert(offers==0)
roles={dps=true}; grouped=true; L.Check(); assert(offers==0)
grouped=false; combat=true; L.Check(); assert(offers==0)
combat=false; active={}; L.Check(); assert(offers==0)
active=nil; A.log[1].complete=true; L.Check(); assert(offers==0)
A.log[1]=nil; L.Check(); L.Check(); assert(offers==1 and sends==0) -- Ready inside pickups also qualify.
combat=true; L.Accept("ZF"); assert(sends==0)
combat=false; L.Accept("ZF"); L.Accept("ZF"); assert(sends==1 and L.pending)
assert(not notices[#notices]:find("Listed for",1,true))
active={activityIDs={10},generalPlaystyle=2,comment=""}; L.Confirm()
assert(not L.pending and notices[#notices]:find("Listed for ZF",1,true))
L.Accept("ZF"); assert(sends==1) -- Never replace an existing entry.
active=nil; result=false; L.Accept("ZF"); assert(sends==2 and not L.pending)
result=true; L.Accept("ZF"); assert(L.pending); timers[#timers].fn(); assert(not L.pending and sends==3)
L.Accept("ZF"); active={activityIDs={10},generalPlaystyle=0,comment=""}; L.Confirm()
assert(not L.pending and notices[#notices]:find("do not match",1,true))
active=nil; C_LFGList.CreateListing=function() eventHandler(nil,"ADDON_ACTION_BLOCKED"); return true end
L.Accept("ZF"); assert(not L.pending and notices[#notices]:find("not confirmed",1,true))
''')
print('PASS: readiness/role/solo/combat/existing-entry gates, single offer, no send before acceptance, revalidation, async confirmation, rejection/timeout/mismatch/blocked handling, no retry')
