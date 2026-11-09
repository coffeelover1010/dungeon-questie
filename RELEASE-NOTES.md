# Dungeon Questie 0.1.8

- Show ready counts and green ticks for confirmed quest offers and ready-to-turn-in steps, including prerequisites.
- Distinguish active quests, unknown availability, unavailable offers and skipped optional breadcrumbs.
- Add a manual target button for the current step's recorded quest giver or turn-in NPC, with combat guards.
- Prevent pickup navigation from pointing at a quest that is no longer the current pickup step.
- Simplify the window header, use Blizzard's dungeon minimap icon, and fix dungeon artwork layering.
- Refresh the README with a current in-game screenshot.

Stable release for WoW Forever. Offline Lua, tracking, walkthrough, data reproducibility, group controls and packaging checks passed. The supplied screenshot confirms the updated header and dungeon artwork in game; quest offers, targeting and combat behavior are covered by mocks and still need live verification.

# Dungeon Questie 0.1.7

- Improve walkthrough progression through prerequisite quests and completed steps.
- Correct both Glowing Shard entries with Mutanus, the Fanglord/Disciple event and item-start directions.
- Show recorded pickup directions in dungeon quest rows.

Stable release for WoW Forever. Offline tracking, walkthrough, catalogue and packaging checks passed. Community and Classic-reference data retain their source labels; live quest offers and rendering are not established by these checks.

## 0.1.6 — 7 November 2026

Reviewed against QuestieDB 1.0.11 and fresh quest-cache pages. Resolved 52 faction eligibility gaps, added three Drowned City quests, named Magus Olvek, refreshed pickup coordinates, and replaced blanket confidence labels with source details. Catalogue: 266 quests in 25 populated groups. See RESEARCH-2026-11-07.md for scope and remaining gaps.

# Dungeon Questie 0.1.5 - beta

- Replaced repeated uncertainty wording with a small warning icon beside quest titles. Hover for a short explanation.
- Kept pickup directions visible for incomplete routes.
- Updated Highland Hides to follow Young Crocolisk Skins, with its pickup and objectives.

256 goals and 456 walkthrough records. The icon changes presentation; quest eligibility and readiness rules still apply.

# Dungeon Questie 0.1.4 - beta

- Added the Horde Dalaran sewer-key preparation route and corrected Heart of Disruption's pickup and turn-in.
- Identified Elemental Aid as Shaman-only and added the Alliance Call of Air lead-in.
- Improved Dalaran and Wetlands pickup directions.
- Removed a mandatory Seeking Caitlin detour and flagged conflicting Highland Hides requirements.

256 quest goals and 455 walkthrough records. These are sourced data corrections; disputed requirements remain labelled and still need in-game checks.

# Dungeon Questie 0.1.3 - beta

- Added eight City of Dalaran quests following its beta opening.
- Added Heart of the Void, Elemental Aid, Return of the Ring and Past Due records.
- Refreshed beta quest objectives, rewards and pickup locations.
- Fixed quest-starting items appearing as rewards.
- Includes the existing Scarlet Monastery group search and tank/healer recruitment filters.

256 quest records. Unverified eligibility and chains stay labelled; Drowned City records remain deferred. Elemental Aid eligibility is not yet verified and stays hidden unless your quest history establishes it.

# Dungeon Questie 0.1.2 — beta

- Added clearer Ready for dungeon and Completed statuses, with separate totals.
- Updated Wetlands quest directions and the Greenwarden prerequisite chain.
- Added Rethiel's map pin and refreshed quest data from current sources.
- Fixed accepted quests being missed under collapsed quest-log headings.
- Fixed text overflowing quest rows.
- Reduced work when clicking quests to avoid selection lag.

241 quest goals, including 14 Wetlands records. Classic reference and community-reported data remain labelled. Further in-game checks are welcome during the Forever beta.
