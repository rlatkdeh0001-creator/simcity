extends RefCounted
## Directed, metre-based lane graph derived from the existing city road data.
## At-grade crossings use turn connectors and simulation reservations.
const Junctions = preload("res://core/road_junctions.gd")
const Profile = preload("res://core/road_profile.gd")
var junctions: Array = []
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
	junctions.clear()
	search.clear()
	search.lengths.clear()
	var topology: Dictionary=Junctions.analyze(roads)
	errors.assign(topology.errors)
	if not errors.is_empty(): return false
	junctions=topology.junctions
	for section in topology.sections:
		var road_id: int=section.road
		var road: Dictionary=roads[road_id]
		var original: PackedVector2Array=section.points
		var length: float=Junctions.length_of(original)
		var first: Dictionary=topology.nodes[section.start_node]
		var last: Dictionary=topology.nodes[section.end_node]
		var first_connection: Dictionary=Junctions.connection(first,topology)
		var last_connection: Dictionary=Junctions.connection(last,topology)
		var trim_start: float=minf(length*.4,first_connection.radius) if not first_connection.is_empty() else 0.0
		var trim_end: float=minf(length*.4,last_connection.radius) if not last_connection.is_empty() else 0.0
		var cells: PackedVector2Array=Junctions.slice(original,trim_start,length-trim_end)
		var points := PackedVector2Array()
		for point in cells:points.append(point*METRES_PER_CELL)
		if points.size()<2:continue
		var closed: bool=first_connection.is_empty() and last_connection.is_empty() and points[0].distance_to(points[-1])<.01
		var lane_width := Profile.lane_width_metres(road)
		for direction in [1,-1]:
			var count:=Profile.direction_count(road,direction)
			var ordered := points.duplicate()
			if direction==-1:ordered.reverse()
			for index in range(count):
				var lane := _add_lane(_offset(ordered,(index+.5)*lane_width+Profile.median_offset(road)*METRES_PER_CELL*direction,closed))
				lane.merge({"road":road_id,"section":section.id,"direction":direction,"index":index,"closed":closed,"junction":-1,
					"start":original[0 if direction==1 else -1]*METRES_PER_CELL,"end":original[-1 if direction==1 else 0]*METRES_PER_CELL,
					"start_node":section.start_node if direction==1 else section.end_node,"end_node":section.end_node if direction==1 else section.start_node,
					"speed_limit":(160.0 if road.kind=="highway" else 80.0)/3.6})
				if closed:lane.next.append(lane.id)
	var base_count := lanes.size()
	for i in range(base_count):
		var a: Dictionary=lanes[i]
		if a.closed:continue
		var node: Dictionary=topology.nodes[a.end_node]
		for j in range(base_count):
			var b: Dictionary=lanes[j]
			if i==j or b.closed or a.end_node!=b.start_node:continue
			var incoming := tangent(i,a.length)
			var outgoing := tangent(j,0)
			var connection: Dictionary=Junctions.connection(node,topology)
			if connection.is_empty():
				if a.road==b.road or a.index!=b.index or incoming.dot(outgoing)<.95:continue
				if sample(i,a.length).distance_to(sample(j,0))<.1:a.next.append(j)
				continue
			if incoming.dot(outgoing)<-.95:continue # No U-turn into the incoming carriageway.
			var outgoing_count: int=Profile.direction_count(roads[b.road],b.direction)
			if b.index!=mini(a.index,outgoing_count-1):continue
			var points := PackedVector2Array()
			var start := sample(i,a.length)
			var finish := sample(j,0)
			var handle := minf(start.distance_to(finish)*.5,float(connection.radius)*METRES_PER_CELL*.8)
			var c1 := start+incoming*handle
			var c2 := finish-outgoing*handle
			# Keep turns inside the rectangular road union instead of cutting
			# across the formerly flared junction corners.
			var denominator := incoming.cross(outgoing)
			if absf(denominator)>.001:
				var delta := finish-start
				var along_in := delta.cross(outgoing)/denominator
				var along_out := incoming.cross(delta)/denominator
				if along_in>=0 and along_out>=0:
					var corner := start+incoming*along_in
					c1=corner
					c2=corner
			for step in range(25):
				var t := step/24.0
				var u := 1-t
				points.append(start*u*u*u+c1*3*u*u*t+c2*3*u*t*t+finish*t*t*t)
			var connector := _add_lane(points)
			connector.merge({"road":-1,"section":-1,"direction":0,"index":a.index,"closed":false,"junction":node.junction,"transition":node.join>=0,"from":i,"to":j,"start":start,"end":finish,"speed_limit":minf(a.speed_limit,b.speed_limit) if node.join>=0 else 30.0/3.6})
			a.next.append(connector.id)
			connector.next.append(j)
	for lane in lanes:
		search.add_point(lane.id,sample(lane.id,0))
		search.lengths[lane.id]=lane.length
	for lane in lanes:
		for next_id in lane.next:
			if next_id!=lane.id:search.connect_points(lane.id,next_id,false)
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
