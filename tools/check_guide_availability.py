"""Catalogue-wide guide availability checks without visiting quest givers."""
import runpy
from pathlib import Path
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
for name in ('WalkthroughData.lua','Walkthrough.lua'):
    lua.execute((root/name).read_text(encoding='utf-8'),'DungeonGuideForever',lua.globals().A)
lua.execute('''
completed={}; A.db.confirmed={}; A.offers={}; A.log={}; A.logAvailable=true
C_QuestLog.IsQuestFlaggedCompleted=function(id) return completed[id] or false end
local checked,pickups,gaps=0,0,0
for _,side in ipairs({'Alliance','Horde'}) do
 faction=side; race=side=='Alliance' and 'Human' or 'Orc'
 for _,profession in ipairs({'WARRIOR','PALADIN','HUNTER','ROGUE','PRIEST','SHAMAN','MAGE','WARLOCK','DRUID'}) do
  class=profession
  for _,lvl in ipairs({1,30,60}) do
   level=lvl
   for _,q in ipairs(A.quests) do
    local n,phase,note=A.WalkStep(q); checked=checked+1
    assert(not note or not note:find('Not yet confirmed',1,true),q.id)
    if phase=='pickup' or phase=='inside' then
     pickups=pickups+1
     assert(not A.WalkRestriction(n),n.id)
     assert(not n.requirementsNote and not n.unverifiedChain,n.id)
     assert(A.Availability(n.id)==nil,'Guide must not fabricate observed offers')
    elseif phase=='check' then
     gaps=gaps+1; assert(note and note~='',q.id)
    end
   end
  end
 end
end
faction='Alliance'; race='Human'; class='WARRIOR'; level=60
for _,q in ipairs(A.quests) do
 if q.name=='Mortality Wanes' or q.name=='Willix the Importer' then
  assert(select(2,A.WalkStep(q))=='inside',q.name)
  assert(A.RunReadiness(q),q.name)
 end
end
print('PASS: '..checked..' quest/profile checks; '..pickups..' guide pickups without NPC visits; '..gaps..' specific data gaps retained')
''')