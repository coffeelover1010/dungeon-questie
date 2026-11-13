# Dungeon preparation walkthroughs

Current runtime: [QuestieDB integration](PROVIDER-INTEGRATION.md), 12 November 2026. QuestieDB is required and Questie optional. The provider supplies available fields; independently reviewed corrections and missing-field fallbacks remain local. Historical build descriptions below describe the retained research inputs.

Choose a dungeon and select a quest from the list. The right panel shows one current quest on the path to that dungeon quest. While it is in the log, the panel shows its live objectives (or factual reference objectives if the API has none). When ready, it shows the turn-in NPC. Completing the turn-in advances the panel. Accepting the final dungeon quest marks that goal collected; select another quest from the list to view its details. No manual completion button is used.

The goal is to collect outside quests before entering. Some prerequisites themselves require a dungeon visit, so no guide can always obtain every later quest before the first run. Inside pickups and unknown requirements do not count as collected.

## Sources and coverage

All 256 current catalogue goals have been examined by the builder. There are 456 records including prerequisites; 86 goals have recorded prerequisite edges. Thirty-nine goals have an unresolved Forever chain, explicitly flagged in `data/walkthrough-coverage.json`. The October 9 deeper review adds the Horde Dalaran key preparation route and Alliance Shaman lead-in, while removing optional or disputed Wetlands gates. See RESEARCH-2026-10-09-DEEP.md for field-level evidence and limits. This does not establish that all quests in Forever are in the catalogue.

Classic reference facts now come from the GPLv3 CMaNGOS Classic-DB snapshot recorded in data/classic-source-provenance.json. See SOURCE-REBUILD.md for extraction, comparison and coverage details and THIRD-PARTY-NOTICES.md for licences. Questie is not a build input. Classic records remain reference data, not verified Forever routes.

Forever-specific Toxic Soil / Destruction in Deadmines walkthrough facts were checked against the quest pages beginning at https://www.wowhead.com/forever/quest=92742 and the storyline at https://www.wowhead.com/forever/quest=92753 on 2026-10-02. This follows published storyline order, which does not prove every step is mandatory. A Dynamite Plan includes an explicit optionality warning. A later accepted/completed step overrides earlier guide steps. Hall of Thanes uses the existing sourced Underground Map prerequisite record.

Profession, reputation, active-parent and spell requirements that cannot be evaluated safely stop with a check message. Missing quest records, failed log/completion scans, or cyclic links also stop rather than claim readiness. Optional/branch differences still require live testing. Missing pickup pins use Classic-DB NPC/object world coordinates converted using client map rectangles on mapped outdoor and city zones, labelled Classic reference and approximate. Curated pins take priority. A representative recorded spawn is used for moving or multi-location givers; item drops and unmapped dungeon floors do not receive fabricated coordinates. Map buttons also support mapped prerequisite steps, and the quest-log/source buttons refer to the current prerequisite rather than the goal quest.

## Rebuild and verification

The builder now merges populated catalogue pickup, level, restriction, objective and preparation fields over the Classic baseline for non-Classic catalogue records. It preserves the baseline prerequisite graph and identifies inherited locations/requirements as reference data. Explicit walkthrough overrides win last; a beta label alone does not certify every field. Preparation notes appear before accepting outside or inside quests.

Sparklematic 2951 was corrected on 2026-10-02 using the Wowhead Forever quest page and the player's unchanged-behavior report: bring one Grime-Encrusted Object and three silver to the Clean Zone machine. The initial quest is separate from the Classic reward step 2952 and repeatable follow-up 2953. Corrections live in both override inputs so rebuilding preserves them. In-game rendering and completion behavior still require a reload check.

`uv run --with lupa python tools/build_walkthroughs.py` rebuilds `WalkthroughData.lua` and the JSON coverage/data files from the licensed data/classic-source.json input and `data/walkthrough-overrides.json`. The existing catalogue builder does not overwrite this separate walkthrough data.

`uv run --with lupa python tools/check_walkthroughs.py` runs Lua 5.1 syntax, manifest and existing addon tests, then exercises progression, late acceptance, abandonment, alternative and joint prerequisites, class restrictions, missing data, scan failure, graph closure/cycles and every catalogue detail panel with the actual resolver. These are offline mocks, not game-client proof.

After installation, `/reload`, select Deadmines and Destruction in Deadmines. Check that the current prerequisite matches your log/completions; accept it, complete objectives, and turn it in. Confirm the panel advances, Open quest log selects that prerequisite, and the pickup pin is not reused for turn-in. Also check a Classic chain, a different-class goal, an inside pickup and an unresolved Forever record.

## Step and reward labels

The detail panel distinguishes accepting, completing, and turning in a prerequisite. Rewards remain those of the selected dungeon goal and name that quest explicitly; when a prerequisite is shown, the panel explains that the rewards are for the goal. A prerequisite with missing pickup directions never borrows the goal quest location.


## Source confidence

Generic source-confidence warning icons are hidden in quest rows and detail headers. Quest status, next steps and dungeon readiness still show actionable guidance. Source records retain their evidence and historical notes; readiness gates are unchanged.

The follow-up October 9 review resolves Highland Hides to Young Crocolisk Skins (484), based on a firsthand Wowhead report corroborated by Icy Veins. The prerequisite's current quest page specifies six skins. See data/confidence-review-2026-10-09.json. Client rendering and offered-quest behavior have not been observed locally.

## Chain progress

Quest details show **Step X of Y** and a numbered route with completed, in-log, ready-to-turn-in and uncollected states. The current step is marked with `>`. Required parallel prerequisites count once each; alternative prerequisites count only the selected route. Unambiguous recorded follow-ups are included, including return trips after the selected dungeon quest. Multiple possible follow-ups stop the count at the known route. Incomplete records are labelled **known route**; the count does not claim the full server chain is known. Single-step quests have no chain counter. Offline Lua/UI checks pass; live layout remains to be checked.
