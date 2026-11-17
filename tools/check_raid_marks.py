from pathlib import Path
import runpy
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
lua.execute((root/'RaidMarks.lua').read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
lua.execute(r''' 
local M=A.RaidMarks
local plate=CreateFrame("Frame")
local related=true
UnitIsPlayer=function() return false end
UnitIsDeadOrGhost=function() return false end
C_QuestLog=C_QuestLog or {}
C_QuestLog.UnitIsRelatedToActiveQuest=function(unit) assert(unit=="nameplate1"); return related end
C_NamePlate={GetNamePlateForUnit=function() return plate end}
SetRaidTarget=function() error("Must not change raid markers") end
M.AddUnit("nameplate1"); assert(M.badges[plate]:IsShown())
-- Updates in combat need no click, and completed objectives can remove the badge.
InCombatLockdown=function() return true end
related=false; M.Refresh(); assert(not M.badges[plate]:IsShown())
related=true; M.Refresh(); assert(M.badges[plate]:IsShown())
M.RemoveUnit("nameplate1"); assert(not M.badges[plate]:IsShown() and not next(M.plates))
-- Recycled nameplates must not inherit the previous unit's badge.
related=false; M.AddUnit("nameplate1"); assert(not M.badges[plate]:IsShown())
related=true; M.Refresh(); assert(M.badges[plate]:IsShown())
A.db.questTargetIndicators=false; M.Refresh(); assert(not M.badges[plate]:IsShown())
A.db.questTargetIndicators=true
UnitIsDeadOrGhost=function() return true end
M.Refresh(); assert(not M.badges[plate]:IsShown())
UnitIsDeadOrGhost=function() return false end
C_QuestLog.UnitIsRelatedToActiveQuest=nil
M.Refresh(); assert(not M.badges[plate]:IsShown())
C_QuestLog.UnitIsRelatedToActiveQuest=function() return true end
issecretvalue=function(v) return v==true end
M.Refresh(); assert(not M.badges[plate]:IsShown())
print("PASS: automatic quest nameplate badges, combat updates, completion, recycling, opt-out, dead units, unavailable API and secret values")
''')
