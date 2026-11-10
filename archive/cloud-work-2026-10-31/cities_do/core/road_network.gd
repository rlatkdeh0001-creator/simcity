extends RefCounted
## Layer-aware centreline topology. Rebuilt atomically on committed road edits.
const EPS := 0.0001
static func snap_endpoints(points: PackedVector2Array, roads: Array, own_width: float = 0.0, layer: int = 0) -> PackedVector2Array:
	var result:=points.duplicate()
	if result.size()<2:return result
	for end in [0,result.size()-1]:
		var original:Vector2=result[end];var best:=INF;var target:=original
		for road in roads:
			if road.get("layer",1 if road.get("kind","local")=="highway" else 0)!=layer or road.get("kind","local")=="ramp":continue
			for i in range(road.points.size()-1):
				var p:=Geometry2D.get_closest_point_to_segment(original,road.points[i],road.points[i+1])
				var distance:=original.distance_to(p)
				if distance<=(road.width+own_width)/2+.05 and distance<best:best=distance;target=p
		result[end]=target
	return result
static func _node(nodes: Array,point: Vector2,layer: float) -> int:
	for i in range(nodes.size()):
		if nodes[i].position.distance_to(point)<EPS and absf(nodes[i].layer-layer)<EPS:return i
	nodes.append({"position":point,"layer":layer,"edges":[],"arms":[]})
	return nodes.size()-1
static func build(roads: Array) -> Dictionary:
	var segments:Array=[];var nodes:Array=[];var edges:Array=[]
	for ri in range(roads.size()):
		for si in range(roads[ri].points.size()-1):
			var a:Vector2=roads[ri].points[si];var b:Vector2=roads[ri].points[si+1]
			var r:Dictionary=roads[ri]
			var layer:float=r.get("layer",1 if r.get("kind","local")=="highway" else 0)
			var la:float=lerpf(float(r.get("start_layer",layer)),float(r.get("end_layer",layer)),float(si)/(r.points.size()-1))
			var lb:float=lerpf(float(r.get("start_layer",layer)),float(r.get("end_layer",layer)),float(si+1)/(r.points.size()-1))
			if r.get("smooth_join",false):
				la=preload("res://core/ramp_geometry.gd").height(r,float(si)/(r.points.size()-1))
				lb=preload("res://core/ramp_geometry.gd").height(r,float(si+1)/(r.points.size()-1))
			if a.distance_to(b)>EPS:segments.append({"a":a,"b":b,"la":la,"lb":lb,"road":ri,"cuts":[0.0,1.0]})
	# Side attachments cut only their parent road at the logical anchor.
	# The visible ramp endpoint remains outside the carriageway.
	for road in roads:
		for key in ["start_attachment","end_attachment"]:
			if not road.has(key):continue
			var port:Dictionary=road[key]
			for segment in segments:
				if segment.road!=port.road:continue
				var closest:=Geometry2D.get_closest_point_to_segment(port.anchor,segment.a,segment.b)
				if closest.distance_to(port.anchor)<EPS:segment.cuts.append(clampf((closest-segment.a).dot(segment.b-segment.a)/(segment.b-segment.a).length_squared(),0,1))
	for i in range(segments.size()):
		var a:Dictionary=segments[i];var da:Vector2=a.b-a.a
		for j in range(i):
			var b:Dictionary=segments[j];var db:Vector2=b.b-b.a
			var p=Geometry2D.segment_intersects_segment(a.a,a.b,b.a,b.b)
			if p!=null:
				var ta:float=clampf((p-a.a).dot(da)/da.length_squared(),0,1)
				var tb:float=clampf((p-b.a).dot(db)/db.length_squared(),0,1)
				if absf(lerpf(a.la,a.lb,ta)-lerpf(b.la,b.lb,tb))>EPS:continue
				a.cuts.append(clampf((p-a.a).dot(da)/da.length_squared(),0,1));b.cuts.append(clampf((p-b.a).dot(db)/db.length_squared(),0,1))
			elif absf(a.la-b.la)<EPS and absf(a.lb-b.lb)<EPS and absf(da.cross(db))<EPS*da.length()*db.length() and absf(da.cross(b.a-a.a))<EPS*da.length():
				# Split partial collinear overlaps as well as coincident endpoints.
				for q in [b.a,b.b]:
					var t:float=(q-a.a).dot(da)/da.length_squared()
					if t>=0 and t<=1:a.cuts.append(t)
				for q in [a.a,a.b]:
					var t:float=(q-b.a).dot(db)/db.length_squared()
					if t>=0 and t<=1:b.cuts.append(t)
	var edge_keys:={}
	for s in segments:
		s.cuts.sort()
		for i in range(s.cuts.size()-1):
			var a:Vector2=s.a.lerp(s.b,s.cuts[i]);var b:Vector2=s.a.lerp(s.b,s.cuts[i+1])
			if a.distance_to(b)<EPS:continue
			var start:=_node(nodes,a,lerpf(s.la,s.lb,s.cuts[i]));var finish:=_node(nodes,b,lerpf(s.la,s.lb,s.cuts[i+1]))
			var key:="%d:%d" % [mini(start,finish),maxi(start,finish)]
			if edge_keys.has(key):
				var existing:Dictionary=edges[edge_keys[key]]
				if roads[s.road].width>existing.width:
					var dominant:=preload("res://core/road_geometry.gd").lane_profile(roads[s.road])
					var aligned:bool=(nodes[existing.to].position-nodes[existing.from].position).dot(b-a)>0
					existing.forward_lanes=dominant.forward if aligned else dominant.backward
					existing.backward_lanes=dominant.backward if aligned else dominant.forward
					existing.width=roads[s.road].width
					existing.speed_limit_kmh=roads[s.road].get("speed_limit_kmh",160 if roads[s.road].get("kind","local")=="highway" else 80)
				if not s.road in existing.roads:existing.roads.append(s.road)
				continue
			var profile:=preload("res://core/road_geometry.gd").lane_profile(roads[s.road])
			var ei:=edges.size();edge_keys[key]=ei
			edges.append({"from":start,"to":finish,"kind":roads[s.road].get("kind","local"),"speed_limit_kmh":roads[s.road].get("speed_limit_kmh",160 if roads[s.road].get("kind","local")=="highway" else 80),"roads":[s.road],"width":roads[s.road].width,"forward_lanes":profile.forward,"backward_lanes":profile.backward})
			nodes[start].edges.append(ei);nodes[finish].edges.append(ei)
			nodes[start].arms.append((b-a).normalized());nodes[finish].arms.append((a-b).normalized())
	var ports:Array=[]
	for ri in range(roads.size()):
		var road:Dictionary=roads[ri]
		for key in ["start_attachment","end_attachment"]:
			if not road.has(key):continue
			var port:Dictionary=road[key].duplicate()
			port.ramp=ri
			var anchor:=_node(nodes,port.anchor,port.layer)
			var side:=_node(nodes,port.position,port.layer)
			var start:int=anchor if key=="start_attachment" else side
			var finish:int=side if key=="start_attachment" else anchor
			var ei:=edges.size()
			edges.append({"from":start,"to":finish,"kind":"ramp_port","roads":[ri,port.road],"width":road.width,"forward_lanes":1,"backward_lanes":0,"speed_limit_kmh":road.speed_limit_kmh,"carriageway":port.carriageway})
			nodes[start].edges.append(ei);nodes[finish].edges.append(ei)
			nodes[start].arms.append((nodes[finish].position-nodes[start].position).normalized())
			nodes[finish].arms.append((nodes[start].position-nodes[finish].position).normalized())
			nodes[anchor].port_join=true;nodes[side].port_join=true
			ports.append(port)
	for edge in edges:
		edge.free_flow_seconds=nodes[edge.from].position.distance_to(nodes[edge.to].position)*14.4/edge.speed_limit_kmh
	var junctions:Array=[]
	for i in range(nodes.size()):
		var n:Dictionary=nodes[i];n.degree=n.arms.size()
		n.kind="end" if n.degree==1 else ("T" if n.degree==3 else ("cross" if n.degree==4 else ("multi" if n.degree>4 else "join")))
		if n.degree>=3 and not n.get("port_join",false):
			var w:=0.0
			for ei in n.edges:w=maxf(w,edges[ei].width)
			junctions.append({"node":i,"position":n.position,"layer":n.layer,"degree":n.degree,"kind":n.kind,"radius":w*.68})
	return {"nodes":nodes,"edges":edges,"junctions":junctions,"ports":ports}
