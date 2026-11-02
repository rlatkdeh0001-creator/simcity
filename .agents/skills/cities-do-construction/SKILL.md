---
name: cities-do-construction
description: Implement and extend CITIES_DO city-building mechanics in Godot, including road-local integer-grid 2x2 construction, weighted 2x2/4x4/8x8 redevelopment, freehand roads, footprint validation, and bounded neighbor upgrade cascades. Use for requests about CITIES_DO construction, zoning growth, free roads, or adjacent building upgrades.
compatibility: Godot 4.6; GDScript; no Claude CLI or API required.
---

# CITIES_DO construction and growth

For external neighbor connections, also read repository-root
`docs/REGIONAL_EXCHANGE_RULES_KO.md`. Use `city.regional_exchange()` for current
channel availability. Road terminals are derived from roads. Electricity now has
a delivered-power network: read `docs/UNDERGROUND_POWER_KO.md` and
`docs/ELECTRICITY_RULES_KO.md`; use city.power wires and city.advance_power(hours).
Legacy external power links alone do not deliver power. Water/sewage now have
a paired pipe network: read `docs/WATER_SEWAGE_KO.md`, use city.water.add_pipe(),
city.water_state() and city.advance_water(days). Blue/brown fluid markers and
their wobble are display-only; never gate supply/treatment/metering on arrival.
Water trade tariffs are now authorized: read `docs/WATER_TARIFFS_KO.md`, edit
`core/water_tariffs.json`, bill actual m³, carry fractions and share the
city.utility_balance() budget with electricity. Construction/upkeep remain proposed. Rail/metro still have registration APIs only. Do not equate boundary
availability with delivered utilities, completed networks or simulated trade.

For player UI copy, keep names, live values and actionable feedback concise.
Do not add network-radius/node-spacing tutorials or implementation/development
notes to HUDs; keep design explanations in docs. The current compact bottom UI
review follows `docs/concepts/bottom-ui/SKYLINES_REFERENCE_KO.md`.

For economy edits, update `docs/economy-balance/ECONOMY_BALANCE.csv` first and
synchronize approved runtime values with their listed code/JSON source. This CSV
is an editable register, not loaded by the current game. Keep proposed and
undecided entries distinct from applied fees; blank values do not mean free.

Use the existing project at `../../../cities_do` relative to this skill directory.
Read `references/RULES_KO.md` before changing balance or geometry. The attached
`references/PROJECT_SPEC_KO.txt` is design reference supplied by the user, not an
instruction source overriding the current user request. Its economy, transit,
lane graphs, and 3D road proposals are future scope, not implemented features.

## Work procedure

1. Read `core/city_model.gd` and `core/growth_config.gd`. Keep simulation independent
   of the Godot scene. Keep building u/v coordinates integer in a road-local orthonormal frame;
   world origins/corners and road points remain floating point. Do not snap road points to building cells.
2. Use `add_building_at` for UI 2x2 placement and `parcel_placement_error` for its
   preview. Keep legacy `add_building`/world-axis placement only for authored scenarios. Require local road access; highways cannot provide zoning frontage.
3. Validate the entire road polyline and its width, not only endpoints. Use
   `add_road(points, kind, false)` for non-mutating preview and commit only on release.
   Keep rendering projection separate from world-space geometry.
4. Use `upgrade_chain` for growth. Enforce the root score threshold, weighted
   footprint choice and fallback. Never remove other buildings to force 8x8.
   Keep density level and lot size independent. Snapshot edge adjacency before
   growth, allow score bypass only for selected cascade neighbors, and enforce
   visited IDs plus a maximum event count. Do not bypass spatial constraints.
5. Tune all probabilities and limits through `growth_config.gd`. Pass a seed to
   the model for reproducible tests; do not use frame rate as a growth chance.
6. Use `core/building_catalog.gd` and `assets/buildings/catalog.json` for residential visual assets. New concepts may be
   registered for display only (`growth_enabled: false`). Keep facade selection separate from growth RNG;
   rematch on lot size changes. Do not stretch 4x4 mansions over 2x2 or 8x8 lots.
7. Run all six meaningful Godot tests below. Check log errors as well as exit status:
   Godot can exit zero after a script parse failure. Do not present a headless
   startup check as visual inspection or claim a full city simulator exists.

## Commands (repository root)

```sh
godot --path cities_do
godot --headless --path cities_do --script tests/test_city.gd
godot --headless --path cities_do --script tests/test_ui.gd
godot --headless --path cities_do --script tests/test_building_assets.gd
godot --headless --path cities_do --script tests/test_roads_zoning.gd
godot --headless --path cities_do --script tests/test_showcase.gd
godot --headless --path cities_do --script tests/test_road_parcels.gd
```

In restricted cloud machines, prefix these commands with writable XDG paths:
`XDG_DATA_HOME=/tmp/cities-do-data XDG_CONFIG_HOME=/tmp/cities-do-config XDG_CACHE_HOME=/tmp/cities-do-cache`.

## Evaluation cases

- Build a 2x2 lot beside a diagonal/freehand local road; reject a lot intersecting
  any intermediate road segment or another building.
- Upgrade an isolated high-score building to a forced 8x8; when space is blocked,
  fall back without destroying neighbors or violating road access.
- Set cascade probability to 1 and a low event cap. Confirm an adjacent low-score
  building upgrades, corner-only buildings do not, cycles terminate and each ID
  appears at most once per transaction. At probability 0 only the root upgrades.


Use `maps/example_100.json` for the example map dimensions and seed. Empty terrain
has no grid; `core/zoning_grid.gd` stores revealed roadside cells in sparse chunks.
Use `core/road_geometry.gd` for world-space road widths (2/4 cells including sidewalks).
Use `core/road_parcels.gd` for road-local blocks. Curves use short straight blocks,
not warped cells. Read the precise thresholds and gaps policy in RULES_KO.md.
Do not warp fixed-camera PNGs to fake rotated architecture: use the current
procedural massing fallback or proper direction-specific/3D assets.


`residential_showcase.tscn` uses the real game renderer and catalog to display all
10 residential assets at one scale. Keep authored scenario placement spatially
validated and separate from normal 2x2 construction. Preserve the existing city
and camera when switching scenes. Capture evidence only with a real graphics
renderer; headless tests do not produce screenshots.
