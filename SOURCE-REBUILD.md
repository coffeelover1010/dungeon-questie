# Data source rebuild — 3 October 2026

The walkthrough generator now reads a pinned CMaNGOS Classic-DB factual subset
and the independently sourced catalogue/Forever overrides. It never reads
Questie research files or the previous generated walkthroughs.

The importer keeps only quests reachable from the catalogue, related
prerequisites/alternatives/breadcrumbs, their quest givers, objective entities
and pickup/turn-in spawns. It does not export dialogue or quest descriptions.
The selected source contains 407 Classic quest records; merging the separately
sourced Forever records produces 432 walkthrough nodes for 240 catalogue goals.

Rebuild runtime data with:

```powershell
uv run python tools/build_walkthroughs.py
uv run --with lupa python tools/check_walkthroughs.py
```

To reproduce the source extraction, download the exact snapshot identified in
`data/classic-source-provenance.json`, verify its SHA-256, then run
`tools/import_classic_db.py <snapshot.sql.gz> --revision <recorded revision>`.
The base SQL snapshot is used as a dated Classic reference; later SQL updates
are not implicitly applied. Keep the GPL and other notices with distributions.

## Independent comparison

`tools/compare_questie.py <local-reference-directory> --output <review.json>`
is optional and requires locally held Questie v10.0.0 inputs. Its output is
never consumed by either build script. No comparison values are imported.

389 overlapping records were compared. After normalising race-mask encodings,
18 records were flagged: 11 prerequisite differences and seven level differences.
Every prerequisite difference was checked against Classic-DB's own
`BreadcrumbForQuestId` fields: these are breadcrumb links, not required
completion edges in that source. We retain that distinction instead of making
the player complete them. The seven level differences (1489, 1490, 914, 1144,
2904, 2842, 1160) keep their primary-source or Forever catalogue values; the
comparison is not evidence that either version matches the current beta.

## Coordinates and remaining limitations

The 50 independently recorded catalogue pins are retained. Extra Classic pins
are rebuilt from Classic-DB world coordinates and client map rectangles, not
Questie coordinates. Ambiguous overlapping rectangles and unmapped or interior
locations do not produce pins. Moving givers use a representative recorded
spawn. The final walkthrough set has 166 pins, all reference additions labelled
as approximate and unverified in Forever.

84 catalogue goals have prerequisite edges. Thirty goals have unresolved
chains. Conditional or unsupported requirements produce a check message.
There are no missing graph edges or cycles in the checked output.

Offline checks cover syntax, data, resolver progression, restrictions, map
guards and mocked UI. They do not establish beta availability or live rendering.
After reloading, check Gnomeregan, a multi-step prerequisite, a Classic pickup
pin and a Forever-specific chain. Release screenshots predate this data rebuild.
