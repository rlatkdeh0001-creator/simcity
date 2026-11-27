extends RefCounted
const Profile=preload("res://core/road_profile.gd")
const Height=preload("res://core/road_height.gd")
const Junctions=preload("res://core/road_junctions.gd")
const Parcels=preload("res://core/road_parcels.gd")
const ARROW_INTERVAL:=16.0 # 64 metres
const ARROW_END_INSET:=2.0
const ARROW_MIN_SPACING:=1.75
## World-space ribbons keep road width consistent across axis/diagonal/curved strokes.
static func ribbons(points: PackedVector2Array, width: float,flat_start: bool=false,flat_end: bool=false) -> Array[PackedVector2Array]:
	# Cut fragments use butt caps: two round caps would paint over a one-cell gap.
	return Geometry2D.offset_polyline(points,width/2.0,Geometry2D.JOIN_ROUND,Geometry2D.END_BUTT if flat_start or flat_end else Geometry2D.END_ROUND)
static func clipped_ribbons(points: PackedVector2Array,width: float,bounds: Vector2,flat_start: bool=false,flat_end: bool=false) -> Array[PackedVector2Array]:
	return clip_to_map(ribbons(points,width,flat_start,flat_end),bounds)
static func clip_to_map(shapes: Array[PackedVector2Array],bounds: Vector2) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	var border:=PackedVector2Array([Vector2.ZERO,Vector2(bounds.x,0),bounds,Vector2(0,bounds.y)])
	for shape in shapes:
		for clipped in Geometry2D.intersect_polygons(shape,border):
			for i in range(clipped.size()):clipped[i]=clipped[i].clamp(Vector2.ZERO,bounds)
			result.append(clipped)
	return result
static func clipped_asphalt(road: Dictionary,bounds: Vector2) -> Array[PackedVector2Array]:
	return clip_to_map(asphalt_ribbons(road),bounds)
static func asphalt_ribbons(road: Dictionary) -> Array[PackedVector2Array]:
	var edges:=Profile.asphalt_edges(road)
	var flat_start:bool=road.get("flat_start",true);var flat_end:bool=road.get("flat_end",true)
	var points:PackedVector2Array=road.points
	if is_zero_approx(edges.x+edges.y):return ribbons(points,Profile.asphalt_width(road),flat_start,flat_end)
	# On the uncurbed side, reuse the original pavement rim (including its round
	# joins). Offsetting a second centreline drifts away from that rim at bends.
	var half:=float(road.width)/2
	var result: Array[PackedVector2Array]=[]
	for pavement in ribbons(points,road.width,flat_start,flat_end):
		var asphalt:=pavement.duplicate()
		for i in range(asphalt.size()):asphalt[i]=inset_pavement_vertex(asphalt[i],points,edges/half)
		result.append_array(Geometry2D.intersect_polygons(asphalt,pavement))
	return result
static func inset_pavement_vertex(point: Vector2,points: PackedVector2Array,ratios: Vector2) -> Vector2:
	var best:=INF;var anchor:=point;var ratio:=1.0;var best_edge:=-1
	for i in range(1,points.size()):
		var a:=points[i-1];var b:=points[i]
		var nearest:=Geometry2D.get_closest_point_to_segment(point,a,b)
		var gap:=point.distance_to(nearest)
		var scale:=ratios.y if (b-a).cross(point-nearest)>0 else -ratios.x
		if gap<best-.0001:
			best=gap;anchor=nearest;ratio=scale;best_edge=i
		elif i==best_edge+1 and absf(gap-best)<=.0001 and is_equal_approx(scale,ratio):
			# An inside miter is equidistant to both edges. Inset around their
			# common vertex so both new curb segments remain parallel.
			anchor=a
	return anchor+(point-anchor)*ratio
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
			var key: String=preload("res://core/road_junctions.gd").merged_key(p,topology.nodes,Height.height_at(roads[i],p))
			if not links.has(key):links[key]=[]
			links[key].append({"road":i,"end":end})
	var used := {}
	var result := []
	for i in range(roads.size()):
		if used.has(i):continue
		used[i]=true
		var chain: PackedVector2Array=roads[i].points.duplicate()
		var heights:=PackedFloat64Array()
		for point in chain:heights.append(Height.height_at(roads[i],point))
		var source_ids:Array=[int(roads[i].get("parcel_id",-1))]
		var supports:Array=roads[i].get("piers",[]).duplicate(true)
		var seams: Array[Vector2]=[]
		for side in [0,1]:
			if side==1:chain.reverse();heights.reverse()
			while true:
				var key: String=preload("res://core/road_junctions.gd").merged_key(chain[-1],topology.nodes,heights[-1])
				if topology.nodes[key].arms.size()!=2 or links[key].size()!=2:break
				var next: Dictionary={}
				for entry in links[key]:
					if not used.has(entry.road):next=entry
				if next.is_empty():break
				var road: Dictionary=roads[next.road]
				if Height.level(road)!=Height.level(roads[i]):break
				if road.kind!=roads[i].kind or road.lanes!=roads[i].lanes or not is_equal_approx(road.width,roads[i].width):break
				var next_order:=1 if next.end==0 else -1
				var chain_order:=1 if side==0 else -1
				var travel:=Profile.travel_direction(roads[i])
				if Profile.travel_direction(road)*next_order!=travel*chain_order:break
				if travel==0 and int(road.lanes)%2 and int(road.get("major_side",1))*next_order!=int(roads[i].get("major_side",1))*chain_order:break
				var extension: PackedVector2Array=road.points.duplicate()
				if next.end==1:extension.reverse()
				seams.append(chain[-1]);used[next.road]=true
				source_ids.append(int(road.get("parcel_id",-1)));supports.append_array(road.get("piers",[]))
				for j in range(1,extension.size()):chain.append(extension[j]);heights.append(Height.height_at(road,extension[j]))
		chain.reverse();heights.reverse()
		var height_source:Dictionary={"points":chain,"heights_m":heights}
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
		if Height.off_ground(roads[i]):
			visual.heights_m=PackedFloat64Array()
			for point in smooth:visual.heights_m.append(Height.height_at(height_source,point))
			visual.source_ids=source_ids;visual.piers=supports
		var first_node: Dictionary=topology.nodes[preload("res://core/road_junctions.gd").merged_key(smooth[0],topology.nodes,heights[0])]
		var last_node: Dictionary=topology.nodes[preload("res://core/road_junctions.gd").merged_key(smooth[-1],topology.nodes,heights[-1])]
		visual.flat_start=first_node.arms.size()==1 or flat_points.any(func(p):return p.distance_to(smooth[0])<.0005)
		visual.flat_end=last_node.arms.size()==1 or flat_points.any(func(p):return p.distance_to(smooth[-1])<.0005)
		result.append(visual)
	return result

## Preview and retained rendering share the world-space glyphs. The retained
## layer additionally connects profiles across tapers and masks other paint.
static func direction_arrows(road: Dictionary) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	if Profile.travel_direction(road)==0:return result
	var surfaces:=asphalt_ribbons(road)
	for shape in arrow_run([road],[],false):
		if arrow_supported(shape,surfaces):result.append(shape)
	return result

static func arrow_supported(shape: PackedVector2Array,surfaces: Array[PackedVector2Array]) -> bool:
	var area:=Parcels.area(shape)
	var painted:=0.0
	for surface in surfaces:
		for piece in Geometry2D.intersect_polygons(shape,surface):painted+=Parcels.area(piece)
		if painted>=area-.0001:return true
	return false

static func retained_direction_arrows(visuals: Array,topology: Dictionary,surfaces: Array[PackedVector2Array],blocked: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	var parts: Array[Dictionary]=[]
	var starts: Dictionary={}
	var ends: Dictionary={}
	for road: Dictionary in visuals:
		var travel:=Profile.travel_direction(road)
		if travel==0 or Height.off_ground(road):continue
		var start:=Junctions.merged_key(road.points[0 if travel>0 else -1],topology.nodes)
		var finish:=Junctions.merged_key(road.points[-1 if travel>0 else 0],topology.nodes)
		starts[start]=parts.size();ends[finish]=parts.size()
		parts.append({"road":road,"start":start})
	# An authored stroke passing through a junction retains its phase; it gets
	# separate approach candidates in arrow_run.
	var successors: Dictionary={}
	var predecessors: Dictionary={}
	for finish: String in ends:
		if starts.has(finish) and topology.nodes[finish].arms.size()==2:
			successors[ends[finish]]=starts[finish];predecessors[starts[finish]]=true
	var order: Array=range(parts.size())
	order.sort_custom(func(a,b):
		if predecessors.has(a)!=predecessors.has(b):return not predecessors.has(a)
		return parts[a].start<parts[b].start)
	var used: Dictionary={}
	for start: int in order:
		if used.has(start):continue
		var run: Array=[]
		var cursor:=start
		while cursor>=0 and not used.has(cursor):
			used[cursor]=true;run.append(parts[cursor].road)
			cursor=successors.get(cursor,-1)
		for shape in arrow_run(run,topology.junctions,cursor==start):
			if blocked.any(func(mask):return not Geometry2D.intersect_polygons(shape,mask).is_empty()):continue
			# Keep a whole glyph rather than a fragment at a curb or map edge.
			if arrow_supported(shape,surfaces):result.append(shape)
	return result

## Split final white strokes (ordinary dashes and transition pieces), without
## restarting their phase. Arrows, medians and junction exclusion masks stay put.
static func trim_direction_arrow_marks(lines: Array[PackedVector2Array],arrows: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	if arrows.is_empty():return lines
	# Retained paint uses a butt-ended strip at the default play camera: .325px
	# opaque half-width plus a 1px AA fringe. Use that footprint, not a line/point test.
	const HALF_STROKE:=1.325
	const PAD:=.002 # Absorb Clipper quantization at a newly cut end.
	const BUCKET_SIZE:=128.0
	var buckets: Dictionary={}
	for arrow in arrows:
		var shape:=PackedVector2Array()
		for p in arrow:shape.append(_paint_projection(p))
		var bounds:=Parcels.bounds(shape)
		var key:=Vector2i((bounds.get_center()/BUCKET_SIZE).floor())
		if not buckets.has(key):buckets[key]=[]
		buckets[key].append({"shape":shape,"bounds":bounds})
	var result: Array[PackedVector2Array]=[]
	for line in lines:
		var a:=_paint_projection(line[0]);var b:=_paint_projection(line[-1])
		var length:=a.distance_to(b)
		if length<=PAD:result.append(line);continue
		var axis:=(b-a)/length
		var normal:=axis.orthogonal()*HALF_STROKE
		var strip:=PackedVector2Array([a-normal,b-normal,b+normal,a+normal])
		var bounds:=Parcels.bounds(strip)
		# A whole glyph is smaller than a bucket; look across its adjacent cells.
		var first:=Vector2i((bounds.position/BUCKET_SIZE).floor())-Vector2i.ONE
		var last:=Vector2i((bounds.end/BUCKET_SIZE).floor())+Vector2i.ONE
		var cuts: Array[Vector2]=[]
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				for mask: Dictionary in buckets.get(Vector2i(x,y),[]):
					if not bounds.intersects(mask.bounds):continue
					for piece in Geometry2D.intersect_polygons(strip,mask.shape):
						var limits:=Vector2(length,0)
						for point in piece:
							var distance:=(point-a).dot(axis)
							limits=Vector2(minf(distance,limits.x),maxf(distance,limits.y))
						cuts.append(Vector2(maxf(0,limits.x-PAD),minf(length,limits.y+PAD)))
		if cuts.is_empty():result.append(line);continue
		cuts.sort_custom(func(left,right):return left.x<right.x)
		var cursor:=0.0
		for cut in cuts:
			if cut.x>cursor+PAD:result.append(PackedVector2Array([line[0].lerp(line[-1],cursor/length),line[0].lerp(line[-1],cut.x/length)]))
			cursor=maxf(cursor,cut.y)
		if length>cursor+PAD:result.append(PackedVector2Array([line[0].lerp(line[-1],cursor/length),line[-1]]))
	return result

static func _paint_projection(point: Vector2) -> Vector2:
	return Vector2((point.x-point.y)*14,(point.x+point.y)*7)*.65

static func arrow_run(roads: Array,junctions: Array,closed: bool) -> Array[PackedVector2Array]:
	var segments: Array[Dictionary]=[]
	var length:=0.0
	for road: Dictionary in roads:
		var travel:=Profile.travel_direction(road)
		var points:PackedVector2Array=road.points
		var first:=Profile.lane_center_metres(road,travel,0)
		var last:=Profile.lane_center_metres(road,travel,int(road.lanes)-1)
		var offset:=(first+last)/8 # Average and convert metres to cells.
		for i in range(1,points.size()):
			var a:Vector2=points[i-1 if travel>0 else -i]
			var b:Vector2=points[i if travel>0 else -i-1]
			var span:=a.distance_to(b)
			if span<=.0001:continue
			segments.append({"a":a,"b":b,"start":length,"length":span,"offset":offset})
			length+=span
	var result: Array[PackedVector2Array]=[]
	if length<1.1:return result
	closed=closed or segments[0].a.is_equal_approx(segments[-1].b)
	var candidates: Array[float]=[]
	if not closed:
		var inset:=minf(ARROW_END_INSET,length/2)
		candidates.append_array([inset,length-inset])
	for junction: Dictionary in junctions:
		if absf(float(junction.height_m))>Junctions.EPS:continue
		for arm: Dictionary in junction.arms:
			var travel:=Profile.travel_direction(arm)
			if travel==0:continue
			var inset:=Junctions.stop_line_distance(junction,arm)+.75
			if inset+.55>arm.length:continue
			var point:=Junctions.sample(arm.points,inset)
			var direction:=(Junctions.sample(arm.points,inset+.001)-Junctions.sample(arm.points,inset-.001)).normalized()*travel
			for segment in segments:
				var nearest:=Geometry2D.get_closest_point_to_segment(point,segment.a,segment.b)
				if nearest.distance_to(point)<.001 and direction.dot((segment.b-segment.a).normalized())>.95:
					candidates.append(segment.start+nearest.distance_to(segment.a))
	var distance:=ARROW_INTERVAL
	while distance<length-.55:
		candidates.append(distance);distance+=ARROW_INTERVAL
	# Approaches win over periodic marks. Compare distance around loops too.
	var selected: Array[float]=[]
	for candidate in candidates:
		if selected.any(func(other):
			var gap:=absf(candidate-float(other))
			return minf(gap,length-gap)<ARROW_MIN_SPACING if closed else gap<ARROW_MIN_SPACING):continue
		selected.append(candidate)
	selected.sort()
	var index:=0
	for chainage in selected:
		while index+1<segments.size() and chainage>segments[index].start+segments[index].length:index+=1
		var segment:=segments[index]
		var a:Vector2=segment.a;var b:Vector2=segment.b
		var forward:=(b-a)/float(segment.length)
		var right:=Vector2(-forward.y,forward.x)
		var center:=a+forward*(chainage-float(segment.start))+right*float(segment.offset)
		result.append(PackedVector2Array([center+forward*.50,center+right*.24,center+right*.075,center-forward*.50+right*.075,center-forward*.50-right*.075,center-right*.075,center-right*.24]))
	return result

static func clean_polygon(source:PackedVector2Array)->PackedVector2Array:
	var polygon:=source.duplicate();var changed:=true
	while changed and polygon.size()>=3:
		changed=false
		for i in range(polygon.size()):
			var before:Vector2=polygon[posmod(i-1,polygon.size())];var point:Vector2=polygon[i];var after:Vector2=polygon[(i+1)%polygon.size()];var axis:=after-before
			if point.distance_to(before)<.00001 or (axis.length()>.00001 and absf((point-before).cross(axis))/axis.length()<.00001):
				polygon.remove_at(i);changed=true;break
	return polygon
static func outside_regions(shapes: Array[PackedVector2Array],regions: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=shapes.duplicate()
	for region in regions:
		var next: Array[PackedVector2Array]=[]
		for shape in result:
			for piece in Geometry2D.clip_polygons(shape,region):
				piece=clean_polygon(piece)
				if piece.size()>=3 and preload("res://core/road_parcels.gd").area(piece)>.00001 and not Geometry2D.triangulate_polygon(piece).is_empty():next.append(piece)
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
