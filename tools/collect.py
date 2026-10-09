"""Collect factual quest fields; retain source pages outside the install folder."""
import argparse, json, re, time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import requests
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--cache',type=Path,default=ROOT.parent/'tmp/dungeon-research')
parser.add_argument('--index',default='1.html')
parser.add_argument('--checked',required=True,help='ISO date on which these source pages were checked')
parser.add_argument('--output',type=Path,default=ROOT/'data/quests.json')
parser.add_argument('--refresh',action='store_true',help='Fetch quest pages even if this snapshot already has a copy')
args=parser.parse_args()
CACHE = args.cache
BASE = 'https://wowforevertalents.com'
index = BeautifulSoup((CACHE/args.index).read_text(encoding='utf-8'), 'html.parser')
tasks = []
for group in index.select('.qh-grp'):
    if not group.select_one('.qh-meta').get_text(strip=True).startswith('Dungeon'):
        continue
    dungeon = group.h2.get_text(strip=True)
    for a in group.select('a.qh-name'):
        tasks.append((dungeon, a.get_text(strip=True), a['href']))

def collect(task):
    dungeon, name, path = task
    qid = int(re.search(r'-(\d+)/$',path)[1])
    dest = CACHE/f'quest-{qid}.html'
    if args.refresh or not dest.exists():
        r = requests.get(BASE+path, timeout=40); r.raise_for_status()
        dest.write_bytes(r.content)
    soup = BeautifulSoup(dest.read_text(encoding='utf-8'), 'html.parser')
    header = soup.select_one('.qi-by').get_text(' ',strip=True)
    body = soup.select_one('.qp')
    q = dict(id=qid,name=name,dungeons=[dungeon],source=BASE+path,evidence='Beta cache report',checked=args.checked)
    q['level']=int(re.search(r'Level (\d+)',header)[1])
    m=re.search(r'from level (\d+)',header)
    if m: q['minLevel']=int(m[1])
    for faction in ('Alliance','Horde'):
        if faction in header: q['faction']=faction
    q['objectives']=[x.get_text(' ',strip=True) for x in body.select('.qp-obj li')]
    q['rewards']=[]
    for a in body.select('a.qp-item'):
        # Quest-starting items are not completion rewards.
        if a.find_parent(class_='qp-start'): continue
        m=re.search(r'item=(\d+)',a['href'])
        if m: q['rewards'].append(dict(id=int(m[1]),name=a.select_one('.qp-item-name').get_text(' ',strip=True).replace('★','').strip()))
    q['people']=[]
    q['personEvidence']=[]
    q['sourceDetails']=[p.get_text(' ',strip=True) for p in body.select('.qp-src')]
    for li in body.select('.qp-npcs li'):
        q['people'].append(li.select_one('.qp-role').get_text(strip=True)+': '+li.select_one('.qp-npc').get_text(strip=True))
        where=li.select_one('.qp-where')
        q['personEvidence'].append(dict(role=li.select_one('.qp-role').get_text(strip=True),name=li.select_one('.qp-npc').get_text(strip=True),location=where.get_text(' ',strip=True) if where else None))
    q['chain']=[]
    for li in body.select('.qp-chain li'):
        role=li.select_one('.qp-role').get_text(strip=True)
        a=li.find('a')
        title=a.get_text(' ',strip=True) if a else li.select_one('.qp-chain-bare').get_text(strip=True)
        entry=dict(role=role,name=title.replace('★','').replace('↗','').strip())
        m=re.search(r'(?:-|quest=)(\d+)(?:/|$)',a['href']) if a else None
        if m: entry['id']=int(m[1])
        q['chain'].append(entry)
    return q

with ThreadPoolExecutor(max_workers=4) as pool:
    quests=list(pool.map(collect,tasks))
(ROOT/'data').mkdir(exist_ok=True)
if not quests: raise ValueError('No dungeon quests parsed; refusing to replace output')
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(quests,indent=2,ensure_ascii=False),encoding='utf-8')
print(f'Collected {len(quests)} quest records in {len(set(q["dungeons"][0] for q in quests))} dungeons')
