# Dungeon Questie

A simple dungeon-only quest addon for players who prefer a focused checklist
or want a companion to their existing quest addon. Made for **WoW Forever**.

- Pickup directions, rewards and prerequisite steps.
- Progress from your quest log and confirmed turn-ins.
- Pickup pins, with optional TomTom arrows.
- Search by quest, dungeon, NPC or quest ID.
- Find Group buttons and manual whisper/invite controls.

Open with **`/dungeons`**, **`/dgf`**, or the minimap button.

Coverage: **266 quests across 25 dungeon groups**, reviewed 7 November 2026.
Four dungeon groups have no catalogue records. Source details distinguish
Classic references and approximate pins. Empty lists do not mean every quest is done.

## Screenshots

![Blackfathom Deeps quest actions and walkthrough](release-media/blackfathom-quests.png)

![Deadmines quest checklist and prerequisite tracking](release-media/deadmines-quests.png)

![Gnomeregan quest checklist](release-media/gnomeregan-quests.png)

![Dungeon list and an empty catalogue](release-media/dungeon-list.png)

## Quest actions and availability

Green ticks and the ready count refer to the currently actionable step: a confirmed
quest offer or a quest ready to turn in, including prerequisites. Accepted quests
with unfinished objectives show Active. Completed quests remain separate.

Uncollected quests show availability unknown until an NPC offer is reported by
`C_GossipInfo.GetAvailableQuests` or `QUEST_DETAIL`. An absent offer at the recorded
NPC shows unavailable for that interaction; closing it clears that evidence.
Optional breadcrumbs show Skipped when their recorded follow-up has progressed;
they are not marked completed. A live offer overrides a reference breadcrumb link.
The bundled links and creature names include Classic reference data, not verified
Forever server availability.

The target icon uses the active step's structured NPC name and a secure
`/targetexact` click (pickup NPC for collection, recipient for turn-in). Missing
NPC records and non-actionable steps disable it. The window closes securely on
combat entry; reopen it afterwards to rescan. Native targeting, range, rendering,
and combat taint still require an in-game check after `/reload`.

## Install

Download the addon ZIP from Releases and extract `DungeonGuideForever` into
`World of Warcraft/_forever_/Interface/AddOns/`. Restart the game if it is
not in the AddOns list. Keep that folder name even though the addon is called
Dungeon Questie.

For WoW Forever Interface **16001**. TomTom is optional. Questie is not required.

## Credits

By Videocat. Classic reference records are adapted from
[CMaNGOS Classic-DB](https://github.com/cmangos/classic-db) under GPLv3.
Original addon code retains its MIT licence. Game content belongs to Blizzard.
See [third-party notices](THIRD-PARTY-NOTICES.md) for the complete credits and terms.
This is an independent addon, unaffiliated with the Questie project.

[Data sources and checks](SOURCE-REBUILD.md) · [Walkthrough details](WALKTHROUGHS.md)
· [Maintainer guide](AI-RESEARCH-README.md)
· [7 November review and dependency recommendation](RESEARCH-2026-11-07.md)
