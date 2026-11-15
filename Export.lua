local _, A = ...
local function plain(value)
 return tostring(value or "unknown"):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
end
function A.BuildProgressExport(selected)
 local _,class=UnitClass("player")
 local _,race=UnitRace("player")
 local lines={"Dungeon Questie - quest progress", "Dungeon: "..plain(A.db.dungeon),
  "Character: level "..UnitLevel("player").." "..plain(race).." "..plain(class).." ("..plain(UnitFactionGroup("player"))..")",
  "Quest log available: "..tostring(A.logAvailable==true),
  "Selected quest: "..(selected and (plain(selected.name).." ["..selected.id.."]") or "none"),
  "Pickup instructions are guide data; they do not confirm an NPC offers a quest.",
  "Offer observations apply only to the most recently checked NPC.", "", "Dungeon quests:"}
 local roots={}
 for _,q in ipairs(A.quests) do
  if A.InDungeon(q,A.db.dungeon) and not A.Restriction(q) then roots[#roots+1]=q end
 end
 table.sort(roots,function(a,b) return a.id<b.id end)
 local records={}
 local function collect(id)
  if records[id] then return end
  local n=(A.walkthroughs or {})[id] or A.byID[id] or {id=id,name="Quest "..id}
  records[id]=n
  for _,field in ipairs({"all","any","prereqs"}) do for _,prior in ipairs(n[field] or {}) do collect(prior) end end
 end
 for _,q in ipairs(roots) do
  local step,phase,reason=A.WalkStep(q)
  lines[#lines+1]=plain(q.name).." ["..q.id.."]"
  lines[#lines+1]="  Next: "..(step and (plain(step.name).." ["..step.id.."] / "..plain(phase)) or "no remaining step")
  if reason then lines[#lines+1]="  Reason: "..plain(reason) end
  collect(q.id)
  if step then collect(step.id) end
 end
 if selected then collect(selected.id) end
 lines[#lines+1]=""; lines[#lines+1]="Quest and prerequisite records (shared steps listed once):"
 local ids={}; for id in pairs(records) do ids[#ids+1]=id end; table.sort(ids)
 for _,id in ipairs(ids) do
  local n=records[id]; local completed=A.Completed(id); local log=A.log[id]; local offer=A.Availability(id)
  lines[#lines+1]=""; lines[#lines+1]=plain(n.name).." ["..id.."]"
  lines[#lines+1]="  Turned in: "..(completed==nil and "unknown" or tostring(completed)).."; log: "..(log and (log.complete and "objectives finished" or "active") or "absent").."; observed offer: "..(offer==nil and "unknown" or tostring(offer))
  for _,field in ipairs({"minLevel","pickup","turnin","requirementsNote","unverifiedChain","source"}) do
   if n[field]~=nil then lines[#lines+1]="  "..field..": "..plain(n[field]) end
  end
  for _,field in ipairs({"all","any","prereqs"}) do
   if n[field] and #n[field]>0 then lines[#lines+1]="  "..field..": "..table.concat(n[field],", ") end
  end
  local restriction=A.WalkRestriction(n)
  if restriction then lines[#lines+1]="  Restriction: "..plain(restriction) end
  local objectives=log and A.Safe(C_QuestLog and C_QuestLog.GetQuestObjectives,id)
  for _,o in ipairs(type(objectives)=="table" and objectives or {}) do
   lines[#lines+1]="  Objective: "..plain(o.text).." (finished: "..tostring(o.finished==true)..")"
  end
 end
 return table.concat(lines,"\n")
end
function A.ShowProgressExport(selected)
 if InCombatLockdown() then return end
 local f=A.exportWindow
 if not f then
  f=CreateFrame("Frame","DungeonGuideForeverExport",UIParent,"BackdropTemplate")
  A.exportWindow=f; f:SetSize(700,480); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:EnableMouse(true); f:SetClampedToScreen(true)
  f:SetScale(A.window and A.window:GetScale() or 1)
  f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
  local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOPLEFT",22,-20); title:SetText("Share quest progress")
  local hint=f:CreateFontString(nil,"OVERLAY","GameFontHighlight"); hint:SetPoint("TOPLEFT",22,-48); hint:SetText("Ctrl+A, Ctrl+C to copy, then paste into your message. Escape closes.")
  local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-4,-4)
  local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",24,-78); scroll:SetPoint("BOTTOMRIGHT",-44,24)
  local edit=CreateFrame("EditBox",nil,scroll); edit:SetMultiLine(true); edit:SetFontObject(ChatFontNormal); edit:SetWidth(620); edit:SetHeight(360); edit:SetAutoFocus(false); edit:SetMaxLetters(0)
  scroll:SetScrollChild(edit); f.edit=edit; f.scroll=scroll
  edit:SetScript("OnEscapePressed",function() f:Hide() end)
  f:SetScript("OnHide",function() edit:ClearFocus() end)
  tinsert(UISpecialFrames,"DungeonGuideForeverExport")
 end
 f:Show(); f.edit:SetText(A.BuildProgressExport(selected)); f.edit:SetFocus(); f.edit:HighlightText(); f.scroll:SetVerticalScroll(0)
end
