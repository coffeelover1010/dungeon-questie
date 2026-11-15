"""Current-step and missed breadcrumb regression checks."""
import runpy
from pathlib import Path
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
for f in ('WalkthroughData.lua','Walkthrough.lua'):
 lua.execute((root/f).read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
lua.execute("""
completed={}; A.db.confirmed={}; A.log={}; A.offers={}; A.logAvailable=true
level=60; faction="Alliance"; race="Human"; class="WARRIOR"
local b={id=999801,name="Introduction",breadcrumbFor=999802}
local q={id=999802,name="Destination",dungeons={"Test"},rewards={}}
A.walkthroughs[b.id]=b; A.walkthroughs[q.id]=q; A.byID[q.id]=q
A.RebuildSuccessors()
assert(A.WalkStep(q).id==b.id,"Show breadcrumb first")
A.log[q.id]={complete=false}
assert(A.WalkStep(q).id==q.id,"Accepted destination wins")
assert(A.BreadcrumbRecovery(q):find("abandon Destination",1,true))
A.log[q.id]=nil
assert(A.WalkStep(q).id==b.id,"Abandonment restores breadcrumb guidance")
completed[q.id]=true
assert(not A.BreadcrumbRecovery(q):find("abandon Destination",1,true))
completed[b.id]=true
assert(A.BreadcrumbRecovery(q)==nil,"Completed breadcrumb needs no recovery")
print("PASS: breadcrumb-first guidance, skipped active destination, abandonment and completed-quest safeguards")
""")
