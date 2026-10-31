extends RefCounted
## Prototype balance, not final game design. Footprints and density are independent.
var size_weights := {8: 0.45, 4: 0.30, 2: 0.25}
var score_threshold := 100.0
var neighbor_chance := 0.55
var max_chain := 8
var road_access_distance := 2.5
var road_width := 2.0
var zoning_depth := 8.0

var parcel_block_length := 8.0
var parcel_turn_degrees := 10.0
var parcel_max_deviation := 0.25
