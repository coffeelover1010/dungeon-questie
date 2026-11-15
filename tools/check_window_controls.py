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
-- Preserve inherited secure targeting; minimize only after release, outside combat.
local target=f.targetButton
assert(target.OnClick==target.secureClick)
target:SetAttribute("macrotext","/targetexact Test NPC")
target.PostClick(target,"LeftButton",true); assert(f:IsShown())
target.PostClick(target,"LeftButton",false); assert(mini:IsShown() and not f:IsShown())
A.RestoreWindow(); target:SetAttribute("macrotext",nil)
target.PostClick(target,"LeftButton",false); assert(f:IsShown())
local before=f.scale
function InCombatLockdown() return true end
A.MinimizeWindow(); A.SetWindowScale(0.9); assert(f:IsShown() and f.scale==before)
f.resize.OnMouseDown(f.resize,"LeftButton"); assert(not f.resize.OnUpdate)
function InCombatLockdown() return false end
A.ResetWindowGeometry(); assert(f.scale==1 and not A.db.position and not A.db.minimizedPosition)
print("PASS: minimize/restore, saved scale, bounds, resize drag, reset and secure target release/combat guards")
''')
