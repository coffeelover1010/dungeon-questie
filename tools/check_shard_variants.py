"""Regression: live Glowing Shard variant controls checklist visibility."""
from check import lua
lua.execute(''' 
A.db.confirmed={}; completed={}; A.log={}; A.logAvailable=true
local old,new=A.byID[3366],A.byID[6981]
assert(A.ChecklistVisible(old) and A.ChecklistVisible(new),"unknown variant was discarded")
A.log[6981]={complete=false}
assert(not A.ChecklistVisible(old) and A.ChecklistVisible(new))
assert(not A.CountsForProgress(old) and A.CountsForProgress(new))
assert(A.Preparation(new)=="packed")
A.db.dungeon="Wailing Caverns"; A.db.search=""
assert(not A.Matches(old) and A.Matches(new))
A.log={}; completed[6981]=true
assert(not A.ChecklistVisible(old) and A.ChecklistVisible(new))
assert(A.Completed(3366)==false,"unused variant falsely marked complete")
completed={}; A.log[3366]={complete=false}
assert(A.ChecklistVisible(old) and not A.ChecklistVisible(new))
A.log[6981]={complete=false}
assert(A.ChecklistVisible(old) and A.ChecklistVisible(new),"actual accepted quest hidden")
A.log={}
assert(A.ChecklistVisible(old) and A.ChecklistVisible(new),"abandon did not restore alternatives")
''')
print("PASS: Glowing Shard live variants, readiness, counts, completion and abandonment")
