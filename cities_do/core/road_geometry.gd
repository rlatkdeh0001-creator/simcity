extends RefCounted
const Profile=preload("res://core/road_profile.gd")
const Height=preload("res://core/road_height.gd")
const Junctions=preload("res://core/road_junctions.gd")
const Parcels=preload("res://core/road_parcels.gd")
const Transitions=preload("res://core/road_transitions.gd")
const ARROW_INTERVAL:=16.0 # 64 metres
const ARROW_END_INSET:=2.0
const ARROW_MIN_SPACING:=1.75
const BRANCH_STRIPE_GAP:=.02 # Cells; leave 8 cm of asphalt at the curb.
const REFERENCE_ZOOM:=.65
const PAINT_TILE:=Vector2(14,7)
const WHITE_HALF_STROKE:=REFERENCE_ZOOM*.5+1.0 # Opaque body plus the shader's 1px fringe.
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
static func _closed_branch(road:Dictionary)->bool:
	var points: PackedVector2Array=road.points
	return points.size()>3 and points[0]==points[-1] and (road.has("branch_edge_spans") or road.has("road_variant"))
static func _closed_branch_surface(points:PackedVector2Array,edges:Vector2)->Array[PackedVector2Array]:
	# Offset contours of a closed stroke can return its hole as another polygon.
	# Build positive surface pieces around the cyclic path instead, with no caps.
	var result:Array[PackedVector2Array]=[]
	var count:=points.size()-1
	for side:int in [-1,1]:
		var radius:=edges.y if side>0 else -edges.x
		var incoming:=PackedVector2Array();incoming.resize(count)
		var outgoing:=PackedVector2Array();outgoing.resize(count)
		for i in range(count):
			var vertex:=points[i]
			var before:=(vertex-points[posmod(i-1,count)]).normalized()
			var after:=(points[i+1]-vertex).normalized()
			var u:=Vector2(-before.y,before.x)*side
			var v:=Vector2(-after.y,after.x)*side
			if before.cross(after)*side>=-.0001:
				var normal:=(u+v).normalized()
				var edge:=vertex+normal*radius/maxf(.5,normal.dot(v))
				incoming[i]=edge;outgoing[i]=edge
				continue
			incoming[i]=vertex+u*radius;outgoing[i]=vertex+v*radius
			var sweep:=u.angle_to(v)
			var steps:=ceili(absf(sweep)/.25)
			var fan:=PackedVector2Array([vertex,incoming[i]])
			for step in range(1,steps):fan.append(vertex+u.rotated(sweep*float(step)/steps)*radius)
			fan.append(outgoing[i]);result.append(fan)
		for i in range(count):
			result.append(PackedVector2Array([points[i],points[i+1],incoming[(i+1)%count],outgoing[i]]))
	return result
static func pavement_ribbons(road:Dictionary)->Array[PackedVector2Array]:
	var half:=float(road.width)/2
	var center:=center_ribbons(road,Vector2(-half,half))
	if not center.is_empty():return center
	if not _closed_branch(road):return ribbons(road.points,road.width,road.flat_start,road.flat_end)
	return _closed_branch_surface(road.points,Vector2(-half,half))
static func asphalt_ribbons(road: Dictionary) -> Array[PackedVector2Array]:
	var edges:=Profile.asphalt_edges(road)
	var center:=center_ribbons(road,edges)
	if not center.is_empty():return center
	if _closed_branch(road):return _closed_branch_surface(road.points,edges)
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
## Adjacent E4c members share an authored cross-section instead of offsetting
## their offset centrelines a second time. Cuts interpolate the same end frame.
static func center_ribbons(road:Dictionary,edges:Vector2)->Array[PackedVector2Array]:
	var result:Array[PackedVector2Array]=[]
	var frame:Variant=road.get("center_ribbon")
	if not frame is Dictionary or not frame.get("axis") is PackedVector2Array or not frame.get("basis") is PackedVector2Array or not frame.get("offset") is float:return result
	var axis:PackedVector2Array=frame.axis
	var points:PackedVector2Array=road.points
	if axis.size()<2 or axis.size()!=frame.basis.size() or points.size()<2:return result
	var left:=Profile.offset_path(frame.basis,frame.offset+edges.x)
	var right:=Profile.offset_path(frame.basis,frame.offset+edges.y)
	var start:float=road.get("source_start",0.0)
	if points!=axis:
		var end:=start+Junctions.length_of(points)
		if Junctions.sample(axis,start).distance_to(points[0])>.0001 or Junctions.sample(axis,end).distance_to(points[-1])>.0001:return result
		var first:=_ribbon_cut(axis,left,right,start)
		var last:=_ribbon_cut(axis,left,right,end)
		var trimmed_left:=PackedVector2Array([first[0]])
		var trimmed_right:=PackedVector2Array([first[1]])
		var distance:=0.0
		for i in range(1,axis.size()):
			distance+=axis[i-1].distance_to(axis[i])
			if distance>start+.0001 and distance<end-.0001:
				trimmed_left.append(left[i]);trimmed_right.append(right[i])
		trimmed_left.append(last[0]);trimmed_right.append(last[1])
		left=trimmed_left;right=trimmed_right
	left.reverse();right.append_array(left);result.append(right)
	return result

static func center_median_hatching(roads:Array,bounds:Vector2,pavement:Array[PackedVector2Array])->Array[PackedVector2Array]:
	var result:Array[PackedVector2Array]=[]
	var branches:Dictionary={}
	for road:Dictionary in roads:
		var role:int=road.get("center_role",0)
		if role not in [1,2] or not road.get("center_family") is int or not road.has("center_ribbon"):continue
		if Profile.branch_profile(road).is_empty() or Height.off_ground(road):continue
		var family:int=road.center_family
		if not branches.has(family):branches[family]=[[],[]]
		var start:float=road.get("source_start",0.0)
		var end:float=road.get("source_end",start+Height.length_cells(road.points))
		var frame:Dictionary=road.center_ribbon
		var inner:=Vector2(_center_chainage(frame,start),_center_chainage(frame,end))
		if role==2:
			var length:=Height.length_cells(frame.basis)
			inner=Vector2(length-inner.y,length-inner.x)
		branches[family][role-1].append(inner)
	var phases:=_median_phases(roads)
	for deck:Dictionary in roads:
		if not Profile.is_center_deck(deck) or not deck.has("center_ribbon") or not branches.has(deck.get("center_family")):continue
		var sides:Array=branches[deck.center_family]
		if sides[0].is_empty() or sides[1].is_empty():continue
		var points:PackedVector2Array=deck.points
		var heights:PackedFloat64Array=deck.get("heights_m",PackedFloat64Array())
		if heights.size()!=points.size():continue
		var axis:PackedVector2Array=deck.center_ribbon.axis
		var phase:Vector2=phases.get(deck.parcel_id,Vector2(0,1))
		var width:float=deck.width
		var left:=Profile.offset_path(axis,-width/2)
		var right:=Profile.offset_path(axis,width/2)
		var region:=Rect2(axis[0],Vector2.ZERO)
		for point:Vector2 in axis:region=region.expand(point)
		region=region.grow(width)
		var masks:Array[PackedVector2Array]=[]
		for polygon:PackedVector2Array in pavement:
			var box:=Rect2(polygon[0],Vector2.ZERO)
			for point:Vector2 in polygon:box=box.expand(point)
			if box.intersects(region):masks.append(polygon)
		var stripes:Array[PackedVector2Array]=[]
		var start:float=deck.get("source_start",0.0)
		for i in range(1,points.size()):
			var end:=start+points[i-1].distance_to(points[i])
			var a:=heights[i-1];var b:=heights[i]
			# E1 uses fill/retaining walls below +5m; only open ground gets paint.
			if maxf(a,b)>=5.0 and end-start>.0001:
				var low:=start if a>=5.0 else lerpf(start,end,(5.0-a)/(b-a))
				var high:=end if b>=5.0 else lerpf(start,end,(5.0-a)/(b-a))
				for first:Vector2 in sides[0]:
					for second:Vector2 in sides[1]:
						var lo:=maxf(low,maxf(first.x,second.x));var hi:=minf(high,minf(first.y,second.y))
						if hi-lo<=.0001:continue
						var begin_edges:=_ribbon_cut(axis,left,right,lo)
						var end_edges:=_ribbon_cut(axis,left,right,hi)
						if phase.y>0:
							stripes.append_array(_median_stripes(phase.x+lo,phase.x+hi,width,begin_edges,end_edges))
						else:
							begin_edges.reverse();end_edges.reverse()
							stripes.append_array(_median_stripes(phase.x-hi,phase.x-lo,width,end_edges,begin_edges))
			start=end
		result.append_array(outside_regions(clip_to_map(stripes,bounds),masks))
	return result

## Join live deck fragments by endpoint, without bridging removed spans.
## Evaluate paint in the saved ribbon's chainage, even at a newly cut endpoint.
static func _median_phases(roads:Array)->Dictionary:
	var fragments:Dictionary={}
	var ends:Dictionary={}
	var buckets:Dictionary={}
	for deck:Dictionary in roads:
		if not Profile.is_center_deck(deck) or not deck.has("center_ribbon"):continue
		var id:int=deck.parcel_id
		var axis:PackedVector2Array=deck.center_ribbon.axis
		var points:PackedVector2Array=deck.points
		if axis.size()<2 or points.size()<2:continue
		var first:float=deck.get("source_start",0.0)
		var last:=first+Height.length_cells(points)
		fragments[id]={"points":points,"span":Vector2(first,last),"source_length":Height.length_cells(axis)}
		for end in [0,1]:
			var at:=0 if end==0 else -1
			var p:Vector2=points[at]
			if absf(Height.height_at(deck,p)-10.0)>Junctions.EPS:continue
			var station:=first if end==0 else last
			if Junctions.sample(axis,station).distance_to(p)>Junctions.EPS:continue
			var handle:=Vector2i(id,end)
			var inward:Vector2=(points[1 if end==0 else -2]-p).normalized()
			ends[handle]={"point":p,"inward":inward,"lanes":deck.center_lanes}
			var bucket:Array=buckets.get_or_add(Junctions.key(p),[])
			bucket.append(handle)
	var seeks:Dictionary={}
	for end:Vector2i in ends:
		var a:Dictionary=ends[end]
		var cell:=Junctions.key(a.point)
		var compatible:Array[Vector2i]=[]
		for x in range(-1,2):
			for y in range(-1,2):
				for peer:Vector2i in buckets.get(cell+Vector2i(x,y),[]):
					if peer.x==end.x:continue
					var b:Dictionary=ends[peer]
					if a.lanes==b.lanes and a.point.distance_to(b.point)<=Junctions.EPS and a.inward.dot(b.inward)<-.99999 and absf(a.inward.cross(b.inward))<=Junctions.EPS:
						compatible.append(peer)
		if compatible.size()==1:seeks[end]=compatible[0]
	var links:Dictionary={}
	var linked:Dictionary={}
	for end:Vector2i in seeks:
		var peer:Vector2i=seeks[end]
		if seeks.get(peer,Vector2i(-1,-1))!=end:continue
		links[end]=peer
		linked[end.x]=true
	var order:Array[Vector2i]=[]
	for id:int in linked:
		order.append(Vector2i(id,0));order.append(Vector2i(id,1))
	order.sort_custom(func(a:Vector2i,b:Vector2i)->bool:
		if links.has(a)!=links.has(b):return not links.has(a)
		var p:Vector2=fragments[a.x].points[0 if a.y==0 else -1]
		var q:Vector2=fragments[b.x].points[0 if b.y==0 else -1]
		return p.x<q.x if p.x!=q.x else p.y<q.y if p.y!=q.y else a.x<b.x if a.x!=b.x else a.y<b.y)
	var phases:Dictionary={}
	for start:Vector2i in order:
		if phases.has(start.x):continue
		var cursor:=start
		var entry:Dictionary=fragments[start.x]
		# Preserve the root's authored origin when only part of it survives.
		var distance:float=entry.span.x if start.y==0 else entry.source_length-entry.span.y
		while not phases.has(cursor.x):
			var span:Vector2=fragments[cursor.x].span
			phases[cursor.x]=Vector2(distance-span.x,1) if cursor.y==0 else Vector2(distance+span.y,-1)
			distance+=span.y-span.x
			var far:=Vector2i(cursor.x,1-cursor.y)
			if not links.has(far):break
			cursor=links[far]
	return phases

## A branch runs along its offset axis, not the spine. Convert at the shared
## cross-sections so a cut on the inside or outside of a bend clips the right span.
static func _center_chainage(frame:Dictionary,distance:float)->float:
	var station:=0.0
	for i in range(1,frame.axis.size()):
		var used:float=frame.axis[i-1].distance_to(frame.axis[i])
		var span:float=frame.basis[i-1].distance_to(frame.basis[i])
		if used>0 and distance<=used:return station+span*clampf(distance/used,0,1)
		station+=span;distance-=used
	return station

## Generate 45-degree strips in chainage/lateral space before bending them into
## the authored ribbon. Phase is measured from the full spine even after edits.
static func _median_stripes(start:float,end:float,width:float,first:PackedVector2Array,last:PackedVector2Array)->Array[PackedVector2Array]:
	const PITCH:=1.5 # 6m
	const THICKNESS:=.12 # 48cm along the road (about 34cm normal to the stripe)
	var stripes:Array[PackedVector2Array]=[]
	var length:=end-start
	var section:=PackedVector2Array([Vector2.ZERO,Vector2(length,0),Vector2(length,width),Vector2(0,width)])
	for station in range(floori((start-width-THICKNESS)/PITCH),ceili(end/PITCH)):
		var d:=station*PITCH-start
		var strip:=PackedVector2Array([Vector2(d,0),Vector2(d+THICKNESS,0),Vector2(d+width+THICKNESS,width),Vector2(d+width,width)])
		for clipped:PackedVector2Array in Geometry2D.intersect_polygons(section,strip):
			var shape:=PackedVector2Array()
			for p:Vector2 in clipped:
				var across:=clampf(p.y/width,0,1)
				shape.append(first[0].lerp(first[1],across).lerp(last[0].lerp(last[1],across),clampf(p.x/length,0,1)))
			stripes.append(shape)
	return stripes

static func _ribbon_cut(axis:PackedVector2Array,left:PackedVector2Array,right:PackedVector2Array,distance:float)->PackedVector2Array:
	for i in range(1,axis.size()):
		var span:=axis[i-1].distance_to(axis[i])
		if distance<=span and span>0:
			return PackedVector2Array([left[i-1].lerp(left[i],distance/span),right[i-1].lerp(right[i],distance/span)])
		distance-=span
	return PackedVector2Array([left[-1],right[-1]])

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
		var branch_seed:bool=roads[i].has("road_variant") and not Profile.branch_profile(roads[i]).is_empty()
		var first_is_branch:=branch_seed
		var branch_boundaries:Dictionary={}
		for side in [0,1]:
			var tail_is_branch:=branch_seed
			if side==1:chain.reverse();heights.reverse()
			while true:
				var key: String=preload("res://core/road_junctions.gd").merged_key(chain[-1],topology.nodes,heights[-1])
				if topology.nodes[key].arms.size()!=2 or links[key].size()!=2:break
				var next: Dictionary={}
				for entry in links[key]:
					if not used.has(entry.road):next=entry
				if next.is_empty():break
				var road: Dictionary=roads[next.road]
				if roads[i].has("center_ribbon") or road.has("center_ribbon"):break
				if Height.level(road)!=Height.level(roads[i]):break
				if road.kind!=roads[i].kind or road.lanes!=roads[i].lanes or not is_equal_approx(road.width,roads[i].width):break
				var next_order:=1 if next.end==0 else -1
				var chain_order:=1 if side==0 else -1
				var travel:=Profile.travel_direction(roads[i])
				if Profile.travel_direction(road)*next_order!=travel*chain_order:break
				if travel==0 and int(road.lanes)%2 and int(road.get("major_side",1))*next_order!=int(roads[i].get("major_side",1))*chain_order:break
				var extension_is_branch:=road.has("road_variant") and not Profile.branch_profile(road).is_empty()
				if extension_is_branch!=tail_is_branch:branch_boundaries[chain[-1]]=true
				tail_is_branch=extension_is_branch
				if side==1:first_is_branch=extension_is_branch
				var extension: PackedVector2Array=road.points.duplicate()
				if next.end==1:extension.reverse()
				seams.append(chain[-1]);used[next.road]=true
				source_ids.append(int(road.get("parcel_id",-1)));supports.append_array(road.get("piers",[]))
				for j in range(1,extension.size()):chain.append(extension[j]);heights.append(Height.height_at(road,extension[j]))
		chain.reverse();heights.reverse()
		var height_source:Dictionary={"points":chain,"heights_m":heights}
		var smooth := PackedVector2Array()
		var edge_spans:Array[Vector2i]=[]
		var span_start:=0
		var in_branch:=first_is_branch
		for j in range(chain.size()):
			if j==0 or j==chain.size()-1 or not seams.has(chain[j]):smooth.append(chain[j]);continue
			var before: Vector2=(chain[j]-chain[j-1]).normalized()
			var after: Vector2=(chain[j+1]-chain[j]).normalized()
			var split:=smooth.size()
			if before.dot(after)>.99999:smooth.append(chain[j])
			else:
				var inset: float=minf(float(roads[i].width)*.6,minf(chain[j].distance_to(chain[j-1]),chain[j].distance_to(chain[j+1]))*.24)
				var a: Vector2=chain[j]-before*inset
				var b: Vector2=chain[j]+after*inset
				for step in range(13):
					var t:=step/12.0
					smooth.append(a*(1-t)*(1-t)+chain[j]*2*(1-t)*t+b*t*t)
				split+=6 # Both profiles share the same cross-section at the middle of the fillet.
			if branch_boundaries.has(chain[j]):
				if in_branch:edge_spans.append(Vector2i(span_start,split))
				in_branch=not in_branch
				span_start=split
		if in_branch:edge_spans.append(Vector2i(span_start,smooth.size()-1))
		var visual: Dictionary=roads[i].duplicate()
		visual.points=smooth
		if not edge_spans.is_empty():visual.branch_edge_spans=edge_spans
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

## Adjoining pieces share cross-sections. At an outside corner the curb is
## rounded, so clipping a miter would cut away the stripe instead of turning it.
static func branch_edge_marks(visual:Dictionary,rim:Array[PackedVector2Array],asphalt:Array[PackedVector2Array])->Array[PackedVector2Array]:
	var result:Array[PackedVector2Array]=[]
	var side:=Profile.travel_direction(visual)
	var edges:=Profile.asphalt_edges(visual)
	var edge:=edges.y if side>0 else edges.x
	var points:PackedVector2Array=visual.points
	var outer:=Profile.offset_path(points,edge-side*BRANCH_STRIPE_GAP)
	var inner:=outer.duplicate()
	for i in range(points.size()):inner[i]=_stripe_inner(outer[i],outer[i]-points[i],_projected_normal(outer,i))
	var owned:=PackedByteArray()
	owned.resize(points.size()-1)
	for span:Vector2i in visual.branch_edge_spans:
		for i in range(span.x,span.y):owned[i]=1
	var outer_in:=outer.duplicate();var inner_in:=inner.duplicate()
	var last:=points.size()-1
	var closed:=last>2 and points[0]==points[last]
	# A closed path repeats its first vertex. Process that corner once, but
	# write the incoming cross-section at the repeated vertex, not the first.
	for i in range(0 if closed else 1,last):
		var incoming:=last if i==0 else i
		if not owned[incoming-1] and not owned[i]:continue
		var before:=(points[i]-points[incoming-1]).normalized()
		var after:=(points[i+1]-points[i]).normalized()
		if before.cross(after)*side>=-.0001:
			if i==0 and owned[incoming-1] and owned[i]:
				var seam:=PackedVector2Array([points[incoming-1],points[i],points[i+1]])
				var rim_seam:=Profile.offset_path(seam,edge-side*BRANCH_STRIPE_GAP)
				outer[i]=rim_seam[1];outer_in[incoming]=outer[i]
				inner[i]=_stripe_inner(outer[i],outer[i]-points[i],_projected_normal(rim_seam,1));inner_in[incoming]=inner[i]
			continue
		var radius:=absf(edge)
		var start:=Vector2(-before.y,before.x)*side;var finish:=Vector2(-after.y,after.x)*side
		var cuts:=_branch_corner_rim(points[i],start,finish,radius,float(visual.width)/2,rim)
		var outside_scale:=1.0-BRANCH_STRIPE_GAP/radius
		var arc:=PackedVector2Array()
		var arc_inner:=PackedVector2Array()
		for cut in cuts:arc.append(points[i]+cut*outside_scale)
		for j in range(arc.size()):
			var normal:=_projected_normal(arc,j)
			if j==0:normal=_paint_projection(before).orthogonal().normalized()
			if j==arc.size()-1:normal=_paint_projection(after).orthogonal().normalized()
			arc_inner.append(_stripe_inner(arc[j],cuts[j],normal))
		outer_in[incoming]=arc[0];inner_in[incoming]=arc_inner[0]
		outer[i]=arc[-1];inner[i]=arc_inner[-1]
		result.append_array(_branch_corner_marks(points[i],arc,arc_inner,asphalt,owned[incoming-1]!=0,owned[i]!=0))
	for i in range(owned.size()):
		if not owned[i]:continue
		var quad:=PackedVector2Array([outer[i],outer_in[i+1],inner_in[i+1],inner[i]])
		result.append_array(Junctions.clip_paint(quad,asphalt))
	return result

static func _branch_corner_rim(center:Vector2,start:Vector2,finish:Vector2,radius:float,half:float,rim:Array[PackedVector2Array])->Array[Vector2]:
	var sweep:=start.angle_to(finish)
	var cuts:Array[Vector2]=[]
	var first:=start*radius;var last:=finish*radius
	# Use the same arc chords as the actual asphalt, not a smoother circle
	# running outside its tessellated edge. All vectors here are corner-local.
	for polygon in rim:
		for vertex in polygon:
			var offset:=vertex-center
			var distance:=offset.length()
			if distance<radius-.001 or distance>half+.001:continue
			var fraction:=start.angle_to(offset)/sweep
			if absf(fraction)<=.001:
				if distance>first.length():first=start*distance
			elif absf(fraction-1)<=.001:
				if distance>last.length():last=finish*distance
			elif fraction>0 and fraction<1:cuts.append(offset)
	cuts.sort_custom(func(a,b):return start.angle_to(a)/sweep<start.angle_to(b)/sweep)
	cuts.push_front(first);cuts.append(last)
	return cuts

static func _projected_normal(path:PackedVector2Array,index:int)->Vector2:
	var before:=_paint_projection(path[index]-path[maxi(0,index-1)]).normalized()
	var after:=_paint_projection(path[mini(path.size()-1,index+1)]-path[index]).normalized()
	return (before+after).normalized().orthogonal()

static func _stripe_inner(outer:Vector2,outward:Vector2,screen_normal:Vector2)->Vector2:
	# The white shader's opaque body is one projected pixel before camera zoom.
	# Move along the shared world cross-section so authored ownership never leaks.
	var scale:=absf(_paint_projection(outward).dot(screen_normal))
	return outer-outward*minf(.5,REFERENCE_ZOOM/maxf(scale,.0001))

static func _branch_corner_marks(center:Vector2,outer:PackedVector2Array,inner:PackedVector2Array,asphalt:Array[PackedVector2Array],before:bool,after:bool)->Array[PackedVector2Array]:
	var result:Array[PackedVector2Array]=[]
	var start:=(outer[0]-center).normalized()
	var sweep:=start.angle_to(outer[-1]-center)
	var seam:=start.rotated(sweep*.5)
	for i in range(1,outer.size()):
		var a:=outer[i-1];var b:=outer[i]
		var inner_a:=inner[i-1];var inner_b:=inner[i]
		if before!=after:
			# A mixed fillet owns only its half of the corner at the shared plane.
			var first:=start.angle_to(a-center)/sweep;var last:=start.angle_to(b-center)/sweep
			if (before and first>=.5) or (after and last<=.5):continue
			if first<.5 and last>.5:
				var split:Vector2=Geometry2D.line_intersects_line(center,seam,a,b-a)
				var split_inner:Vector2=Geometry2D.line_intersects_line(center,seam,inner_a,inner_b-inner_a)
				if before:b=split;inner_b=split_inner
				else:a=split;inner_a=split_inner
		result.append_array(Junctions.clip_paint(PackedVector2Array([a,b,inner_b,inner_a]),asphalt))
	return result

static func branch_taper_marks(join:Dictionary)->Array[PackedVector2Array]:
	var result:Array[PackedVector2Array]=[]
	if not join.get("taper",false):return result
	var edge:PackedVector2Array=join.taper_asphalt
	var axis:Vector2=join.box_axis
	var normal:=Vector2(-axis.y,axis.x)
	var seam:float=join.taper_extents[0]/(join.taper_extents[0]+join.taper_extents[1])
	for i in range(2):
		var arm:Dictionary=join.arms[i]
		if not arm.has("road_variant"):continue
		var side:=Profile.travel_direction(arm)*(-1 if i==0 else 1)
		var start:=edge[0 if side>0 else 3]
		var finish:=edge[1 if side>0 else 2]
		var middle:=start.lerp(finish,seam)
		var a:Vector2=(start if i==0 else middle)-normal*side*BRANCH_STRIPE_GAP
		var b:Vector2=(middle if i==0 else finish)-normal*side*BRANCH_STRIPE_GAP
		var screen_normal:=_paint_projection(b-a).normalized().orthogonal()
		result.append(PackedVector2Array([a,b,_stripe_inner(b,normal*side,screen_normal),_stripe_inner(a,normal*side,screen_normal)]))
	return result

## Preview and retained rendering share the world-space glyphs. The retained
## layer additionally connects profiles across tapers and masks other paint.
static func direction_arrows(road: Dictionary) -> Array[PackedVector2Array]:
	if Profile.travel_direction(road)==0:return []
	var white:=lane_marks(road)
	for path in shoulder_marks(road):
		for i in range(1,path.size()):white.append(PackedVector2Array([path[i-1],path[i]]))
	return arrow_run([road],[],false,asphalt_ribbons(road),[],_white_paint_index(white))

static func arrow_supported(shape: PackedVector2Array,surfaces: Array[PackedVector2Array]) -> bool:
	var area:=Parcels.area(shape)
	var painted:=0.0
	for surface in surfaces:
		for piece in Geometry2D.intersect_polygons(shape,surface):painted+=Parcels.area(piece)
		if painted>=area-.0001:return true
	return false

static func directed_marking_layout(visuals: Array,topology: Dictionary) -> Dictionary:
	var parts: Array[Dictionary]=[]
	var starts: Dictionary={}
	var ends: Dictionary={}
	var marking_joins: Dictionary={}
	for join: Dictionary in topology.joins:
		if absf(float(join.height_m))<=Junctions.EPS:marking_joins[join.key]=join
	for index in range(visuals.size()):
		var road: Dictionary=visuals[index]
		var travel:=Profile.travel_direction(road)
		if travel==0 or Height.off_ground(road):continue
		var start:=Junctions.merged_key(road.points[0 if travel>0 else -1],topology.nodes)
		var finish:=Junctions.merged_key(road.points[-1 if travel>0 else 0],topology.nodes)
		starts[start]=parts.size();ends[finish]=parts.size()
		parts.append({"road":road,"start":start,"finish":finish,"index":index})
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
	var layout: Dictionary={"runs":[],"visual_phase":{},"seams":{}}
	for start: int in order:
		if used.has(start):continue
		var run: Array=[]
		var seams: Array[Dictionary]=[]
		var phase:=0.0
		var cursor:=start
		while cursor>=0 and not used.has(cursor):
			var part:=parts[cursor]
			used[cursor]=true;run.append(part.road)
			layout.visual_phase[part.index]=phase
			var points: PackedVector2Array=part.road.points
			for i in range(1,points.size()):phase+=points[i-1].distance_to(points[i])
			cursor=successors.get(cursor,-1)
			if cursor>=0 and marking_joins.has(part.finish):
				var join:Dictionary=marking_joins[part.finish]
				var extents:=Transitions.marking_extents(join)
				if extents!=Vector2.ZERO:
					layout.seams[part.finish]=phase
					seams.append(_arrow_taper_section(join,phase,extents))
		layout.runs.append({"roads":run,"closed":cursor==start,"seams":seams})
	return layout

static func retained_direction_arrows(layout: Dictionary,junctions: Array,surfaces: Array[PackedVector2Array],blocked: Array[PackedVector2Array],white: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	if layout.runs.is_empty():return result
	var paint:=_white_paint_index(white)
	for run in layout.runs:
		result.append_array(arrow_run(run.roads,junctions,run.closed,surfaces,blocked,paint,run.seams))
	return result

const PAINT_BUCKET:=128.0
static func _white_paint_index(lines: Array[PackedVector2Array]) -> Dictionary:
	var buckets: Dictionary={}
	for line in lines:
		var a:=_paint_projection(line[0]);var b:=_paint_projection(line[-1])
		var normal:=(b-a).orthogonal().normalized()*(WHITE_HALF_STROKE+.002)
		var shape:=PackedVector2Array([a-normal,b-normal,b+normal,a+normal])
		var bounds:=Parcels.bounds(shape)
		var first:=Vector2i((bounds.position/PAINT_BUCKET).floor())
		var last:=Vector2i((bounds.end/PAINT_BUCKET).floor())
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var key:=Vector2i(x,y)
				if not buckets.has(key):buckets[key]=[]
				buckets[key].append({"shape":shape,"bounds":bounds})
	return buckets

static func _clear_of_white(glyph:PackedVector2Array,paint:Dictionary,opaque_only:bool=false)->bool:
	var shape:=PackedVector2Array()
	for point in glyph:shape.append(_paint_projection(point))
	var bounds:=Parcels.bounds(shape)
	var first:=Vector2i((bounds.position/PAINT_BUCKET).floor())
	var last:=Vector2i((bounds.end/PAINT_BUCKET).floor())
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			for mark:Dictionary in paint.get(Vector2i(x,y),[]):
				if not bounds.intersects(mark.bounds):continue
				var stroke:PackedVector2Array=mark.shape
				if opaque_only:
					var a:=(stroke[0]+stroke[3])*.5;var b:=(stroke[1]+stroke[2])*.5
					var n:=(b-a).orthogonal().normalized()*(REFERENCE_ZOOM*.5+.002)
					stroke=PackedVector2Array([a-n,b-n,b+n,a+n])
				if not Geometry2D.intersect_polygons(shape,stroke).is_empty():return false
	return true

static func _centre_hits_white_fringe(centre:Vector2,paint:Dictionary)->bool:
	var point:=_paint_projection(centre)
	for mark:Dictionary in paint.get(Vector2i((point/PAINT_BUCKET).floor()),[]):
		var stroke:PackedVector2Array=mark.shape
		if not Geometry2D.is_point_in_polygon(point,stroke):continue
		var a:=(stroke[0]+stroke[3])*.5;var b:=(stroke[1]+stroke[2])*.5
		var across:=absf((point-a).cross((b-a).normalized()))
		if across>REFERENCE_ZOOM*.5 and across<WHITE_HALF_STROKE:return true
	return false

static func _paint_projection(point: Vector2) -> Vector2:
	return Vector2(point.x-point.y,point.x+point.y)*PAINT_TILE*REFERENCE_ZOOM

static func arrow_run(roads: Array,junctions: Array,closed: bool,surfaces: Array[PackedVector2Array],blocked: Array[PackedVector2Array],paint: Dictionary,seams: Array[Dictionary]=[]) -> Array[PackedVector2Array]:
	var segments: Array[Dictionary]=[]
	var length:=0.0
	for road: Dictionary in roads:
		var travel:=Profile.travel_direction(road)
		var points:PackedVector2Array=road.points
		var offsets:=_lane_centres(road)
		for i in range(1,points.size()):
			var a:Vector2=points[i-1 if travel>0 else -i]
			var b:Vector2=points[i if travel>0 else -i-1]
			var span:=a.distance_to(b)
			if span<=.0001:continue
			segments.append({"a":a,"b":b,"start":length,"length":span,"offsets":offsets})
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
	var seam_index:=0
	for chainage in selected:
		while index+1<segments.size() and chainage>segments[index].start+segments[index].length:index+=1
		var segment:=segments[index]
		var a:Vector2=segment.a;var b:Vector2=segment.b
		var forward:=(b-a)/float(segment.length)
		var right:=-forward.orthogonal()
		var point:=a+forward*(chainage-float(segment.start))
		var offsets:PackedFloat64Array=segment.offsets
		var taper:Dictionary={}
		while seam_index<seams.size() and chainage>seams[seam_index].end:seam_index+=1
		if seam_index<seams.size() and chainage>=seams[seam_index].start:
			taper=seams[seam_index]
			offsets=_taper_lane_centres(taper,chainage)
		elif closed and not seams.is_empty() and chainage+length<=seams[-1].end and chainage+length>=seams[-1].start:
			taper=seams[-1]
			offsets=_taper_lane_centres(taper,chainage+length)
		for lane in range(offsets.size()):
			var center:=point+right*offsets[lane]
			var trial:bool=taper.get("fringe_trial",false) and offsets.size()==4 and lane==3
			var glyph:=_fit_arrow(center,forward,right,surfaces,blocked,paint,trial)
			if not glyph.is_empty():result.append(glyph)
	return result

static func _lane_centres(road:Dictionary)->PackedFloat64Array:
	var offsets:=PackedFloat64Array()
	var travel:=Profile.travel_direction(road)
	for lane in range(int(road.lanes)):offsets.append(Profile.lane_center_metres(road,travel,lane)/4)
	return offsets

static func _arrow_taper_section(join:Dictionary,phase:float,extents:Vector2)->Dictionary:
	var incoming:=0 if Profile.travel_direction(join.arms[0])<0 else 1
	var a:Dictionary=join.arms[incoming];var b:Dictionary=join.arms[1-incoming]
	var first:float=extents[incoming];var last:float=extents[1-incoming]
	# Use local coordinates (longitudinal chainage, lateral distance) and
	# exactly the same separator paths as the dashed transition paint.
	var p:=Vector2(-first,0);var q:=Vector2(last,0)
	var a_edges:=_travel_edges(a,-1);var b_edges:=_travel_edges(b,1)
	var fringe_trial:bool=a.get("road_variant")==Profile.BRANCH_IDS[Profile.BranchVariant.EIGHT_METRE] and b.kind=="local" and b.lanes==4 and Profile.width_for_record(b)==5.
	return {"start":phase-first,"end":phase+last,"phase":phase,"a_edges":a_edges,"b_edges":b_edges,
		"separators":Transitions.separator_paths(a,b,p,q,Vector2.DOWN,Transitions.taper_centre_edges(a,b)),"fringe_trial":fringe_trial}

static func _travel_edges(arm:Dictionary,travel:int)->Vector2:
	var half:=Profile.lane_width_metres(arm)/8
	return Vector2(Profile.lane_center_metres(arm,travel,0)/4-half,Profile.lane_center_metres(arm,travel,int(arm.lanes)-1)/4+half)

static func _taper_lane_centres(seam:Dictionary,chainage:float)->PackedFloat64Array:
	var ratio:float=(chainage-seam.start)/(seam.end-seam.start)
	var a:Vector2=seam.a_edges;var b:Vector2=seam.b_edges
	var edges:=a.lerp(b,ratio)
	var left:=edges.x
	var x:float=chainage-seam.phase
	var offsets:=PackedFloat64Array()
	for path:PackedVector2Array in seam.separators:
		if x<path[0].x or x>path[-1].x:continue
		var right:=lerpf(path[0].y,path[-1].y,(x-path[0].x)/(path[-1].x-path[0].x))
		if right<=left or right>=edges.y:continue
		offsets.append((left+right)*.5)
		left=right
	offsets.append((left+edges.y)*.5)
	return offsets

static func _fit_arrow(center:Vector2,forward:Vector2,right:Vector2,surfaces:Array[PackedVector2Array],blocked:Array[PackedVector2Array],paint:Dictionary,fringe_trial:bool=false)->PackedVector2Array:
	var glyph:=PackedVector2Array([center+forward*.50,center+right*.24,center+right*.075,center-forward*.50+right*.075,center-forward*.50-right*.075,center-right*.075,center-right*.24])
	if blocked.any(func(mask):return not Geometry2D.intersect_polygons(glyph,mask).is_empty()):return PackedVector2Array()
	# Protect the existing paint, not the outline size. Bend and taper clearances
	# can be tighter than a straight lane; keep the glyph centered and whole.
	var outline:=glyph.duplicate()
	for scale:float in [1.,.9,.8,.65,.5,.35,.2]:
		if scale<1.:
			for i in range(glyph.size()):glyph[i]=center.lerp(outline[i],scale)
		if _clear_of_white(glyph,paint) and arrow_supported(glyph,surfaces):return glyph
	# Scratch feasibility only: if the lane centre itself is in the fringe,
	# keep the smallest existing scale, same tangent, and original mask gate.
	if fringe_trial and _centre_hits_white_fringe(center,paint) and _clear_of_white(glyph,paint,true) and arrow_supported(glyph,surfaces):
		for vertex in glyph:
			if not surfaces.any(func(poly):return Geometry2D.is_point_in_polygon(vertex,poly)):return PackedVector2Array()
		return glyph
	return PackedVector2Array()

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

static func lane_marks(road: Dictionary,phase:float=0.0) -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	var offsets:=Profile.separators(road)
	if offsets.is_empty(): return lines
	var points:PackedVector2Array=road.points
	var order:=-1 if Profile.travel_direction(road)<0 else 1
	if order<0:points=points.duplicate();points.reverse()
	for i in range(points.size()-1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i+1]
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
					var shift: Vector2 = normal*offset*order
					lines.append(PackedVector2Array([a+direction*start+shift,a+direction*end+shift]))
			start = end+0.00001
		phase += length
	return lines
static func shoulder_marks(road: Dictionary) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	for offset in Profile.shoulder_offsets(road):result.append(Profile.offset_path(road.points,offset))
	return result
