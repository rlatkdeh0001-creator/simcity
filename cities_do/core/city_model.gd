extends RefCounted
const Catalog = preload("res://core/building_catalog.gd")
var catalog = Catalog.new()
var appearance_rng := RandomNumberGenerator.new()
const Config = preload("res://core/growth_config.gd")
var config = Config.new()
var width: int
var height: int
var buildings: Array[Dictionary] = []
var roads: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var next_id := 1

func _init(w: int = 40, h: int = 40, seed_value: int = 42):
	width = w
	height = h
	rng.seed = seed_value
	appearance_rng.seed = seed_value ^ 0x5f3759df

func _rect(b: Dictionary) -> Rect2:
	return Rect2(Vector2(b.x, b.y), Vector2(b.size, b.size))

func _point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))

func _segment_rect_distance(a: Vector2, b: Vector2, rect: Rect2) -> float:
	if rect.has_point(a) or rect.has_point(b):
		return 0.0
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var result := INF
	for i in range(4):
		var c: Vector2 = corners[i]
		var d: Vector2 = corners[(i + 1) % 4]
		if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
			return 0.0
		result = min(result, _point_segment(c, a, b), _point_segment(d, a, b), _point_segment(a, c, d), _point_segment(b, c, d))
	return result

func _road_distance(rect: Rect2, road: Dictionary) -> float:
	var result := INF
	for i in range(road.points.size() - 1):
		result = min(result, _segment_rect_distance(road.points[i], road.points[i + 1], rect) - road.width / 2.0)
	return result

func placement_error(x: int, y: int, size: int, ignore_id: int = -1) -> String:
	if size not in [2, 4, 8]:
		return "크기는 2·4·8만 가능합니다"
	var rect := Rect2(x, y, size, size)
	if x < 0 or y < 0 or x + size > width or y + size > height:
		return "지도 경계 밖입니다"
	for b in buildings:
		if b.id != ignore_id and rect.intersects(_rect(b)):
			return "다른 건물이 있습니다"
	var access := false
	for road in roads:
		var distance := _road_distance(rect, road)
		if distance <= 0.0:
			return "도로와 충돌합니다"
		if road.kind == "local" and distance <= config.road_access_distance:
			access = true
	return "" if access else "일반도로 접근이 필요합니다"

func add_building(x: int, y: int, zone: String = "residential", score: float = 0.0) -> Dictionary:
	if zone not in ["residential", "commercial", "industrial"]:
		return {"ok": false, "reason": "지원하지 않는 구획입니다"}
	var error := placement_error(x, y, 2)
	if error != "":
		return {"ok": false, "reason": error}
	var b := {"id": next_id, "x": x, "y": y, "size": 2, "level": 1, "zone": zone, "score": score, "asset_id": ""}
	next_id += 1
	buildings.append(b)
	return {"ok": true, "building": b}

func add_road(points: PackedVector2Array, kind: String = "local", commit: bool = true) -> Dictionary:
	if kind not in ["local", "highway"] or points.size() < 2:
		return {"ok": false, "reason": "도로 경로가 필요합니다"}
	var total := 0.0
	for i in range(points.size()):
		var p := points[i]
		if not p.is_finite() or p.x < 0 or p.y < 0 or p.x > width or p.y > height:
			return {"ok": false, "reason": "지도 경계 밖입니다"}
		if i > 0:
			total += points[i - 1].distance_to(p)
	if total < 0.1:
		return {"ok": false, "reason": "도로가 너무 짧습니다"}
	var road := {"points": points.duplicate(), "kind": kind, "width": config.road_width}
	for b in buildings:
		if _road_distance(_rect(b), road) <= 0.0:
			return {"ok": false, "reason": "건물과 충돌합니다"}
	if commit:
		roads.append(road)
	return {"ok": true}

func find_building(id: int) -> Dictionary:
	for b in buildings:
		if b.id == id:
			return b
	return {}

func building_at(point: Vector2) -> Dictionary:
	for b in buildings:
		if _rect(b).has_point(point):
			return b
	return {}

func adjacent(a: Dictionary, b: Dictionary) -> bool:
	var r := _rect(a)
	var s := _rect(b)
	return ((r.end.x == s.position.x or s.end.x == r.position.x) and min(r.end.y, s.end.y) > max(r.position.y, s.position.y)) or ((r.end.y == s.position.y or s.end.y == r.position.y) and min(r.end.x, s.end.x) > max(r.position.x, s.position.x))

func pick_size() -> int:
	var total := 0.0
	for weight in config.size_weights.values():
		total += max(0.0, float(weight))
	if total <= 0.0:
		return 2
	var roll := rng.randf() * total
	for size in [8, 4, 2]:
		roll -= max(0.0, float(config.size_weights.get(size, 0.0)))
		if roll < 0.0:
			return size
	return 2

func _upgrade(b: Dictionary) -> bool:
	var preferred := pick_size()
	for size in [8, 4, 2]:
		if size > preferred:
			continue
		# Search footprints containing the previous center, nearest anchor first.
		var candidates: Array[Vector2i] = []
		var center := Vector2(b.x + b.size / 2.0, b.y + b.size / 2.0)
		for x in range(int(floor(center.x)) - size + 1, int(floor(center.x)) + 1):
			for y in range(int(floor(center.y)) - size + 1, int(floor(center.y)) + 1):
				candidates.append(Vector2i(x, y))
		candidates.sort_custom(func(a, c): return Vector2(a).distance_squared_to(Vector2(b.x, b.y)) < Vector2(c).distance_squared_to(Vector2(b.x, b.y)))
		for pos in candidates:
			if placement_error(pos.x, pos.y, size, b.id) == "":
				b.x = pos.x
				b.y = pos.y
				b.size = size
				b.level += 1
				catalog.assign(b, appearance_rng)
				return true
	return false

func upgrade_chain(id: int) -> Dictionary:
	var root := find_building(id)
	if root.is_empty():
		return {"ok": false, "reason": "건물이 없습니다", "events": []}
	if root.score < config.score_threshold:
		return {"ok": false, "reason": "성장 수치가 부족합니다", "events": []}
	# Snapshot original edge neighbors so resizing does not create or erase propagation edges.
	var neighbors := {}
	for a in buildings:
		neighbors[a.id] = []
		for b in buildings:
			if a.id != b.id and adjacent(a, b):
				neighbors[a.id].append(b.id)
	var queue := [id]
	var visited := {id: true}
	var events: Array[Dictionary] = []
	while not queue.is_empty() and events.size() < config.max_chain:
		var current: int = queue.pop_front()
		var b := find_building(current)
		var old_size: int = b.size
		if not _upgrade(b):
			continue
		events.append({"id": current, "from_size": old_size, "size": b.size, "level": b.level, "cascade": current != id})
		for other in neighbors[current]:
			if not visited.has(other):
				visited[other] = true
				if rng.randf() < config.neighbor_chance:
					queue.append(other)
	return {"ok": not events.is_empty(), "events": events, "reason": "" if not events.is_empty() else "성장 가능한 공간이 없습니다"}
