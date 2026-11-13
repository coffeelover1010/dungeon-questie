"""Reviewed Dalaran directions; preserve existing prerequisite decisions."""
import json, shutil
from pathlib import Path
root=Path(__file__).resolve().parents[1]
backup=root.parent/'backups'/'dalaran-20261112'
backup.mkdir(parents=True,exist_ok=True)
sources=['https://www.icy-veins.com/wow-forever/city-of-dalaran-quests/','https://www.method.gg/wow-forever/dungeons/city-of-dalaran']
patches={
92456:dict(turnin='Shylamiir in The Park, Stormwind City.',routeNote='Collect a Fel Infused Blossom from the grass near the Fel Ancient encounter in City of Dalaran, then return to Shylamiir in Stormwind.'),
92457:dict(pickup='Image of Archmage Modera outside the Dalaran sewer entrance, Silverpine Forest (68.7, 45.2).',turnin='Image of Archmage Modera outside the Dalaran sewer entrance.',routeNote='Defeat 8 Seeking Remnants, 8 Saturated Remnants and 8 Mana Echoes inside City of Dalaran. Return to Modera outside the entrance when all three objectives are complete.'),
92458:dict(pickup='Image of Archmage Modera outside the Dalaran sewer entrance, Silverpine Forest (68.7, 45.2).',turnin='Image of Archmage Modera outside the Dalaran sewer entrance.',routeNote='Accept the quest to receive the Dalaran Sewer Key. Loot the Arcane Mote from the Shade of the Archmage, then return to Modera outside the entrance.',preparationNote='An Alarming Request from Emissary Jacques in Southshore town hall leads to Modera. Visit Jacques if Modera does not offer Heart of Disruption.'),
92489:dict(turnin='High Sorcerer Andromath in the Mage Quarter, Stormwind City.',routeNote='Defeat Arcanic Enigma in City of Dalaran, then return to High Sorcerer Andromath in Stormwind. No quest item needs to be looted.'),
}
for filename in ['catalogue-overrides.json','walkthrough-overrides.json']:
 p=root/'data'/filename
 shutil.copy2(p,backup/filename)
 data=json.loads(p.read_text(encoding='utf-8'))
 for ident,patch in patches.items():
  node=data.setdefault(str(ident),{})
  node.update(patch)
  node['fieldChecked']='2026-11-12'
  node.setdefault('fieldSources',{}).update({field:sources[0] for field in patch})
  if filename=='walkthrough-overrides.json' and ident in (92456,92457,92489):
   node.update(unverifiedChain=False,chainSource=sources[1],chainChecked='2026-11-12')
 p.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
(root/'data/dalaran-review-2026-11-12.json').write_text(json.dumps(dict(sources=sources,patches=patches,notes='Standard direct pickups reviewed for Green Sample, Starving Arcane and Power Overwhelming. Existing Alliance Heart prerequisite decision retained because guides disagree about mandatory introduction. No new coordinates inferred.'),indent=2)+'\n',encoding='utf-8')
