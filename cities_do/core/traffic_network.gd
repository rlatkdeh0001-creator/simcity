extends RefCounted
## Directed, metre-based lane graph derived from the existing city road data.
## Crossing roads require a future junction controller; fail closed for now.
const METRES_PER_CELL := 4.0
var lanes: Array[Dictionary] = []
var errors: Array[String] = []

class LaneSearch extends AStar2D:
	var lengths := {}
	func _compute_cost(from_id: int, _to_id: int) -> float:
		return lengths[from_id]
	func _estimate_cost(_from_id: int, _end_id: int) -> float:
		# Zero is admissible for curved lanes and zero-distance endpoint nodes.
		return 0.0

var search := LaneSearch.new()

func build(roads: Array) -> bool:
	lanes.clear()
	errors.clear()
	search.clear()
	search.lengths.clear()
	_check_crossings(roads)
	if not errors.is_empty(): return false
	for road_id in range(roads.size()):
		var road: Dictionary = roads[road_id]
		var points := PackedVector2Array()
		for point in road.points:
			var metres: Vector2 = point * METRES_PER_CELL
			if points.is_empty() or points[-1].distance_to(metres) > 0.01:
				points.append(metres)
		if points.size() < 2: continue
		var closed := points[0].distance_to(points[-1]) < 0.01
		var count := int(road.lanes) / 2
		var lane_width := minf(3.5, (float(road.width) * METRES_PER_CELL - 2.0) / int(road.lanes))
		for direction in [1, -1]:
			var ordered := points.duplicate()
			if direction == -1: ordered.reverse()
			for index in range(count):
				var shifted := _offset(ordered, (index + 0.5) * lane_width, closed)
				var lane := _add_lane(shifted)
				lane.merge({"road":road_id, "direction":direction, "index":index, "closed":closed,
					"start":ordered[0], "end":ordered[-1], "speed_limit":(160.0 if road.kind == "highway" else 80.0) / 3.6})
				if closed: lane.next.append(lane.id)
	var base_count := lanes.size()
	for i in range(base_count):
		var a: Dictionary = lanes[i]
		if a.closed: continue
		for j in range(base_count):
			var b: Dictionary = lanes[j]
			if a.road == b.road or b.closed or a.index != b.index: continue
			if a.end.distance_to(b.start) > 0.05: continue
			# Only unambiguous near-straight continuations in this first integration.
			# Crossing/turning junctions need reservations rather than implicit links.
			if tangent(i, a.length).dot(tangent(j, 0.0)) < 0.95: continue
			var end_point := sample(i, a.length)
			var start_point := sample(j, 0.0)
			if end_point.distance_to(start_point) > 0.1: continue
			a.next.append(j)
	for lane in lanes:
		search.add_point(lane.id, sample(lane.id, 0.0))
		search.lengths[lane.id] = lane.length
	for lane in lanes:
		for next_id in lane.next:
			if next_id != lane.id: search.connect_points(lane.id, next_id, false)
	return errors.is_empty()

func _add_lane(points: PackedVector2Array) -> Dictionary:
	var curve := Curve3D.new()
	curve.bake_interval = 0.2
	for point in points: curve.add_point(Vector3(point.x, 0, point.y))
	var lane := {"id":lanes.size(), "curve":curve, "length":curve.get_baked_length(), "next":[]}
	lanes.append(lane)
	return lane

func _offset(points: PackedVector2Array, distance: float, closed: bool) -> PackedVector2Array:
	var result := PackedVector2Array()
	var count := points.size() - (1 if closed else 0)
	for i in range(count):
		var before: Vector2 = points[(i-1+count)%count] if closed or i > 0 else points[i]
		var after: Vector2 = points[(i+1)%count] if closed or i < count-1 else points[i]
		var incoming := (points[i]-before).normalized()
		var outgoing := (after-points[i]).normalized()
		if incoming == Vector2.ZERO: incoming = outgoing
		if outgoing == Vector2.ZERO: outgoing = incoming
		var n1 := Vector2(-incoming.y, incoming.x)
		var n2 := Vector2(-outgoing.y, outgoing.x)
		var bisector := (n1+n2).normalized()
		if bisector == Vector2.ZERO:
			errors.append("급격한 되돌림 도로는 주행할 수 없습니다")
			bisector = n2
		var offset := bisector * minf(distance / maxf(0.5, bisector.dot(n2)), distance*1.5)
		result.append(points[i]+offset)
	if closed: result.append(result[0])
	return result

func sample(lane_id: int, progress: float) -> Vector2:
	var p: Vector3 = lanes[lane_id].curve.sample_baked(clampf(progress, 0, lanes[lane_id].length))
	return Vector2(p.x, p.z)

func tangent(lane_id: int, progress: float) -> Vector2:
	var length: float = lanes[lane_id].length
	return (sample(lane_id, minf(length, progress+0.1)) - sample(lane_id, maxf(0, progress-0.1))).normalized()

func route(start: int, goal: int) -> Array:
	if start < 0 or goal < 0 or start >= lanes.size() or goal >= lanes.size(): return []
	return Array(search.get_id_path(start, goal))

func _check_crossings(roads: Array):
	for a in range(roads.size()):
		for b in range(a, roads.size()):
			var pa: PackedVector2Array = roads[a].points
			var pb: PackedVector2Array = roads[b].points
			for i in range(pa.size()-1):
				for j in range(pb.size()-1):
					if a == b and abs(i-j) <= 1: continue
					if a == b and i == 0 and j == pb.size()-2 and pa[0].is_equal_approx(pa[-1]): continue
					if a == b and j == 0 and i == pa.size()-2 and pa[0].is_equal_approx(pa[-1]): continue
					var edge := pa[i+1]-pa[i]
					if edge.length() > 0.0001 and absf(edge.cross(pb[j]-pa[i]))/edge.length() < 0.001 and absf(edge.cross(pb[j+1]-pa[i]))/edge.length() < 0.001:
						var t0 := (pb[j]-pa[i]).dot(edge)/edge.length_squared()
						var t1 := (pb[j+1]-pa[i]).dot(edge)/edge.length_squared()
						if minf(1,maxf(t0,t1))-maxf(0,minf(t0,t1)) > 0.001:
							errors.append("겹치는 도로는 주행할 수 없습니다")
							return
					var hit = Geometry2D.segment_intersects_segment(pa[i], pa[i+1], pb[j], pb[j+1])
					if hit == null: continue
					var terminal_a: bool = hit.distance_to(pa[0]) < 0.01 or hit.distance_to(pa[-1]) < 0.01
					var terminal_b: bool = hit.distance_to(pb[0]) < 0.01 or hit.distance_to(pb[-1]) < 0.01
					if a != b and terminal_a and terminal_b:
						var da := (pa[i+1]-pa[i]).normalized()
						var db := (pb[j+1]-pb[j]).normalized()
						if absf(da.dot(db)) > 0.95: continue
					errors.append("교차·분기 도로는 교차로 제어 연결 후 주행할 수 있습니다")
					return
