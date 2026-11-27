extends RefCounted
## Directed, metre-based lane graph derived from the existing city road data.
## At-grade crossings use turn connectors and simulation reservations.
const Junctions = preload("res://core/road_junctions.gd")
const Profile = preload("res://core/road_profile.gd")
const RoadGeometry = preload("res://core/road_geometry.gd")
const CenterPortals = preload("res://core/center_flyover_portals.gd")
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
	var split_lanes:Dictionary={}
	for section in topology.sections:
		var road_id: int=section.road
		var road: Dictionary=roads[road_id]
		var original: PackedVector2Array=section.points
		var length: float=Junctions.length_of(original)
		var first: Dictionary=topology.nodes[section.start_node]
		var last: Dictionary=topology.nodes[section.end_node]
		var first_connection: Dictionary=Junctions.connection(first,topology)
		var last_connection: Dictionary=Junctions.connection(last,topology)
		var reverse:=original.duplicate();reverse.reverse()
		var trim_start: float=minf(length*.4,Junctions.boundary_distance(first_connection,original)) if not first_connection.is_empty() else 0.0
		var trim_end: float=minf(length*.4,Junctions.boundary_distance(last_connection,reverse)) if not last_connection.is_empty() else 0.0
		var cells: PackedVector2Array=Junctions.slice(original,trim_start,length-trim_end)
		var points := PackedVector2Array()
		for point in cells:points.append(point*METRES_PER_CELL)
		if points.size()<2:continue
		var closed: bool=first_connection.is_empty() and last_connection.is_empty() and points[0].distance_to(points[-1])<.01
		for direction in [1,-1]:
			var count:=Profile.direction_count(road,direction)
			if count==0:continue
			var ordered := points.duplicate()
			if direction==-1:ordered.reverse()
			for index in range(count):
				var offset:=Profile.lane_center_metres(road,direction,index)
				var shifted:=CenterPortals.lane_points(road,section,float(section.first)+trim_start,float(section.last)-trim_end,direction,index,offset) if road.has("center_portals") else PackedVector2Array()
				var lane := _add_lane(_offset(ordered,offset,closed) if shifted.is_empty() else shifted)
				lane.merge({"road":road_id,"section":section.id,"direction":direction,"index":index,"closed":closed,"junction":-1,
					"start":original[0 if direction==1 else -1]*METRES_PER_CELL,"end":original[-1 if direction==1 else 0]*METRES_PER_CELL,
					"start_node":section.start_node if direction==1 else section.end_node,"end_node":section.end_node if direction==1 else section.start_node,
					"speed_limit":(160.0 if road.kind=="highway" else 80.0)/3.6})
				if closed:lane.next.append(lane.id)
				if not topology.splits.is_empty():split_lanes[Vector3i(section.id,direction,index)]=lane.id
	var base_count := lanes.size()
	var seam_asphalt := {}
	for i in range(base_count):
		var a: Dictionary=lanes[i]
		if a.closed:continue
		var node: Dictionary=topology.nodes[a.end_node]
		if node.get("center_split",false) and node.junction<0:continue # Explicit portal mapping only.
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
			var start := sample(i,a.length)
			var finish := sample(j,0)
			var handle := minf(start.distance_to(finish)*.5,float(connection.radius)*METRES_PER_CELL*.8)
			var c1 := start+incoming*handle
			var c2 := finish-outgoing*handle
			# For ordinary turns, use a shared control point at the lane tangent
			# intersection. At a tight directed bend the signed outer-lane offsets
			# can put that intersection far beyond the seam. Cap the two handles
			# independently so both endpoint tangents still match their lanes.
			var directed := Profile.travel_direction(roads[a.road])!=0 or Profile.travel_direction(roads[b.road])!=0
			var denominator := incoming.cross(outgoing)
			if absf(denominator)>.001:
				var delta := finish-start
				var along_in := delta.cross(outgoing)/denominator
				var along_out := incoming.cross(delta)/denominator
				if along_in>=0 and along_out>=0:
					if directed:
						c1=start+incoming*minf(along_in,handle)
						c2=finish-outgoing*minf(along_out,handle)
					else:
						var corner := start+incoming*along_in
						c1=corner
						c2=corner
			var connector := _add_lane(_cubic(start,c1,c2,finish))
			if directed and node.join>=0 and not connection.has("box") and roads[a.road].lanes!=roads[b.road].lanes:
				# A bent same-width profile change is not merged into a continuous
				# render ribbon. Its two asphalt strips end at the seam; there is
				# no asphalt in the outside wedge between their butt ends.
				if not seam_asphalt.has(node.key):
					var surfaces: Array[PackedVector2Array] = []
					for arm in connection.arms:
						surfaces.append_array(RoadGeometry.asphalt_ribbons(arm))
					seam_asphalt[node.key]=surfaces
				var asphalt: Array[PackedVector2Array]=seam_asphalt[node.key]
				if not _on_asphalt(connector.curve,asphalt):
					var inside: Vector2=(connection.arms[0].direction+connection.arms[1].direction).normalized()
					var width := minf(Profile.asphalt_width(roads[a.road]),Profile.asphalt_width(roads[b.road]))*METRES_PER_CELL
					# Try the overlap, not the outside tangent intersection. Keep the
					# legal connector even if a degenerate arm offers no better curve.
					for inset in [width/8.0,width/16.0,width/4.0]:
						var pivot: Vector2=node.position*METRES_PER_CELL+inside*inset
						var rerouted := _seam_curve(start,finish,incoming,outgoing,pivot)
						if not _on_asphalt(rerouted,asphalt):continue
						connector.curve=rerouted
						connector.length=rerouted.get_baked_length()
						break
			connector.merge({"road":-1,"section":-1,"direction":0,"index":a.index,"closed":false,"junction":node.junction,"transition":node.join>=0,"from":i,"to":j,"start":start,"end":finish,"speed_limit":minf(a.speed_limit,b.speed_limit) if node.join>=0 else 30.0/3.6})
			a.next.append(connector.id)
			connector.next.append(j)
	for split in topology.splits:
		for link in split.links:
			var member:int=split_lanes.get(Vector3i(link.member_section,link.member_direction,link.member_index),-1)
			var trunk:int=split_lanes.get(Vector3i(link.trunk_section,link.trunk_direction,link.trunk_index),-1)
			if member<0 or trunk<0:continue
			var from:int=member if link.from_member else trunk
			var to:int=trunk if link.from_member else member
			if sample(from,lanes[from].length).distance_to(sample(to,0))<.003 and to not in lanes[from].next:lanes[from].next.append(to)
	for lane in lanes:
		search.add_point(lane.id,sample(lane.id,0))
		search.lengths[lane.id]=lane.length
	for lane in lanes:
		for next_id in lane.next:
			if next_id!=lane.id:search.connect_points(lane.id,next_id,false)
	return errors.is_empty()

func _cubic(start: Vector2,c1: Vector2,c2: Vector2,finish: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in range(25):
		var t := step/24.0
		var u := 1-t
		points.append(start*u*u*u+c1*3*u*u*t+c2*3*u*t*t+finish*t*t*t)
	return points

func _seam_curve(start: Vector2,finish: Vector2,incoming: Vector2,outgoing: Vector2,pivot: Vector2) -> Curve3D:
	# Two cubics keep the lane endpoints and share a tangent at the seam.
	var before := start.distance_to(pivot)/3.0
	var after := finish.distance_to(pivot)/3.0
	var middle := (incoming+outgoing).normalized()*minf(before,after)*.5
	var points := _cubic(start,start+incoming*before,pivot-middle,pivot)
	var second := _cubic(pivot,pivot+middle,finish-outgoing*after,finish)
	points.append_array(second.slice(1))
	return _curve(points)

func _on_asphalt(curve: Curve3D,surfaces: Array[PackedVector2Array]) -> bool:
	var points := curve.get_baked_points()
	for i in range(1,points.size()):
		var a := Vector2(points[i-1].x,points[i-1].z)/METRES_PER_CELL
		var b := Vector2(points[i].x,points[i].z)/METRES_PER_CELL
		var delta := b-a
		var length_squared := delta.length_squared()
		if length_squared==0.0:continue
		# Between adjacent boundary crossings the union's coverage is constant.
		# Test full baked chords, including excursions smaller than a sample step.
		var cuts: Array[float]=[0.0,1.0]
		for polygon in surfaces:
			for j in range(polygon.size()):
				var hit: Variant=Geometry2D.segment_intersects_segment(a,b,polygon[j],polygon[(j+1)%polygon.size()])
				if hit!=null:cuts.append(clampf((hit-a).dot(delta)/length_squared,0,1))
		cuts.sort()
		for j in range(1,cuts.size()):
			var middle := a.lerp(b,(cuts[j-1]+cuts[j])*.5)
			if not surfaces.any(func(poly):return Geometry2D.is_point_in_polygon(middle,poly)):return false
	return true

func _curve(points: PackedVector2Array) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.2
	for point in points: curve.add_point(Vector3(point.x, 0, point.y))
	return curve

func _add_lane(points: PackedVector2Array) -> Dictionary:
	var curve := _curve(points)
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
		var offset := bisector * distance * minf(1.0 / maxf(0.5, bisector.dot(n2)), 1.5)
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
