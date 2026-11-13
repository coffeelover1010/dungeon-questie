# Current-step routing review — 2026-11-13

The old MapLocation resolver used the associated dungeon entrance whenever pickup/hand-in coordinates were missing, including active outdoor prerequisites. It also treated a prerequisite giver as an objective fallback. Both fallbacks have been removed. Dungeon association remains separate from current-step location.

The shared resolver now chooses pickup coordinates before acceptance, objective coordinates while active, and hand-in coordinates when objectives are complete. Dungeon entrances are used only when RunReadiness confirms current work inside. Single structured NPC/object objectives can use live QuestieDB coordinates. Multiple objectives, item drops and event tasks without explicit objective routing remain unmapped rather than selecting an arbitrary destination. Instructions and map buttons use this resolver. Selected markers are re-resolved and stale native/TomTom waypoints cleared on destination changes; clicking an older map target also re-resolves it.

## Verified Get the Scoop route

- Quest 1950: active objective is “Plucky” Johnson at Mirage Raceway, Thousand Needles. Target the chicken, use `/beckon`, then talk to his human form to obtain the phrase.
- Approximate objective area: 80, 76, not a guaranteed stationary NPC position.
- Once objectives complete, use the recorded Magus Tirth hand-in location.
- After turn-in, collect Rituals of Power (1951) from Magus Tirth. Only the accepted dungeon quest routes to Scarlet Monastery.

Sources checked: [Wowhead Forever quest text and player interaction reports](https://www.wowhead.com/forever/quest=1950/get-the-scoop), [Forever XP location and chain](https://forever-xp.com/quests/1950/), and installed QuestieDB Forever 1.1.0 public records. The Icy Veins quest page could not be accessed. Interaction reports on Wowhead are historical player reports; this has not been tested in a live Forever client.

## Audit and limitations

`data/preparation-routing-audit-2026-11-13.json` inventories all 230 non-catalogue preparation nodes. 21 have a single mapped active objective; 209 lack an exact active-objective route. Some are delivery, multi-objective or event quests; this is a location-coverage count, not evidence that 209 quests are incorrect. Their hand-in locations remain separately recorded. Unmapped active objectives direct the player to quest-log instructions and disable the map destination instead of guessing a dungeon. Catalogue browsing also now exposes missing current-step locations honestly.

Offline checks cover the real 1950→1951 progression, instruction/map agreement, phase transitions and stale selected markers. All 550 graph nodes are exercised through five missing-coordinate phases (2,750 cases) to ensure an unready step cannot inherit a dungeon entrance. Provider-backed map and quest-state tests are also run. No live-client validation is claimed.

## In-game verification

On a mage with Get the Scoop active, open Rituals of Power and its Get the Scoop child: both should show Thousand Needles and the beckon instruction. Use the map button; it must not mark Scarlet Monastery. Obtain the phrase: the next destination must change to Magus Tirth and the old waypoint must clear. Turn in: the pickup remains at Magus Tirth. Accept Rituals of Power: only now should the map suggest Scarlet Monastery. Check a preparation step with no coordinates: its map button should be disabled, with quest-log guidance.
