"""Window lifecycle and secure-action regression checks using offline client mocks."""
import runpy
from pathlib import Path
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
lua.execute(r''' 
local f=A.window; local mini=A.minimizedWindow
function f:GetScale() return self.scale end
function f:GetLeft() return 100/self.scale end
function f:GetTop() return 900/self.scale end
function UIParent:GetEffectiveScale() return 1 end
function GetCursorPosition() return 868,380 end
f:Show(); A.MinimizeWindow()
assert(not f:IsShown() and mini:IsShown())
A.Toggle(); assert(f:IsShown() and not mini:IsShown())
A.SetWindowScale(0.8); assert(f.scale==0.8 and A.db.windowScale==0.8)
A.SetWindowScale(100); assert(f.scale<=1.5)
A.SetWindowScale(0); assert(f.scale==0.55)
f.resize.OnMouseDown(f.resize,"LeftButton"); assert(f.resize.OnUpdate)
f.resize.OnUpdate(); assert(math.abs(f.scale-0.8)<0.0001)
f.resize.OnMouseUp(f.resize); assert(not f.resize.OnUpdate and A.db.position)
-- Preserve secure targeting without automatic minimization.
local slot=f.targetButton
function slot:GetLeft() return 400 end
function slot:GetTop() return 500 end
function slot:GetBottom() return 468 end
function slot:GetEffectiveScale() return 1 end
function slot:IsVisible() return true end
function f.detailScroll:GetTop() return 600 end
function f.detailScroll:GetBottom() return 100 end
slot:Show(); f.targetMacro="/targetexact Test"; A.UpdateTargetAction(f)
local target=f.targetAction
assert(target:GetParent()==UIParent and f.template=="BackdropTemplate")
assert(target.stateDriver=="[combat] combat; peace")
assert(target.OnClick==target.secureClick)
assert(target.PostClick==nil)
assert(f:IsShown() and not mini:IsShown())
local before=f.scale
function InCombatLockdown() return true end
-- Mimic the secure driver's combat hide; insecure code must not touch it.
target:Hide()
local oldHide,oldShow,oldAttribute=target.Hide,target.Show,target.SetAttribute
target.Hide=function() error("Secure hide in combat") end
target.Show=function() error("Secure show in combat") end
target.SetAttribute=function() error("Secure attribute in combat") end
A.UpdateTargetAction(f); assert(slot.enabled==false)
A.MinimizeWindow(); assert(not f:IsShown() and mini:IsShown())
A.Toggle(); assert(f:IsShown() and not mini:IsShown())
f.close.OnClick(); assert(not f:IsShown())
A.Toggle(); assert(f:IsShown())
A.SetWindowScale(0.9); assert(f.scale==0.9)
A.SetDetailsCollapsed(false); A.Refresh()
A.SetDetailsCollapsed(true); A.ShowCompactQuestPage(true); assert(f.compactQuestPage)
f.search:SetText("Troll"); assert(A.db.search=="Troll"); f.search:SetText("")
f.resize.OnMouseDown(f.resize,"LeftButton"); assert(f.resize.OnUpdate); f.resize.OnMouseUp(f.resize)
function InCombatLockdown() return false end
target.Hide,target.Show,target.SetAttribute=oldHide,oldShow,oldAttribute
f.targetMacro="/targetexact Test"; slot:Show()
A.UpdateTargetAction(f); assert(target:IsShown() and slot.enabled)
A.ResetWindowGeometry(); assert(f.scale==1 and not A.db.position and not A.db.minimizedPosition)
print("PASS: combat close/open, minimize/restore, search, layouts and resize; targeting isolated under UIParent and untouched in combat")
A.SetDetailsCollapsed(true); A.ShowCompactQuestPage(true)
assert(f.detailTitle:GetText()==A.db.dungeon.." > "..f.currentQuest.name)
local overWindow=false
function f:IsMouseOver() return overWindow end
local function mouse(button) f.backMouseWatcher.OnEvent(f.backMouseWatcher,"GLOBAL_MOUSE_UP",button) end
mouse("RightButton"); assert(f.compactQuestPage)
overWindow=true
mouse("LeftButton"); assert(f.compactQuestPage)
function InCombatLockdown() return true end
mouse("RightButton"); assert(not f.compactQuestPage)
function InCombatLockdown() return false end
mouse("RightButton"); assert(not f.compactQuestPage and f.listScroll:IsShown())
A.ShowCompactQuestPage(true); f.backToQuests.OnClick()
assert(not f.compactQuestPage and f.listScroll:IsShown())
print("PASS: title and right-click return to list, including during combat")
local savedCompleted,savedFinished,savedReadiness=A.Completed,A.DungeonWorkFinished,A.RunReadiness
A.Completed=function(id) return id==1 end
A.DungeonWorkFinished=function(q) return q.id==2 end
A.RunReadiness=function(q) return q.id==1 or q.id==2 or q.id==3 end
local ready,total=A.QuestListProgress({{id=1},{id=2},{id=3},{id=4}})
assert(ready==3 and total==4) -- Each ready/completed row counts only once.
ready,total=A.QuestListProgress({}); assert(ready==0 and total==0)
A.Completed,A.DungeonWorkFinished,A.RunReadiness=savedCompleted,savedFinished,savedReadiness
print("PASS: ready, objectives-finished and turned-in counts, no double counting, and empty list")
local savedSummary=A.PreparationSummary
local summary={total=2,done=2,skipped=0,finished=0,ready=0}
A.PreparationSummary=function() return summary end
A.Refresh()
assert(f.completionTick==nil and not f.heading:GetText():find("|T",1,true))
summary.done=1; summary.ready=1
A.Refresh()
assert(f.completionTick==nil)
summary.total=0; summary.done=0; summary.ready=0
A.Refresh()
assert(f.completionTick==nil)
A.PreparationSummary=savedSummary
print("PASS: no dungeon-header tick for completed, partially completed or empty scenarios")
function InCombatLockdown() return true end
A.window=nil; A.CreateWindow(); assert(A.window and not A.window.targetAction)
A.Toggle(); assert(A.window:IsShown()); A.window.close.OnClick(); assert(not A.window:IsShown())
print("PASS: first journal creation and closing during combat creates no secure controls")
''')
