extends RefCounted
## Road-local orthonormal blocks. Curves are piecewise-straight, never bent cells.
static func blocks(points: PackedVector2Array, half_width: float, road_index: int, max_length: float = 8.0, turn_degrees: float = 10.0, deviation: float = 0.25) -> Array[Dictionary]:
	var clean := PackedVector2Array()
	for point in points:
		if clean.is_empty() or clean[-1].distance_to(point)>0.00001: clean.append(point)
	var spans: Array[PackedVector2Array] = []
	if clean.size()<2:return []
	var current := PackedVector2Array([clean[0]])
	for i in range(1,clean.size()):
		var a: Vector2 = current[-1]
		var b: Vector2 = clean[i]
		# Subdivide long input segments so sampling density cannot determine block length.
		var steps := maxi(1,ceili(a.distance_to(b)/1.0))
		for step in range(1,steps+1):
			var candidate := a.lerp(b,float(step)/steps)
			var trial := current.duplicate();trial.append(candidate)
			var chord: Vector2 = candidate-current[0]
			var valid := true
			if chord.length()>0.00001:
				for k in range(trial.size()-1):
					var segment: Vector2 = trial[k+1]-trial[k]
					if segment.length()<0.00001:continue
					if absf(segment.angle_to(chord))>deg_to_rad(turn_degrees) or trial[k].distance_to(Geometry2D.get_closest_point_to_segment(trial[k],trial[0],candidate))>deviation:
						valid=false;break
			if valid and chord.length()>max_length+0.00001 and current.size()>1:
				var delta: Vector2=candidate-current[-1]
				var offset: Vector2=current[-1]-current[0]
				var aa:=delta.length_squared()
				var bb:=2.0*offset.dot(delta)
				var cc:=offset.length_squared()-max_length*max_length
				var t:=clampf((-bb+sqrt(maxf(0,bb*bb-4*aa*cc)))/(2*aa),0,1)
				var boundary: Vector2=current[-1]+delta*t
				current.append(boundary);spans.append(current)
				current=PackedVector2Array([boundary,candidate])
			elif not valid and current.size()>1:
				spans.append(current)
				current=PackedVector2Array([current[-1],candidate])
			else:current.append(candidate)
	if current.size()>1:spans.append(current)
	var result: Array[Dictionary] = []
	var travelled:=0.0
	for index in range(spans.size()):
		var span := spans[index]
		var arc_start:=travelled
		for i in range(1,span.size()):travelled+=span[i-1].distance_to(span[i])
		var length := span[0].distance_to(span[-1])
		var columns := floori(length+0.0005)
		if columns<1:continue
		var tangent := (span[-1]-span[0]).normalized()
		for side in [-1,1]:
			var normal: Vector2 = Vector2(-tangent.y,tangent.x)*side
			result.append({"id":"%d:%d:%d" % [road_index,index,side],"road_index":road_index,"side":side,"origin":span[0]+normal*half_width,"along":tangent,"outward":normal,"columns":columns,"arc_start":arc_start,"centerline":span.duplicate()})
	return result

static func polygon(frame: Dictionary, u: int, v: int, size: int = 1) -> PackedVector2Array:
	var origin: Vector2 = frame.origin+frame.along*u+frame.outward*v
	return PackedVector2Array([origin,origin+frame.along*size,origin+(frame.along+frame.outward)*size,origin+frame.outward*size])

static func area(polygon_value: PackedVector2Array) -> float:
	var total := 0.0
	var origin:=polygon_value[0]
	for i in range(polygon_value.size()):total+=(polygon_value[i]-origin).cross(polygon_value[(i+1)%polygon_value.size()]-origin)
	return absf(total)*0.5

static func overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for intersection in Geometry2D.intersect_polygons(a,b):
		if area(intersection)>0.0005:return true
	return false

static func bounds(polygon_value: PackedVector2Array) -> Rect2:
	var rect := Rect2(polygon_value[0],Vector2.ZERO)
	for point in polygon_value:rect=rect.expand(point)
	return rect
