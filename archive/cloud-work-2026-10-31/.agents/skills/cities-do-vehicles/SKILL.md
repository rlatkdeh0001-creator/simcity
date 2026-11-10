---
name: cities-do-vehicles
description: Build original low-poly CITIES_DO vehicles, with metric dimensions, Blender source, wheel pivots, game GLBs, and actual Godot visual checks. Adapts the installed vehicle skill rather than the building-asset workflow.
---

Read ../vehicle/SKILL.md and ../vehicle/reference/rig-contract.md before vehicle work.
For the city-fleet task, apply the upstream metric frame, silhouette-first body construction,
separate glass/lamps/wheels, wheel steering/spin pivots, GLB extras and export re-import checks.
Use reviewed common.py helpers from that skill. Do not run remote install scripts.

This is an original, stylized game fleet, so real-product photo matching, full interiors,
opening-door/crash rigs and silhouette IoU gates are outside the requested asset scope.
Record these as not performed, never as passed. Nominal dimensions are original design values.

Use tools/build_vehicle_fleet.py through Blender. Source is assets/vehicle-fleet;
game models and catalog are cities_do/assets/vehicles. Keep all 20 silhouettes distinct.
Blender frame: -Y forward, +X left, +Z up, ground z=0; exported glTF: +Z forward, +X left, +Y up.
Use left-hand-drive driver anchors, put bus passenger doors on -X (right side), and preserve
right-hand road traffic. Cars must fit the lane width, including mirrors.

Keep render-only cameras/lights out of exported GLBs. Wheels must have separate steer and
spin pivots. Semi-trailers and dump beds keep articulation pivots. Re-import every GLB into
Godot, validate counts/bounds/pivots and inspect the complete fleet in vehicle_showcase.tscn.
Preserve building and road behavior. Vehicle assets do not imply a completed traffic simulator.
