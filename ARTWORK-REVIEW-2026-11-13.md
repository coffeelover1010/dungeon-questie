# Universal location artwork and status review — 13 November 2026

Implemented in Artwork.lua, Locations.lua and Window.lua. Existing parchment framing, rewards, functional buttons, provider integration, saved-variable identifiers and tracking are retained. Existing uncommitted work was preserved; the three edited runtime files were backed up before this task.

## Behavior

Every selected catalogue quest or expanded prerequisite uses the same current-step artwork panel. It renders the client's first/base map-art layer for the resolved destination, with zone/city name, recorded coordinates and a marker. Clicking uses the existing navigation function, which re-resolves the current step before placing a waypoint or opening the map. Approximate dungeon approaches and reference coordinates are labelled. Missing destinations show a compact text fallback; missing artwork retains the map-opening action when coordinates exist. Completed quests show their recorded hand-in location for reference, with no further action requested.

The preview reuses one pool of tiles, crops edge tiles, preserves map proportions, and refreshes on map/art-ID changes. It loads no per-row artwork, bundles no extracted textures and persists no artwork cache. Native map tile FileDataIDs are requested at runtime, avoiding hundreds of quest-specific paths. Existing LFG dungeon portraits remain on dungeon buttons. Fixed city/zone image paths and atlases are unnecessary for the preview: map-ID tiles cover supported maps without guessed asset names. Dungeon interiors without an established map/coordinate-space mapping retain explicitly labelled entrance/approach destinations, not fabricated interior pins.

Unaccepted quests have no status ticks. Active quests use text; accepted dungeon-ready quests may retain the readiness tick. Objective completion is labelled Objectives finished and remains distinct from Completed (confirmed turn-in). Unfinished, blocked, later and skipped actions have no decorative status icon. A ready prerequisite does not mark its unaccepted goal complete. Item, class and functional-button icons are retained.

Details separate Where to go, What to do, Who offers this step, Objectives and Return to. Existing curated special mechanics remain, including Get the Scoop's /beckon guidance. Live unfinished objectives can resolve NPC/object/item-drop locations by matching provider entity names to the live objective text. Ambiguous or unmatchable objectives do not guess. Completion advances to hand-in; prerequisites advance through the existing resolver. Curated mechanic directions take precedence. No new quest-specific mechanic or coordinate claims were invented.

## API evidence

Installed .build.info identifies Forever 1.60.1.70938. Read-only CASC extraction on 13 November confirmed the current client's MapDocumentation.lua declarations for C_Map.GetMapArtID, GetMapArtLayers and GetMapArtLayerTextures, plus Blizzard_MapCanvasDetailLayer.lua's use of those APIs and row-major tile indexing. The WorldMapPartyIcon texture exists in that archive. Extracted evidence is outside the addon in ../tmp/dungeon-artwork-70938; it is not packaged. Earlier Forever build 69893 UI source independently has the same contract. The upstream [Blizzard UI source mirror](https://github.com/tomrus88/BlizzardInterfaceCode/blob/master/Interface/AddOns/Blizzard_MapCanvas/Blizzard_MapCanvas.lua) also uses the contract, but the installed Forever source is the implementation evidence. Calls are guarded and unavailable/malformed API responses fall back safely. Archive presence does not prove live execution or every requested texture can be rendered.

## Coverage gaps

This is universal rendering/routing infrastructure, not verified full quest coverage.

- 320 catalogue quests and 550 total catalogue/prerequisite nodes were exercised offline.
- The installed QuestieDB 1.1.0 public API supplies 316 of the 320 catalogue IDs; 3366, 3911, 95056 and 92070 use existing local fallbacks.
- The static location presence audit across 550 nodes finds 37 without pickup pins, 498 without static objective pins and 34 without hand-in pins. Objective counts exclude live-text matching and dungeon-entrance fallbacks; they are not the count of quests with no possible map preview. Some existing pins are approaches/reference coordinates rather than exact verified objectives.
- Of 230 prerequisite-only nodes, 209 lack an exact static active-objective route. The per-ID gaps are recorded in data/location-artwork-gaps-2026-11-13.json and data/preparation-routing-audit-2026-11-13.json.
- Multi-location spawn selection uses a recorded provider spawn, not a nearest-location or optimal-route calculation. Ambiguous text, localized name mismatches, event objectives, item sources absent from provider data, unusual mechanics without curated directions, and unsupported dungeon interiors remain gaps.
- Existing source provenance is retained. No claim is made that all coordinates, instructions or Forever quest availability were reverified live today.

## Validation

Passed check.py, check_location_artwork.py, check_actions.py, check_walkthroughs.py, check_dungeon_instructions.py, check_readiness_review.py, check_routing.py and check_provider.py (uv with lupa and cbor2). Checks cover Lua 5.1 syntax; all 320 quests in unaccepted/active/objectives-finished/turned-in states; 550 chain nodes; 1,280 installed-provider state/profile cases; 2,750 missing-location cases; outdoor class preparation and /beckon; inside pickup; multi-zone objective advancement; prerequisite hand-in versus goal status; abandonment; saved settings; API absence; tile cropping/cache/art-ID invalidation; fallback and click dispatch. UI and character APIs are mocked, not live game tests. Existing assertions were updated only for the intended label/icon changes.

After /reload, verify a city pickup, an outdoor prerequisite, an accepted dungeon quest, a multi-objective travel quest and a completed quest. Check parchment layout/scrolling, readable preview captions, marker positions, click-to-map, acceptance/objective/hand-in updates, rewards and class icons. Rendering, actual API execution, protected interactions and server behavior still require live-client verification.
