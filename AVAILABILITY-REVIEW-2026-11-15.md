# Quest availability review — 15 November 2026

Removed The Heart of the Void (78916 Alliance and 78917 Horde) from the active dungeon catalogue at the user's request. Both variants use the disputed Aku'mai pearl acquisition. Player reports support suspected current unavailability, not official permanent removal. Raw source and walkthrough records are retained. `data/catalogue-exclusions.json` persists the decision across catalogue rebuilds. No other quests were removed.

Evidence: https://www.wowhead.com/forever/quest=78916/the-heart-of-the-void#comments and the user's screenshot of Artora, Mocharaid and Kurtosis reporting uncertainty/no pearl. The database entries alone do not establish a live drop.

## Other findings for review

- Hearts of the Lost (87318), Thandol Span: multiple Forever comments say Corma offers no quest, including reports after nearby quests were completed and a player who remembers the beta chain. Strong player-reported suspect; not official removal confirmation. https://www.wowhead.com/forever/quest=87318/hearts-of-the-lost
- Accessories of the Lost (88757) and Sentiments of the Lost (88758): listed follow-ups. If the opening quest cannot be obtained, this route may also be inaccessible. This is an inference, not separate firsthand confirmation. https://www.wowhead.com/forever/quest=88757/accessories-of-the-lost and https://www.wowhead.com/forever/quest=88758/sentiments-of-the-lost
- None of that three-quest chain is in this addon's catalogue or local walkthrough graph; no removal needed here.
- Castpipe's Task (2931): search surfaced an unavailable report, but the page identifies zero Forever-only comments and the report concerns patch 1.13. Insufficient current Forever evidence; retained. https://www.wowhead.com/forever/quest=2931/castpipes-task
- Seeking the Kor Gem (1442), The Last Element (3911): surfaced comments are largely historical Classic comments; not evidence of current removal. Retained.
- Alcaz State Secrets / More Valuable Than Gold: a current walkthrough describes the route; no matching removal evidence found. https://www.wowhead.com/forever/guide/alcaz-operative-disguise-toy-secret-walkthrough
- Chief Engineer Scooty: a recent hotfix fixes Sovik's offer. Do not interpret earlier failures as removal. https://www.wowhead.com/blue-tracker/topic/us/wow-forever-hotfixes-november-13-2026-2403040
- Vorsha the Lasher: launch disablement appears struck through in the updated known-issues tracker, so it is not being proposed as currently removed. https://www.warcrafttavern.com/blue-tracker/post/us/2402363/

## Scope and checks

Targeted review of flagged unknown pickup/eligibility records, quest-specific searches, current dungeon guide comments, general Forever unavailable/removed reports and recent hotfixes. This is not a live-client audit of every quest or a guarantee no other unavailable quests exist. Search matches for Krol'dok No More, Blackmaw and Digestible Research supplied no comparable removal evidence.

Catalogue semantic comparison: exactly IDs 78916 and 78917 removed; no other quest fields changed. 318 active catalogue records remain. Base offline checks passed. Installed/live rendering requires reload and an in-game check.

## Installed-provider discrepancies

The installed QuestieDB 1.1.1 Forever contract-4 audit passed 1,272 profile cases and found 315 of 318 active catalogue IDs. Missing IDs: 3366 The Glowing Shard (Wailing Caverns), 3911 The Last Element (Blackrock Depths), and 95056 Krol'dok No More! (Horde, Krol'dok Stronghold). These are verification candidates only: provider absence does not prove removal. All three remain unchanged. The Glowing Shard also has a separate variant, so do not remove the quest by name alone. The current dungeon guide still lists The Last Element.

Source: local tools/check_provider.py output against installed QuestieDB public API. No provider data was imported into the catalogue. Base and provider checks passed; in-game validation remains pending.

## User decision: Hearts of the Lost

The user subsequently requested excluding Hearts of the Lost (87318). Added it to catalogue-exclusions.json so later catalogue imports cannot reintroduce it. It was already absent from the active catalogue, so this decision changes no installed quest rows. Its follow-ups remain unchanged.
