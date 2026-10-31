extends RefCounted
## World-space ribbons keep road width consistent across axis/diagonal/curved strokes.
static func ribbons(points: PackedVector2Array, width: float) -> Array[PackedVector2Array]:
	return Geometry2D.offset_polyline(points,width/2.0,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
static func lane_marks(road: Dictionary) -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	if road.lanes != 4: return lines
	var phase := 0.0
	for i in range(road.points.size()-1):
		var a: Vector2 = road.points[i]
		var b: Vector2 = road.points[i+1]
		var length := a.distance_to(b)
		if length < 0.00001: continue
		var direction := (b-a)/length
		var normal := Vector2(-direction.y,direction.x)
		var start := 0.0
		while start < length:
			var cycle := fposmod(phase+start,1.25)
			var end := minf(length,start+(0.75-cycle if cycle<0.75 else 1.25-cycle))
			if cycle < 0.75:
				for sign_value in [-1,1]:
					var shift: Vector2 = normal*road.width*(3.25/16.0)*sign_value
					lines.append(PackedVector2Array([a+direction*start+shift,a+direction*end+shift]))
			start = end+0.00001
		phase += length
	return lines
