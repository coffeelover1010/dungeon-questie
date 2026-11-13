"""Offline integration against the installed provider's own public API and baked TOC.
WoW metadata/encoding/UI calls are emulated; no provider data is copied to outputs.
"""
from pathlib import Path
import base64, json, re, runpy, zlib
import cbor2
from compare_questiedb import read_metadata
root=Path(__file__).resolve().parents[1]
provider=Path('C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/QuestieDB')
meta=read_metadata(provider/'QuestieDB_Forever.toc')
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
def convert(v):
 if isinstance(v,bytes):return v.decode('utf-8')
 if isinstance(v,dict):return lua.table_from({convert(k):convert(x) for k,x in v.items()})
 if isinstance(v,list):return lua.table_from([convert(x) for x in v])
 return v
# Keep binary bytes in Python objects so Lua's UTF-8 bridge cannot reinterpret them.
lua.globals().metadata=lambda addon,key:meta.get(key)
lua.globals().decode64=lambda s: {'bytes':base64.b64decode(s)}
lua.globals().decompress=lambda v,method:{'bytes':zlib.decompress(v['bytes'])}
lua.globals().deserialize=lambda v:convert(cbor2.loads(v['bytes']))
lua.execute('''
C_AddOns={GetAddOnMetadata=function(a,k) return metadata(a,k) end}
C_EncodingUtil={DecodeBase64=function(s) return decode64(s) end,
 DecompressString=function(s,m) return decompress(s,m) end,
 DeserializeCBOR=function(s) return deserialize(s) end}
P={}; function UnitClassBase() return class end
function GetLocale() return "enUS" end
bit={band=function(a,b) local n,p=0,1; while a>0 and b>0 do if a%2==1 and b%2==1 then n=n+p end; a=math.floor(a/2); b=math.floor(b/2); p=p*2 end; return n end}
bit.bor=function(a,b) return a+b-bit.band(a,b) end
bit.lshift=function(a,b) return a*2^b end
bit.rshift=function(a,b) return math.floor(a/2^b) end
''')
paths=[s.strip().replace('\\','/') for s in (provider/'QuestieDB_Forever.toc').read_text(encoding='utf-8').splitlines() if s.strip() and not s.startswith('#')]
for path in paths:
 if path=='src/ui/modeIndicator.lua':continue # unrelated provider indicator needs native UI
 try:lua.execute((provider/path).read_text(encoding='utf-8-sig'),'QuestieDB',lua.globals().P)
 except Exception as e:raise RuntimeError(path) from e
for file in ('LocalData.lua','ProviderCorrections.lua','Provider.lua','Tracking.lua','Walkthrough.lua','Locations.lua'):
 lua.execute((root/file).read_text(encoding='utf-8-sig'),'DungeonGuideForever',lua.globals().A)
lua.execute('''
assert(not A.providerError,A.providerError)
assert(LibQuestieDB.flavor.name=="Forever" and LibQuestieDB.RequireContract(4))
completed={}; log={}; A.db.confirmed={}; A.log={}; A.offers={}; A.logAvailable=true
level=60; faction="Alliance"; class="WARRIOR"; race="Human"
C_QuestLog.GetNumQuestLogEntries=function() return #log end
C_QuestLog.GetInfo=function(i) return log[i] end
C_Map.GetMapInfo=function(id) return {name="Map "..id} end
A.LoadLocations()
for _,q in ipairs(A.quests) do
 assert(not q.minLevel or q.minLevel>0)
 assert(A.walkthroughs[q.id])
 A.SelectQuest(q)
 -- Missing newly researched starters must not receive a fabricated map.
 local location=A.MapLocation(q)
 if location then assert(type(location)=="table")
 end -- Unknown current-step locations are intentional; audited by check_routing.py.
 if A.ChecklistVisible(q) and not A.Restriction(q) then
  local text=A.window.detailText:GetText()
  assert(text:find("Who offers this step",1,true) and text:find("Objectives",1,true) and text:find("Return to",1,true),q.id)
 end
end
''')
A=lua.globals().A
coverage={'version':meta['Version'],'flavour':meta['X-Flavor'],'contract':lua.globals().LibQuestieDB.contractVersion,'catalogue':len(A.quests),'providerFound':0,'missing':[],'positiveMinimum':0,'objectivesText':0,'starters':0,'finishers':0,'prerequisiteLinks':0}
Q=lua.globals().LibQuestieDB.Quest
for _,q in A.quests.items():
 id=q.id
 if not Q.Exists(id):coverage['missing'].append(id);continue
 coverage['providerFound']+=1
 if Q.Get(id,'requiredLevel')>0:coverage['positiveMinimum']+=1
 for field,out in [('objectivesText','objectivesText'),('startedBy','starters'),('finishedBy','finishers')]:
  v=Q.Get(id,field)
  if v is not None and any(True for _ in v.items()):coverage[out]+=1
 if Q.Get(id,'preQuestGroup') or Q.Get(id,'preQuestSingle'):coverage['prerequisiteLinks']+=1
print(json.dumps(coverage))
# Presence-only audit: no QuestieDB field contents are written or bundled.
presence={}
for sid in json.loads((root/'data/walkthroughs.json').read_text(encoding='utf-8')):
 id=int(sid)
 if not Q.Exists(id):continue
 fields=[]
 for local,remote in [('minLevel','requiredLevel'),('level','questLevel'),('objectives','objectivesText'),('all','preQuestGroup'),('any','preQuestSingle'),('raceMask','requiredRaces'),('classMask','requiredClasses')]:
  value=Q.Get(id,remote)
  if value is not None and (not isinstance(value,(int,float)) or value>0):fields.append(local)
 presence[sid]=fields
(root/'data/provider-field-coverage.json').write_text(json.dumps({'version':meta['Version'],'flavour':'Forever','contract':4,'fields':presence,'coverage':coverage},indent=2)+'\n',encoding='utf-8')
lua.execute('''
-- Real public API values, fallback provenance and reviewed corrections coexist.
local q=A.byID[168]
assert(q.name==LibQuestieDB.Quest.Get(168,"name"))
assert(q.minLevel==LibQuestieDB.Quest.Get(168,"requiredLevel"))
assert(A.walkthroughs[2948].all[1]==2947)
assert(A.walkthroughs[2950].all[1]==2949)
assert(A.walkthroughs[95737].breadcrumbFor==95647)
-- Live acceptance/history outrank stale restrictions, unknown levels and chains.
for _,profile in ipairs({{"Alliance","Human","WARRIOR"},{"Alliance","Gnome","MAGE"},{"Horde","Orc","SHAMAN"},{"Horde","Scourge","WARLOCK"}}) do
 faction,race,class=unpack(profile)
 for _,q in ipairs(A.quests) do
  completed={}; A.db.confirmed={}; A.log={[q.id]={complete=false}}; A.offers={}
  assert(A.Status(q)=="active",q.id)
  assert(not A.Restriction(q),q.id)
  A.log[q.id].complete=true; assert(A.Status(q)=="ready",q.id)
  A.log={}; completed[q.id]=true; assert(A.Status(q)=="done",q.id)
 end
end
completed={}; A.db.confirmed={}; A.log={}; A.offers={}; faction="Alliance"; race="Human"; class="WARRIOR"
-- Actual API is wrapped only for controlled failure/default injection.
local original=LibQuestieDB.Quest.Get
LibQuestieDB.Quest.Get=function(id,key) if id==168 and key=="requiredLevel" then return 0 end; return original(id,key) end
A.LoadQuestData(); q=A.byID[168]
assert(q.minLevel==nil and not A.RunReadiness(q),"level="..tostring(q.minLevel))
A.SelectQuest(q); assert(A.window.levelBadge.label:GetText()=="?",tostring(A.window.levelBadge.label:GetText()).." "..tostring(A.window.detailTitle:GetText()))
assert(select(2,A.WalkStep(q))=="check",tostring(select(2,A.WalkStep(q))))
A.offers[168]=true; assert(select(2,A.WalkStep(q))=="pickup")
A.offers={}; LibQuestieDB.Quest.Get=original
local saved=LibQuestieDB; LibQuestieDB=nil
assert(not A.LoadQuestData() and A.providerError)
assert(not A.RunReadiness(q))
LibQuestieDB=saved; local flavor=saved.flavor; saved.flavor={name="Classic"}
assert(not A.LoadQuestData()); saved.flavor=flavor
local requireContract=saved.RequireContract; saved.RequireContract=function() return false end
assert(not A.LoadQuestData()); saved.RequireContract=requireContract
assert(A.LoadQuestData() and not A.providerError)
-- Missing completion APIs never create completed/readied entries.
local history=C_QuestLog.IsQuestFlaggedCompleted
C_QuestLog.IsQuestFlaggedCompleted=function() return nil end
A.log={}; A.db.confirmed={}; assert(A.Completed(168)==nil and not A.RunReadiness(A.byID[168]))
C_QuestLog.IsQuestFlaggedCompleted=history
print("PASS: installed QuestieDB public API; "..(#A.quests*4).." live-state profile cases; levels/defaults, reviewed chains, breadcrumbs, missing/incompatible provider, history failure and catalogue map/detail coverage")
''')
lua.execute('''
completed={}; A.db.confirmed={}; A.log={}; log={}; A.offers={}; level=60
faction="Alliance"; race="Human"; class="WARRIOR"
assert(not A.Restriction(A.byID[168]),"Neutral class mask must not create class NONE")
assert(A.Restriction(A.byID[1951]),"Mage-only quest must filter warrior")
class="MAGE"; assert(not A.Restriction(A.byID[1951])); class="WARRIOR"
faction="Horde"; race="Orc"; assert(A.Restriction(A.byID[168]))
faction="Alliance"; race="Human"
local original=LibQuestieDB.Quest.Get
LibQuestieDB.Quest.Get=function(id,key)
 if id==168 and key=="preQuestGroup" then return {9999999} end
 return original(id,key)
end
A.LoadQuestData(); local q=A.byID[168]
assert(select(2,A.WalkStep(q))=="check" and not A.RunReadiness(q))
A.offers[168]=true; level=1
assert(select(2,A.WalkStep(q))=="pickup")
A.offers={}; level=60; LibQuestieDB.Quest.Get=original; A.LoadQuestData()
local objectives=C_QuestLog.GetQuestObjectives
C_QuestLog.GetQuestObjectives=function(id) return {{text="Live objective progress: 3/7",finished=false}} end
log={{questID=168,title=q.name,complete=false}}; A.SelectQuest(q)
assert(A.window.detailText:GetText():find("Live objective progress: 3/7",1,true),A.window.detailText:GetText())
assert(not A.window.detailText:GetText():find("Quest chain",1,true))
C_QuestLog.GetQuestObjectives=objectives; log={}; A.log={}
-- Provider data never changes saved settings or stores database rows in SavedVariables.
local saved=A.db; local position=saved.position; local minimap=saved.minimap
A.LoadQuestData(); assert(A.db==saved and A.db.position==position and A.db.minimap==minimap)
assert(not A.db.providerData and not A.db.quests)
print("PASS: unaccepted faction/class masks, missing prerequisite, live objective precedence and unchanged saved settings")
''')
