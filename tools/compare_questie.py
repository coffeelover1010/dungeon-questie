"""Optional local cross-check. Writes a review report, never build inputs.

Pass the directory containing locally held Questie v10 research files.
The release does not include or require those files.
"""
import argparse,json,re
from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('questie_directory');p.add_argument('--output',required=True);a=p.parse_args()
lua=LuaRuntime(unpack_returned_tuples=True)
text=(Path(a.questie_directory)/'classicQuestDB.lua').read_text(encoding='utf-8')
db=lua.execute(re.search(r'Data = \[\[(return .*?)\]\]',text,re.S)[1])
nodes=json.loads((ROOT/'data/walkthroughs.json').read_text(encoding='utf-8'))
differences=[];checked=0
for key,node in nodes.items():
    r=db[int(key)]
    if not r:continue
    checked+=1;fields=[]
    for label,index in [('minLevel',4),('raceMask',6),('classMask',7)]:
        ours_value=node.get(label,0); reference_value=r[index] or 0
        if label=='raceMask':
            ours_value=(ours_value or 255)&255; reference_value=(reference_value or 255)&255
        if ours_value!=reference_value:fields.append(label)
    ours=set(node.get('all',[])+node.get('any',[]))
    theirs=set(list(r[12].values()) if r[12] else [])|set(list(r[13].values()) if r[13] else [])
    if ours!=theirs:fields.append('prerequisite IDs')
    if fields:differences.append({'id':int(key),'fields':fields,'disposition':'Keep primary-source values; review independently. No comparison values imported.'})
report={'checked':checked,'differences':differences,'buildInputsChanged':False}
Path(a.output).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'checked':checked,'recordsFlagged':len(differences),'report':a.output}))
