local _, A = ...
-- Follow only prerequisite edges; a later turn-in is not a prerequisite.
local related = {}
local function include(id)
 if type(id) ~= "number" or related[id] then return end
 related[id] = true
 local q = (A.walkthroughs and A.walkthroughs[id]) or A.byID[id]
 if not q then return end
 for _, previous in ipairs(q.prereqs or {}) do include(previous) end
 for _, previous in ipairs(q.all or {}) do include(previous) end
 for _, previous in ipairs(q.any or {}) do include(previous) end
 for _, link in ipairs(q.chain or {}) do
  if link.role == "Comes after" then include(link.id) end
 end
end
for _, q in ipairs(A.quests) do include(q.id) end
A.dungeonLogQuests = related

local function colour(button)
 if button and related[button.questID] and button.Text then
  button.Text:SetTextColor(0.25, 0.85, 1)
 end
end
local function refresh()
 local pool = QuestScrollFrame and QuestScrollFrame.titleFramePool
 if pool and pool.EnumerateActive then
  for button in pool:EnumerateActive() do colour(button) end
 end
 if type(GetQuestLogTitle) == "function" and QuestLogListScrollFrame then
  local offset = FauxScrollFrame_GetOffset and FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0
  for i = 1, QUESTS_DISPLAYED or 0 do
   local _, _, _, header, _, _, _, id = GetQuestLogTitle(i + offset)
   local button = _G["QuestLogTitle"..i]
   if button and not header and related[id] then
    local font = button:GetFontString()
    if font then font:SetTextColor(0.25, 0.85, 1) end
   end
  end
 end
end
local hooked = {}
local function install()
 if type(hooksecurefunc) ~= "function" then return end
 for _, name in ipairs({"QuestLogQuests_Update", "QuestLog_Update"}) do
  if type(_G[name]) == "function" and not hooked[name] then
   hooksecurefunc(name, refresh); hooked[name] = true
  end
 end
 for _, name in ipairs({"QuestMapLogTitleButton_OnEnter", "QuestMapLogTitleButton_OnLeave"}) do
  if type(_G[name]) == "function" and not hooked[name] then
   hooksecurefunc(name, colour); hooked[name] = true
  end
 end
 refresh()
end
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", install)
