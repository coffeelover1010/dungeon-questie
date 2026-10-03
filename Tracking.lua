local name, A = ...
A.byID = {}; A.state = {}; A.log = {}
for _, q in ipairs(A.quests) do A.byID[q.id] = q end
function A.Safe(fn, ...)
 if type(fn) ~= "function" then return nil end
 local ok, value = pcall(fn, ...)
 if ok then return value end
end
function A.Print(s) print("|cffdfbd76Dungeon Questie:|r "..s) end
function A.Completed(id)
 if A.db and A.db.confirmed[id] then return true end
 return A.Safe(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted,id)
end
function A.Restriction(q)
 local _, class = UnitClass("player")
 local _, race = UnitRace("player")
 if q.faction and q.faction ~= UnitFactionGroup("player") then return q.faction.." only" end
 if q.class and q.class ~= class then return q.class.." only" end
 if q.excludeRace == race then return "Unavailable to this race" end
 if q.restrictionUnknown and not A.log[q.id] and A.Completed(q.id)~=true then return "Eligibility unverified for this character" end
end
function A.InDungeon(q, dungeon)
 if not dungeon then return true end
 for _, d in ipairs(q.dungeons) do if d == dungeon then return true end end
 return false
end
function A.Status(q)
 if A.Completed(q.id) == true then return "done" end
 if A.log[q.id] then return A.log[q.id].complete and "ready" or "active" end
 if A.Restriction(q) then return "restricted" end
 if q.minLevel and UnitLevel("player") < q.minLevel then return "level" end
 if not A.logAvailable or A.Completed(q.id) == nil then return "unknown" end
 return "todo"
end
function A.NeedsPickup(q)
 return not A.log[q.id] and A.Completed(q.id)~=true and A.state[q.id]~="done"
end
-- Same-name sequential stages share one checklist slot.
function A.ChecklistVisible(q)
 if q.checklistPrevious and not A.log[q.id] and A.Completed(q.id)~=true and A.Completed(q.checklistPrevious)~=true then return false end
 for _,nextQuest in ipairs(A.quests) do
  if nextQuest.checklistPrevious==q.id and (A.Completed(q.id)==true or A.log[nextQuest.id] or A.Completed(nextQuest.id)==true) then return false end
 end
 return true
end
-- Preparation is separate from quest completion: having a quest is enough.
function A.Preparation(q)
 if A.Completed(q.id)==true then return "done", "ALREADY COMPLETED", 6 end
 if A.log[q.id] then return "packed", "COLLECTED - IN YOUR LOG", 4 end
 if A.Restriction(q) or (q.minLevel and UnitLevel("player")<q.minLevel) then return "blocked", "NOT ELIGIBLE NOW", 7 end
 if A.WalkStep then
  local n,phase=A.WalkStep(q)
  if phase=="blocked" then return "blocked","NOT ELIGIBLE NOW",7 end
  if phase=="check" then return "check","WALKTHROUGH NEEDS CHECKING",3 end
  if phase=="inside" then return "inside","PICK UP INSIDE",5 end
  if n.id~=q.id then
   local label=phase=="pickup" and "PICK UP FIRST: " or (phase=="ready" and "TURN IN FIRST: " or "IN YOUR LOG: ")
   return "chain",label..n.name,2
  end
  if phase=="pickup" then return "pickup","COLLECT BEFORE ENTERING",1 end
 end
 if q.pickupInside then return "inside", "PICK UP INSIDE", 5 end
 if not A.logAvailable or A.Completed(q.id)==nil then return "check", "CHECK QUEST STATUS", 3 end
 if q.preparationNote then return "chain", "CHECK EARLIER QUEST FIRST", 2 end
 for _,id in ipairs(q.prereqs or {}) do
  if A.Completed(id)~=true then return "chain", "CHECK EARLIER QUEST FIRST", 2 end
 end
 if not q.pickup or q.pickup=="" then return "check", "PICKUP LOCATION UNKNOWN", 3 end
 return "pickup", "COLLECT BEFORE ENTERING", 1
end
function A.PreparationSummary(dungeon)
 local counts={pickup=0,chain=0,check=0,packed=0,inside=0,done=0,blocked=0,total=0,collected=0}
 for _,q in ipairs(A.quests) do
  if A.ChecklistVisible(q) and A.InDungeon(q,dungeon) and not A.Restriction(q) and (not A.db.betaOnly or q.evidence~="Classic reference") then
   local stage=A.Preparation(q); counts[stage]=counts[stage]+1
   counts.total=counts.total+1
   if stage=="packed" or stage=="done" then counts.collected=counts.collected+1 end
  end
 end
 return counts
end
function A.ReadLog()
 A.log = {}; A.logAvailable = false
 local n=A.Safe(C_QuestLog and C_QuestLog.GetNumQuestLogEntries or GetNumQuestLogEntries)
 if type(n) ~= "number" then return end
 local modern=C_QuestLog and C_QuestLog.GetInfo
 if not modern and type(GetQuestLogTitle)~="function" then return end
 A.logAvailable = true
 for i=1,n do
  local id, title, complete
  if modern then
   local info=A.Safe(modern,i)
   if info and not info.isHeader then
    id=info.questID; title=info.title
    complete=A.Safe(C_QuestLog.IsComplete,id)==true
   end
  else
   local t, _, _, header, _, c, _, qid=GetQuestLogTitle(i)
   if not header then id=qid; title=t; complete=c==1 end
  end
  if id and id>0 then A.log[id]={title=title,complete=complete,index=i} end
 end
end
function A.Scan()
 if not A.db then return end
 A.ReadLog()
 if A.target and A.byID[A.target] and not A.NeedsPickup(A.byID[A.target]) then
  if A.ClearWaypoint then A.ClearWaypoint() end
  A.target=nil
 end
 for _,q in ipairs(A.quests) do
  if A.Completed(q.id)==true then A.db.confirmed[q.id]=true end
  A.state[q.id]=A.Status(q)
 end
 if A.Refresh then A.Refresh() end
 if A.RefreshPins then A.RefreshPins() end
end
-- Progress counts quests available now, plus quests already accepted or completed.
function A.CountsForProgress(q)
 if not A.ChecklistVisible(q) then return false end
 if A.Restriction(q) or q.repeatable then return false end
 if A.Completed(q.id)==true or A.log[q.id] then return true end
 if q.minLevel and UnitLevel("player")<q.minLevel then return false end
 return true
end
function A.Count(dungeon)
 local done,total,active=0,0,0
 for _,q in ipairs(A.quests) do
  if A.CountsForProgress(q) and A.InDungeon(q,dungeon) then
   total=total+1
   local s=A.state[q.id]
   if s=="done" then done=done+1 elseif s=="active" or s=="ready" then active=active+1 end
  end
 end
 return done,total,active
end
function A.Matches(q)
 local db=A.db
 if not A.ChecklistVisible(q) then return false end
 if not A.InDungeon(q,db.dungeon) then return false end
 if A.Restriction(q) then return false end
 if db.betaOnly and q.evidence=="Classic reference" then return false end
 if db.search and db.search~="" then
  local hay=(q.name.." "..table.concat(q.dungeons," ").." "..(q.pickup or "").." "..q.id):lower()
  if not hay:find(db.search:lower(),1,true) then return false end
 end
 return true
end
local events=CreateFrame("Frame")
A.events=events
events:RegisterEvent("ADDON_LOADED")
local queued=false
local function queue()
 if queued then return end
 queued=true
 if C_Timer and C_Timer.After then C_Timer.After(0.15,function() queued=false; A.Scan() end)
 else queued=false; A.Scan() end
end
events:SetScript("OnEvent",function(_,event,arg)
 if event=="ADDON_LOADED" then
  if arg~=name then return end
  DungeonGuideForeverDB=DungeonGuideForeverDB or {}
  A.db=DungeonGuideForeverDB
  A.db.confirmed=A.db.confirmed or {}; A.db.manual=nil; A.db.minimap=A.db.minimap or {minimapPos=240}
  A.db.mine=nil -- Remove the retired character-filter choice.
  if A.db.pins==nil then A.db.pins=true end
  local validDungeon=false
  for _,d in ipairs(A.dungeons) do if d.name==A.db.dungeon then validDungeon=true; break end end
  if not validDungeon then A.db.dungeon=A.dungeons[1].name end
  A.db.filter=nil
  for _,e in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","QUEST_LOG_UPDATE","QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN","PLAYER_LEVEL_UP","GET_ITEM_INFO_RECEIVED"}) do events:RegisterEvent(e) end
  return
 end
 if not A.db then return end
 if event=="QUEST_TURNED_IN" and type(arg)=="number" then A.db.confirmed[arg]=true end
 queue()
end)
SLASH_DUNGEONGUIDEFOREVER1="/dungeons"
SLASH_DUNGEONGUIDEFOREVER2="/dgf"
SlashCmdList.DUNGEONGUIDEFOREVER=function(msg)
 if not A.db then return end
 msg=(msg or ""):lower()
 if msg=="resetpos" then
  A.db.position=nil; if A.window then A.window:ClearAllPoints(); A.window:SetPoint("CENTER") end
 elseif msg:find("^minimap") then
  local shown=msg:find("show") or (not msg:find("hide") and A.db.minimap.hide)
  A.SetMinimapShown(shown and true or false)
 elseif msg=="pins" then A.db.pins=not A.db.pins; A.RefreshPins(); A.Print("Map pins "..(A.db.pins and "on" or "off"))
 elseif msg=="clear" then A.ClearWaypoint()
 else A.Toggle() end
end
