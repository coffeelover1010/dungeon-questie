> Current follow-up: [13 November review](RESEARCH-2026-11-13.md), version 0.2.1,
> tested with installed QuestieDB 1.1.0. The figures below describe the earlier
> migration. New independent corrections live in data/forever-review-2026-11-13.json
> and are applied last by all three generators. Unknown eligibility is visible;
> temporary conditions do not participate in the permanent character filter.

# QuestieDB integration — 12 November 2026

Dungeon Questie requires the separately installed **QuestieDB for Forever**.
**Questie itself is optional**, as is TomTom. No release was published.
Enable both QuestieDB and Dungeon Questie in the AddOns list, then `/reload`.
Restart the client if a newly installed dependency is absent from that list.

## Audited installation and public contract

Installed provider: QuestieDB **1.0.14**, Interface **16001**, baked **Forever**,
contract **4** (minimum supported consumer contract 1), commit
`e19dfdf8528334ea63da0ecc4e291c134c0fc266`.
SHA-256 of `QuestieDB_Forever.toc`:
`3A077D61306CCCBAC1C8F9DF6114E337EC7BAF13F2736990259D8236F877A078`.
The reproducible-build timestamp in the TOC is not a data freshness date.

Reviewed installed `src/api.lua`, `Types/Quest.t.lua`, `Types/General.t.lua`,
`src/meta/normalize.lua`, `src/read/shared.lua`, `src/config.lua`, the support API,
and LICENSE.md. Public `RequireContract(4)` and `flavor.name == "Forever"` are
checked at load and login. Public `Quest.Exists`, `Quest.Get`, `Npc.Get`,
`Object.Get`, `Item.Get`, `Enum` and `Support.Get("ZoneDB")` are used. No Questie
internal globals, provider backend rows or TOC metadata are read at runtime.
The offline fixture loads the installed provider itself, emulating only client
metadata, encoding and UI APIs. It does not include Questie or copy provider code.

| Catalogue field | Available through installed API |
| --- | ---: |
| Quest records | 264 / 266 |
| Positive minimum level | 263 |
| Objective text | 260 |
| Starter relations | 257 |
| Finisher relations | 259 |
| Nonempty prerequisite links | 85 |

IDs 3366 and 3911 are absent. Counts describe field presence, not proof of current
server availability. Structured objective tuples are also read; available NPC,
object and item objective labels supplement absent objective text. Map relations
include item drops and dungeon approaches via provider support tables.

Numerics default to zero, including `GetRaw`; missing quests return nil. Zero
minimum levels are unknown, never level 0 or an inferred level 1. Empty starter,
finisher and objective structures do not establish verified absence. Nil
prerequisite arrays retain independent fallback links. A missing field removed
from the slim local export stops readiness rather than silently dropping a gate.

## Precedence and retained data

1. Live game acceptance, objective progress, completion flags and confirmed turn-ins;
   actual NPC offers override guide eligibility. Closing an interaction clears offers.
2. Explicit reviewed local corrections exported from the existing catalogue and
   walkthrough override JSON files; null removals are preserved.
3. QuestieDB composed public reads, including provider corrections and localization.
4. Independently sourced local missing-field fallbacks, with unresolved requirement
   guards retained. Unknown completion, levels, missing prerequisite records and
   cycles never establish readiness. Profession/reputation/item/spell requirements
   that cannot be evaluated safely wait for an actual offer or acceptance.

`LocalData.lua` retains dungeon selection/grouping, checklist variants, inside versus
outside work, names for fallback display, reward IDs, custom mechanics, missing
quest/field records, and fallback routes/pins. `ProviderCorrections.lua` contains
explicit reviewed requirement and location exceptions, not copies from QuestieDB.
`Provider.lua` reads the provider and closes the graph over linked prerequisites,
exclusions, breadcrumbs and next-step hints. Next-step hints are never invented
mandatory edges. Optional breadcrumbs are removed from required predecessor lists.

The slim runtime export removes **2,103 provider-backed field copies** from our
old exports after the actual provider integration passed offline checks. Full
`Data.lua`, `WalkthroughData.lua` and research JSON remain in the repository for
review/rebuilds; they are no longer loaded or installed. Old installed exports are
removed only after backing up the addon and verifying the replacement hashes.
The presence-only audit stores field names and counts, never provider field values.

QuestieDB has no quest reward-item list in this contract. Local reward item IDs
remain; game APIs supply cached item names, icons, links, previews and tooltips.
Item names fall back to existing local names while the game cache loads.
Rewards remain those of the selected goal, labelled with its name when viewing a
prerequisite. Checklist cards, expandable chain navigation, map and quest-log
buttons remain. Details show Pick up, Objectives, Return to and Rewards, plus
useful custom mechanics; the full chain stays in navigation rather than repeating
in the details. Coordinates are available through map buttons.

## Licensing and integration requirements

QuestieDB is installed and updated separately; do not bundle its database, source,
schema, decoder, logo or extracted values in this addon or release archives.
The [upstream public API documentation](https://github.com/Questie/QuestieDB/blob/master/README.md)
describes independent consumers and compatibility checks. The
[upstream licence](https://github.com/Questie/QuestieDB/blob/master/LICENSE.md)
(and the inspected installed LICENSE.md) gives file-specific terms priority,
contains consent-based GPLv3 coverage, and retains an all-rights-reserved caveat
for uncovered historical contributions. It is not blanket GPL permission for all
provider content or branding. This migration uses separate runtime API access;
it does not relicense provider content or claim affiliation. Existing CMaNGOS
fallbacks retain their GPLv3 notices and editable sources; original adapter code
retains this project's MIT licence. See THIRD-PARTY-NOTICES.md.

## Rebuild, offline verification and live checks

After changing local research inputs, rebuild the original catalogue/walkthrough
exports using their existing procedure, then run from the repository directory:

```powershell
uv run python tools/build_provider_corrections.py
uv run --with lupa --with cbor2 python tools/check_provider.py
uv run python tools/build_local_data.py
uv run --with lupa --with cbor2 python tools/check_provider.py
```

The checked-in presence audit permits the first slim build. Review a changed
provider's coverage before accepting newly removed local fields. The runtime does
not depend on the offline audit file. Existing tests exercise the retained research
fallbacks; `check_provider.py` exercises the actual slim runtime with installed
QuestieDB, including 1,064 quest/profile acceptance/completion scenarios, default
levels, dependency/flavour/contract failures, reviewed ring links, breadcrumbs,
missing history and all catalogue map/detail paths. Other regression scripts cover
chains, cards, offers, readiness, targeting, maps, rewards and settings.

These are **offline tests**, not live-client verification. After `/reload`, check:

- QuestieDB enabled with Questie disabled: `/dungeons` opens without Lua errors.
- Gnomeregan ring chains and Blackfathom inside pickup/turn-in readiness; Dalaran
  faction restrictions and key preparation; optional breadcrumbs stay optional.
- Accept, abandon, complete objectives and turn in a quest: only an actual turn-in
  or game completion flag marks it completed. Accepted later steps stay current.
- Unknown minimum levels show `?`; another class/faction's unaccepted quests stay
  filtered. Saved position, minimap and selected dungeon remain intact.
- Compact cards, expanded chains, current-step quest-log/target buttons, map pins,
  turn-in destinations, reward names/icons/tooltips, and detail text bounds.

Use `tools/install.ps1` for the backed-up, SHA-256-verified local installation.
No publish, release, commit or push is part of this migration.

Offline result (12 November 2026): PASS for `check_provider.py`,
`check_walkthroughs.py`, `check_actions.py`, `check_chain_groups.py`,
`check_chain_progress.py`, `check_readiness_review.py`, `check_locations.py`,
`check_guide_availability.py`, `check_quest_cards.py`, `check_display_wording.py`,
`check_shard_variants.py`, `check_quest_groups.py`, `check_group_finder.py` and
`check_recruit.py` (including the shared base checks). Local exports reproduced
byte-for-byte, and `git diff --check` passed. Legacy fixtures exercise the retained
local research records; the dedicated provider fixture separately exercises the
installed public API and slim runtime. No live game interaction was performed.
