"""Regression: dungeon preparation is distinct from completed dungeon work."""
import runpy
from pathlib import Path
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
for name in ('WalkthroughData.lua','Walkthrough.lua'):
 lua.execute((root/name).read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
lua.execute(r'''
completed={}; A.db.confirmed={}; A.log={}; A.offers={}; A.logAvailable=true
faction="Alliance"; race="Human"; class="MAGE"; level=60
C_QuestLog.IsQuestFlaggedCompleted=function(id) return completed[id] or false end
local q
for _,entry in ipairs(A.quests) do if entry.name=="Mythology of the Titans" then q=entry end end
assert(q)
A.log[q.id]={complete=false}
assert(A.DungeonInstruction(q)=="Ready for dungeon")
assert(A.DungeonActionBadge(q)==nil,"Unfinished objectives must not show turn-in")
assert(A.DungeonReadinessBadge(q)=="Interface\\RaidFrame\\ReadyCheck-Ready")
completed[q.id]=true
local completedIcon,completedTip=A.DungeonReadinessBadge(q)
assert(completedIcon==nil and completedTip=="Quest completed")
assert(A.DungeonActionBadge(q)==nil,"Already handed-in quest must not show turn-in")
completed[q.id]=nil
local letter
for _,entry in ipairs(A.quests) do if entry.name=="The Unsent Letter" then letter=entry end end
assert(letter and not A.log[letter.id])
assert(A.DungeonInstruction(letter)=="Ready for dungeon")
assert(A.DungeonReadinessBadge(letter)=="Interface\\RaidFrame\\ReadyCheck-Ready")
assert(A.DungeonActionBadge(letter)=="Interface\\GossipFrame\\AvailableQuestIcon","Inside pickup keeps ! alongside readiness")
A.log[q.id].complete=true
assert(A.DungeonWorkFinished(q))
assert(A.DungeonInstruction(q)=="Objectives finished")
assert(A.DungeonActionBadge(q)=="Interface\\GossipFrame\\ActiveQuestIcon","Completed objectives need yellow ?")
local _,tip=A.DungeonReadinessBadge(q)
assert(not tip:find("Not ready",1,true))
assert(A.DungeonSummary({total=2,done=0,skipped=0,finished=1,ready=1})=="Ready for dungeon")
assert(A.DungeonSummary({total=2,done=0,skipped=0,finished=1,ready=0})=="Preparation needed")
assert(A.DungeonSummary({total=1,done=0,skipped=0,finished=1,ready=0})=="Dungeon work finished")
local precursor={id=999999,name="Outdoor prerequisite",prerequisiteOnly=true}
A.log[precursor.id]={complete=false}
assert(not A.RunReadiness(precursor))
local originalWalk,originalReady=A.WalkStep,A.RunReadiness
A.log={}
A.WalkStep=function() return q,"ready" end
A.RunReadiness=function() return true,"Turn in inside" end
assert(A.DungeonReadinessBadge(q)=="Interface\\RaidFrame\\ReadyCheck-Ready")
assert(A.DungeonActionBadge(q)=="Interface\\GossipFrame\\ActiveQuestIcon")
A.RunReadiness=function() return false end
assert(A.DungeonReadinessBadge(q)==nil)
assert(A.DungeonActionBadge(q)=="Interface\\GossipFrame\\ActiveQuestIcon")
A.WalkStep=originalWalk; A.RunReadiness=originalReady
-- Past Due and every uncertain pickup must expose the recorded directions,
-- while keeping the unresolved prerequisite guard and readiness unchanged.
A.log={}; completed={}; A.db.confirmed={}; A.offers={}
local past=A.byID[96800]
assert(past)
local step,phase=A.WalkStep(past)
assert(phase=="check")
local heading,instruction=A.DungeonInstruction(past)
assert(instruction:find("Magus Olvek",1,true),instruction)
assert(instruction:find("Tempered Tomes",1,true),instruction)
assert(not instruction:lower():find("confirm",1,true),instruction)
assert(not A.RunReadiness(past))
A.SelectQuest(past)
assert(A.window.detailText:GetText():find("Magus Olvek",1,true))
local checked=0
for _,entry in ipairs(A.quests) do
 local node,state=A.WalkStep(entry)
 if state=="check" then
  local _,words=A.DungeonInstruction(entry)
  assert(not words:find("Check the quest details before entering.",1,true),entry.id)
  assert(not words:lower():find("confirm availability",1,true),entry.id)
  assert(not words:find("Guide pickup:",1,true),entry.id)
  assert(not words:find("Recorded level requirement met",1,true),entry.id)
  assert(not words:find("Recorded prerequisites completed",1,true),entry.id)
  local record=A.byID[node.id] or {}
  local prep=node.preparationNote or record.preparationNote
  if prep and prep~="" then assert(not words:find(prep,1,true),entry.id) end
  if node.pickup and not node.pickupUnknown then assert(words:find(node.pickup,1,true),entry.id) end
  checked=checked+1
 end
end
assert(checked>0)
print("PASS: Past Due directions and "..checked.." uncertain quest cards retain availability guards")
print("PASS: finished objectives, readiness summaries, explicit instructions and outdoor prerequisite badge")
''')
