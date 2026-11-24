"""Acceptance returns only the matching unfinished preparation page to the list."""
import runpy
from pathlib import Path
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
for name in ('WalkthroughData.lua','Walkthrough.lua'):
 lua.execute((root/name).read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
lua.execute(r'''
completed={}; A.db.confirmed={}; A.log={}; log={}; level=60
C_QuestLog.GetNumQuestLogEntries=function() return #log end
local prophecy=A.byID[3527]
assert(prophecy)
A.log[3520]={complete=false}
assert(not A.RunReadiness(prophecy),"Screecher Spirits is outdoor preparation")
local icon,tip,grey=A.DungeonActionBadge(prophecy)
assert(icon==nil)
local _,instruction=A.DungeonInstruction(prophecy)
assert(instruction:find("Turn In: Screecher Spirits to Yeh'kinya",1,true))
local spirit=A.walkthroughs[3520]
local oldPin=spirit.turninPin
spirit.turninPin={zone="Tanaris",x=67,y=22.4}
assert(A.QuestTurnInSummary(spirit,true):find("Zone: Tanaris",1,true))
spirit.turninPin=oldPin
A.log[3520].complete=true
assert(not A.RunReadiness(prophecy),"Still must turn in spirits and accept Prophecy")
icon,tip,grey=A.DungeonActionBadge(prophecy)
assert(icon=="Interface\\GossipFrame\\ActiveQuestIcon","Finished prerequisite shows its turn-in icon")
_,instruction=A.DungeonInstruction(prophecy)
assert(instruction:find("Turn In: Screecher Spirits to Yeh'kinya",1,true) and not instruction:find("When finished",1,true))
A.log[3520]=nil; completed[3520]=true; A.log[3527]={complete=false}
assert(A.RunReadiness(prophecy),"Accepted Prophecy is dungeon-ready")
completed={}; A.log={}; log={}
A.SelectQuest(prophecy); A.SetDetailsCollapsed(true); A.ShowCompactQuestPage(true)
local f=A.window
assert(f.currentQuest.id==3520)
A.events.OnEvent(nil,"QUEST_ACCEPTED",1,3520)
assert(f.compactQuestPage,"Wait for the quest to appear in the log")
log={{questID=3520,title="Screecher Spirits",complete=false}}
A.Scan()
assert(not f.compactQuestPage and f:IsShown(),"Return to list, keep journal open")
-- An unrelated acceptance must leave the page alone.
A.ShowCompactQuestPage(true)
A.events.OnEvent(nil,"QUEST_ACCEPTED",999999)
assert(f.compactQuestPage)
-- A dungeon-ready acceptance stays on its page (single-argument event).
completed[3520]=true; log={}; A.Scan(); A.ShowCompactQuestPage(true)
assert(f.currentQuest.id==3527)
log={{questID=3527,title=prophecy.name,complete=false}}
A.events.OnEvent(nil,"QUEST_ACCEPTED",3527)
assert(f.compactQuestPage and f:IsShown())
-- The unprotected journal can update the page during combat.
completed={}; log={}; A.Scan(); A.ShowCompactQuestPage(true)
function InCombatLockdown() return true end
log={{questID=3520,title="Screecher Spirits",complete=false}}
A.events.OnEvent(nil,"QUEST_ACCEPTED",3520)
assert(not f.compactQuestPage and f:IsShown())
function InCombatLockdown() return false end
A.events.OnEvent(nil,"PLAYER_REGEN_ENABLED")
assert(not f.compactQuestPage and f:IsShown())
''')
print('PASS: Screecher Spirits readiness, matching acceptance, delayed log, unrelated pickups, dungeon-ready page and combat updates')
