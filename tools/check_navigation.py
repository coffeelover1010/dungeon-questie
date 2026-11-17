"""Navigation public-contract mocks; no live travel or rendering claims."""
from pathlib import Path
import runpy
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
for name in ('WalkthroughData.lua','Walkthrough.lua','Locations.lua','Navigation.lua','RoutePlanner.lua','NavigationWindow.lua'):
    lua.execute((root/name).read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
lua.execute(r'''
local N,R=A.Navigation,A.RoutePlanner
A.testEntityLocations=A.EntityLocations
local target={id=1,name="Quest",mapOnly=true,explicit=true,pin={map=1453,x=10,y=20,title="NPC",zone="Stormwind City",kind="pickup"}}
local d=N.Destination(target,"Test")
assert(d.x==0.1 and d.y==0.2 and d.questID==1 and d.kind=="pickup")
assert(not N.Destination({pin={map=1,x=0/0,y=20}}))
assert(not N.Destination({name="Unmapped"}))
local calls,fallback,clears=0,0,0
local originalMap=A.NavigateMap
A.NavigateMap=function(q) fallback=fallback+1; assert(q==target); return true end
ShortestPathForever={API={version=2,NavigateRoute=function(owner,stops)
 calls=calls+1; assert(owner==N.owner and #stops==1 and stops[1].x==0.1 and stops[1].hold); return true
end,Cancel=function(owner) assert(owner==N.owner); clears=clears+1; return true end}}
assert(N.Go(d,true) and calls==1 and fallback==0)
N.Stop(); assert(clears==1)
ShortestPathForever.API.version=3; assert(N.Go(d) and fallback==1)
ShortestPathForever.API.version=1; ShortestPathForever.API.NavigateRoute=function() error("mock failure") end
assert(not N.Go(d) and fallback==1)
ShortestPathForever.API.NavigateRoute=function() return false end
assert(not N.Go(d) and fallback==1)
ShortestPathForever=nil; assert(N.Go(d) and fallback==2)
A.NavigateMap=originalMap
TomTom={AddWaypoint=function(_,map,x,y) assert(map==1453 and x==0.1 and y==0.2); return {} end,RemoveWaypoint=function() end}
assert(N.Go(d)); assert(A.tomtom)
TomTom=nil; assert(N.Go(d)); assert(A.locationTarget)
N.Stop(); assert(not A.locationTarget)
-- Real resolver: a prerequisite objective, then hand-in, then root pickup.
A.LoadLocations=function() end; A.ChecklistVisible=function() return true end
A.db.confirmed={}; completed={}; A.log={}; A.offers={}; A.logAvailable=true
A.ProviderGate=function() end; A.providerError=nil
faction="Alliance"; class="MAGE"; level=60
local function quest(id,name,x)
 return {id=id,name=name,minLevel=1,dungeons={"Route test"},pin={map=1453,x=x,y=20,kind="pickup",title=name.." giver",zone="Stormwind City"}}
end
local first=quest(800001,"First",10); local second=quest(800002,"Second",80)
local prep=quest(800003,"Preparation",40)
prep.objectivePin={map=1434,x=30,y=40,kind="objective",title="Objective",zone="Stranglethorn Vale"}
prep.turninPin={map=1453,x=40,y=20,kind="hand-in",title="Turn in",zone="Stormwind City"}
local goal=quest(800004,"Goal",90); goal.all={prep.id}
A.quests={first,second,goal}; A.byID={}; for _,q in ipairs(A.quests) do A.byID[q.id]=q end
-- Walkthrough.lua closes over this existing table.
for id in pairs(A.walkthroughs) do A.walkthroughs[id]=nil end
for _,q in ipairs({first,second,prep,goal}) do A.walkthroughs[q.id]=q end
A.RebuildSuccessors()
A.DungeonEntrance=function() return {map=1436,x=42,y=72,title="Entrance",zone="Westfall",kind="entrance"} end
N.Position=function() return {map=1453,x=0,y=0} end
A.EntityLocations=function() return {} end
ShortestPathForever={API={version=2,Estimate=function(fm,fx,fy,tm,tx,ty)
 -- A transport makes the farther second pickup fastest.
 return tx==0.8 and 5 or 100
end,NavigateRoute=function(owner,stops) calls=calls+1; return true end,Cancel=function() return true end}}
local p=R.Build("Route test")
assert(p.stops[1].questID==second.id and p.stops[1].seconds==5)
for _,s in ipairs(p.stops) do assert(s.questID~=goal.id) end
assert(p.stops[#p.stops].kind=="dungeon" and p.stops[#p.stops].deferred)
A.log[prep.id]={complete=false}
p=R.Build("Route test"); local found=false
for _,s in ipairs(p.stops) do if s.questID==prep.id then assert(s.kind=="objective"); found=true end end
assert(found)
A.log[prep.id].complete=true
p=R.Build("Route test"); found=false
for _,s in ipairs(p.stops) do if s.questID==prep.id then assert(s.kind=="turnin"); found=true end end
assert(found)
A.log={}; completed[prep.id]=true
p=R.Build("Route test"); found=false
for _,s in ipairs(p.stops) do if s.questID==goal.id then found=true end end
assert(found)
completed[first.id]=true; goal.minLevel=70
p=R.Build("Route test"); assert(#p.blocked==1 and p.blocked[1]:find("70"))
for _,s in ipairs(p.stops) do assert(s.questID~=first.id and s.questID~=goal.id) end
p=R.Build("Route test",{[goal.id]=true}); assert(#p.blocked==0)
-- Shared location merges actions; exclusion retains the other quest.
completed[first.id]=nil; first.pin.x=80; goal.minLevel=1
p=R.Build("Route test",{[goal.id]=true}); assert(#p.stops==2 and #p.stops[1].roots==2)
A.collection=p; R.Start(); assert(A.collection.running)
R.Skip(); assert(#A.collection.blocked==2 and not A.collection.running)
R.Recalculate(true); assert(#A.collection.blocked==0)
-- No route is reported as an available stop when SPF proves unreachable.
ShortestPathForever.API.Estimate=function() return nil,"unreachable" end
p=R.Build("Route test"); assert(#p.blocked==4 and #p.stops==1)
-- Multiple NPC spawns choose a reachable estimate, exact browser choice stays exact.
target.pin.entity="Npc"; target.pin.entityID=42
A.EntityLocations=function() return {{map=1453,x=70,y=20,title="Other spawn",zone="Stormwind City",kind="pickup"}} end
ShortestPathForever.API.Estimate=function(_,_,_,_,x) if x==0.7 then return 7 end return nil,"unreachable" end
local best,seconds=N.Best(N.Position(),d); assert(best.x==0.7 and seconds==7)
-- Deferred jobs cancel without resurrecting navigation.
local pending={}; C_Timer.After=function(_,fn) pending[#pending+1]=fn end
A.quests={}; for i=1,12 do A.quests[i]=quest(810000+i,"Many "..i,i*5); A.walkthroughs[810000+i]=A.quests[i] end
A.collection={dungeon="Route test",excluded={},skipped={},quests=A.quests,stops={},blocked={}}
R.Recalculate(false); assert(R.busy and #pending>0); R.Cancel()
for _,fn in ipairs(pending) do fn() end
assert(not R.busy and not A.collection.running)
C_Timer.After=function(_,fn) fn() end
A.db.dungeon="Route test"; A.collection=nil
A.OpenNavigation(); A.OpenNavigation(nil,true); A.RefreshRouteWindow()
print("PASS: SPF v1/v2/future-version guards, API failure, TomTom/map fallbacks, travel-time order, prerequisite objective/turn-in progression, blockers, exclusions, merged skip, unreachable routes, spawn selection, async cancellation, preview construction")
''')


lua.execute(r"""
-- Actual public-provider enumeration: all spawns and all relation types.
A.EntityLocations=A.testEntityLocations
A.quests={}; A.walkthroughs={}; A.collection=nil; A.locationsLoaded=nil
local spawn={ [1]={{10,20},{30,40}}, [2]={{50,60}} }
LibQuestieDB={flavor={name="Forever"},RequireContract=function(v) return v==4 end,
 Support={Get=function() return {private={areaIdToUiMapId={[1]=1453,[2]=1434},dungeons={}}} end},
 Npc={Get=function(id,key) if key=="name" then return "Several spawns" elseif key=="spawns" then return spawn end end},
 Object={Get=function() end},Item={Get=function() end},
 Quest={Get=function(id,key)
  if key=="startedBy" or key=="finishedBy" then return {{42}} end
  if key=="objectives" then return {{{42}}} end
 end}}
C_Map.GetMapInfo=function(id) return {name=id==1453 and "Stormwind City" or "Stranglethorn Vale"} end
local list=A.EntityLocations("Npc",42,"pickup")
assert(#list==3 and list[1].npcID==42 and list[3].map==1434)
local locations=A.QuestLocations({id=99,name="All relations"})
assert(#locations==9)
local kinds={}; for _,t in ipairs(locations) do kinds[t.destinationKind]=true end
assert(kinds.pickup and kinds.objective and kinds.turnin)
-- Entrance-only fallback has no quest ID: map grouping must still work.
ShortestPathForever=nil; TomTom=nil
local door={name="Entrance",mapOnly=true,explicit=true,pin={map=1453,x=10,y=20,title="Entrance",zone="Stormwind City",kind="entrance"}}
assert(A.Navigation.Go(A.Navigation.Destination(door)))
assert(A.RefreshPins()>0)
A.Navigation.Stop()
-- Current-step navigation refreshes, explicit points do not; replacement yields.
local N=A.Navigation
local target={id=1,name="Step",mapOnly=true,origin={},pin={map=1453,x=10,y=20,title="Pickup",zone="Stormwind City",kind="pickup"}}
local count=0
ShortestPathForever={API={version=2,NavigateRoute=function() count=count+1; return true end}}
N.Go(N.Destination(target)); assert(count==1)
A.MapLocation=function() return {id=1,name="Step",mapOnly=true,pin={map=1453,x=30,y=40,title="Hand-in",kind="hand-in",zone="Stormwind City"}} end
N.Progress(); assert(count==2 and N.current.kind=="turnin")
ShortestPathForever.API.Ended=function() return "replaced" end
A.collection={running=true}; N.Progress(); assert(not N.current and not A.collection.running and count==2)
print("PASS: public-provider multi-spawn/location enumeration, entrance-only map fallback, current-step refresh and ownership handoff")
""")

lua.execute(r"""
local N=A.Navigation
local arrow,opened=0,0
local waypoint={}
TomTom={AddWaypoint=function(_,map,x,y,opts) assert(opts.crazy and not opts.persistent); return waypoint end,
 SetCrazyArrow=function(_,point,radius,title) assert(point==waypoint and radius==15); arrow=arrow+1 end,
 RemoveWaypoint=function() end}
ShortestPathForever={API={version=2,NavigateRoute=function() error("TomTom should take precedence") end}}
local mapFallback=A.NavigateMap
A.NavigateMap=function() opened=opened+1 end
local t={id=992001,name="Direct",pin={map=1453,x=10,y=20,title="NPC",zone="Stormwind City"},mapOnly=true}
A.collection=nil; A.navigationWindow:Show(); A.window:Show()
assert(N.Go(N.Destination(t)) and N.provider=="tomtom" and arrow==1 and opened==0)
assert(not A.navigationWindow:IsShown() and not A.window:IsShown())
A.NavigateMap=mapFallback
A.quests={{id=992001,name="Mine",dungeons={"Simple"}},
 {id=992002,name="Other faction",faction="Horde",dungeons={"Simple"}},
 {id=992003,name="Other class",class="WARRIOR",dungeons={"Simple"}}}
faction="Alliance"; class="MAGE"
A.WalkStep=function(q) return q,"pickup" end
A.RunReadiness=function() return false end
local plan=A.RoutePlanner.Build("Simple")
assert(#plan.quests==1 and plan.quests[1].name=="Mine" and #plan.blocked==0)
print("PASS: direct TomTom arrow preferred over SPF, no map opening, panels close, other faction/class quests excluded")
""")
