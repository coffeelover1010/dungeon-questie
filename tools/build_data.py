"""Merge beta facts with explicitly labelled guide/reference records."""
import json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
qs=json.loads((ROOT/'data/quests.json').read_text(encoding='utf-8'))
by={q['id']:q for q in qs}
GUIDE='https://www.wowhead.com/forever/guide/dungeons/every-dungeon-quest-location'
for q in qs:
    q['pickup']='Pickup location not yet verified. Check the source and quest notes.'
    q['notes']='Reported from a beta quest cache; availability and rewards may change. NPC names read from quest text are not proof of a pickup location.'
    q['prereqs']=[c['id'] for c in q['chain'] if c['role']=='Comes after' and c.get('id')]
    if q['dungeons'][0] in ['Ragefire Chasm']: q['faction']='Horde'
    if q['dungeons'][0] in ['Deadmines','Stormwind Stockade']: q['faction']='Alliance'
for ids,faction in [([1489,1490,962,914,1098,1013,1014,6564,6563,6562,6565,2842,2843,92422,95204],'Horde'),([971,1198,1275,2922,2923,2926,2927,2928,96393],'Alliance')]:
    for i in ids: by[i]['faction']=faction
by[1740]['class']='WARLOCK'; by[1740]['dungeons'].append('Blackfathom Deeps')

def add(i,name,dungeon,level,faction=None,pickup='',prereqs=None,evidence='Classic reference'):
    q=dict(id=i,name=name,dungeons=dungeon if isinstance(dungeon,list) else [dungeon],minLevel=level,faction=faction,pickup=pickup,prereqs=prereqs or [],objectives=[],rewards=[],people=[],chain=[],source='https://www.wowhead.com/forever/quest='+str(i),evidence=evidence,checked='2026-10-01',notes='Listed in the Forever dungeon guide, which uses Classic reference data for untested content. Confirm in the current beta before travelling.')
    qs.append(q); by[i]=q
    return q

add(98423,'The Treaty of Understanding','The Hall of Thanes',16,'Alliance','Interact with the treaty vault in the Reliquary of Kings inside the dungeon.',evidence='Forever database')['notes']='Bring the treaty to King Magni Bronzebeard. Pickup level is guide-reported.'
add(96391,'Underground Map','The Hall of Thanes',9,'Alliance','Dark Iron Map drop from Dark Iron Spies in Dun Morogh.',evidence='Forever database')['notes']='Prerequisite to Old Ironforge Incursion. Bring the map to Earthseer Farsen; reported drop area 77, 60 is not verified on the current map.'
by[96393]['prereqs']=[96391]
add(378,'The Fury Runs Deep','Stormwind Stockade',25,'Alliance','Motley Garmason, Dun Modr, Wetlands.',[303])
for i,n,l,loc,pre in [(2924,'Essential Artificials',24,'Klockmort Spannerspan, Tinkertown, Ironforge.',[]),(2930,'Data Rescue',25,'Master Mechanic Castpipe, Tinkertown, Ironforge.',[]),(2929,'The Grand Betrayal',25,'High Tinker Mekkatorque, Tinkertown, Ironforge.',[]),(2962,'The Only Cure is More Green Glow',20,'Ozzie Togglevolt, Kharanos, Dun Morogh.',[2926])]: add(i,n,'Gnomeregan',l,'Alliance',loc,pre)
add(2841,'Rig Wars','Gnomeregan',25,'Horde','Nogg, Valley of Honor, Orgrimmar.')
add(2951,'The Sparklematic 5200!','Gnomeregan',25,None,'Sparklematic machine in the Clean Zone; requires a Grime-Encrusted Object.')['repeatable']=True
add(2945,'Grime-Encrusted Ring','Gnomeregan',28,None,'Quest-starting ring drop inside Gnomeregan.')
add(1102,'A Vengeful Fate','Razorfen Kraul',29,'Horde','Auld Stonespire, Thunder Bluff.')
add(1109,'Going, Going, Guano!','Razorfen Kraul',30,'Horde','Master Apothecary Faranell, Undercity.')
add(6522,'An Unholy Alliance','Razorfen Kraul',28,'Horde','Small Scroll dropped by Charlga Razorflank.')
add(1101,'The Crone of the Kraul','Razorfen Kraul',29,'Alliance','Falfindel Waywarder, Feralas. Complete Lonebrow\'s Journal first.')
add(1142,'Mortality Wanes','Razorfen Kraul',25,'Alliance','Heralath Fallowbrook inside the dungeon, behind the final boss.')
for i,n,l,f,loc,pre in [(1048,'Into The Scarlet Monastery',33,'Horde','Varimathras, Undercity.',[]),(1053,'In the Name of the Light',34,'Alliance','Raleigh the Devout, Southshore. Chain starts with Brother Anton.',[]),(1051,"Vorrel's Revenge",25,'Horde','Vorrel Sengutz inside the Graveyard wing.',[]),(1113,'Hearts of Zeal',30,'Horde','Master Apothecary Faranell, Undercity.',[1109]),(1049,'Compendium of the Fallen',28,'Horde','Sage Truthseeker, Thunder Bluff. Not offered to Undead.',[]),(1160,'Test of Lore',25,'Horde','Parqual Fintallas, Undercity. Long chain starts with Test of Faith.',[]),(1050,'Mythology of the Titans',28,'Alliance','Librarian Mae Paledust, Ironforge.',[]),(1951,'Rituals of Power',30,None,'Magus Tirth, Shimmering Flats. Mage chain starts with Journey to the Marsh.',[])]: add(i,n,'Scarlet Monastery',l,f,loc,pre)
by[1049]['excludeRace']='Scourge'; by[1951]['class']='MAGE'
add(1654,'The Test of Righteousness',['Deadmines','Shadowfang Keep','Blackfathom Deeps'],20,'Alliance','Jordan Stilwell outside Ironforge. Complete the Tome of Valor chain first.')['class']='PALADIN'
add(6921,'Amongst the Ruins','Blackfathom Deeps',21,'Horde',"Je'neu Sancrea, Zoram'gar Outpost.")
add(6922,'Baron Aquanis','Blackfathom Deeps',21,'Horde','Strange Water Globe dropped by Baron Aquanis.')

# Pickup points are factual guide coordinates. Never substitute an outdoor map for an interior floor.
def pin(ids,zone,mapid,x,y,npc):
    for i in ids:
        q=by[i]; q['pickup']=npc+' - '+zone
        q['pin']=dict(map=mapid,x=x,y=y,zone=zone,title=npc)
        q['locationSource']=GUIDE
for row in [([5723,5724],'Thunder Bluff',1456,70,30,'Rahauro'),([5761],'Orgrimmar',1454,49,50,'Neeru Fireblade'),([5728],'Orgrimmar',1454,31,37,'Thrall'),([5725],'Undercity',1458,56,92,'Varimathras'),([168,167],'Stormwind City',1453,65,21,'Wilder Thistlenettle'),([2040,2928],'Stormwind City',1453,55,13,'Shoni the Shilent'),([214,166],'Westfall',1436,56,47,'Sentinel Hill - Scout Riell / Gryan Stoutmantle'),([1491,1221],'The Barrens',1413,62,37,'Mebok Mizzyrix'),([959],'The Barrens',1413,63,37,'Crane Operator Bigglefuzz'),([1486,1487],'The Barrens',1413,46,35,'Nalpak / Ebru - cave above the entrance'),([962],'Thunder Bluff',1456,34,21,'Apothecary Zamah'),([914,1490],'Thunder Bluff',1456,45,23,'Nara Wildmane'),([1013],'Undercity',1458,53,54,"Keeper Bel'dugur"),([1098],'Silverpine Forest',1421,43,41,'High Executor Hadrec'),([1014],'Silverpine Forest',1421,44,39,'Dalar Dawnweaver'),([1740],'The Barrens',1413,49,57,'Doan Karhan'),([6563,6565,6921],'Ashenvale',1440,11,34,"Je'neu Sancrea"),([971],'Ironforge',1455,50,5,'Gerrig Bonegrip'),([1275],'Darkshore',1439,38,43,'Gershala Nightwhisper'),([1198,1199],'Darnassus',1457,55,24,'Dawnwatcher Shaedlass / Argent Guard Manados'),([387,391],'Stormwind City',1453,41,58,'Warden Thelwater'),([386],'Redridge Mountains',1433,26,46,'Guard Berton'),([378],'Wetlands',1437,49,18,'Motley Garmason'),([2922],'Ironforge',1455,69,50,'Tinkmaster Overspark'),([2930],'Ironforge',1455,69,48,'Master Mechanic Castpipe'),([2929],'Ironforge',1455,68,49,'High Tinker Mekkatorque'),([2926,2962],'Dun Morogh',1426,45,49,'Ozzie Togglevolt'),([2841,2842],'Orgrimmar',1454,76,25,'Nogg / Sovik'),([2843],'Stranglethorn Vale',1434,27,77,'Scooty'),([1102],'Thunder Bluff',1456,37,29,'Auld Stonespire'),([1109,1113],'Undercity',1458,48,69,'Master Apothecary Faranell'),([1050],'Ironforge',1455,75,12,'Librarian Mae Paledust'),([1951],'Thousand Needles',1441,78,75,'Magus Tirth'),([1654],'Dun Morogh',1426,52,36,'Jordan Stilwell')]: pin(*row)
by[92401]['pickup']='Tabitha Heartweaver - The Sepulcher, Silverpine Forest'
by[92401]['pin']=dict(map=1421,x=44.5,y=43,zone='Silverpine Forest',title='Tabitha Heartweaver')
by[92401]['locationSource']='https://www.icy-veins.com/wow-forever/ruins-of-lordaeron-quests'
by[96394]['pickup']='Afadra Dunwall, Old Ironforge. Published coordinates conflict; no reliable map pin.'
by[96403]['pickup']='Thom Filch, Old Ironforge. Interior map coordinates not verified.'
by[96395]['pickup']="Ghostly Attendant, Anvilmar's Rest inside Hall of Thanes."
by[96393]['pickup']="Earthseer Farsen, Gol'Bolar Quarry in Dun Morogh, after Underground Map."
by[373]['pickup']='Loot An Unsent Letter from Edwin VanCleef in Deadmines.'
by[5722]['pickup']='Maur Grimtotem / satchel inside Ragefire Chasm; check both satchel quests.'
by[3366]['pickup']='Glowing Shard dropped by Mutanus in Wailing Caverns.'
by[6981]['pickup']='Glowing Shard variant; check the current quest offered by the item.'
for i in [1200,6561]: by[i]['pickup']='Argent Guard Thaelrid, alcove southwest of Ghamoo-ra inside Blackfathom Deeps.'
by[1144]['pickup']='Willix, tent near the final boss inside Razorfen Kraul. Escort him out with your party.'
by[2904]['pickup']='Kernobee, room beside the Clean Zone in Gnomeregan; escort quest.'
by[388]['pickup']='Nikova Raskol patrols Old Town, Stormwind.'
by[377]['pickup']='Councilman Millstipe in Darkshire, Duskwood. Conflicting guide coordinates withheld.'
by[92422]['pickup']='Deathguard Kristof, Brill, Tirisfal Glades.'
by[95195]['pickup']='Quest-starting Bloodied Insignia; bring it to General Marcus Jonathan in Stormwind.'
for i in [95189,95204]: by[i]['pickup']='Crest item found inside Ruins of Lordaeron; faction-specific quest.'
by[92415]['pickup']='Quest-starting item in Ruins of Lordaeron. Exact drop location unverified.'
by[92753]['pickup']='Alba Fairmoon in Westfall. Progress her quest chain starting with Testing the Wells before entering Deadmines.'
by[92753]['preparationNote']='Requires the Westfall chain starting with Testing the Wells. Check your progress with Alba Fairmoon; the guide does not yet track every step.'
by[92753]['locationSource']='https://www.icy-veins.com/wow-forever/deadmines-quests'
by[92753]['pickupInside']=False
by[92753]['rewards']=[]
by[97288]['pickup']='Quest-starting item in Ruins of Lordaeron; the chain has multiple distinct steps.'
by[97288]['notes']+=' Only the initial quest ID is represented in this cache capture; later turn-ins are not implied by completing it.'

# Preserve higher-level reference quests without representing them as beta-tested.
rename={"Temple of Atal'Hakkar - Sunken Temple":'Sunken Temple','Blackrock Depths BRD':'Blackrock Depths','Lower Blackrock Spire - LBRS':'Lower Blackrock Spire','Upper Blackrock Spire - UBRS Dungeon Quests (56 58 59)':'Upper Blackrock Spire'}
for r in json.loads((ROOT/'data/reference.json').read_text(encoding='utf-8')):
    d=rename.get(r['dungeon'],r['dungeon'])
    # The source heading places several Dire Maul rows under LBRS by mistake.
    if r['link'] in [351,356,358,361,362,364]: d='Dire Maul'
    if r['id'] in by:
        if d not in by[r['id']]['dungeons']: by[r['id']]['dungeons'].append(d)
        continue
    f=r['faction'] if r.get('faction') in ['Alliance','Horde'] else None
    q=add(r['id'],r['name'],d,r['minLevel'],f,r['pickup'])
    q['notes']+=' '+r.get('note','')
    if not r.get('faction'): q['restrictionUnknown']=True
    m=re.search(r'(Mage|Paladin|Warlock|Shaman|Warrior|Druid|Priest|Rogue|Hunter) Only',r['pickup'])
    if m:q['class']=m[1].upper()
    # Coordinates in the reference stay as text until their map is cross-checked.
    q['notes']+=' Reference coordinates are not pinned until checked against a Forever map.'
# Reviewed cache refreshes augment the baseline without discarding curated locations.
refresh=ROOT/'data/beta-refresh.json'
if refresh.exists():
    for fresh in json.loads(refresh.read_text(encoding='utf-8')):
        q=by.get(fresh['id'])
        if q is None:
            q=dict(id=fresh['id'],pickup='Pickup location not verified; check the source before travelling.',prereqs=[],notes='Reported from a beta cache; pickup and prerequisite requirements need verification.')
            qs.append(q); by[q['id']]=q
        memberships=list(dict.fromkeys(q.get('dungeons',[])+fresh['dungeons']))
        q.update(fresh); q['dungeons']=memberships
        # Existing reference restrictions and chains are not promoted by a cache refresh.
        if not q.get('prereqs'):
            q['prereqs']=[c['id'] for c in fresh.get('chain',[]) if c['role']=='Comes after' and c.get('id')]
        if q.get('notes','').startswith('Listed in the Forever dungeon guide'):
            q['notes']='Quest fields now have beta-cache evidence. Earlier guide pickup and prerequisite details retain their original reference status.'
add(92819,'Destruction in Deadmines','Deadmines',9,'Alliance',
    'Alba Fairmoon at the Deadmines rear exit, in the hills behind Moonbrook.',
    [92753],evidence='Forever database')

overrides=ROOT/'data/catalogue-overrides.json'
if overrides.exists():
    for quest_id,patch in json.loads(overrides.read_text(encoding='utf-8')).items():
        if int(quest_id) not in by: raise ValueError(f'Override targets missing quest {quest_id}')
        by[int(quest_id)].update(patch)

# Explicit beta pickup locations supersede rounded older guide coordinates.
coordinates=ROOT/'data/source-coordinates.json'
if coordinates.exists():
    for quest_id,patch in json.loads(coordinates.read_text(encoding='utf-8')).items():
        by[int(quest_id)].update(patch)

order=['The Hall of Thanes','Ragefire Chasm','Deadmines','Wailing Caverns','Ruins of Lordaeron','Shadowfang Keep','Blackfathom Deeps','Stormwind Stockade','Excavation Site: Wetlands','Razorfen Kraul','Gnomeregan','Scarlet Monastery','Razorfen Downs','Uldaman',"Zul'Farrak",'Maraudon','Sunken Temple','Blackrock Depths','Dire Maul','Lower Blackrock Spire','Upper Blackrock Spire','Scholomance','Stratholme']
gaps=['City of Dalaran','The Drowned City',"Krol'dok Stronghold",'Alcaz Prison','Blackmaw Hold',"The Shaper's Terrace"]
names=order+gaps
populated={d for q in qs for d in q['dungeons']}
notes_path=ROOT/'data/dungeon-notes.json'
notes=json.loads(notes_path.read_text(encoding='utf-8')) if notes_path.exists() else {}
dungeons=[dict(name=n,note=notes.get(n,'Beta-reported records plus labelled reference additions. Coverage is incomplete; access is not implied by quest level.' if n in populated else 'No curated Forever quest records in this version. This is a coverage gap, not a claim that the dungeon has no quests.')) for n in names]
def lua(v):
    if v is None:return 'nil'
    if v is True:return 'true'
    if v is False:return 'false'
    if isinstance(v,(int,float)):return str(v)
    if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
    if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
    return '{'+','.join('['+lua(k)+']='+lua(x) for k,x in v.items() if x is not None)+'}'
assert len(qs)==len({q['id'] for q in qs})
data_date=max(q['checked'] for q in qs)
(ROOT/'Data.lua').write_text('local _, A = ...\nA.dataDate='+lua(data_date)+'\nA.dungeons='+lua(dungeons)+'\nA.quests={\n'+',\n'.join(lua(q) for q in qs)+'\n}\n',encoding='utf-8')
(ROOT/'data/catalogue.json').write_text(json.dumps(qs,indent=2,ensure_ascii=False),encoding='utf-8')
print(f'{len(qs)} quests; {sum(bool(q.get("pin")) for q in qs)} pickup pins; {len(populated)} populated dungeon groups; {len(set(names)-populated)} explicit coverage gaps')
