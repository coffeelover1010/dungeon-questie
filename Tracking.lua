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
-- Offers are session-local evidence, never inferred from level or an empty log.
A.offers={}
function A.Availability(id)
 if A.offers[id]~=nil then return A.offers[id] end
 return nil
end
function A.ReadOffers()
 A.offers={}
 local available=A.Safe(C_GossipInfo and C_GossipInfo.GetAvailableQuests)
 if type(available)=="table" then
  local npc=A.Safe(UnitName,"npc")
  if npc then
   for id,n in pairs(A.walkthroughs or {}) do
    for _,name in ipairs(n.pickupNPCs or {}) do if name==npc then A.offers[id]=false end end
   end
  end
  for _,offer in ipairs(available) do
   if type(offer.questID)=="number" then
    A.offers[offer.questID]=true
   end
  end
 end
end
function A.Restriction(q)
 local _, class = UnitClass("player")
 local _, race = UnitRace("player")
 if q.faction and q.faction ~= UnitFactionGroup("player") then return q.faction.." only" end
 if q.class and q.class ~= class then return q.class.." only" end
 if q.excludeRace == race then return "Unavailable to this race" end
 if q.restrictionUnknown and not A.log[q.id] and A.Completed(q.id)~=true then return "Character eligibility unavailable" end
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
 -- Suppress an unused variant only when live progress identifies its counterpart.
 -- Never infer completion, or hide a quest that is itself accepted/completed.
 if not A.log[q.id] and A.Completed(q.id)~=true then
  for _,other in ipairs(q.checklistAlternatives or {}) do
   if A.log[other] or A.Completed(other)==true then return false end
  end
 end
 if q.checklistPrevious and not A.log[q.id] and A.Completed(q.id)~=true and A.Completed(q.checklistPrevious)~=true then return false end
 for _,nextQuest in ipairs(A.quests) do
  if nextQuest.checklistPrevious==q.id and (A.Completed(q.id)==true or A.log[nextQuest.id] or A.Completed(nextQuest.id)==true) then return false end
 end
 return true
end
-- Preparation is separate from quest completion: having a quest is enough.
local function handInInside(q)
 local n=(A.walkthroughs or {})[q.id] or q
 -- Existing curated inside destinations: Thaelrid and Daewyn Songblade.
 return q.turninInside or n.turninInside or q.id==1198 or q.id==95772
end
function A.RunReadiness(q)
 if A.Completed(q.id)==true then return false,"Already completed." end
 local location=(A.walkthroughs or {})[q.id] or q
 if A.log[q.id] then
  if A.log[q.id].complete then
   if handInInside(q) then return true,"Turn in inside: "..(q.name or "Quest") end
   return false,"Objectives complete — turn in outside the dungeon or check the hand-in location."
  end
  if location.dungeonObjective==false then return false,"The remaining task is outside the dungeon; follow your quest log." end
  return true,"Collected — follow your quest log."
 end
 if A.Restriction(q) or (q.minLevel and UnitLevel("player")<q.minLevel) then return false end
 if A.WalkStep then
  local n,phase,note=A.WalkStep(q)
  if phase=="inside" then return true,"Pick up inside: "..n.name end
  -- Planning an inside pickup does not assert that the NPC has offered it.
  -- The resolver has already checked level, prerequisites and known restrictions.
  if phase=="check" and note=="Not yet confirmed available for this character." and
     (n.pickupInside or (n.id==q.id and q.pickupInside)) then
   return true,"Pick up inside: "..n.name..". "..(n.pickup or q.pickup or "").." Availability still needs confirming inside."
  end
  if phase=="ready" and handInInside(n) then
   return true,"Turn in inside: "..n.name
  end
  local record=A.byID[n.id]
  local tag=A.Safe(C_QuestLog and C_QuestLog.GetQuestTagInfo,n.id)
  local dungeonObjective=n.dungeonObjective
  if dungeonObjective==nil then dungeonObjective=((A.walkthroughs or {})[n.id] or {}).dungeonObjective end
  if dungeonObjective==nil then dungeonObjective=tag and tag.tagID==81 end
  if phase=="active" and record and dungeonObjective then
   for _,d in ipairs(q.dungeons) do
    if A.InDungeon(record,d) then return true,"Continue inside: "..n.name end
   end
  end
 elseif q.pickupInside then return true,"Pick up inside the dungeon." end
 return false
end
function A.ActionReadiness(q)
 if not A.WalkStep then return false end
 local n,phase=A.WalkStep(q)
 return phase=="ready" or phase=="pickup" or phase=="inside",n,phase
end
function A.Preparation(q)
 if A.WalkStep then
  local n,phase=A.WalkStep(q)
  if phase=="skipped" then return "skipped","SKIPPED BREADCRUMB",8 end
  if phase=="unavailable" then return "blocked","UNAVAILABLE",7 end
  if phase=="active" then return "chain","IN YOUR LOG: "..n.name,2 end
  if phase=="pickup" and n.id~=q.id then return "chain","PICK UP FIRST: "..n.name,2 end
  if phase=="ready" then return "turnin","TURN IN FIRST: "..n.name,1 end
  if phase=="check" then return "check","AVAILABILITY UNKNOWN",3 end
 end
 if A.Completed(q.id)==true then return "done", "ALREADY COMPLETED", 6 end
 if A.log[q.id] then return "packed", "IN YOUR LOG", 4 end
 if A.RunReadiness(q) then return "inside", "READY FOR DUNGEON", 5 end
 if A.Restriction(q) or (q.minLevel and UnitLevel("player")<q.minLevel) then return "blocked", "NOT ELIGIBLE NOW", 7 end
 if A.WalkStep then
  local n,phase=A.WalkStep(q)
  if phase=="blocked" then return "blocked","NOT ELIGIBLE NOW",7 end
  if phase=="check" then return "check","QUEST DETAILS",3 end
  if phase=="inside" then return "inside","PICK UP INSIDE",5 end
  if n.id~=q.id then
   local label=phase=="pickup" and "PICK UP FIRST: " or (phase=="ready" and "TURN IN FIRST: " or "IN YOUR LOG: ")
   return "chain",label..n.name,2
  end
  if phase=="pickup" then return "pickup","COLLECT BEFORE ENTERING",1 end
 end
 if q.pickupInside then return "inside", "PICK UP INSIDE", 5 end
 if not A.logAvailable or A.Completed(q.id)==nil then return "check", "STATUS UNAVAILABLE", 3 end
 if q.preparationNote then return "chain", "EARLIER QUEST", 2 end
 for _,id in ipairs(q.prereqs or {}) do
  if A.Completed(id)~=true then return "chain", "EARLIER QUEST", 2 end
 end
 if not q.pickup or q.pickup=="" then return "check", "PICKUP LOCATION UNKNOWN", 3 end
 return "pickup", "COLLECT BEFORE ENTERING", 1
end
function A.PreparationSummary(dungeon)
 local counts={pickup=0,chain=0,check=0,packed=0,inside=0,done=0,blocked=0,total=0,collected=0,turnin=0,skipped=0,ready=0}
 for _,q in ipairs(A.quests) do
  if A.InDungeon(q,dungeon) and A.ChecklistVisible(q) and not A.Restriction(q) then
   local stage=A.Preparation(q); counts[stage]=counts[stage]+1
   counts.total=counts.total+1
   if A.RunReadiness(q) then counts.ready=counts.ready+1 end
   if A.RunReadiness(q) then counts.collected=counts.collected+1 end
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
 -- Collapsed quest-log headers can omit accepted quests from the entry scan.
 -- Query known IDs directly so live acceptance always wins over guide chains.
 local api=C_QuestLog or {}
 local function include(id,title)
  if A.log[id] then return end
  local index=A.Safe(api.GetLogIndexForQuestID,id)
  if A.Safe(api.IsOnQuest,id)==true or (type(index)=="number" and index>0) then
   A.log[id]={title=title,complete=A.Safe(api.IsComplete,id)==true,index=index}
  end
 end
 for _,q in ipairs(A.quests) do include(q.id,q.name) end
 for id,q in pairs(A.walkthroughs or {}) do include(id,q.name) end
end
function A.Scan()
 if not A.db then return end
 if A.LoadLocations then A.LoadLocations() end
 A.ReadLog()
 local targetInvalid=false
 if A.target and A.WalkStep then
  local q=A.byID[A.target] or (A.walkthroughs or {})[A.target]
  if q then local step,phase=A.WalkStep(q); targetInvalid=step.id~=q.id or (phase~="pickup" and phase~="inside") end
 end
 if A.target and (targetInvalid or (A.byID[A.target] and not A.NeedsPickup(A.byID[A.target]))) then
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
 if A.WalkStep and select(2,A.WalkStep(q))=="skipped" then return false end
 if A.Restriction(q) or q.repeatable then return false end
 if A.Completed(q.id)==true or A.log[q.id] then return true end
 if q.minLevel and UnitLevel("player")<q.minLevel then return false end
 return true
end
function A.Count(dungeon)
 local done,total,active=0,0,0
 for _,q in ipairs(A.quests) do
  if A.InDungeon(q,dungeon) and A.CountsForProgress(q) then
   total=total+1
   local s=A.state[q.id]
   if s=="done" then done=done+1 elseif s=="active" or s=="ready" then active=active+1 end
  end
 end
 return done,total,active
end
function A.Matches(q)
 local db=A.db
 if not A.InDungeon(q,db.dungeon) then return false end
 if not A.ChecklistVisible(q) then return false end
 if A.Restriction(q) then return false end
 if db.search and db.search~="" then
  local hay=(q.name.." "..table.concat(q.dungeons," ").." "..(q.pickup or "").." "..q.id):lower()
  if not hay:find(db.search:lower(),1,true) then return false end
 end
 return true
end
function A.EmptyQuestMessage()
 local recorded,eligible,unknown=0,0,0
 for _,q in ipairs(A.quests) do
  if A.InDungeon(q,A.db.dungeon) then
   recorded=recorded+1
   if A.ChecklistVisible(q) then
    local reason=A.Restriction(q)
    if not reason then eligible=eligible+1
    elseif reason=="Character eligibility unavailable" then unknown=unknown+1 end
   end
  end
 end
 if recorded==0 then
  return "No quest data for this dungeon yet."
 end
 if eligible>0 and A.db.search and A.db.search~="" then
  return "No quests match your search.\n\nTry another search."
 end
 if unknown>0 then
  return "Character requirements unavailable.\n\nFaction or class details are missing."
 end
 return "No quests for your faction or class."
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
  A.db.betaOnly=nil -- Retired filter has no UI; retain labelled Classic references.
  if A.db.pins==nil then A.db.pins=true end
  local validDungeon=false
  for _,d in ipairs(A.dungeons) do if d.name==A.db.dungeon then validDungeon=true; break end end
  if not validDungeon then A.db.dungeon=A.dungeons[1].name end
  A.db.filter=nil
  for _,e in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","QUEST_LOG_UPDATE","QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN","PLAYER_LEVEL_UP","GET_ITEM_INFO_RECEIVED","PLAYER_REGEN_ENABLED","GOSSIP_SHOW","GOSSIP_CLOSED","QUEST_DETAIL","QUEST_FINISHED"}) do events:RegisterEvent(e) end
  return
 end
 if not A.db then return end
 if event=="GOSSIP_SHOW" then A.ReadOffers()
 elseif event=="QUEST_DETAIL" then
  local id=A.Safe(GetQuestID); if type(id)=="number" and id>0 then A.offers[id]=true end
 elseif event=="GOSSIP_CLOSED" or event=="QUEST_FINISHED" or event=="QUEST_ACCEPTED" or event=="QUEST_REMOVED" or event=="QUEST_TURNED_IN" or event=="PLAYER_ENTERING_WORLD" then A.offers={} end
 if event=="QUEST_TURNED_IN" and type(arg)=="number" then A.db.confirmed[arg]=true end
 queue()
end)
SLASH_DUNGEONGUIDEFOREVER1="/dungeons"
SLASH_DUNGEONGUIDEFOREVER2="/dgf"
SlashCmdList.DUNGEONGUIDEFOREVER=function(msg)
 if not A.db then return end
 msg=(msg or ""):lower()
 if msg=="resetpos" then
  if InCombatLockdown() then A.Print("Move the window after combat."); return end
  A.db.position=nil; if A.window then A.window:ClearAllPoints(); A.window:SetPoint("CENTER") end
 elseif msg:find("^minimap") then
  local shown=msg:find("show") or (not msg:find("hide") and A.db.minimap.hide)
  A.SetMinimapShown(shown and true or false)
 elseif msg=="pins" then A.db.pins=not A.db.pins; A.RefreshPins(); A.Print("Map pins "..(A.db.pins and "on" or "off"))
 elseif msg=="clear" then A.ClearWaypoint()
 else A.Toggle() end
end
