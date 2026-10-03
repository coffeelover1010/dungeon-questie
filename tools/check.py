"""Offline Lua 5.1 contracts, not live-client rendering or server proof."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
import json
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
runtime_paths=[line.strip() for line in (root/'DungeonGuideForever.toc').read_text().splitlines() if line.strip() and not line.startswith('#')]
for p in (root/path.replace('\\','/') for path in runtime_paths):
    lua.execute('assert(loadstring(...))',p.read_text(encoding='utf-8-sig'))
lua.execute('''
A={}; completed={}; log={}; faction="Alliance"; class="MAGE"; level=30; race="Gnome"
SlashCmdList={}; C_Timer={After=function(_,fn) fn() end}
function UnitFactionGroup() return faction end
function UnitClass() return class,class end
function UnitRace() return race,race end
function UnitLevel() return level end
function GetLocale() return "enUS" end
function InCombatLockdown() return false end
function CreateFrame()
 local f={}
 function f:RegisterEvent() end; function f:UnregisterEvent() end
 function f:SetScript(e,fn) self[e]=fn end
 return f
end
C_QuestLog={
 IsQuestFlaggedCompleted=function(id) return completed[id] or false end,
 GetNumQuestLogEntries=function() return #log end,
 GetInfo=function(i) return log[i] end,
 IsComplete=function(id) for _,q in ipairs(log) do if q.questID==id then return q.complete end end return false end
}
''')
for name in ['Data.lua','Tracking.lua','Map.lua','Artwork.lua','Window.lua']:
    lua.execute((root/name).read_text(encoding='utf-8'), 'DungeonGuideForever',lua.globals().A)
lua.execute('''
A.events.OnEvent(nil,"ADDON_LOADED","DungeonGuideForever"); A.Scan()
assert(A.db.mine==nil and A.db.pins)
assert(A.state[5723]=="restricted")
assert(A.state[1740]=="restricted")
assert(A.state[96393]=="todo")
completed[96391]=true; A.Scan(); assert(A.state[96393]=="todo")
level=8; A.Scan(); assert(A.state[96393]=="level"); level=30
log={{isHeader=true,title="header"},{questID=96393,title="Old Ironforge Incursion",complete=false}}
A.Scan(); assert(A.state[96393]=="active")
log[2].complete=true; A.Scan(); assert(A.state[96393]=="ready")
log={}; A.Scan(); assert(A.state[96393]=="todo") -- abandoning never completes
local d=A.Count(); A.db.manual={[96393]=true}; A.Scan(); assert(A.state[96393]=="todo"); A.db.filter="To do"; assert(A.Matches(A.byID[96393])); assert(A.Count()==d)
assert(A.ToggleManual==nil)
A.events.OnEvent(nil,"QUEST_TURNED_IN",96393); assert(A.state[96393]=="done")
assert(A.Count()==d+1); assert(A.state[96393]=="done")
completed={}; A.Scan(); assert(A.state[96393]=="done") -- observed turn-ins persist
local old=A.db; DungeonGuideForeverDB={}; A.events.OnEvent(nil,"ADDON_LOADED","DungeonGuideForever"); A.Scan()
assert(A.state[96393]~="done") -- character isolation
faction="Horde"; class="WARLOCK"; A.Scan(); assert(A.state[1740]~="restricted"); assert(A.state[168]=="restricted")
assert(A.InDungeon(A.byID[1740],"Shadowfang Keep") and A.InDungeon(A.byID[1740],"Blackfathom Deeps"))
C_QuestLog.IsQuestFlaggedCompleted=nil; C_QuestLog.GetNumQuestLogEntries=nil; A.Scan(); assert(A.state[5723]=="unknown")
-- No fabricated native success: waypoint setter explicitly returns false.
local calls=0; opened=nil
C_Map={GetMapInfo=function() return {name="Orgrimmar"} end,CanSetUserWaypointOnMap=function() return true end,SetUserWaypoint=function() calls=calls+1; return false end}
UiMapPoint={CreateFromCoordinates=function(m,x,y) return {uiMapID=m,x=x,y=y} end}
function OpenWorldMap(id) opened=id end
A.Print=function() end
A.Navigate(A.byID[5761]); assert(calls==1 and opened==1454 and A.waypoint==nil)
C_Map.GetMapInfo=function() return {name="Wrong map"} end
A.Navigate(A.byID[5761]); assert(calls==1)
-- Reported Forever coordinates have no GetXY; preserve unrelated waypoints.
local cleared=0
C_Map.ClearUserWaypoint=function() cleared=cleared+1 end
local function checkClear(point,expected)
 A.waypoint={map=1455,x=67.92,y=46.1}
 C_Map.GetUserWaypoint=function() return point end
 local before=cleared
 A.ClearWaypoint()
 assert(cleared-before==expected and A.waypoint==nil)
end
checkClear({uiMapID=1455,position={x=0.6792,y=0.461}},1)
checkClear({uiMapID=1455,position={GetXY=function() return 0.6792,0.461 end}},1)
checkClear({uiMapID=1455,position={x=0.2,y=0.461}},0)
checkClear({uiMapID=1454,position={x=0.6792,y=0.461}},0)
checkClear({uiMapID=1455,position={}},0)
checkClear({uiMapID=1455,position={x="bad",y=0.461}},0)
checkClear({uiMapID=1455,position={GetXY=function() error("unavailable") end}},0)
checkClear(nil,0)
C_Map.GetUserWaypoint=nil
''')
data=json.loads((root/'data/catalogue.json').read_text(encoding='utf-8'))
assert len({q['id'] for q in data})==len(data)
for q in data:
    assert q['source'].startswith('https://') and q['evidence']
    assert q['id'] not in q.get('prereqs',[])
    if q.get('pin'):
        p=q['pin']; assert 0<=p['x']<=100 and 0<=p['y']<=100 and p['map']>0 and q['locationSource']
for line in (root/'DungeonGuideForever.toc').read_text().splitlines():
    if line and not line.startswith('#'): assert (root/line.replace('\\','/')).is_file(),line
# Exercise window construction, all quest details, empty filters, and pin pooling.
# This deliberately does not claim visual or native-client validation.
lua.execute('''
UISpecialFrames={}; tinsert=table.insert
function IsShiftKeyDown() return false end
local methods={}
for _,k in ipairs({"SetShadowOffset","SetAlpha","SetAtlas","SetTexCoord","SetNormalTexture","SetPushedTexture","SetHighlightTexture","SetDisabledTexture","SetFont","SetPoint","ClearAllPoints","SetJustifyH","SetJustifyV","SetTextColor","SetFrameStrata","SetClampedToScreen","SetBackdrop","SetBackdropColor","SetBackdropBorderColor","EnableMouse","SetMovable","RegisterForDrag","StartMoving","StopMovingOrSizing","SetAutoFocus","SetMaxLetters","ClearFocus","SetAllPoints","SetTexture","SetDesaturated","SetVertexColor","SetChecked","SetColorTexture","SetVerticalScroll","SetFocus","HighlightText","SetOwner","AddLine","SetHyperlink"}) do methods[k]=function() end end
function methods:SetSize(w,h) self.w=w; self.h=h end
function methods:SetWidth(w) self.w=w end
function methods:SetHeight(h) self.h=h end
function methods:GetWidth() return self.w or 1000 end
function methods:GetHeight() return self.h or 700 end
function methods:SetText(t) self.text=t; if self.OnTextChanged then self:OnTextChanged() end end
function methods:GetText() return self.text or "" end
function methods:SetScript(e,fn) self[e]=fn end
function methods:GetStringHeight() return math.max(15,#(self.text or "")/45*14) end
function methods:SetScrollChild(c) self.child=c end
function methods:Show() local old=self.shown; self.shown=true; if not old and self.OnShow then self:OnShow() end end
function methods:Hide() self.shown=false end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:SetEnabled(v) self.enabled=v end
function methods:SetParent(p) self.parent=p end
function methods:GetParent() return self.parent end
function methods:SetScale(v) self.scale=v end
function methods:GetFrameLevel() return 5 end
function methods:SetFrameLevel() end
function methods:RegisterEvent() end
function methods:GetPoint() return "CENTER",UIParent,"CENTER",0,0 end
function CreateFrame(_,_,p) return setmetatable({parent=p,shown=true},{__index=methods}) end
function methods:CreateFontString() return CreateFrame() end
function methods:CreateTexture() return CreateFrame() end
for _,k in ipairs({"GetNormalTexture","GetPushedTexture","GetHighlightTexture","GetDisabledTexture"}) do methods[k]=function() return CreateFrame() end end
function methods:GetFontString() self.font=self.font or CreateFrame(); return self.font end
UIParent=CreateFrame(); UIParent:SetSize(1920,1080); GameTooltip=CreateFrame()
WorldMapFrame=CreateFrame(); local canvas=CreateFrame(); function WorldMapFrame:GetCanvas() return canvas end
function WorldMapFrame:GetMapID() return 1453 end
C_Map.GetMapInfo=function(id) return {name=id==1453 and "Stormwind City" or "Other"} end
faction="Alliance"; class="MAGE"; level=30
C_QuestLog.IsQuestFlaggedCompleted=function(id) return false end
C_QuestLog.GetNumQuestLogEntries=function() return 0 end
-- A locked seventh quest must not leave six completed quests at 6/7.
local savedQuests=A.quests
A.quests={}
for i=1,6 do local id=900000+i; A.quests[i]={id=id,dungeons={"Eligibility test"}}; A.db.confirmed[id]=true; A.state[id]="done" end
local locked={id=900007,dungeons={"Eligibility test"},minLevel=31}
A.quests[7]=locked
local d,t=A.Count("Eligibility test"); assert(d==6 and t==6)
locked.minLevel=1; locked.prereqs={900008}
d,t=A.Count("Eligibility test"); assert(d==6 and t==7)
A.db.manual={[locked.id]=true}; A.state[locked.id]="todo"
d,t=A.Count("Eligibility test"); assert(d==6 and t==7)
A.db.confirmed[900008]=true
d,t=A.Count("Eligibility test"); assert(d==6 and t==7)
locked.faction="Horde"
d,t=A.Count("Eligibility test"); assert(d==6 and t==6)
A.quests=savedQuests; A.db.manual[locked.id]=nil
-- Sidebar collection progress survives turn-in and includes future/inside quests.
local collectionQuest={id=990020,dungeons={"Collection test"},pickup="Outside NPC"}
A.quests={collectionQuest,{id=990021,dungeons={"Collection test"},pickupInside=true},
 {id=990022,dungeons={"Collection test"},minLevel=99},
 {id=990023,dungeons={"Collection test"},faction="Horde"}}
local summary=A.PreparationSummary("Collection test"); assert(summary.collected==0 and summary.total==3)
A.log[990020]={}; summary=A.PreparationSummary("Collection test"); assert(summary.collected==1 and summary.total==3)
A.log[990020].complete=true; summary=A.PreparationSummary("Collection test"); assert(summary.collected==1 and summary.total==3)
A.log[990020]=nil; A.db.confirmed[990020]=true
summary=A.PreparationSummary("Collection test"); assert(summary.collected==1 and summary.total==3)
A.db.confirmed[990021]=true; A.db.confirmed[990022]=true
summary=A.PreparationSummary("Collection test"); assert(summary.collected==3 and summary.total==3)
A.db.confirmed[990020]=nil; A.db.confirmed[990021]=nil; A.db.confirmed[990022]=nil
A.quests=savedQuests
local insideSteps=A.PickupSteps(A.byID[1200]); assert(insideSteps:find("Get inside Blackfathom Deeps.",1,true))
local outsideSteps=A.PickupSteps(A.byID[1486]); assert(not outsideSteps:find("Get inside",1,true))
local pickupTest={id=990001,name="Later quest",pickup="Later NPC",prereqs={990002},chain={{id=990002,name="Starting quest"}}}
local steps,target=A.PickupSteps(pickupTest)
assert(steps:find("Starting quest",1,true) and steps:find("may not be required",1,true) and target==pickupTest)
A.byID[990002]={id=990002,name="Starting quest",pickup="Starter NPC - Stormwind",pin={map=1453,x=50,y=50}}
steps,target=A.PickupSteps(pickupTest)
assert(target==pickupTest and steps:find("Later NPC",1,true))
A.db.confirmed[990002]=true
steps,target=A.PickupSteps(pickupTest)
assert(target==pickupTest and not steps:find("First finish:",1,true))
A.log[pickupTest.id]={}; steps,target=A.PickupSteps(pickupTest); assert(target==nil and not steps:find("Later NPC",1,true)); A.log[pickupTest.id]=nil
A.state[pickupTest.id]="done"; steps,target=A.PickupSteps(pickupTest); assert(target==nil and steps:find("turned in",1,true)); A.state[pickupTest.id]=nil
A.log[1198]={complete=true}
assert(A.Preparation(A.byID[1198])=="packed")
assert(A.Preparation(A.byID[1200])=="inside")
steps,target=A.PickupSteps(A.byID[1198]); assert(target==nil and steps:find("inside Blackfathom Deeps",1,true) and not steps:find("Darnassus",1,true))
assert(not A.NeedsPickup(A.byID[1198]))
local oldTarget=A.target; A.Navigate(A.byID[1198]); assert(A.target==oldTarget)
A.log[1198]=nil
assert(A.Preparation(A.byID[1198])=="check") -- unavailable log API
local savedAvailability=A.logAvailable
A.logAvailable=true
C_QuestLog.IsQuestFlaggedCompleted=function(id) return completed[id] or false end
assert(A.Preparation(A.byID[1198])=="pickup")
local prepCheck={id=990007,minLevel=99,pickup="Outside NPC"}
assert(A.Preparation(prepCheck)=="blocked")
prepCheck.minLevel=1; prepCheck.prereqs={990008}
assert(A.Preparation(prepCheck)=="chain")
prepCheck.prereqs={}; prepCheck.pickup=nil
assert(A.Preparation(prepCheck)=="check")
A.logAvailable=savedAvailability
A.byID[990002]=nil; A.db.confirmed[990002]=nil
A.Scan(); A.Toggle(); assert(A.window:IsShown())
A.db.mine=false -- An old setting cannot bypass the permanent character filter.
for _,q in ipairs(A.quests) do
 A.SelectQuest(q)
 if not A.Restriction(q) and A.ChecklistVisible(q) then assert(A.window.detailTitle:GetText()==q.name)
 else assert(not A.Matches(q)) end
end
A.window.search:SetText("no such quest 1234567890"); assert(A.window.detailTitle:GetText()=="Select a quest")
A.window.search:SetText("")
A.db.dungeon="City of Dalaran"; A.Refresh(); assert(A.window.detailText:GetText():find("coverage gap"))
A.SelectQuest(A.byID[168]); A.RefreshPins()
A.Toggle(); assert(not A.window:IsShown())
''')
lua.execute("""
local mapID
function WorldMapFrame:SetMapID(id) mapID=id end
A.window:Show()
A.Navigate(A.byID[168])
assert(WorldMapFrame:IsShown() and mapID==1453 and not A.window:IsShown())
""")
print(f'PASS: Lua 5.1 syntax, manifest, {len(data)} unique records, coordinates, completion, abandonment, ignored legacy marks, restrictions, prerequisites, isolation, unavailable APIs, waypoint/map guards, window construction and every detail panel (mocked UI)')
