---
name: cities-do-modular-facilities
description: Build CITIES_DO parks and modular surface parking with Blender sources, GLB previews and tested connected-component merging in Godot. Use for parks, parking lots, mergeable facilities and rectangular modular assets.
---

# Modular facilities

Create original stylized geometry consistent with the existing city palette. One cell is 4m.
Store dimensions as width/depth independently; do not force rectangular facilities into square building growth APIs.

1. Read `docs/PARKS_PARKING_KO.md` and `tools/facility_layout.py`. Generate plain layout data before meshes.
2. Surface parking snaps to a 2-cell lattice. Use shared 8m modules: 3m cross aisle, 3m longitudinal aisle and two 2.5×5m spaces. Keep shared aisles aligned in world coordinates.
3. Group surface lots by positive-length shared edge, never by corner contact. Exclude towers and parks. Reject overlap, invalid IDs and out-of-bounds placement before mutating state.
4. Build one combined ArrayMesh per connected component. Remove interior curbs, retain exterior curbs and align lane markings. Rebuild after addition/deletion; deletion may split groups. Preserve lot identities for selection/removal.
5. Treat merging as common geometry/capacity/access metadata, not proof of traffic AI, reachable parking manoeuvres or a single GPU draw call. Multiple material surfaces may remain.
6. Author editable .blend, GLB, transparent preview and spec per asset. Four-storey tower means four occupied parking decks, not four decks plus occupied roof parking. Use ramps and readable P signage.
7. Compare Python layout fixtures with Godot output, test L shapes/holes/corners/tower exclusion/removal/order invariance and inspect actual runtime captures.
8. Record provenance, commands and remaining limits in the report and skill handoff. Original guidance; procedural-gen/tilemap were reviewed as references, not installed or run as full pipelines.
9. Propose construction cost and monthly upkeep in doth for each new asset, explaining capacity, comparables and the 50,000 doth starting budget. Record as proposed in docs/PRICE_PROPOSALS_KO.md; apply charges only after user approval.

Commands: `blender -b --factory-startup -t 2 -P tools/build_facilities.py` and
`godot --headless --path cities_do --script tests/test_facilities.gd`.
