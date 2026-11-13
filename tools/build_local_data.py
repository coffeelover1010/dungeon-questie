"""Export only needed local runtime facts; never import provider values.
Run check_provider.py first to audit field presence in the installed provider.
Full independently sourced research inputs remain intact for future reviews.
"""
from pathlib import Path
import json
r=Path(__file__).resolve().parents[1]
coverage=json.loads((r/'data/provider-field-coverage.json').read_text())['fields']
remote={'minLevel':'requiredLevel','level':'questLevel','objectives':'objectivesText','all':'preQuestGroup','any':'preQuestSingle','raceMask':'requiredRaces','classMask':'requiredClasses'}
def lua(v):
 if v is None:return 'nil'
 if isinstance(v,bool):return str(v).lower()
 if isinstance(v,(int,float)):return str(v)
 if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
 if isinstance(v,list):return '{'+','.join(map(lua,v))+'}'
 return '{'+','.join('['+(str(k) if str(k).isdigit() else lua(k))+']='+lua(x) for k,x in v.items())+'}'
removed=0
def trim(row):
 global removed
 row=dict(row); expected={}
 for k in coverage.get(str(row['id']),[]):
  if k in row:
   row.pop(k); expected[k]=remote[k]; removed+=1
 if expected:row['providerExpected']=expected
 # Historical source paragraphs are research material, not player instructions.
 for key in ('notes','people','chain','fieldSources','locationEvidence','fieldChecked','locationSource'):
  row.pop(key,None)
 return row
catalogue=[trim(q) for q in json.loads((r/'data/catalogue.json').read_text(encoding='utf-8'))]
nodes={id:trim(q) for id,q in json.loads((r/'data/walkthroughs.json').read_text(encoding='utf-8')).items()}
header=(r/'Data.lua').read_text(encoding='utf-8').split('A.quests=',1)[0]
(r/'LocalData.lua').write_text('-- Local selection, reviewed mechanics and missing-field fallbacks; see PROVIDER-INTEGRATION.md.\n'+header+'A.quests='+lua(catalogue)+'\nA.walkthroughs='+lua(nodes)+'\n',encoding='utf-8')
print(f'Exported {len(catalogue)} goals and {len(nodes)} fallback nodes; removed {removed} provider-backed field copies.')
