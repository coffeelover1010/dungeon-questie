"""Offline quest group actions; native rendering and taint still need a client check."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
A={Safe=function(fn,...) if fn then local ok,v=pcall(fn,...); if ok then return v end end end,Print=function(s) message=s end}
tag=1; size=1; channel=4; combat=false; active=false; leader=true
C_QuestLog={GetQuestTagInfo=function() return {tagID=tag} end,GetSuggestedGroupSize=function() return size end}
function GetChannelName() return channel end
function GetQuestLink(id) return "|Hquest:"..id.."|h[Test]|h" end
ChatFrameUtil={OpenChat=function(s) draft=s end}
function InCombatLockdown() return combat end
function IsInGroup() return true end
function UnitIsGroupLeader() return leader end
C_LFGInfo={CanPlayerUsePremadeGroup=function() return true end}
C_LFGList={HasActiveEntryInfo=function() return active end,GetAvailableCategories=function() return {2,120} end,
 CreateListing=function() error("Must not publish") end}
function SendChatMessage() error("Must not send") end
LFGListingFrame={SetCategorySelection=function(_,id) category=id end}
function LFGVanilla_ShowFrame(tab) opened=tab end
function CreateFrame()
 return setmetatable({CreateFontString=function() return {SetPoint=function() end,SetWidth=function() end,SetText=function(_,s) hint=s end} end},
 {__index=function() return function() end end})
end
''')
lua.execute((Path(__file__).resolve().parents[1]/'QuestGroups.lua').read_text(), 'DungeonGuideForever',lua.globals().A)
lua.execute('''
local q={id=123,name="Group Quest"}
-- All quest types can be linked, without sending or replacing an open draft.
tag=81
local inserted
ChatEdit_InsertLink=function(link) inserted=link; return true end
A.LinkQuestInChat(q); assert(inserted==GetQuestLink(123) and draft==nil)
ChatEdit_InsertLink=function() return false end
A.LinkQuestInChat(q); assert(draft==GetQuestLink(123)); draft=nil
local native=GetQuestLink; GetQuestLink=function() return nil end
assert(A.QuestChatLink({id=456,name="Unaccepted",level=30})=="|cffffff00|Hquest:456:30|h[Unaccepted]|h|r")
GetQuestLink=function() error("Not cached") end
assert(A.QuestChatLink({id=456,name="Unknown level"}):find("quest:456:-1",1,true))
GetQuestLink=native; ChatEdit_InsertLink=nil
local modern=ChatFrameUtil; ChatFrameUtil=nil
ChatFrame_OpenChat=function(s) draft=s end
A.LinkQuestInChat(q); assert(draft==GetQuestLink(123)); draft=nil
ChatFrame_OpenChat=nil; A.LinkQuestInChat(q); assert(message=="Chat input is unavailable.")
A.LinkQuestInChat(nil); ChatFrameUtil=modern; tag=1
assert(A.IsGroupQuest(q)); tag=41; assert(not A.IsGroupQuest(q))
tag=0; size=3; assert(A.IsGroupQuest(q)); size=1; assert(not A.IsGroupQuest(q))
size=5
for _,instanceTag in ipairs({62,81,85,88,89}) do
 tag=instanceTag; assert(not A.IsGroupQuest(q))
 A.QuestGeneral(q); A.QuestCreateGroup(q); assert(draft==nil and opened==nil)
end
tag=1; q.pickupInside=true; assert(not A.IsGroupQuest(q)); q.pickupInside=nil
A.byID={[123]={pickupInside=true}}; assert(not A.IsGroupQuest(q)); A.byID=nil
size=1; assert(A.IsGroupQuest(q))
A.QuestGeneral(q); assert(draft:find("/4 LFG |Hquest:123",1,true))
draft=nil; channel=0; A.QuestGeneral(q); assert(draft==nil)
combat=true; A.QuestCreateGroup(q); assert(opened==nil)
combat=false; active=true; A.QuestCreateGroup(q); assert(opened==nil)
active=false; leader=false; A.QuestCreateGroup(q); assert(opened==nil)
leader=true; A.QuestCreateGroup(q); assert(opened==1 and category==120 and hint:find("[Group Quest]",1,true))
''')
print('PASS: group classification, linked General draft, missing channel, combat/leader/existing listing gates, Custom form; no sends or posts')
