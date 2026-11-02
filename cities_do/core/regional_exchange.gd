extends RefCounted
## Connection availability only. No invented trade prices, volumes or utility supply.
const CHANNELS := ["road", "rail", "power", "metro", "water", "sewage"]
const EDGE_EPSILON := 0.00001

static func path_error(points: PackedVector2Array, width: int, height: int) -> String:
	if width <= 0 or height <= 0: return "지도 크기가 올바르지 않습니다"
	if points.size() < 2: return "연결 경로가 필요합니다"
	var length := 0.0
	for i in range(points.size()):
		var p: Vector2 = points[i]
		if not p.is_finite() or p.x < 0 or p.y < 0 or p.x > width or p.y > height:
			return "지도 경계 밖이거나 유효하지 않은 경로입니다"
		if i > 0: length += p.distance_to(points[i-1])
	if length < 0.1: return "연결 경로가 너무 짧습니다"
	return ""

static func endpoint_edge(point: Vector2, inside: Vector2, width: int, height: int) -> String:
	var sides: Array[String] = []
	if absf(point.x) <= EDGE_EPSILON: sides.append("x_min")
	if absf(point.x-width) <= EDGE_EPSILON: sides.append("x_max")
	if absf(point.y) <= EDGE_EPSILON: sides.append("y_min")
	if absf(point.y-height) <= EDGE_EPSILON: sides.append("y_max")
	# A corner cannot silently grant two neighboring towns a connection.
	if sides.size() != 1: return ""
	var edge: String = sides[0]
	if edge == "x_min" and inside.x <= EDGE_EPSILON: return ""
	if edge == "x_max" and inside.x >= width-EDGE_EPSILON: return ""
	if edge == "y_min" and inside.y <= EDGE_EPSILON: return ""
	if edge == "y_max" and inside.y >= height-EDGE_EPSILON: return ""
	return edge

static func evaluate(width: int, height: int, roads: Array, infrastructure: Array) -> Dictionary:
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/region_neighbors.json"))
	var result := {"neighbors":[], "economy_simulated":false}
	var by_edge := {}
	for spec in definition.neighbors:
		var town: Dictionary = spec.duplicate(true)
		town.channels = {}
		for kind in CHANNELS: town.channels[kind] = {"connected":false,"connection_count":0}
		town.exchange_available = false
		result.neighbors.append(town)
		by_edge[town.edge] = town
	var paths := []
	for road in roads: paths.append({"kind":"road","points":road.points})
	paths.append_array(infrastructure)
	for path in paths:
		if not path.kind in CHANNELS: continue
		var points: PackedVector2Array = path.points
		if path_error(points,width,height) != "": continue
		var touched := {}
		# Boundary contact in the middle of a path is not an external terminal.
		for pair in [[0,1],[points.size()-1,points.size()-2]]:
			var point: Vector2 = points[pair[0]]
			var inside: Vector2 = points[pair[1]]
			# Ignore redundant equal end samples when choosing the approach vector.
			var step := 1 if pair[0] == 0 else -1
			var cursor: int = pair[0]+step
			while cursor >= 0 and cursor < points.size() and points[cursor].distance_to(point) <= EDGE_EPSILON:
				cursor += step
			if cursor >= 0 and cursor < points.size(): inside = points[cursor]
			var edge := endpoint_edge(point,inside,width,height)
			if edge != "": touched[edge] = true
		for edge in touched:
			var town: Dictionary = by_edge[edge]
			town.channels[path.kind].connection_count += 1
			town.channels[path.kind].connected = true
			town.exchange_available = true
	return result
