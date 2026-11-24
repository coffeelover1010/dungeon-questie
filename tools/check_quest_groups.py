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
 local frame=setmetatable({SetText=function(self,value) self.text=value end,GetText=function(self) return self.text end,Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end,SetScript=function(self,event,fn) self[event]=fn end,CreateTexture=function() return CreateFrame() end,CreateFontString=function() return setmetatable({SetJustifyH=function() end,SetPoint=function() end,SetWidth=function() end,SetText=function(_,s) hint=s end},{__index=function() return function() end end}) end},
 {__index=function() return function() end end})
 frames=frames or {}; frames[#frames+1]=frame; return frame
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
assert(A.QuestChatLink({id=456,name="Unaccepted",level=30})==nil)
QuestieLoader={ImportModule=function(self,name)
 assert(self==QuestieLoader and name=="QuestieLink")
 return {GetQuestLinkStringById=function(id) return "[Unaccepted ("..id..")]" end}
end}
assert(A.QuestChatLink({id=456,name="Unaccepted"})=="[Unaccepted (456)]")
GetQuestLink=function() error("Not cached") end
assert(A.QuestChatLink({id=456,name="Unknown level"})=="[Unaccepted (456)]")
C_QuestLog.GetQuestLink=function(id) return "|Hquest:"..id.."|h[Modern]|h" end
assert(A.QuestChatLink(q)==C_QuestLog.GetQuestLink(q.id))
ChatFrameUtil.InsertLink=function(link) inserted=link; return true end
A.LinkQuestInChat(q); assert(inserted==C_QuestLog.GetQuestLink(q.id))
ChatFrameUtil.InsertLink=nil; C_QuestLog.GetQuestLink=nil; QuestieLoader=nil
message=nil; draft=nil; A.LinkQuestInChat(q)
assert(draft==nil and message:find("Quest link unavailable",1,true))
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

lua.execute('''
local q={id=123,name="Group Quest"}
local guild=true
IsInGuild=function() return guild end
IsInRaid=function() return false end
GetChannelList=function() return 1,"General",false,2,"Unavailable",true end
local shift=false
IsShiftKeyDown=function() return shift end
local menu,opened,sends={},0,0
MenuUtil={CreateContextMenu=function(owner,generator)
 opened=opened+1; menu={}
 generator(owner,{CreateTitle=function() end,CreateDivider=function() end,
 CreateButton=function(_,label,callback) menu[label]=callback end})
end}
local inserted
ChatFrameUtil.InsertLink=function(link) inserted=link; return true end
SendChatMessage=function(link,kind,language,target)
 sends=sends+1; sent={link=link,kind=kind,target=target}
end
shift=true; A.OpenQuestChatMenu(q,{})
assert(opened==0 and sends==0 and inserted==GetQuestLink(123))
shift=false; A.OpenQuestChatMenu(q,{})
assert(opened==1 and sends==0 and menu.Guild and menu.Party and menu['1. General'] and not menu['2. Unavailable'])
menu.Guild(); assert(sends==1 and sent.kind=='GUILD' and sent.link==GetQuestLink(123))
menu['1. General'](); assert(sends==2 and sent.kind=='CHANNEL' and sent.target==1)
guild=false; menu.Guild(); assert(sends==2 and message:find('destination changed',1,true))
GetChannelList=function() return 1,"Trade",false end
menu['1. General'](); assert(sends==2)
draft=nil
SendChatMessage=function() error('blocked') end
menu.Say(); assert(draft=='/s '..GetQuestLink(123))
draft=nil
SendChatMessage=function() frames[1].OnEvent(nil,'ADDON_ACTION_BLOCKED') end
menu.Yell(); assert(draft=='/y '..GetQuestLink(123))
MenuUtil=nil; inserted=nil; A.OpenQuestChatMenu(q,{})
assert(inserted==GetQuestLink(123))
''')
print('PASS: chat menu, Shift-click insertion, sends only on selection, membership/channel recheck, blocked-send draft, missing-menu fallback')

lua.execute('''
assert(A.DungeonRunMessage("Zul'Farrak","LFG",true,true)=="LFG ZF - Quest Pickup - Full Run")
assert(A.DungeonRunMessage("Zul'Farrak","LFM",false,false):find("Dungeon Only",1,true))
assert(A.DungeonRunMessage("Test","LFG",true,false):find("Full Run",1,true))
assert(A.DungeonRunMessage("Test","guild",true,false):find("Quest Pickup + Full Run",1,true))
local quests={}; for i=1,25 do quests[i]={id=1000+i,name="Quest "..i} end
quests[#quests+1]=quests[1]
local messages=A.DungeonQuestMessages("Zul'Farrak",quests)
assert(#messages>1)
assert(messages[1]:find("ZF quests: ",1,true)==1)
for i=2,#messages do
 local startsWithLink=false
 for _,quest in ipairs(quests) do
  local link=GetQuestLink(quest.id)
  if messages[i]:sub(1,#link)==link then startsWithLink=true; break end
 end
 assert(startsWithLink)
end
local combined=table.concat(messages," ")
for _,text in ipairs(messages) do assert(#text<=255) end
for i=1,25 do
 local link=GetQuestLink(1000+i)
 local start,finish=combined:find(link,1,true); assert(start and not combined:find(link,finish+1,true))
end
assert(not A.DungeonQuestMessages("Test",{}))
local original=A.QuestChatLink
A.QuestChatLink=function() return nil end
assert(not A.DungeonQuestMessages("Test",quests))
A.QuestChatLink=original
local sends=0
SendChatMessage=function(text) sends=sends+1; sentText=text end
C_Timer={After=function() error("Chat must not be sent from a timer") end}
A.pendingDungeonMessages=nil
A.SendDungeonMessages({"First","Second"},{label="Say",kind="SAY",prefix="/s "})
assert(sends==1 and sentText=="First")
local pending=A.pendingDungeonMessages
assert(#pending.messages==1 and pending.messages[1]=="Second")
A.pendingDungeonMessages=nil
A.SendDungeonMessages(pending.messages,pending.destination)
assert(sends==2 and sentText=="Second" and A.pendingDungeonMessages==nil)
''')
print('PASS: LFG/LFM/full-run wording, quest deduplication, bounded complete links, missing-link handling, one batch per click and remaining-link continuation')

lua.execute(r'''
local label
local originalWindow=A.window
A.db={dungeon="Test"}
A.window={listedQuests={},questShareButton={count={SetText=function(_,value) label=value end}}}
for i=1,25 do A.window.listedQuests[i]={id=1000+i,name="Quest "..i} end
local state=A.UpdateQuestShare()
local total=#state.messages
assert(total>1 and label=="")
local count=0
SendChatMessage=function() count=count+1 end
local destination={label="Say",kind="SAY",prefix="/s "}
A.SendQuestShare(state,destination)
assert(count==1 and label=="2/"..total)
for i=2,total do A.OpenDungeonChatAction("quests",{}) end
assert(count==total and label=="" and state.destination==nil)
A.SendQuestShare(state,destination)
A.db.dungeon="Another dungeon"
A.SendQuestShare(state,destination)
assert(count==total+1 and A.questShare.index==1 and A.questShare.destination==nil)
A.window=originalWindow
''')
print('PASS: precomputed share count, one send per click, completion reset and stale selection rejection')
