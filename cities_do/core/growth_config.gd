extends RefCounted
## Prototype balance, not final game design. Footprints and density are independent.
var size_weights := {8: 0.45, 4: 0.30, 2: 0.25}
var score_threshold := 100.0
var neighbor_chance := 0.55
var max_chain := 8
var road_access_distance := 1.5 / 4.0 # 1.5 metres from sidewalk-inclusive road edge to lot front.
var road_width := 2.0
var zoning_depth := 8.0

var parcel_block_length := 8.0
var parcel_turn_degrees := 10.0
var parcel_max_deviation := 0.25

# Prototype pacing in speed-adjusted real seconds; 2 seconds = 48 game seconds.
# Population demand must also permit construction.
var development_interval_seconds := 2.0
var development_max_steps := 8
var development_checks_per_step := 256
