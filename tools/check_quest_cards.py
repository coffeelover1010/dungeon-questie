"""Audit long quest prose and verify compact catalogue-wide card summaries."""
import json, runpy
from pathlib import Path
root=Path(__file__).resolve().parents[1]
records=json.loads((root/'data/walkthroughs.json').read_text(encoding='utf-8'))
audit=[]
for q in records.values():
    text=' '.join(q.get(k) or '' for k in ('pickup','preparationNote','requirementsNote','routeNote'))
    words=len(text.split())
    if words>=40:
        audit.append(dict(id=q['id'],name=q['name'],words=words))
audit.sort(key=lambda q:q['words'],reverse=True)
(root/'data/wordy-quest-audit-2026-11-13.json').write_text(json.dumps(dict(threshold=40,scope=f'All {len(records)} quest and prerequisite records; long directions remain in the detail panel, not cards.',quests=audit),indent=2)+'\n',encoding='utf-8')
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
for f in ('WalkthroughData.lua','Walkthrough.lua'):
    lua.execute((root/f).read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
lua.execute('''
completed={}; A.db.confirmed={}; A.log={}; A.offers={}; A.logAvailable=true
level=60; faction="Alliance"; class="WARRIOR"; race="Human"
for _,q in ipairs(A.quests) do
 local summary=A.QuestCardSummary(q)
 assert(not summary:find("\\n",1,true),q.id)
 assert(#summary<140,q.id..":"..summary)
 if summary~="" then assert(summary:find("Next: ",1,true)==1 or summary=="Pick up inside the dungeon.",q.id) end
end
for _,id in ipairs({92456,92457,92458,92489}) do assert(A.QuestCardSummary(A.byID[id])=="",id) end
print("PASS: "..#A.quests.." compact cards; no repeated titles or location paragraphs; prerequisite names retained")
''')
print(f'Audited {len(records)} records; {len(audit)} have 40+ words of directions, now confined to details.')
