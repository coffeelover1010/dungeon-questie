"""Collect explicit pickup coordinates; never treat turn-in coordinates as pickups."""
import json,re
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import requests
from bs4 import BeautifulSoup
ROOT=Path(__file__).resolve().parents[1]
qs=json.loads((ROOT/'data/catalogue.json').read_text(encoding='utf-8'))
maps={q['pin']['zone']:q['pin']['map'] for q in qs if q.get('pin')}
maps.update({'Westfall':1436,'Tirisfal Glades':1420,'Duskwood':1431})
# Website subzone used for Gryan Stoutmantle; map reviewed separately.
aliases={'Sentinel Tower':'Westfall'}
def collect(q):
    r=requests.get(q['source'],timeout=40); r.raise_for_status()
    soup=BeautifulSoup(r.text,'html.parser'); result=[]
    for row in soup.select('.qp-npcs li'):
        role,npc,where=[row.select_one(s) for s in ('.qp-role','.qp-npc','.qp-where')]
        if not all((role,npc,where)) or role.get_text(strip=True)!='Picked up from':continue
        loc=where.get_text(' ',strip=True)
        m=re.search(r'\((\d+(?:\.\d+)?),\s*(\d+(?:\.\d+)?)\)',loc)
        if not m:continue
        zone=loc.split(',')[0].split('(')[0].strip(); zone=aliases.get(zone,zone)
        entry=dict(id=q['id'],name=npc.get_text(strip=True),location=loc,source=q['source'])
        if zone in maps:
            x,y=map(float,m.groups()); assert 0<=x<=100 and 0<=y<=100
            entry['pin']=dict(map=maps[zone],x=x,y=y,zone=zone,title=entry['name'])
        result.append(entry)
    return result
sources=[q for q in qs if q['source'].startswith('https://wowforevertalents.com/quests/')]
with ThreadPoolExecutor(max_workers=4) as pool:
    records=[r for result in pool.map(collect,sources) for r in result]
patches={}
for r in records:
    if 'pin' not in r:continue
    key=str(r['id'])
    if key in patches:raise ValueError('Multiple pickups need manual review: '+key)
    patches[key]=dict(pin=r['pin'],pickup=r['name']+' - '+r['location'],locationSource=r['source'],locationEvidence='Website-reported beta pickup coordinates')
(ROOT/'data/source-coordinates.json').write_text(json.dumps(patches,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
(ROOT/'data/source-coordinate-audit.json').write_text(json.dumps(dict(pagesChecked=len(sources),records=records),indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(f'Checked {len(sources)} pages; {len(patches)} pickup coordinates; {sum("pin" not in r for r in records)} unmapped')
