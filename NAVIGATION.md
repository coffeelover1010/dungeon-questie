# Simplified destination selection — 16 November 2026

The destination window now shrinks to fit its entries. Technical estimate messages are hidden; route management is under **More options**. Quests restricted to other factions/classes/races are excluded from collection planning. Click **Navigate** to set the TomTom arrow and close the navigation/journal windows. TomTom is now preferred when its waypoint API is available; Shortest Path and map fallback remain when it is absent. TomTom must be installed and enabled to show its arrow. Offline mocks cover precedence, arrow activation, window closing and character filtering; live rendering remains unverified.

# Optional navigation and collection routes

Implemented against cjber's [Shortest Path Forever public API](https://github.com/cjber/shortest-path-forever/blob/main/docs/api.md), reviewed 16 November 2026 (API versions 1 and 2; documentation currently version 2, minor 3). No Shortest Path Forever source code is copied or bundled. Credit: [Shortest Path Forever by cjber](https://github.com/cjber/shortest-path-forever).

## Player controls

The journal header has two additional icons: **Collect Quests — Shortest Route** (tracking icon) and **Navigate recorded locations** (map icon). `/dungeons route` opens the collection preview; `/dungeons locations` lists all recorded locations for the selected dungeon. The header location icon limits that list to the selected quest and its recorded prerequisite branches, plus the dungeon entrance. The existing current-location icon and Shift-click destination markers use the same navigation provider.

The location browser lists pickup, objective, turn-in and entrance points, including completed quests and future prerequisite steps. Each known NPC/object spawn is individually selectable. Item objectives and item-started quests expose known drop sources. Navigation to a future quest location does **not** mean the quest is available. Interior entities without outdoor coordinates use an explicitly labelled dungeon approach, never an invented interior position. Missing coordinates remain unavailable.

The collection preview shows the next actionable preparation step per included quest chain, associated quest names, stop type, coordinates, estimated travel minutes and blockers. Hover long rows to read all associated actions. Use **Start**, **Navigate**, **Skip stop**, **Quests** (include/exclude), **Recalculate** or **Cancel navigation**. Exclusions last for the current preview/session. Skipping a shared stop skips its grouped actions; those quests remain blocked until completed, excluded or restored with Recalculate. Selecting an individual destination pauses collection automation. Cancel or `/dungeons clear` removes only Dungeon Questie's navigation.

## Providers and restrictions

* When TomTom is absent, a compatible Shortest Path Forever API is used. Versions 1 and 2 are accepted; future major versions are rejected, and every function is checked and protected with `pcall`. It handles transport, route drawing, directions and its own UI. Dungeon Questie creates no extra arrow or native waypoint on this path.
* If that API is unavailable, the existing TomTom and world-map functionality remains. Neither addon is required. An API rejection/error from an available Shortest Path provider is reported instead of silently launching competing navigation.
* Journey ownership uses `DungeonGuideForever`. A player cancellation or replacement by another guide stops collection automation. Nothing resumes or changes RestedXP settings. Cancelling this addon cannot cancel another owner's journey.
* Collection uses a held single stop, then revisits the plan after real quest progress. Arrival alone cannot unlock a prerequisite or mark a quest collected. Current-step navigation also follows changing quest state; explicit location choices stay fixed.

## Planning assumptions and limits

This is **greedy travel-time ordering, not a mathematically optimal itinerary**. It chooses the cheapest currently actionable destination, then estimates from there. Reachable alternatives for provider-backed NPCs/objects are compared; direct browser selections use the exact selected spawn. Curated coordinates retain their existing precedence.

The existing `WalkStep`, `RunReadiness`, completion, log, faction, race, class, level and availability rules are reused without changing quest progression. Each chain contributes its current resolved action. Future and alternative branches are not optimistically scheduled. Missing requirements or reliable current-objective data appear as blockers. Once all included preparation is actually complete, the entrance becomes the current destination. Explicitly selecting that entrance is always possible.

`Estimate` supplies transport-aware travel seconds using the player's known travel options and Shortest Path settings. The documented endpoint terrain approximation remains; these are not promises of exact arrival times. The API includes player-origin cooldown/teleport options only when estimating from the player's actual position. Estimates for later stops exclude those player-origin abilities. Quest work time, combat duration, drops, queues and interaction time are not estimated. Without estimates, stable catalogue order is used and times are labelled unavailable; no straight-line shortcut is claimed. Unreachable/invalid steps are blocked.

Shortest Path owns its documented five-second estimate cache. Dungeon Questie retains no travel-time cache between plans. Manual Recalculate refreshes after travel settings, flight knowledge, cooldowns or other travel conditions change. Quest scans are already debounced; an action-state signature avoids rebuilding for unchanged log notifications. The planner yields after small batches of candidate/alternate-spawn evaluations and cancels superseded calculations. No route search runs every frame. QuestieDB spawn enumeration is on demand.

Current objective selection remains deliberately conservative: ambiguous unmatched live objectives, missing QuestieDB records and disputed coordinates are not guessed. Such known alternative objective locations remain directly selectable in the location browser, but are not promoted to confirmed current preparation actions.

## Verification

Run from the project directory:

```powershell
uv run --with lupa python tools/check_navigation.py
uv run --with lupa --with cbor2 python tools/check_locations.py
uv run --with lupa --with cbor2 python tools/check_routing.py
uv run --with lupa python tools/check_actions.py
uv run --with lupa python tools/check_window_controls.py
```

`check_navigation.py` exercises version/function guards, SPF errors, TomTom/map fallback, transport-time ordering, prerequisite objective/turn-in/pickup transitions, completed quests, level blockers, exclusions, shared stop skipping, unreachable routes, alternate NPC spawns, asynchronous cancellation and mocked preview construction. Existing tests cover the underlying resolver and installed provider snapshot. These are offline checks, not live-client validation.

### Required in-game checks

1. With Shortest Path enabled, navigate to a dungeon entrance, a pickup NPC, objective and turn-in. Verify its UI, transport legs and absence of a second Dungeon Questie arrow.
2. Use Locations to choose two different spawns of an NPC, a completed quest's turn-in, and a future prerequisite pickup. Confirm exactly the selected location is used. Check a missing-coordinate quest and an interior approach label.
3. Preview multi-zone preparation (for example the Mage Rituals of Power/Get the Scoop chain), compare estimated order, accept a quest, complete objectives, turn in and abandon. Verify only newly eligible steps unlock and the entrance follows completion.
4. Check a level/availability blocker and an unavailable route. Skip a shared stop, exclude one of its quests, restore skipped stops, and cancel. Confirm blockers prevent an automatic entrance trip.
5. Start another guide/player journey while collecting; confirm Dungeon Questie yields and does not take it back after a quest update. Test combat/loading/API rejection and a manual recalculate after changing transport availability.
6. Disable Shortest Path with TomTom enabled, then disable both. Confirm existing waypoints/map pins, entrance-only navigation and cancellation still work. Reload in each configuration.
7. Check header icon spacing, tooltips, long rows, pagination, scaling, window dragging and Escape. Verify the existing checklist, readiness counts, quest links, targeting and artwork remain intact.

## Modified files

`Locations.lua` enumerates locations; `Navigation.lua` owns destinations/provider calls; `RoutePlanner.lua` orders and advances preparation; `NavigationWindow.lua` supplies preview/location controls. `Map.lua`, `Tracking.lua`, `Window.lua` and the TOC connect them to existing features. Documentation, package/install allowlists and `tools/check_navigation.py` accompany the implementation.

## Offline result — 16 November 2026

All 24 check scripts passed, including Lua 5.1 syntax, existing behavior checks and the new navigation contracts. Provider-dependent checks used the installed QuestieDB 1.1.2 snapshot. Shortest Path Forever was not installed locally; its behavior was exercised with public-contract mocks. No live-client rendering or journey test was performed.
