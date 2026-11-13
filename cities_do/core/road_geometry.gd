extends RefCounted
const Profile=preload("res://core/road_profile.gd")
## World-space ribbons keep road width consistent across axis/diagonal/curved strokes.
static func ribbons(points: PackedVector2Array, width: float,flat_start: bool=false,flat_end: bool=false) -> Array[PackedVector2Array]:
	# Cut fragments use butt caps: two round caps would paint over a one-cell gap.
	return Geometry2D.offset_polyline(points,width/2.0,Geometry2D.JOIN_ROUND,Geometry2D.END_BUTT if flat_start or flat_end else Geometry2D.END_ROUND)
static func clipped_ribbons(points: PackedVector2Array,width: float,bounds: Vector2,flat_start: bool=false,flat_end: bool=false) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	var border:=PackedVector2Array([Vector2.ZERO,Vector2(bounds.x,0),bounds,Vector2(0,bounds.y)])
	for shape in ribbons(points,width,flat_start,flat_end):
		for clipped in Geometry2D.intersect_polygons(shape,border):
			for i in range(clipped.size()):clipped[i]=clipped[i].clamp(Vector2.ZERO,bounds)
			result.append(clipped)
	return result
static func clipped_segment(a: Vector2,b: Vector2,bounds: Vector2) -> PackedVector2Array:
	var first:=0.0
	var last:=1.0
	var delta:=b-a
	for axis in [0,1]:
		if absf(delta[axis])<.000001:
			if a[axis]<0 or a[axis]>bounds[axis]:return PackedVector2Array()
			continue
		var near: float=(0-a[axis])/delta[axis]
		var far: float=(bounds[axis]-a[axis])/delta[axis]
		first=maxf(first,minf(near,far))
		last=minf(last,maxf(near,far))
		if last<first:return PackedVector2Array()
	return PackedVector2Array([a.lerp(b,first).clamp(Vector2.ZERO,bounds),a.lerp(b,last).clamp(Vector2.ZERO,bounds)])

static func continuous_roads(roads: Array, topology: Dictionary={}) -> Array:
	# Derived render-only chains. Construction IDs, zoning and authored points stay intact.
	if topology.is_empty():topology=preload("res://core/road_junctions.gd").analyze(roads)
	var links := {}
	var flat_points: Array[Vector2]=[]
	for i in range(roads.size()):
		if roads[i].get("flat_start",false):flat_points.append(roads[i].points[0])
		if roads[i].get("flat_end",false):flat_points.append(roads[i].points[-1])
		for end in [0,1]:
			var p: Vector2=roads[i].points[0 if end==0 else -1]
			var key: Vector2i=preload("res://core/road_junctions.gd").merged_key(p,topology.nodes)
			if not links.has(key):links[key]=[]
			links[key].append({"road":i,"end":end})
	var used := {}
	var result := []
	for i in range(roads.size()):
		if used.has(i):continue
		used[i]=true
		var chain: PackedVector2Array=roads[i].points.duplicate()
		var seams: Array[Vector2]=[]
		for side in [0,1]:
			if side==1:chain.reverse()
			while true:
				var key: Vector2i=preload("res://core/road_junctions.gd").merged_key(chain[-1],topology.nodes)
				if topology.nodes[key].arms.size()!=2 or links[key].size()!=2:break
				var next: Dictionary={}
				for entry in links[key]:
					if not used.has(entry.road):next=entry
				if next.is_empty():break
				var road: Dictionary=roads[next.road]
				if road.kind!=roads[i].kind or road.lanes!=roads[i].lanes or not is_equal_approx(road.width,roads[i].width):break
				if int(road.lanes)%2 and int(road.get("major_side",1))*(1 if next.end==0 else -1)!=int(roads[i].get("major_side",1))*(1 if side==0 else -1):break
				var extension: PackedVector2Array=road.points.duplicate()
				if next.end==1:extension.reverse()
				seams.append(chain[-1]);used[next.road]=true
				for j in range(1,extension.size()):chain.append(extension[j])
		chain.reverse()
		var smooth := PackedVector2Array()
		for j in range(chain.size()):
			if j==0 or j==chain.size()-1 or not seams.has(chain[j]):smooth.append(chain[j]);continue
			var before: Vector2=(chain[j]-chain[j-1]).normalized()
			var after: Vector2=(chain[j+1]-chain[j]).normalized()
			if before.dot(after)>.99999:smooth.append(chain[j]);continue
			var inset: float=minf(float(roads[i].width)*.6,minf(chain[j].distance_to(chain[j-1]),chain[j].distance_to(chain[j+1]))*.24)
			var a: Vector2=chain[j]-before*inset
			var b: Vector2=chain[j]+after*inset
			for step in range(13):
				var t:=step/12.0
				smooth.append(a*(1-t)*(1-t)+chain[j]*2*(1-t)*t+b*t*t)
		var visual: Dictionary=roads[i].duplicate()
		visual.points=smooth
		var first_node: Dictionary=topology.nodes[preload("res://core/road_junctions.gd").merged_key(smooth[0],topology.nodes)]
		var last_node: Dictionary=topology.nodes[preload("res://core/road_junctions.gd").merged_key(smooth[-1],topology.nodes)]
		visual.flat_start=first_node.arms.size()==1 or flat_points.any(func(p):return p.distance_to(smooth[0])<.0005)
		visual.flat_end=last_node.arms.size()==1 or flat_points.any(func(p):return p.distance_to(smooth[-1])<.0005)
		result.append(visual)
	return result

static func outside_regions(shapes: Array[PackedVector2Array],regions: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=shapes.duplicate()
	for region in regions:
		var next: Array[PackedVector2Array]=[]
		for shape in result:
			for piece in Geometry2D.clip_polygons(shape,region):
				if piece.size()>=3:next.append(piece)
		result=next
	return result

static func visible_lines(points: PackedVector2Array,bounds: Vector2,regions: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	for i in range(1,points.size()):
		var line:=clipped_segment(points[i-1],points[i],bounds)
		if line.size()!=2:continue
		var delta: Vector2=line[1]-line[0]
		if delta.length_squared()<.00000001:continue
		var cuts: Array[float]=[0,1]
		for region in regions:
			for edge in range(region.size()):
				var point=Geometry2D.segment_intersects_segment(line[0],line[1],region[edge],region[(edge+1)%region.size()])
				if point!=null:cuts.append(clampf((point-Vector2(line[0])).dot(delta)/delta.length_squared(),0,1))
		cuts.sort()
		for j in range(1,cuts.size()):
			if cuts[j]-cuts[j-1]<.00001:continue
			var middle: Vector2=line[0]+delta*(cuts[j]+cuts[j-1])/2
			var hidden:=false
			for region in regions:
				if Geometry2D.is_point_in_polygon(middle,region):hidden=true;break
			if not hidden:result.append(PackedVector2Array([line[0]+delta*cuts[j-1],line[0]+delta*cuts[j]]))
	return result

static func lane_marks(road: Dictionary) -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	var offsets:=Profile.separators(road)
	if offsets.is_empty(): return lines
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
				for offset in offsets:
					var shift: Vector2 = normal*offset
					lines.append(PackedVector2Array([a+direction*start+shift,a+direction*end+shift]))
			start = end+0.00001
		phase += length
	return lines
static func shoulder_marks(road: Dictionary) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	for offset in Profile.shoulder_offsets(road):result.append(Profile.offset_path(road.points,offset))
	return result
