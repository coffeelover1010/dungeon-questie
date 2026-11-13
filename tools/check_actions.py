"""Live-state simulations; not native secure execution or server verification."""
import runpy,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
for f in ('WalkthroughData.lua','Walkthrough.lua'):
    if f=='Walkthrough.lua':
        lua.execute('A.walkthroughs[990901]={id=990901,name="Later step",all={1275}}')
    lua.execute((root/f).read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
lua.execute(r'''
completed={}; log={}; A.log={}; A.db.confirmed={}; A.offers={}
faction="Alliance"; race="Human"; class="WARRIOR"; level=60
C_QuestLog.GetNumQuestLogEntries=function() return #log end
C_QuestLog.GetInfo=function(i) return log[i] end
C_QuestLog.IsQuestFlaggedCompleted=function(id) return completed[id] or false end
C_QuestLog.IsComplete=function(id) for _,q in ipairs(log) do if q.questID==id then return q.complete end end return false end
local function state(entries) log=entries; A.Scan() end
local q=A.byID[1200]; assert(q and q.name=="Blackfathom Villainy")
state({{questID=1198,title="In Search of Thaelrid",complete=true}})
local n,p=A.WalkStep(q); assert(n.id==1198 and p=="ready")
assert(A.ActionReadiness(q)); assert(A.QuestRowStatus(q)=="Preparation needed")
local minimum=A.walkthroughs[1200].minLevel; A.walkthroughs[1200].minLevel=99
assert(A.ActionReadiness(q),"Future level must not hide a ready prerequisite")
A.walkthroughs[1200].minLevel=minimum
local _,icon=A.QuestRowStatus(q); assert(icon==nil,"An unaccepted goal must not display a tick for its prerequisite")
A.SelectQuest(q)
local b=A.window.targetButton
assert(b:GetAttribute("macrotext")=="/targetexact Argent Guard Thaelrid")
assert(b.OnClick==b.secureClick and b.OnClick~=nil,"Do not clear inherited secure click")
assert(A.window.detailText:GetText():find("Ready to turn in",1,true))
-- Standalone/final ready versus active objectives, with open-window updates.
state({{questID=1200,title=q.name,complete=true}})
assert(A.ActionReadiness(q)); assert(b:GetAttribute("macrotext")=="/targetexact Dawnwatcher Selgorm")
log[1].complete=false; A.events.OnEvent(nil,"QUEST_LOG_UPDATE")
assert(not A.ActionReadiness(q) and A.QuestRowStatus(q)=="Active")
assert(not b.enabled and b:GetAttribute("macrotext")==nil)
-- Completed predecessor does not prove the next quest is offered.
completed[1198]=true; state({})
n,p=A.WalkStep(q); assert(n.id==1200 and p=="inside")
assert(A.ActionReadiness(q))
A.offers[1200]=true; A.Refresh()
assert(A.ActionReadiness(q) and A.QuestRowStatus(q)=="Collect quest")
assert(b:GetAttribute("macrotext")=="/targetexact Argent Guard Thaelrid",tostring(b:GetAttribute("macrotext")))
-- Unknown, missing and non-creature targets must clear the previous macro.
A.offers[1275]=false; A.SelectQuest(A.byID[1275]); assert(not b.enabled and b:GetAttribute("macrotext")==nil)
assert(not A.QuestGiverMacro({id=999999,pickup="A chest - A place"},"pickup"))
assert(not A.QuestGiverMacro(q,"blocked"))
-- Multi-step route advances to the current accepted step and its finisher.
completed={}; A.db.confirmed={}; A.offers={}
local goal=A.byID[92753]
state({{questID=92744,title="Step",complete=true}})
n,p=A.WalkStep(goal); assert(n.id==92744 and p=="ready")
assert(A.ActionReadiness(goal))
completed[92744]=true; state({{questID=92750,title="Step",complete=false}})
n,p=A.WalkStep(goal); assert(n.id==92750 and p=="active" and not A.ActionReadiness(goal))
-- Every recorded breadcrumb link: collected/completed successors skip it,
-- but own acceptance/completion and a live contrary offer take precedence.
for id,node in pairs(A.walkthroughs) do
 if node.breadcrumbFor then
  completed={}; A.db.confirmed={}; A.offers={}; A.log={[node.breadcrumbFor]={complete=false}}; A.logAvailable=true
  local _,phase=A.WalkStep(node); assert(phase=="skipped",id)
  assert(A.Preparation(node)=="skipped" and not A.ActionReadiness(node))
  A.log={}; completed[node.breadcrumbFor]=true
  assert(select(2,A.WalkStep(node))=="skipped",id)
  A.log[id]={complete=false}; assert(select(2,A.WalkStep(node))=="packed",id)
  A.log={}; completed[id]=true; assert(select(2,A.WalkStep(node))=="done",id)
 end
end
completed={}; A.db.confirmed={}; A.offers={}
state({{questID=1275,title="Researching the Corruption",complete=false}})
local crumb=A.byID[3765]
A.SelectQuest(crumb); assert(A.QuestRowStatus(crumb)=="Skipped")
assert(not b.enabled and not A.window.pickupTarget and not A.db.confirmed[3765])
assert(not A.CountsForProgress(crumb))
A.offers[3765]=true; assert(select(2,A.WalkStep(crumb))=="pickup")
A.offers={}
state({{questID=990901,title="Later step",complete=false}})
assert(select(2,A.WalkStep(crumb))=="skipped")
-- Authoritative offers, local negative evidence, expiry, API absence.
function UnitName(unit) return unit=="npc" and "Argos Nightwhisper" end
C_GossipInfo={GetAvailableQuests=function() return {} end}
state({}); A.events.OnEvent(nil,"GOSSIP_SHOW")
assert(A.Availability(3765)==false and select(2,A.WalkStep(crumb))=="unavailable")
C_GossipInfo.GetAvailableQuests=function() return {{questID=3765}} end
A.events.OnEvent(nil,"GOSSIP_SHOW")
assert(A.Availability(3765)==true and select(2,A.WalkStep(crumb))=="pickup")
A.SelectQuest(crumb); assert(b:GetAttribute("macrotext")=="/targetexact Argos Nightwhisper")
A.events.OnEvent(nil,"GOSSIP_CLOSED")
assert(A.Availability(3765)==nil and select(2,A.WalkStep(crumb))=="pickup")
assert(b.enabled and b:GetAttribute("macrotext")=="/targetexact Argos Nightwhisper")
C_GossipInfo=nil; A.ReadOffers(); assert(A.Availability(3765)==nil)
-- Summary numerators exactly match dungeon readiness badges.
state({{questID=1198,title="In Search of Thaelrid",complete=true},{questID=1275,title="Researching the Corruption",complete=false}})
local count=0
for _,quest in ipairs(A.quests) do
 if A.InDungeon(quest,"Blackfathom Deeps") and A.ChecklistVisible(quest) and not A.Restriction(quest) and A.RunReadiness(quest) then count=count+1 end
end
assert(A.PreparationSummary("Blackfathom Deeps").ready==count and count>0)
-- Inside pickup planning does not invent a live offer or bypass requirements.
completed={}; A.db.confirmed={}; A.offers={}; state({})
local fallen=A.byID[95795]
assert(not A.RunReadiness(fallen))
state({{questID=95772,title="Songblade Search",complete=false}})
assert(A.RunReadiness(fallen),"Accepted dungeon precursor is ready for the run")
log[1].complete=true; A.Scan(); assert(A.RunReadiness(fallen))
completed[95772]=true; state({}); assert(A.RunReadiness(fallen),"Follow-up is collected inside")
assert(A.ActionReadiness(fallen) and A.offers[fallen.id]==nil,"Guide pickup does not fabricate live evidence")
completed[95795]=true; assert(not A.RunReadiness(fallen))
local reference={id=990991,evidence="Classic reference",unverifiedChain=true,restrictionUnknown=true,pickup="Pickup unverified"}
assert(not A.DataWarning(reference),"Source warning icons stay hidden")
A.log[reference.id]={complete=false}; assert(not A.DataWarning(reference))
reference.turnin="Exact hand-in unverified"
assert(not A.DataWarning(reference),"Unverified directions do not restore removed warning icons")
completed[reference.id]=true; assert(not A.DataWarning(reference))
A.log[reference.id]=nil; completed[reference.id]=nil; reference.turnin=nil
A.offers[reference.id]=true; assert(not A.DataWarning(reference)); A.offers[reference.id]=nil
completed={}; A.db.confirmed={}; A.offers={}; state({})
local relic=A.byID[95810]
assert(A.RunReadiness(relic))
assert(A.ActionReadiness(relic) and select(2,A.WalkStep(relic))=="inside")
assert(select(1,A.DungeonReadinessBadge(relic))==nil,"Inside pickup has no acceptance tick")
level=1; assert(not A.RunReadiness(relic)); level=60
A.offers[95810]=false; assert(not A.RunReadiness(relic)); A.offers={}
local node=A.walkthroughs[95810]
node.requirementsNote="Needs a key"; assert(not A.RunReadiness(relic)); node.requirementsNote=nil
state({{questID=95772,title="Songblade Search",complete=true}})
assert(A.RunReadiness(A.byID[95772]))
state({{questID=1198,title="In Search of Thaelrid",complete=true}})
assert(A.RunReadiness(q),"Inside prerequisite hand-in is ready for the run")
state({{questID=1275,title="Researching the Corruption",complete=false}})
assert(A.RunReadiness(A.byID[1275]))
state({{questID=1275,title="Researching the Corruption",complete=true}})
assert(not A.RunReadiness(A.byID[1275]),"Outside hand-in does not need a dungeon run")
completed[1275]=true; state({})
assert(not A.RunReadiness(A.byID[1275]))
assert(select(1,A.DungeonReadinessBadge(A.byID[1275])):find("UI-CheckBox-Check",1,true))
-- Combat guard: model the registered secure state transition, then assert
-- no insecure attribute/layout mutation; reopening rescans the latest state.
A.SelectQuest(q)
local original=b:GetAttribute("macrotext")
local attributes=b.SetAttribute
b.SetAttribute=function(self,k,v) assert(not InCombatLockdown(),"protected mutation in combat"); attributes(self,k,v) end
function InCombatLockdown() return true end
local f=A.window
assert(f.stateDriver=="[combat] combat; peace")
local secure=assert(loadstring(f:GetAttribute("_onstate-combat")))
setfenv(secure,{self=f,newstate="combat"}); secure(); assert(not f:IsShown())
state({}); A.SelectQuest(crumb); A.Toggle(); A.Refresh()
assert(not f:IsShown() and b:GetAttribute("macrotext")==original)
function InCombatLockdown() return false end
A.events.OnEvent(nil,"PLAYER_REGEN_ENABLED"); A.Toggle()
assert(f:IsShown() and b.enabled and b:GetAttribute("macrotext")=="/targetexact Dawnwatcher Shaedlass", "Reopened guide targets the current uncollected prerequisite")
''')
source=json.loads((root/'data/classic-source.json').read_text())
nodes=json.loads((root/'data/walkthroughs.json').read_text())
links=0
for row in source['quest_template']:
    if str(row['entry']) in nodes and row['BreadcrumbForQuestId']:
        assert nodes[str(row['entry'])]['breadcrumbFor']==row['BreadcrumbForQuestId']
        links+=1
assert nodes['3765']['breadcrumbFor']==1275 and nodes['463']['breadcrumbFor']==276
print(f'PASS: actionable readiness, standalone/prerequisite/multistep states, {links} breadcrumb links, offers/absence/expiry, counts, secure click preservation, target switching and combat guards (mocked).')
