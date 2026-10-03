"""Build from licensed Classic-DB facts and sourced Forever records, never Questie."""
import csv,json
from collections import defaultdict
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(name): return json.loads((ROOT/'data'/name).read_text(encoding='utf-8'))
source=read('classic-source.json'); provenance=read('classic-source-provenance.json')
quests={r['entry']:r for r in source['quest_template']}
names={'npc':{r['Entry']:r['Name'] for r in source['creature_template']},'object':{r['entry']:r['name'] for r in source['gameobject_template']},'item':{r['entry']:r['name'] for r in source['item_template']}}
starters=defaultdict(list); finishers=defaultdict(list); incoming=defaultdict(set); groups=defaultdict(set)
for table,kind in [('creature','npc'),('gameobject','object')]:
    for suffix,dest in [('questrelation',starters),('involvedrelation',finishers)]:
        for r in source[table+'_'+suffix]: dest[r['quest']].append((kind,r['id']))
for r in source['item_template']:
    if r['startquest']: starters[r['startquest']].append(('item',r['entry']))
for i,r in quests.items():
    if r['NextQuestId']: incoming[abs(r['NextQuestId'])].add(i if r['NextQuestId']>0 else -i)
    if r['ExclusiveGroup']: groups[r['ExclusiveGroup']].add(i)
catalogue=read('catalogue.json'); catalogue_by_id={q['id']:q for q in catalogue}
overrides=read('walkthrough-overrides.json'); nodes={}
zone_maps={q['pin']['zone']:q['pin']['map'] for q in catalogue if q.get('pin')}
zone_maps.update({'Duskwood':1431,'Tirisfal Glades':1420,'Westfall':1436})
aliases={'Stormwind':'Stormwind City','Ogrimmar':'Orgrimmar','Tirisfal':'Tirisfal Glades','Stranglethorn':'Stranglethorn Vale','Hinterlands':'The Hinterlands','Barrens':'The Barrens','Hilsbrad':'Hillsbrad Foothills','Alterac':'Alterac Mountains'}
areas=[]
for row in csv.DictReader((ROOT/'data/worldmaparea.csv').open(encoding='utf-8-sig')):
    key=aliases.get(row['AreaName'],row['AreaName'])
    zone=next((z for z in zone_maps if z.replace(' ','').replace("'",'').lower()==key.replace(' ','').replace("'",'').lower()),None)
    if zone:areas.append((zone,row))
spawn_pins=defaultdict(list)
for table,kind in [('creature','npc'),('gameobject','object')]:
    for spawn in source[table]:
        matches=[]
        for zone,area in areas:
            if spawn['map']!=int(area['MapID']):continue
            left,right,top,bottom=(float(area[k]) for k in ('LocLeft','LocRight','LocTop','LocBottom'))
            x=100*(left-spawn['position_y'])/(left-right); y=100*(top-spawn['position_x'])/(top-bottom)
            if 0<x<100 and 0<y<100:matches.append(dict(map=zone_maps[zone],zone=zone,x=round(x,2),y=round(y,2),reference=True,title=names[kind][spawn['id']]))
        # Overlapping map rectangles cannot reliably identify the zone.
        if len(matches)==1:spawn_pins[(kind,spawn['id'])].append(matches[0])
def entity(kind,i): return names[kind].get(i,f'{kind} {i}')
def people(entries):
    labels=[]
    for kind,i in sorted(entries):
        zones=sorted({p['zone'] for p in spawn_pins[(kind,i)]})
        labels.append(('Use item: ' if kind=='item' else '')+entity(kind,i)+(' - '+', '.join(zones) if zones else ''))
    return '; '.join(labels) or 'Location not recorded; check your quest log.'
def prerequisites(r):
    candidates=set(incoming[r['entry']])
    if r['PrevQuestId']: candidates.add(r['PrevQuestId'])
    bundles=[]
    for i in sorted(i for i in candidates if i>0):
        group=quests.get(i,{}).get('ExclusiveGroup',0)
        bundles.append(tuple(sorted(groups[group])) if group<0 else (i,))
    bundles=sorted(set(bundles))
    # Unsupported OR-of-ANDs and active-parent requirements remain explicit gaps.
    if len(bundles)==1: all_of=list(bundles[0]); any_of=[]
    elif all(len(b)==1 for b in bundles): all_of=[]; any_of=sorted(b[0] for b in bundles)
    else: all_of=[]; any_of=[]
    complex_case=any(i<0 for i in candidates) or (len(bundles)>1 and any(len(b)>1 for b in bundles))
    return all_of,any_of,complex_case
def visit(i):
    if str(i) in nodes:return
    r=quests.get(i); q=catalogue_by_id.get(i); o=overrides.get(str(i),{})
    if not r and not q and not o:
        nodes[str(i)]=dict(id=i,name=f'Quest {i}',all=[],any=[],unverifiedChain=True,evidence='Classic reference'); return
    if r:
        all_of,any_of,complex_case=prerequisites(r)
        n=dict(id=i,name=r['Title'],minLevel=r['MinLevel'],raceMask=r['RequiredRaces'],classMask=r['RequiredClasses'],pickup=people(starters[i]),turnin=people(finishers[i]),all=all_of,any=any_of,source=f'https://www.wowhead.com/classic/quest={i}',dataSource=provenance['source'],evidence='Classic reference',objectives=[])
        group=r['ExclusiveGroup']; n['exclusive']=sorted(groups[group]-{i}) if group>0 else []
        pins=[p for giver in starters[i] for p in spawn_pins[giver]]
        if pins:n['pin']=sorted(pins,key=lambda p:(p['map'],p['title'],p['x'],p['y']))[0]
        for slot in range(1,5):
            item=r[f'ReqItemId{slot}']; target=r[f'ReqCreatureOrGOId{slot}']; spell=r[f'ReqSpellCast{slot}']
            if item:n['objectives'].append(f"Collect {r[f'ReqItemCount{slot}']} {entity('item',item)}")
            if target:
                verb='Use the required spell on' if spell else ('Defeat' if target>0 else 'Interact with')
                n['objectives'].append(f"{verb} {entity('npc' if target>0 else 'object',abs(target))} ({r[f'ReqCreatureOrGOCount{slot}']})")
        if complex_case or any(r[k] for k in ('RequiredSkill','RequiredCondition','RequiredMinRepFaction','RequiredMaxRepFaction')):
            n['requirementsNote']='Additional or conditional requirements need checking in your quest log or at the quest giver.'
    else:
        n=dict(id=i,name=(q or o)['name'],all=(q or {}).get('prereqs',[]),any=[],evidence=(q or {}).get('evidence','Forever database'),source=(q or {}).get('source',''),unverifiedChain=True)
    if q:
        # These are independently sourced catalogue facts, not old walkthroughs.
        for key in ('pickup','pin','pickupInside','preparationNote'):
            if q.get(key) not in (None,'',[]):n[key]=q[key]
        if q.get('evidence')!='Classic reference':
            for key in ('name','minLevel','faction','class','objectives'):
                if q.get(key) not in (None,'',[]):n[key]=q[key]
            n['evidence']=q['evidence']; n['source']=q.get('source',n.get('source','')); n['checked']=q.get('checked')
            if r:n['referenceDetails']='Turn-in locations and prerequisite requirements include Classic reference data.'
    if o:
        n.update(o)
        if o.get('evidence'):n.pop('referenceDetails',None)
    nodes[str(i)]=n
    for prior in n.get('all',[])+n.get('any',[]):
        if prior>0:visit(prior)
for q in catalogue:visit(q['id'])
def to_lua(v):
    if v is None:return 'nil'
    if v is True:return 'true'
    if v is False:return 'false'
    if isinstance(v,(int,float)):return str(v)
    if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
    if isinstance(v,list):return '{'+','.join(map(to_lua,v))+'}'
    return '{'+','.join('['+(str(k) if str(k).isdigit() else to_lua(k))+']='+to_lua(x) for k,x in v.items())+'}'
(ROOT/'data/walkthroughs.json').write_text(json.dumps(nodes,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
(ROOT/'WalkthroughData.lua').write_text('-- Classic-DB reference data, GPLv3; see THIRD-PARTY-NOTICES.md.\nlocal _, A = ...\nA.walkthroughs='+to_lua(nodes)+'\n',encoding='utf-8')
report={'targets':len(catalogue),'nodes':len(nodes),'targetsWithPrerequisites':sum(bool(nodes[str(q['id'])].get('all') or nodes[str(q['id'])].get('any')) for q in catalogue),'unverifiedForeverTargets':[q['id'] for q in catalogue if nodes[str(q['id'])].get('unverifiedChain')],'missingEdges':sorted({p for n in nodes.values() for p in n.get('all',[])+n.get('any',[]) if str(p) not in nodes}),'source':provenance,'pickupPins':sum(bool(n.get('pin')) for n in nodes.values())}
(ROOT/'data/walkthrough-coverage.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report))
