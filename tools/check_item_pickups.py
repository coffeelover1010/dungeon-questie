"""Check item pickup cards against the installed Forever provider."""
import runpy
from pathlib import Path
root = Path(__file__).resolve().parents[1]
# Reuse the provider loader without rerunning its full catalogue audit.
loader = (root / 'tools/check_provider.py').read_text()
loader = loader[:loader.index("lua.execute(" + chr(39)*3 + "\nassert(not A.providerError")]
context = {'__file__': str(root / 'tools/check_provider.py')}
exec(loader, context)
lua = context['lua']
lua.execute(r''' 
completed={}; A.log={}; A.db.confirmed={}; A.offers={}; A.logAvailable=true
level=60; faction="Alliance"; race="Human"; class="WARRIOR"
local old,q=A.byID[3366],A.byID[6981]
assert(not A.ChecklistVisible(old) and A.ChecklistVisible(q), "Current item quest must be the default")
local step,phase=A.WalkStep(q)
assert(step.id==6981 and phase=="inside",phase)
assert(A.DungeonActionBadge(q)=="Interface\\GossipFrame\\AvailableQuestIcon")
assert(A.DungeonReadinessBadge(q)=="Interface\\RaidFrame\\ReadyCheck-Ready")
local _,words=A.DungeonInstruction(q)
assert(words=="Accept: The Glowing Shard from Glowing Shard, dropped by Mutanus the Devourer\nZone: Wailing Caverns", words)
A.log[q.id]={complete=false}
assert(A.DungeonActionBadge(q)==nil)
A.log[q.id]=nil; A.log[old.id]={complete=false}
assert(A.ChecklistVisible(old) and not A.ChecklistVisible(q), "Accepted legacy quest must remain visible")
A.log={}; level=1
assert(A.DungeonActionBadge(q)==nil, "Level-blocked quest must not offer pickup")
print("PASS: current item quest, source/zone text, combined icons, active quest and level restrictions")
''')
