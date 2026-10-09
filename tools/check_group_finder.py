"""Offline Group Browser contracts; not live-client or taint verification."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
A={Print=function(message) lastMessage=message end}
A.OpenRecruit=function(dungeon,ids) recruitDungeon=dungeon; recruitIDs=ids end
combat=false; available=true; opened=0; searches=0; hidden=0; resets=0
function InCombatLockdown() return combat end
C_LFGInfo={CanPlayerUsePremadeGroup=function() return available end}
local info={
 [10]={fullName="The Stockades",shortName="Stockades",categoryID=2},
 [11]={fullName="The Deadmines",shortName="Deadmines",categoryID=2},
 [12]={fullName="Scarlet Monastery Graveyard",shortName="Graveyard",categoryID=2,groupFinderActivityGroupID=7},
 [13]={fullName="The Hall of Thanes",shortName="Hall of Thanes",categoryID=2},
 [14]={fullName="Scarlet Monastery - Library",shortName="Library",categoryID=2},
 [15]={fullName="Scarlet Monastery - Armory",shortName="Armory",categoryID=2},
 [16]={fullName="Scarlet Monastery - Cathedral",shortName="Cathedral",categoryID=2},
}
C_LFGList={GetAvailableCategories=function() return {2} end,
 GetAvailableActivities=function() return {10,11,12,13,14,15,16,10} end,
 GetActivityInfoTable=function(id) return info[id] end,
 GetActivityGroupInfo=function(id) if id==7 then return "Scarlet Monastery" end end,
 CreateListing=function() error("Must not post a listing") end,
 Search=function() error("Use the native browser") end}
C_PartyInfo={InviteUnit=function() error("Invitations must stay manual") end}
A.window={Hide=function() hidden=hidden+1 end}
function LFGVanilla_ShowFrame(tab) assert(tab==2); opened=opened+1 end
function GroupFinderVanillaStyle_LoadUI()
 LFGBrowseFrame={ShowSearchForActivities=function(self,ids)
  LFGVanilla_ShowFrame(2); searches=searches+1; selectedIDs=ids
 end, ResetDropdowns=function() resets=resets+1 end}
end
''')
lua.execute((Path(__file__).resolve().parents[1] / 'GroupFinder.lua').read_text(),
            'DungeonGuideForever', lua.globals().A)
lua.execute('''
local ids=A.GroupActivities("Stormwind Stockade"); assert(#ids==1 and ids[1]==10)
assert(A.GroupActivities("Deadmines")[1]==11)
assert(A.GroupActivities("The Hall of Thanes")[1]==13)
assert(A.GroupActivities("Scarlet Monastery")[1]==12) -- client-defined wing group
assert(#A.GroupActivities("Scarlet Monastery")==4) -- include wings without group metadata
assert(#A.GroupActivities("Scarlet")==0) -- no guessed partial match
A.FindGroup("Stormwind Stockade"); assert(searches==1 and selectedIDs[1]==10 and hidden==1)
A.FindGroup("Deadmines"); assert(searches==2 and #selectedIDs==1 and selectedIDs[1]==11)
LFGBrowseFrame.searching=true
A.FindGroup("Deadmines"); assert(searches==2 and hidden==3 and recruitDungeon=="Deadmines" and recruitIDs[1]==11)
-- Switching dungeon while busy shows its helper without replacing native filters.
A.FindGroup("Scarlet Monastery"); assert(searches==2 and #recruitIDs==4 and selectedIDs[1]==11)
LFGBrowseFrame.searching=false
combat=true; A.FindGroup("Deadmines"); assert(opened==4); combat=false
available=false; A.FindGroup("Deadmines"); assert(opened==4); available=true
A.FindGroup("Unknown dungeon"); assert(opened==5 and searches==2 and resets==1 and #recruitIDs==0)
LFGBrowseFrame=nil; GroupFinderVanillaStyle_LoadUI=nil
A.FindGroup("Deadmines"); assert(opened==5 and lastMessage:find("could not be opened"))
''')
print('PASS: activity matching, aliases, duplicates, native browser handoff, manual invites, combat/unavailable/busy guards and unknown activity fallback (mocked).')
