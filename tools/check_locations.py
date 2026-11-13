"""Exercise optional map integration against the installed baked Forever snapshot.
Does not simulate character-dependent QuestieDB corrections or live map rendering.
"""
import json, re, runpy
from pathlib import Path
from compare_questiedb import read_metadata, field

root=Path(__file__).resolve().parents[1]
db=Path('C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/QuestieDB')
meta=read_metadata(db/'QuestieDB_Forever.toc')
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
for name in ('WalkthroughData.lua','Walkthrough.lua','Locations.lua'):
    lua.execute((root/name).read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
lua.execute('''
support={private={}}
QuestieLoader={ImportModule=function(_,name)
 if name=="Expansions" then return {Current=1,Wotlk=3,Cata=4,MoP=5} end
 return support
end}
''')
for name in ('areaIdToUiMapId','subZoneToParentZone','dungeons'):
    lua.execute((db/f'support/Forever/Zones/{name}.lua').read_text(encoding='utf-8'))
def convert(value):
    if isinstance(value, bytes): return value.decode('utf-8')
    if isinstance(value, dict): return lua.table_from({convert(k):convert(v) for k,v in value.items()})
    if isinstance(value, list): return lua.table_from([convert(v) for v in value])
    return value
def get(entity, ident, key):
    idx=keys[entity][key]
    val=field(meta,entity,int(ident),idx)
    if val is None:
        scalar=field(meta,entity,int(ident),'S') or {}
        val=scalar.get(idx)
    return convert(val)
keys={}
for entity in ('Quest','Npc','Object','Item'):
    source=(db/f'src/meta/{entity.lower()}Meta.lua').read_text(encoding='utf-8')
    keys[entity]={k:int(v) for k,v in re.findall(r"\['([^']+)'\] = (\d+)",source)}
lua.globals().readField=get
lua.execute('''
LibQuestieDB={flavor={name="Forever"},RequireContract=function() return true end,
 Support={Get=function() return support end}}
for _,entity in ipairs({"Quest","Npc","Object","Item"}) do
 local e=entity; LibQuestieDB[e]={Get=function(id,key) return readField(e,id,key) end}
end
C_Map.GetMapInfo=function(id) return {name=id==1434 and "Stranglethorn Vale" or "Map "..id} end
function WorldMapFrame:SetMapID(id) self.mapID=id end
function WorldMapFrame:GetMapID() return self.mapID or 1453 end
C_QuestLog.IsQuestFlaggedCompleted=function(id) return completed[id] or false end
C_QuestLog.GetNumQuestLogEntries=function() return #log end
C_QuestLog.GetInfo=function(i) return log[i] end
C_QuestLog.IsComplete=function(id) for _,q in ipairs(log) do if q.questID==id then return q.complete end end return false end
completed={}; A.db.confirmed={}; A.log={}; A.offers={}; A.logAvailable=true
faction="Alliance"; class="WARRIOR"; race="Human"; level=60
A.LoadLocations()
''')
report={'providerVersion':meta.get('Version'),'quests':[],'nodesWithoutPickup':[],'questsWithoutMap':[]}
A=lua.globals().A
for _,q in A.quests.items():
    result=A.MapLocation(q)
    target=result[0] if isinstance(result,tuple) else result
    if target is None:
        # Missing current-step coordinates must not fall back to a dungeon.
        report['questsWithoutMap'].append({'id':q['id'],'name':q['name']})
        continue
    p=target['pin']
    report['quests'].append({'id':q['id'],'name':q['name'],'pickupKind':q['pin'] and (q['pin']['kind'] or 'curated'),
                             'mapKind':p['kind'] or 'curated','map':p['map'],'x':p['x'],'y':p['y'],'title':p['title']})
for ident,n in A.walkthroughs.items():
    if n['pin'] is None: report['nodesWithoutPickup'].append({'id':ident,'name':n['name']})
lua.execute('''
-- Map viewing must not change the resolver or require an available quest.
local q=A.byID[95810]
local _,before=A.WalkStep(q)
local target=A.MapLocation(q); assert(target and target.mapOnly)
assert(select(2,A.WalkStep(q))==before)
for _,state in ipairs({"unknown","active","ready","done","blocked"}) do
 A.log={}; log={}; completed={}; A.db.confirmed={}; level=60
 if state=="active" or state=="ready" then log={{questID=q.id,title=q.name,complete=state=="ready"}} end
 if state=="done" then completed[q.id]=true end
 if state=="blocked" then level=1 end
 local expected=A.MapLocation(q)
 A.SelectQuest(q)
 local actual=A.MapLocation(q)
 assert((A.window.mapTarget~=nil)==(actual~=nil),state.." map button disagrees with resolver")
end
completed={}; level=60; A.log={[95647]={complete=false}}
assert(select(2,A.WalkStep(A.byID[95737]))=="skipped")
assert(not A.MapLocation(A.byID[95737]),"Skipped breadcrumb must not suggest a trip")
-- Browse a completed quest's map and keep its pin across a scan.
completed[q.id]=true; A.log={}; A.SelectQuest(q)
local target=A.window.mapTarget
A.Navigate(target); assert(A.locationTarget and A.locationTarget.id==target.id and A.RefreshPins()>0)
A.Scan(); assert(A.locationTarget and A.locationTarget.id==target.id and A.RefreshPins()>0)
A.locationTarget=nil; assert(A.RefreshPins()>0,"Completed quests must retain browseable map pins")
assert(not A.window.pickupTarget,"Map browsing must not enable a pickup action")
-- Provider coordinates supersede unreviewed fallback coordinates.
assert(A.byID[168].pin.source=="QuestieDB Forever")
-- Incompatible / absent providers must fail without throwing.
local saved=LibQuestieDB; LibQuestieDB=nil; A.LoadLocations()
assert(A.MapLocation(q)); LibQuestieDB=saved
''')
out=root/'data/provider-location-audit-2026-11-13.json'
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
from collections import Counter
print('PASS:',len(report['quests']),'catalogue maps;',len(report['questsWithoutMap']),'explicit map gaps;',dict(Counter(q['mapKind'] for q in report['quests'])))
print('Catalogue pickup coverage:',dict(Counter(q['pickupKind'] for q in report['quests'])))
print('Walkthrough nodes without exact pickup:',len(report['nodesWithoutPickup']))
