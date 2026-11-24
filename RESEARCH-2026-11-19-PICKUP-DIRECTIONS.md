# Missing pickup directions — 19 November 2026

The user's screenshots show Past Due (96800) with an unmapped destination and
an overview card saying only to check quest details. The detail panel displayed
quest objective text but omitted the pickup context promised by the map fallback.

The existing record identifies Magus Olvek at Tempered Tomes, City of Dalaran
(9.5, 63.1). Rechecked https://wowforevertalents.com/quests/past-due-96800/:
the firsthand beta-log report dated 23 October identifies creature 264265 at
that location; its quest text sends the player to Scarlet Monastery for The
Lost Magic of the Runemasters. The NPC name comes from the existing provider
identification. This check does not establish an outdoor coordinate conversion
or prove that there are no prerequisites. Existing uncertainty is preserved.

Window.lua now shows recorded pickup context and the availability caveat on
uncertain overview cards. The detail panel includes current-step directions
when the destination is absent or availability is uncertain/blocked. Original
quest wording remains intact. Blocked cards show the actual resolver reason.
No changes to quest readiness, routing, coordinates, eligibility or saved data.

Checked local Blizzard API documentation for C_Map.GetMapInfo; it accepts a
UI map ID and can return no result. No new API calls or guessed map IDs added.

Offline checks: base Lua/UI contracts, original quest text, Past Due and 34
uncertain catalogue cards. Installed QuestieDB public-API integration is also
covered by check_provider.py, including Past Due in both views.
These are mocked-client checks; live text wrapping and map behavior require
an in-game reload and visual inspection.
