"""Check source extraction, breadcrumb semantics, pins and reproducibility."""
import hashlib,json,runpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(name):return json.loads((ROOT/'data'/name).read_text())
source=read('classic-source.json'); nodes=read('walkthroughs.json')
assert len(source['quest_template'])==len({r['entry'] for r in source['quest_template']})
for row in source['quest_template']:
    assert not set(row)&{'Details','Objectives','OfferRewardText','RequestItemsText','EndText'}
by_id={r['entry']:r for r in source['quest_template']}
for i in (1275,2922,2865,4134,4126,4136,7489,7488,4734,4768,4764):
    assert any(r['BreadcrumbForQuestId']==i for r in source['quest_template'])
    assert by_id[i]['PrevQuestId']==0
    assert not nodes[str(i)]['all'] and not nodes[str(i)]['any']
assert nodes['378']['all']==[303]
assert nodes['1654']['classMask']==2
assert nodes['377']['pin']['map']==1431
for node in nodes.values():
    if node.get('pin'):
        assert 0<node['pin']['x']<100 and 0<node['pin']['y']<100
paths=[ROOT/'WalkthroughData.lua',ROOT/'data/walkthroughs.json',ROOT/'data/walkthrough-coverage.json']
before=[hashlib.sha256(p.read_bytes()).hexdigest() for p in paths]
runpy.run_path(str(ROOT/'tools/build_classic_walkthroughs.py'))
assert before==[hashlib.sha256(p.read_bytes()).hexdigest() for p in paths]
print('PASS: no narrative SQL fields, unique source quests, breadcrumb semantics, known prerequisite/class/pin, valid coordinates and deterministic generation.')
