# Questie cross-check - 17 October 2026

Compared against the dedicated Forever flavor of [QuestieDB](https://github.com/Questie/QuestieDB/tree/e9a67d1a2753a0e64c4c96bf7864788fac7b765f), pinned at commit `e9a67d1a2753a0e64c4c96bf7864788fac7b765f`. This replaces reliance on the workspace's old Questie v10 Classic comparison for this review. The latest Questie bundle listed by GitHub was v12.1.0 + QuestieDB v1.0.6, published October 12; this comparison uses the newer source checkout, not that release artifact.

Used QuestieDB's own static merge helper with authored corrections enabled: base, inherited corrections, generated Forever data, player traces and authored Forever corrections. Dynamic character-dependent corrections, derived passes, localization and live client behavior are outside this comparison. The trace layer records generation on October 13. See [upstream layering documentation](https://github.com/Questie/QuestieDB/blob/e9a67d1a2753a0e64c4c96bf7864788fac7b765f/docs/forever.md).

## Results

- 253 of our 257 goal IDs and 453 of 457 total walkthrough nodes occur in the merged Questie data. Presence is a cross-reference, not proof that all fields agree.
- 434 of 443 comparable minimum-level fields agree. Missing values were excluded from this count.
- 17 of the 18 records changed in today's refresh occur in Questie, and all 17 agree on minimum level. Questie corroborates the treaty's level 9 requirement and Starving Arcane's Alliance restriction.
- NPC identities agree for Thom Filch, Afadra Dunwall, Earthseer Farsen, Wilder Thistlenettle, Morbin Lightbane, Theodore Griffs, Andromath, Melisara and Modera. Both crest turn-in NPCs also agree. This does not independently verify our exact pickup coordinates.
- Questie has no starter recorded for Abominable Creatures in this merged static output, so the Captain Truman direction remains guide-supported rather than Questie-verified.
- Rewards were not verified by this comparison. Baron Aquanis's reward update still rests on the separately checked beta-cache page.

## Differences requiring care

- Missing IDs: 3366 (The Glowing Shard), 78916/78917 (The Heart of the Void variants), and 3911 (The Last Element). Questie contains another Last Element record, 7201; a shared title is not enough to merge or replace IDs. Quest 3911 remains explicitly uncertain in our addon.
- Questie marks Important Heirlooms and An Ancient Grudge Alliance-only, whereas the reviewed Icy Veins guide lists them without a faction restriction. Questie's authored An Ancient Grudge correction explicitly says it is unsure whether Horde can obtain it. No faction restriction was imposed from that conflicting evidence.
- Some Forever chain edges are absent in Questie, including portions of the Deadmines preparation and Horde Dalaran route. The generated delta-base documentation explicitly warns that its coverage is incomplete. Missing edges do not establish that a quest has no prerequisite.
- Other flags include Classic breadcrumb handling and old minimum levels. These are review candidates, not automatic corrections. The earlier user-confirmed Researching the Corruption exception and researched Highland Hides route remain intact.
- Raw faction-mask comparisons against catalogue strings would produce misleading results: our explicit unknown-eligibility flags and walkthrough race masks must be considered, and Questie includes Skyborne bits. Such flags were not treated as confirmed bugs.

## Reproduction and outcome

Local comparison script: workspace `tmp/compare-questiedb-20261017.py`. Run from the workspace root with `uv run --with lupa python tmp/compare-questiedb-20261017.py` after checking out the pinned QuestieDB revision at `tmp/questiedb-review-20261017`.

Detailed local report: workspace `tmp/questiedb-comparison-20261017.json`, including missing IDs, minimum-level/prerequisite differences and checks of the 18 updated quests. Comparison data stays outside addon build inputs and the live AddOns directory.

No runtime data or styling changed in this verification pass. The comparison corroborates several specific changes; it does not certify every quest or replace live-client validation.
