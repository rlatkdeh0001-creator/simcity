extends RefCounted
## Road widths include sidewalks. Odd lane totals use asymmetric two-way carriageways.
static func ribbons(points: PackedVector2Array, width: float) -> Array[PackedVector2Array]:
	return Geometry2D.offset_polyline(points,width/2.0,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
static func allows_solid_edge_lines(road:Dictionary)->bool:
	return road.get("kind","local")!="ramp"
static func carriageway_width(road: Dictionary) -> float:
	return road.width*(.88 if road.get("kind","local") in ["highway","ramp"] else {2:.75,3:.8,4:.8125,5:.825,8:.875}.get(int(road.lanes),.8))
static func lane_profile(road: Dictionary) -> Dictionary:
	var forward:=ceili(float(road.lanes)/2);var backward:=floori(float(road.lanes)/2)
	if road.get("reverse_lanes",false):
		var tmp:=forward;forward=backward;backward=tmp
	var lane_width:float=carriageway_width(road)/road.lanes
	return {"forward":forward,"backward":backward,"lane_width":lane_width,"median_offset":-carriageway_width(road)/2+backward*lane_width}
static func offset_line(points: PackedVector2Array,offset: float) -> PackedVector2Array:
	var clean:=PackedVector2Array()
	for p in points:
		if clean.is_empty() or p.distance_to(clean[-1])>.00001:clean.append(p)
	var result:=PackedVector2Array()
	for i in range(clean.size()):
		var before:Vector2=(clean[i]-clean[maxi(0,i-1)]).normalized()
		var after:Vector2=(clean[mini(clean.size()-1,i+1)]-clean[i]).normalized()
		if before==Vector2.ZERO:before=after
		if after==Vector2.ZERO:after=before
		var n0:=Vector2(-before.y,before.x);var n1:=Vector2(-after.y,after.x)
		var miter:Vector2=(n0+n1).normalized();var denominator:=miter.dot(n0)
		result.append(clean[i]+miter*offset/maxf(.5,denominator))
	return result
static func center_marks(road: Dictionary) -> Array[PackedVector2Array]:
	var result:Array[PackedVector2Array]=[]
	if road.get("kind","local")=="ramp":return result
	var p:=offset_line(road.points,lane_profile(road).median_offset)
	for i in range(p.size()-1):result.append(PackedVector2Array([p[i],p[i+1]]))
	return result
static func lane_marks(road: Dictionary) -> Array[PackedVector2Array]:
	var result:Array[PackedVector2Array]=[];var profile:=lane_profile(road)
	for boundary in range(1,int(road.lanes)):
		if boundary==profile.backward:continue
		var offset:float=-carriageway_width(road)/2+boundary*profile.lane_width
		var points:=offset_line(road.points,offset);var phase:=0.0
		for i in range(points.size()-1):
			var a:=points[i];var delta:Vector2=points[i+1]-a;var length:=delta.length();var start:=0.0
			while start<length:
				var cycle:=fposmod(phase+start,1.25)
				var end:=minf(length,start+(.75-cycle if cycle<.75 else 1.25-cycle))
				if cycle<.75 and length>.00001:result.append(PackedVector2Array([a+delta*start/length,a+delta*end/length]))
				start=end+.00001
			phase+=length
	return result
static func direction_arrows(road: Dictionary) -> Array[PackedVector2Array]:
	var result:Array[PackedVector2Array]=[]
	if not int(road.lanes) in [3,5,8] and road.get("kind","local") not in ["highway","ramp"]:return result
	var profile:=lane_profile(road)
	for i in range(road.points.size()-1):
		var a:Vector2=road.points[i];var delta:Vector2=road.points[i+1]-a
		if road.get("kind","local")=="ramp":
			if i!=int((road.points.size()-1)/2):continue
		elif delta.length()<6:continue
		var direction:=delta.normalized();var normal:=Vector2(-direction.y,direction.x)
		for lane in range(int(road.lanes)):
			var offset:float=-carriageway_width(road)/2+(lane+.5)*profile.lane_width
			var center:Vector2=a+delta*.35+normal*offset
			var heading:=direction if lane>=profile.backward else -direction
			result.append(PackedVector2Array([center+heading*.42,center-heading*.15+normal*.18,center-heading*.05,center-heading*.15-normal*.18]))
	return result
static func clip_marks(lines: Array[PackedVector2Array],junctions: Array) -> Array[PackedVector2Array]:
	var result:Array[PackedVector2Array]=[]
	for line in lines:
		var a:=line[0];var d:Vector2=line[1]-a;var length2:=d.length_squared()
		if length2<.0000001:continue
		var cuts:Array=[0.0,1.0]
		for j in junctions:
			var offset:Vector2=a-j.position;var bb:=2*offset.dot(d);var cc:float=offset.length_squared()-j.radius*j.radius
			var discriminant:float=bb*bb-4*length2*cc
			if discriminant<0:continue
			for t in [(-bb-sqrt(discriminant))/(2*length2),(-bb+sqrt(discriminant))/(2*length2)]:
				if t>0 and t<1:cuts.append(t)
		cuts.sort()
		for i in range(cuts.size()-1):
			var middle:Vector2=a+d*(cuts[i]+cuts[i+1])/2;var inside:=false
			for j in junctions:
				if middle.distance_to(j.position)<j.radius:inside=true;break
			if not inside and cuts[i+1]-cuts[i]>.00001:result.append(PackedVector2Array([a+d*cuts[i],a+d*cuts[i+1]]))
	return result
