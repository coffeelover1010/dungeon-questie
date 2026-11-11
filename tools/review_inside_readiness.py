"""Apply the sourced 2026-11-10 inside-pickup review, preserving unrelated overrides."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
path=root/'data/walkthrough-overrides.json'
overrides=json.loads(path.read_text(encoding='utf-8'))
sources={
 'hall':'https://warcraft.blizzplanet.com/hall-of-thanes-dungeon-world-of-warcraft-forever/',
 'ruins':'https://www.icy-veins.com/wow-forever/ruins-of-lordaeron-quests',
 'wetlands':'https://www.warcrafttavern.com/forever/guides/excavation-site-wetlands-quests',
 'relic':'https://www.wowhead.com/forever/item=270866/titan-relic',
 'ring':'https://questing.wiki/wow-forever/quests/2945/',
 'dalaran':'https://www.icy-veins.com/wow-forever/city-of-dalaran-quests/',
}
reviewed={96395:'hall',98423:'hall',95250:'ruins',97288:'ruins',92415:'ruins',95195:'ruins',95189:'ruins',95204:'ruins',95664:'relic',95809:'wetlands',2947:'ring',2949:'ring',96987:'dalaran'}
patches={}
for ident,source in reviewed.items():
 patches[ident]={'unverifiedChain':False,'pickupInside':True,'chainSource':sources[source],'chainChecked':'2026-11-10','readinessReviewed':'2026-11-10'}
for ident in (2947,2949):
 patches[ident].update(all=[2945],any=[],turninInside=False,dungeonObjective=False)
patches[95809].update(all=[95647],any=[],turninInside=False,dungeonObjective=False)
for ident in (96395,95250,96987): patches[ident].update(turninInside=True,dungeonObjective=True)
patches[95195].update(turninInside=False,dungeonObjective=True)
for ident in (98423,97288,92415,95189,95204,95664): patches[ident].update(turninInside=False,dungeonObjective=False)
patches[95664]['turnin']='Bashana Runetotem, Elder Rise, Thunder Bluff.'
patches[96395]['turnin']='Ghostly Attendant inside the Hall of Thanes.'
patches[95250]['turnin']='Captain Truman inside Ruins of Lordaeron.'
patches[96987]['turnin']='Rexxie Copperclutch inside City of Dalaran, near the sewer entrance.'
for ident,source in ((2945,'ring'),(95647,'wetlands')):
 patches[ident]={'dungeonObjective':True,'turninInside':True,'readinessReviewed':'2026-11-10','readinessSource':sources[source]}
unresolved={
 3366:'This older Glowing Shard quest variant is not in the installed Forever QuestieDB. Use the Glowing Shard to check which quest ID it offers; the recorded current item-start variant is 6981.',
 78916:'The Perfect Blackfathom Pearl quest is recorded in a beta cache, but its current availability and minimum acceptance level are not confirmed. Check the quest offered by the item.',
 78917:'The Perfect Blackfathom Pearl quest is recorded in a beta cache, but its current availability and minimum acceptance level are not confirmed. Check the quest offered by the item.',
}
for ident,note in unresolved.items(): patches[ident]={'requirementsNote':note,'readinessReviewed':'2026-11-10'}
for ident,patch in patches.items(): overrides.setdefault(str(ident),{}).update(patch)
path.write_text(json.dumps(overrides,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
report={'checked':'2026-11-10','scope':'16 previously flagged inside-pickup quests; no inference of availability from missing QuestieDB fields.',
 'questieDBVersion':'1.0.13','resolved':list(reviewed),'remaining':unresolved,'supportingSteps':[2945,95647],
 'sources':sources,'patches':patches}
(root/'data/inside-readiness-review-2026-11-10.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('Reviewed 16 inside-pickup quests: 13 corrected, 3 retained with specific evidence gaps; 2 precursor location records corrected.')
