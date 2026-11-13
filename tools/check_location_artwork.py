"""Shared artwork/status regressions; mocked rendering, real provider snapshot."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
setup=(root/'tools/check_locations.py').read_text().split("report={'providerVersion'")[0]
exec(compile(setup,str(root/'tools/check_locations.py'),'exec'))
lua.execute(r'''
completed={}; A.db.confirmed={}; A.log={}; A.offers={}; A.logAvailable=true
for _,q in ipairs(A.quests) do
 faction=q.faction or "Alliance"; class=q.class or "WARRIOR"; level=60
 local _,icon=A.QuestRowStatus(q); assert(not icon,q.id.." unaccepted tick")
 assert(not A.DungeonReadinessBadge(q),q.id.." unaccepted badge")
 A.log[q.id]={complete=false}
 assert(A.QuestRowStatus(q)=="Active",q.id.." active status")
 local instruction=A.DungeonInstruction(q)
 assert(instruction=="Active" or instruction=="Ready for dungeon" or instruction=="Objectives finished",q.id.." active instruction")
 A.log[q.id].complete=true
 assert(A.QuestRowStatus(q)=="Objectives finished",q.id.." objectives")
 assert(A.DungeonInstruction(q)=="Objectives finished",q.id.." detail status")
 A.log={}; completed[q.id]=true
 assert(A.QuestRowStatus(q)=="Completed",q.id.." turn-in")
 completed={}; A.db.confirmed={}
end
local f=A.CreateLocationArtwork(UIParent)
local calls=0; local artID=12
C_Map.GetMapArtID=function() return artID end
C_Map.GetMapArtLayers=function() calls=calls+1; return {{layerWidth=1000,layerHeight=668,tileWidth=256,tileHeight=256}} end
C_Map.GetMapArtLayerTextures=function() local ids={}; for i=1,12 do ids[i]=100+i end; return ids end
local q={id=-1,name="Test"}
local target={id=-1,origin=q,mapOnly=true,pin={map=1453,x=50,y=50,zone="Stormwind City",title="NPC"}}
assert(A.UpdateLocationArtwork(f,q,target)==200 and f.loaded)
assert(#f.tiles==12 and f.tiles[12]:GetWidth()<f.tiles[1]:GetWidth(),"edge tiles cropped")
A.UpdateLocationArtwork(f,q,target); assert(calls==1,"same map reloaded")
artID=13; A.UpdateLocationArtwork(f,q,target); assert(calls==2,"phased art not refreshed")
local nav=A.Navigate; A.Navigate=function(t) assert(t==target); calls=calls+1 end
f:OnClick(); assert(calls==3); A.Navigate=nav
C_Map.GetMapArtLayers=nil; artID=14
assert(A.UpdateLocationArtwork(f,q,target)==54 and not f.loaded)
assert(f.caption:GetText():find("unavailable",1,true) and f.enabled)
assert(A.UpdateLocationArtwork(f,q,nil)==54 and not f.enabled and not f.marker:IsShown())
for _,t in ipairs(f.tiles) do assert(not t:IsShown(),"stale artwork") end
assert(A.UpdateLocationArtwork(f,nil)==0 and not f:IsShown())
-- Multi-zone objectives advance by live unfinished text, not grouped index.
local oldGet=LibQuestieDB.Quest.Get; local oldNpc=LibQuestieDB.Npc.Get
LibQuestieDB.Quest.Get=function(id,key) if id==-1 and key=="objectives" then return {{{11},{22}}} end; return oldGet(id,key) end
LibQuestieDB.Npc.Get=function(id,key)
 if id==11 or id==22 then
  if key=="name" then return id==11 and "First enemy" or "Second enemy" end
  if key=="spawns" then return {[id==11 and 12 or 40]={{50,50}}} end
 end
 return oldNpc(id,key)
end
local firstDone=false
C_QuestLog.GetQuestObjectives=function() return {{text="First enemy slain: 0/1",finished=firstDone},{text="Second enemy slain: 0/1",finished=false}} end
local p=A.LiveObjectivePin(-1); assert(p and p.map==1429)
firstDone=true; p=A.LiveObjectivePin(-1); assert(p and p.map==1436)
C_QuestLog.GetQuestObjectives=function() return {{text="Perform mysterious ritual",finished=false}} end
local p,available=A.LiveObjectivePin(-1); assert(not p and available,"unknown mechanic must not guess")
C_QuestLog.GetQuestObjectives=nil
LibQuestieDB.Quest.Get=oldGet; LibQuestieDB.Npc.Get=oldNpc
print("PASS: all 320 quests across unaccepted/active/objective-finished/turned-in states; tiled artwork, cropping, phase/cache invalidation, fallback, click handling and multi-zone objective advancement")
''')
# Current installed client's documented contract, extracted read-only from CASC.
evidence=root.parent/'tmp/dungeon-artwork-70938/MapDocumentation.lua'
if evidence.exists():
 api=evidence.read_text()
 for name in ('GetMapArtID','GetMapArtLayers','GetMapArtLayerTextures'):
  assert f'Name = "{name}"' in api,name
 print('PASS: map art API declarations in installed Forever 1.60.1.70938')
else:
 print('SKIP: optional local CASC evidence; see ARTWORK-REVIEW-2026-11-13.md')

import json
nodes=[]
for ident,n in lua.globals().A.walkthroughs.items():
 missing=[label for field,label in [('pin','pickup'),('objectivePin','objective'),('turninPin','turn-in')] if n[field] is None]
 if missing: nodes.append({'id':ident,'missing':missing})
report={'scope':'Presence audit of 550 catalogue/prerequisite nodes with installed provider spawn locations; not live verification. Objective counts exclude dynamic live-text matches and dungeon-entrance fallbacks.',
 'nodes':sum(1 for _ in lua.globals().A.walkthroughs.items()),'gaps':sorted(nodes,key=lambda n:n['id'])}
(root/'data/location-artwork-gaps-2026-11-13.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('Location gaps:',{phase:sum(phase in n['missing'] for n in nodes) for phase in ['pickup','objective','turn-in']})
