"""Catalogue-wide presentation checks; source uncertainty remains intact."""
import runpy
from pathlib import Path
root = Path(__file__).resolve().parents[1]
lua = runpy.run_path(str(root / 'tools/check.py'))['lua']
lua.execute('''
assert(A.DisplayText("Minimum level unknown")=="Minimum level: ?")
assert(A.DisplayText("Loot the pearl. Its minimum level is not yet confirmed.")=="Loot the pearl.")
assert(A.DisplayText("Visit Borstan (57.5, 53.4).")=="Visit Borstan (57.5, 53.4).")
assert(A.DisplayText("Requires level 25.")=="Requires level 25.")
assert(A.DisplayText("Check requirements")=="Quest details")
local count=0
for _,q in ipairs(A.quests) do
 for _,field in ipairs({"pickup","notes","routeNote","preparationNote","requirementsNote"}) do
  local value=A.DisplayText(q[field]):lower()
  for _,word in ipairs({"beta","cache","unverified","unconfirmed"}) do
   assert(not value:find(word,1,true),q.id..":"..field..":"..value)
  end
 end
 count=count+1
end
print("PASS: player-facing wording across "..count.." quests, unknown level marker, preserved coordinates and level restrictions")
''')
