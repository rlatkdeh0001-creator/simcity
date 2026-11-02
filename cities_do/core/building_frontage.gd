extends RefCounted
## Front direction in world X/Y; original Blender front -Y exports to Godot +Z.
## Require lot-side frontage in the access band, not just a nearby corner.
static func candidates(polygon: PackedVector2Array, roads: Array, access_distance: float) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var center:=Vector2.ZERO
	for point in polygon:center+=point
	center/=polygon.size()
	for road in roads:
		if road.kind!="local":continue
		for edge in range(polygon.size()):
			var a:=polygon[edge]
			var b:=polygon[(edge+1)%polygon.size()]
			var gap: float=-INF
			# Include endpoints and midpoint: a corner or short nearby road is insufficient.
			for point in [a,(a+b)/2,b]:
				var distance:=INF
				for i in range(road.points.size()-1):
					distance=minf(distance,Vector2(point).distance_to(Geometry2D.get_closest_point_to_segment(point,road.points[i],road.points[i+1])))
				gap=maxf(gap,distance-float(road.width)/2)
			if gap<=access_distance+.0005:
				result.append({"road":int(road.get("parcel_id",-1)),"gap":gap,"front":((a+b)/2-center).normalized()})
	return result

static func resolve(building: Dictionary, polygon: PackedVector2Array, roads: Array, access_distance: float) -> void:
	var chosen: Dictionary={}
	for candidate in candidates(polygon,roads,access_distance):
		var id: int=candidate.road
		var priority:=2 if id==int(building.get("front_road_id",-2)) else (1 if building.has("frame") and id==int(building.frame.road_index) else 0)
		candidate.priority=priority
		# At equal distance preserve the same face as well as the same road.
		var same_face: bool=Vector2(candidate.front).dot(direction(building))>.999
		candidate.same_face=same_face
		if chosen.is_empty() or priority>chosen.priority or (priority==chosen.priority and (candidate.gap<chosen.gap-.00001 or (absf(candidate.gap-chosen.gap)<.00001 and same_face and not chosen.same_face))):chosen=candidate
	if chosen.is_empty():
		building.front_road_id=-1
		if not building.has("front_direction"):building.front_direction=Vector2.DOWN
		return
	building.front_road_id=chosen.road
	building.front_direction=direction(building) if chosen.same_face else chosen.front

static func direction(building: Dictionary) -> Vector2:
	return building.get("front_direction",-Vector2(building.frame.outward) if building.has("frame") else Vector2.DOWN)
