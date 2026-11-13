"""Current-step routing audit using the installed Forever provider snapshot."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
setup=(root/'tools/check_locations.py').read_text().split("report={'providerVersion'")[0]
exec(compile(setup,str(root/'tools/check_locations.py'),'exec'))
lua.execute(r'''
class="MAGE"; faction="Alliance"; level=60
local goal=A.byID[1951]
assert(goal and goal.name=="Rituals of Power")
A.log={[1950]={complete=false}}
local step,phase=A.WalkStep(goal)
assert(step.id==1950 and phase=="active")
local target=A.MapLocation(goal)
assert(target.id==1950 and target.pin.map==1441 and target.pin.kind=="objective")
assert(A.RouteInstruction(goal):find("/beckon",1,true))
assert(not A.RunReadiness(goal))
log={{questID=1950,title="Get the Scoop",complete=false}}
A.SelectQuest(goal)
assert(A.window.mapTarget.pin.map==1441)
assert(A.window.detailText:GetText():find("/beckon",1,true))
A.locationTarget=target
A.log[1950].complete=true
local handin=A.MapLocation(goal)
assert(handin.id==1950 and handin.pin.map==1441 and handin.pin.kind=="hand-in")
assert(A.RouteInstruction(goal):find("Magus Tirth",1,true))
A.RefreshPins(); assert(A.locationTarget.pin.kind=="hand-in")
completed[1950]=true; A.log={}
local pickup=A.MapLocation(goal)
assert(pickup.id==1951 and pickup.pin.map==1441 and pickup.pin.kind~="entrance")
assert(not A.RunReadiness(goal))
A.log[1951]={complete=false}
assert(A.RunReadiness(goal))
local inside=A.MapLocation(goal)
assert(inside and inside.pin.kind=="entrance")
-- Missing objective/pickup/hand-in locations must never inherit a dungeon.
local originalWalk,originalReady=A.WalkStep,A.RunReadiness
local originalDoor=A.DungeonEntrance
local doors=0
A.DungeonEntrance=function(...) doors=doors+1; return originalDoor(...) end
local audited=0
for _,node in pairs(A.walkthroughs) do
 for _,state in ipairs({"active","pickup","ready","check","blocked"}) do
  local current={id=-node.id,name=node.name}
  A.WalkStep=function() return current,state end
  A.RunReadiness=function() return false end
  assert(A.MapLocation(goal)==nil,node.id.." "..state.." guessed destination")
  audited=audited+1
 end
end
assert(doors==0,"Unready steps must never fall back to a dungeon entrance")
-- Actual outdoor preparation records retain only their own phase coordinates.
for id,node in pairs(A.walkthroughs) do
 if not A.byID[id] then
  A.WalkStep=function() return node,"active" end
  A.RunReadiness=function() return false end
  local route=A.MapLocation(goal)
  local expected=node.breadcrumbFor and node.turninPin or node.objectivePin
  if expected then assert(route and route.id==id and route.pin==expected,id)
  else assert(not route,id.." active preparation borrowed another location") end
  A.WalkStep=function() return node,"ready" end
  route=A.MapLocation(goal)
  if node.turninPin then assert(route and route.pin==node.turninPin,id)
  else assert(not route,id.." hand-in borrowed another location") end
 end
end

A.WalkStep=originalWalk; A.RunReadiness=originalReady; A.DungeonEntrance=originalDoor
print("PASS: Get the Scoop objective/hand-in/acceptance transitions, detail/map agreement, stale marker refresh and "..audited.." missing-location routing cases")
''')

# Audit every actual preparation node's active objective independently of its
# associated dungeon. Record missing routes instead of inventing coordinates.
report=[]
for ident,node in lua.globals().A.walkthroughs.items():
 if lua.globals().A.byID[ident] is not None:
  continue
 p=node['objectivePin']
 report.append({'id':ident,'name':node['name'],'objectiveLocation':p['title'] if p else None,
                'map':p['map'] if p else None,'breadcrumb':bool(node['breadcrumbFor']),
                'handInMapped':bool(node['turninPin'])})
import json
out=root/'data/preparation-routing-audit-2026-11-13.json'
out.write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print('Preparation node audit:',len(report),'nodes;',sum(bool(n['objectiveLocation']) for n in report),'objective locations;',sum(not n['objectiveLocation'] and not n['breadcrumb'] for n in report),'without an exact active-objective route')
