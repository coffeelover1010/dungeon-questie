local _, A = ...
-- Personal quest indicators; these do not set or replace shared raid markers.
local M={plates={},badges=setmetatable({},{__mode="k"})}; A.RaidMarks=M
local function readable(value)
 return not (issecretvalue and issecretvalue(value))
end
function M.Relevance(unit)
 unit=unit or "target"
 local player=A.Safe(UnitIsPlayer,unit)
 local dead=A.Safe(UnitIsDeadOrGhost,unit)
 if not readable(player) or not readable(dead) or player or dead then return false end
 local related=A.Safe(C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest,unit)
 return readable(related) and related==true
end
function M.UpdateUnit(unit)
 local plate=M.plates[unit]
 if not plate then return end
 local badge=M.badges[plate]
 local relevant=A.db and A.db.questTargetIndicators~=false and M.Relevance(unit)
 if relevant and not badge then
  badge=plate:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  badge:SetFont("Fonts\\FRIZQT__.TTF",22,"OUTLINE")
  badge:SetPoint("RIGHT",plate,"LEFT",-4,0)
  badge:SetText("!"); badge:SetTextColor(1,0.82,0)
  M.badges[plate]=badge
 end
 if badge then badge:SetShown(relevant==true) end
end
function M.Update()
 for unit in pairs(M.plates) do M.UpdateUnit(unit) end
end
function M.Refresh() M.Update() end
function M.AddUnit(unit)
 local plate=A.Safe(C_NamePlate and C_NamePlate.GetNamePlateForUnit,unit)
 if not plate or A.Safe(plate.IsForbidden,plate) then return end
 M.plates[unit]=plate
 M.UpdateUnit(unit)
end
function M.RemoveUnit(unit)
 local plate=M.plates[unit]
 if plate and M.badges[plate] then M.badges[plate]:Hide() end
 M.plates[unit]=nil
end
function A.ShowRaidMarks()
 A.db.questTargetIndicators=A.db.questTargetIndicators==false
 M.Update()
 A.Print("Automatic quest target indicators: "..(A.db.questTargetIndicators and "on" or "off")..". Shown beside visible nameplates.")
end
local events=CreateFrame("Frame")
M.events=events
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","QUEST_LOG_UPDATE","UNIT_HEALTH"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,unit)
 if event=="NAME_PLATE_UNIT_REMOVED" then M.RemoveUnit(unit); return end
 if not A.db then return end
 if event=="NAME_PLATE_UNIT_ADDED" then M.AddUnit(unit)
 elseif event=="UNIT_HEALTH" then M.UpdateUnit(unit)
 elseif event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_LOGIN" then
  for _,plate in ipairs(A.Safe(C_NamePlate and C_NamePlate.GetNamePlates) or {}) do
   if plate.namePlateUnitToken then M.AddUnit(plate.namePlateUnitToken) end
  end
  M.Update()
 else M.Update() end
end)
