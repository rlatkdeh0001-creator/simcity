extends RefCounted
## Front direction in world X/Y; original Blender front -Y exports to Godot +Z.
static func resolve(building: Dictionary, polygon: PackedVector2Array, roads: Array, access_distance: float) -> void:
	var center := Vector2.ZERO
	for p in polygon: center += p
	center /= polygon.size()
	var chosen := {}
	var distance := INF
	# Keep the existing frontage at corners instead of turning whenever another road is added.
	for road in roads:
		if road.kind != "local": continue
		var id: int = road.get("parcel_id", -1)
		for i in range(road.points.size()-1):
			var closest := Geometry2D.get_closest_point_to_segment(center,road.points[i],road.points[i+1])
			var edge_distance := INF
			for j in range(polygon.size()):
				var a := polygon[j]
				var b := polygon[(j+1)%polygon.size()]
				edge_distance = minf(edge_distance, a.distance_to(Geometry2D.get_closest_point_to_segment(a,road.points[i],road.points[i+1])))
				edge_distance = minf(edge_distance, road.points[i].distance_to(Geometry2D.get_closest_point_to_segment(road.points[i],a,b)))
				edge_distance = minf(edge_distance, road.points[i+1].distance_to(Geometry2D.get_closest_point_to_segment(road.points[i+1],a,b)))
			if edge_distance-road.width/2.0 > access_distance+.0005: continue
			var d := center.distance_to(closest)-float(road.width)/2
			var priority := 2 if id == int(building.get("front_road_id",-2)) else (1 if building.has("frame") and id==int(building.frame.road_index) else 0)
			if chosen.is_empty() or (priority>chosen.priority) or (priority==chosen.priority and d<distance-.00001):
				distance=d
				chosen={"road":id,"toward":(closest-center).normalized(),"priority":priority}
	if chosen.is_empty():
		building.front_road_id = -1
		# A disconnected building keeps its last orientation; it is not moved or demolished.
		if not building.has("front_direction"): building.front_direction = Vector2.DOWN
		return
	building.front_road_id = chosen.road
	# Select a side of the existing square lot, never rotate its collision footprint.
	var best := -Vector2(building.frame.outward) if building.has("frame") else Vector2.DOWN
	var directions: Array=[Vector2.RIGHT,Vector2.UP,Vector2.LEFT]
	if building.has("frame"):
		directions=[building.frame.along,-Vector2(building.frame.along),building.frame.outward]
	for candidate in directions:
		var direction: Vector2=candidate
		if direction.dot(chosen.toward)>best.dot(chosen.toward)+.00001:best=direction
	building.front_direction=best

static func direction(building: Dictionary) -> Vector2:
	return building.get("front_direction",-Vector2(building.frame.outward) if building.has("frame") else Vector2.DOWN)
