# Credits and licences

Original Dungeon Questie code: Copyright (c) 2026 Videocat, MIT (LICENSE).

Classic reference data in `data/classic-source.json`, `data/walkthroughs.json`
and `WalkthroughData.lua` is adapted from CMaNGOS Classic-DB, GPL version 3.
The original code retains its MIT permission. Libraries retain their individual
terms. This is a mixed-licence distribution; do not describe the whole package
as MIT-only. The editable data and generation tools accompany the data.

- Project: https://github.com/cmangos/classic-db
- Exact revision and archive hash: `data/classic-source-provenance.json`.
- Licence: `licenses/ClassicDB-LICENSE.md`.
- Authors: `licenses/ClassicDB-AUTHORS`.
- Blizzard material notice: `licenses/ClassicDB-COPYRIGHT.md`.
- Modifications made 3 October 2026: extracted selected quest/entity fields,
  converted relationships to our checklist schema, generated short objective
  labels, and merged separately researched Forever records. Quest dialogue,
  descriptions, SQL scripts and server implementation are not included.
- Corresponding editable source, importer and generator are included in the
  source repository and source archive distributed with the release.

Map rectangle facts come from the WoW 1.12.1.5875 WorldMapArea client table as
published by Thomas Laurenson in wow-vanilla-world-coords. That project's MIT
notice is included in `licenses/world-coords-MIT.txt`; the pinned revision is
in `data/worldmaparea-revision.txt`.
https://github.com/TheGrayDot/wow-vanilla-world-coords

Minimap libraries: see `Libs/NOTICE.txt` and `Libs/Ace3-LICENSE.txt`.
LibDataBroker is embedded as directed by its upstream project:
https://www.wowace.com/projects/libdatabroker-1-1

Questie is used only for a separate local comparison, not as a build input.
No Questie database, implementation or generated research copy is distributed.
Dungeon Questie is an independent addon and is not affiliated with Questie.

World of Warcraft names, quest content and game artwork belong to Blizzard
Entertainment or its licensors. No extracted artwork is bundled; runtime
artwork references the installed client. User-provided screenshots contain
Blizzard game artwork and are not relicensed as original artwork.
