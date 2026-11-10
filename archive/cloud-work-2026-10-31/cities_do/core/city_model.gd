extends RefCounted
const Parcels = preload("res://core/road_parcels.gd")
const ZoningGrid = preload("res://core/zoning_grid.gd")
var zoning_grid = ZoningGrid.new()
const Catalog = preload("res://core/building_catalog.gd")
var catalog = Catalog.new()
var appearance_rng := RandomNumberGenerator.new()
const Config = preload("res://core/growth_config.gd")
var config = Config.new()
var width: int
var height: int
var buildings: Array[Dictionary] = []
var road_network := {"nodes":[],"edges":[],"junctions":[]}
const RampGeometry = preload("res://core/ramp_geometry.gd")
const RoadNetwork = preload("res://core/road_network.gd")
var roads: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var next_id := 1
var interchanges: Array[Dictionary] = []

func _init(w: int = 40, h: int = 40, seed_value: int = 42):
	width = w
	height = h
	rng.seed = seed_value
	appearance_rng.seed = seed_value ^ 0x5f3759df

func _rect(b: Dictionary) -> Rect2:
	return Rect2(Vector2(b.x, b.y), Vector2(b.size, b.size))

func _point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))

func footprint(b: Dictionary) -> PackedVector2Array:
	if b.has("frame"):return Parcels.polygon(b.frame,b.u,b.v,b.size)
	var r:=_rect(b)
	return PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])

func _polygon_road_distance(polygon_value: PackedVector2Array,road: Dictionary) -> float:
	var result:=INF
	for i in range(road.points.size()-1):
		var a: Vector2=road.points[i]
		var b: Vector2=road.points[i+1]
		if Geometry2D.is_point_in_polygon(a,polygon_value) or Geometry2D.is_point_in_polygon(b,polygon_value):return -road.width/2
		for j in range(polygon_value.size()):
			var c:=polygon_value[j]
			var d:=polygon_value[(j+1)%polygon_value.size()]
			if Geometry2D.segment_intersects_segment(a,b,c,d)!=null:return -road.width/2
			result=min(result,_point_segment(c,a,b),_point_segment(d,a,b),_point_segment(a,c,d),_point_segment(b,c,d))
	return result-road.width/2

func _polygon_error(polygon_value: PackedVector2Array,ignore_id: int=-1,check_buildings: bool=true) -> String:
	for point in polygon_value:
		if point.x< -0.0005 or point.y< -0.0005 or point.x>width+0.0005 or point.y>height+0.0005:return "지도 경계 밖입니다"
	if check_buildings:
		for b in buildings:
			if b.id!=ignore_id and Parcels.overlap(polygon_value,footprint(b)):return "다른 건물이 있습니다"
	var access:=false
	for road in roads:
		var distance:=_polygon_road_distance(polygon_value,road)
		if distance< -0.0005:return "도로와 충돌합니다"
		if road.kind=="local" and distance<=config.road_access_distance:access=true
	# Revealed cells may extend deeper than building frontage range.
	if not check_buildings:return ""
	return "" if access else "일반도로 접근이 필요합니다"

func placement_error(x: int,y: int,size: int,ignore_id: int=-1) -> String:
	if size not in [2,4,8]:return "크기는 2·4·8만 가능합니다"
	return _polygon_error(footprint({"x":x,"y":y,"size":size}),ignore_id)

func parcel_placement_error(frame: Dictionary,u: int,v: int,size: int,ignore_id: int=-1) -> String:
	if size not in [2,4,8]:return "크기는 2·4·8만 가능합니다"
	for x in range(u,u+size):
		for y in range(v,v+size):
			if not zoning_grid.has_parcel(frame.id,x,y):return "한 도로 블록 안에 반듯한 부지가 필요합니다"
	return _polygon_error(Parcels.polygon(frame,u,v,size),ignore_id)

func add_building_at(point: Vector2,zone: String="residential",score: float=0.0) -> Dictionary:
	if zone not in ["residential","commercial","industrial"]:return {"ok":false,"reason":"지원하지 않는 구획입니다"}
	var parcel: Dictionary=zoning_grid.parcel_at(point)
	if parcel.is_empty():return {"ok":false,"reason":"도로 주변 건설 구획을 선택하세요"}
	var error:=parcel_placement_error(parcel.frame,parcel.u,parcel.v,2)
	if error!="":return {"ok":false,"reason":error}
	var origin: Vector2=parcel.polygon[0]
	var building:={"id":next_id,"x":origin.x,"y":origin.y,"u":parcel.u,"v":parcel.v,"frame":parcel.frame.duplicate(),"size":2,"level":1,"zone":zone,"score":score,"asset_id":""}
	catalog.assign(building, appearance_rng)
	next_id+=1;buildings.append(building)
	return {"ok":true,"building":building}

func supports_static_sprite(b: Dictionary) -> bool:
	return not b.has("frame") or (Vector2(b.frame.along).distance_to(Vector2.RIGHT)<0.00001 and Vector2(b.frame.outward).distance_to(Vector2.DOWN)<0.00001)

func add_building(x: int, y: int, zone: String = "residential", score: float = 0.0) -> Dictionary:
	if zone not in ["residential", "commercial", "industrial"]:
		return {"ok": false, "reason": "지원하지 않는 구획입니다"}
	var error := placement_error(x, y, 2)
	if error != "":
		return {"ok": false, "reason": error}
	var b := {"id": next_id, "x": x, "y": y, "size": 2, "level": 1, "zone": zone, "score": score, "asset_id": ""}
	next_id += 1
	catalog.assign(b, appearance_rng)
	buildings.append(b)
	return {"ok": true, "building": b}

func add_road(points: PackedVector2Array, kind: String = "local", commit: bool = true, lanes: int = 2, reverse_lanes: bool = false) -> Dictionary:
	if kind not in ["local", "highway"] or points.size() < 2 or lanes not in ([2,3,4,5,8] if kind=="local" else [2,3,4,5]):
		return {"ok": false, "reason": "도로 경로가 필요합니다"}
	var total := 0.0
	for i in range(points.size()):
		var p := points[i]
		if not p.is_finite() or p.x < 0 or p.y < 0 or p.x > width or p.y > height:
			return {"ok": false, "reason": "지도 경계 밖입니다"}
		if i > 0:
			total += points[i - 1].distance_to(p)
	if total < 0.1:
		return {"ok": false, "reason": "도로가 너무 짧습니다"}
	points = RoadNetwork.snap_endpoints(points,roads,config.road_width*lanes/2.0,1 if kind=="highway" else 0)
	var clean := PackedVector2Array()
	for point in points:
		if clean.is_empty() or clean[-1].distance_to(point)>.0001:clean.append(point)
	if clean.size()<2:return {"ok":false,"reason":"연결할 도로가 너무 짧습니다"}
	points=clean
	var road := {"speed_limit_kmh":160 if kind=="highway" else 80,"layer":1 if kind=="highway" else 0,"reverse_lanes":reverse_lanes,"points": points.duplicate(), "kind": kind, "lanes": lanes, "width": config.road_width * lanes / 2.0}
	for b in buildings:
		if _polygon_road_distance(footprint(b), road) < -0.0005:
			return {"ok": false, "reason": "건물과 충돌합니다"}
	if commit:
		roads.append(road)
		road_network=RoadNetwork.build(roads)
		_update_zoning_for_road(road)
	return {"ok": true,"road":road}

func _road_sample(points:PackedVector2Array,distance:float)->Dictionary:
	if distance<0:return {}
	for i in range(points.size()-1):
		var length:=points[i].distance_to(points[i+1])
		if distance<=length and length>.0001:return {"point":points[i].lerp(points[i+1],distance/length),"tangent":(points[i+1]-points[i])/length}
		distance-=length
	return {}

func _ramp_attachments(road:Dictionary,segment:int,crossing:Vector2,span:float)->Dictionary:
	var distance:=0.0
	for i in range(segment):distance+=road.points[i].distance_to(road.points[i+1])
	distance+=road.points[segment].distance_to(crossing)
	var result:Dictionary={}
	var axis:Vector2=(road.points[segment+1]-road.points[segment]).normalized()
	# Support densely sampled freehand strokes, with a nearly straight ramp site.
	for i in range(9):
		var sample:=_road_sample(road.points,distance-span+(span*2)*i/8)
		if sample.is_empty() or sample.tangent.dot(axis)<.9659:return {}
	result.negative=_road_sample(road.points,distance-span)
	result.positive=_road_sample(road.points,distance+span)
	return result

func add_interchange_at(point: Vector2, commit: bool = true) -> Dictionary:
	var best:=10.0
	var proposal:Dictionary={}
	for hi in range(roads.size()):
		if roads[hi].kind!="highway":continue
		for li in range(roads.size()):
			if roads[li].kind!="local":continue
			for h in range(roads[hi].points.size()-1):
				for l in range(roads[li].points.size()-1):
					var a:Vector2=roads[hi].points[h];var b:Vector2=roads[hi].points[h+1]
					var c:Vector2=roads[li].points[l];var d:Vector2=roads[li].points[l+1]
					var crossing=Geometry2D.segment_intersects_segment(a,b,c,d)
					if crossing==null or crossing.distance_to(point)>=best:continue
					best=crossing.distance_to(point)
					proposal={"highway":hi,"local":li,"position":crossing,"a":a,"b":b,"c":c,"d":d,"h":h,"l":l}
	if proposal.is_empty():return {"ok":false,"reason":"일반도로와 고속도로가 교차하는 곳을 선택하세요"}
	for existing in interchanges:
		if existing.position.distance_to(proposal.position)<1:return {"ok":false,"reason":"이미 나들목이 있습니다"}
	var u:Vector2=(proposal.b-proposal.a).normalized()
	var v:Vector2=(proposal.d-proposal.c).normalized()
	if absf(u.dot(v))>.5:return {"ok":false,"reason":"나들목 교차각은 60~120도가 필요합니다"}
	var span:float=maxf(14.0,(roads[proposal.highway].width+roads[proposal.local].width)*1.5)+config.ramp_join_length
	var high_ends:=_ramp_attachments(roads[proposal.highway],proposal.h,proposal.position,span)
	var local_ends:=_ramp_attachments(roads[proposal.local],proposal.l,proposal.position,span)
	if high_ends.is_empty() or local_ends.is_empty():return {"ok":false,"reason":"교차점 양쪽에 완만하고 충분한 나들목 공간이 필요합니다"}
	var ramps:Array[Dictionary]=[]
	for quadrant in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var high_end:Dictionary=high_ends.negative if quadrant.x<0 else high_ends.positive
		var local_end:Dictionary=local_ends.negative if quadrant.y<0 else local_ends.positive
		var hn:=Vector2(-high_end.tangent.y,high_end.tangent.x)
		var ln:=Vector2(-local_end.tangent.y,local_end.tangent.x)
		var high_side:float=signf(hn.dot(local_end.point-high_end.point))
		var local_side:float=signf(ln.dot(high_end.point-local_end.point))
		var high_offset:float=roads[proposal.highway].width/2
		var local_offset:float=roads[proposal.local].width/2
		var a:Vector2=high_end.point+hn*high_side*high_offset
		var b:Vector2=local_end.point+ln*local_side*local_offset
		var points:=PackedVector2Array()
		var exit_ramp:bool=quadrant.x*quadrant.y*u.cross(v)<0
		var ramp:Dictionary={"kind":"ramp","points":points,"lanes":1,"width":1.5,"reverse_lanes":false,"speed_limit_kmh":80,"layer":0,"start_layer":1 if exit_ramp else 0,"end_layer":0 if exit_ramp else 1,"role":"exit" if exit_ramp else "entry"}
		var high_port:Dictionary={"road":proposal.highway,"anchor":high_end.point,"position":a,"normal":hn*high_side,"side":high_side,"layer":1,"radius":1.0,"carriageway":"forward" if high_side>0 else "backward"}
		var local_port:Dictionary={"road":proposal.local,"anchor":local_end.point,"position":b,"normal":ln*local_side,"side":local_side,"layer":0,"radius":1.0,"carriageway":"forward" if local_side>0 else "backward"}
		ramp.start_attachment=high_port if exit_ramp else local_port
		ramp.end_attachment=local_port if exit_ramp else high_port
		var start_heading:Vector2=high_end.tangent*-quadrant.x if exit_ramp else local_end.tangent*-quadrant.y
		var end_heading:Vector2=local_end.tangent*quadrant.y if exit_ramp else high_end.tangent*quadrant.x
		RampGeometry.configure(ramp,start_heading,end_heading,config.ramp_samples,config.ramp_taper_fraction,config.ramp_fillet_width)
		points=ramp.points
		for p in points:
			if p.x<0 or p.y<0 or p.x>width or p.y>height:return {"ok":false,"reason":"나들목이 지도 경계를 벗어납니다"}
		for building in buildings:
			if _polygon_road_distance(footprint(building),ramp)<-.0005:return {"ok":false,"reason":"나들목 부지에 건물이 있습니다"}
		# A template must not silently connect to unrelated roads.
		for ri in range(roads.size()):
			if ri in [proposal.highway,proposal.local]:continue
			for j in range(roads[ri].points.size()-1):
				for k in range(points.size()-1):
					if Geometry2D.segment_intersects_segment(points[k],points[k+1],roads[ri].points[j],roads[ri].points[j+1])!=null:return {"ok":false,"reason":"나들목 위치에 다른 도로가 있습니다"}
		ramps.append(ramp)
	if commit:
		var first:=roads.size()
		roads.append_array(ramps)
		interchanges.append({"position":proposal.position,"highway":proposal.highway,"local":proposal.local,"ramps":[first,first+1,first+2,first+3]})
		road_network=RoadNetwork.build(roads)
		_update_zoning_for_road(ramps[0])
	return {"ok":true,"ramps":ramps,"position":proposal.position}

func find_building(id: int) -> Dictionary:
	for b in buildings:
		if b.id == id:
			return b
	return {}

func building_at(point: Vector2) -> Dictionary:
	for b in buildings:
		if Geometry2D.is_point_in_polygon(point,footprint(b)):
			return b
	return {}

func adjacent(a: Dictionary, b: Dictionary) -> bool:
	if a.has("frame") or b.has("frame"):
		var pa:=footprint(a)
		var pb:=footprint(b)
		for i in range(4):
			var start:=pa[i]
			var edge:=pa[(i+1)%4]-start
			for j in range(4):
				var c:=pb[j]-start
				var d:=pb[(j+1)%4]-start
				if absf(edge.cross(c))/edge.length()>0.0005 or absf(edge.cross(d))/edge.length()>0.0005:continue
				var t0:=c.dot(edge)/edge.length_squared()
				var t1:=d.dot(edge)/edge.length_squared()
				if minf(1.0,maxf(t0,t1))-maxf(0.0,minf(t0,t1))>0.00001:return true
		return false
	var r := _rect(a)
	var s := _rect(b)
	return ((r.end.x == s.position.x or s.end.x == r.position.x) and min(r.end.y, s.end.y) > max(r.position.y, s.position.y)) or ((r.end.y == s.position.y or s.end.y == r.position.y) and min(r.end.x, s.end.x) > max(r.position.x, s.position.x))

func pick_size() -> int:
	var total := 0.0
	for weight in config.size_weights.values():
		total += max(0.0, float(weight))
	if total <= 0.0:
		return 2
	var roll := rng.randf() * total
	for size in [8, 4, 2]:
		roll -= max(0.0, float(config.size_weights.get(size, 0.0)))
		if roll < 0.0:
			return size
	return 2

func _upgrade(b: Dictionary) -> bool:
	var preferred := pick_size()
	if b.has("frame"):return _upgrade_parcel_building(b,preferred)
	for size in [8, 4, 2]:
		if size > preferred:
			continue
		# Search footprints containing the previous center, nearest anchor first.
		var candidates: Array[Vector2i] = []
		var center := Vector2(b.x + b.size / 2.0, b.y + b.size / 2.0)
		for x in range(int(floor(center.x)) - size + 1, int(floor(center.x)) + 1):
			for y in range(int(floor(center.y)) - size + 1, int(floor(center.y)) + 1):
				candidates.append(Vector2i(x, y))
		candidates.sort_custom(func(a, c): return Vector2(a).distance_squared_to(Vector2(b.x, b.y)) < Vector2(c).distance_squared_to(Vector2(b.x, b.y)))
		for pos in candidates:
			if placement_error(pos.x, pos.y, size, b.id) == "":
				b.x = pos.x
				b.y = pos.y
				b.size = size
				b.level += 1
				catalog.assign(b, appearance_rng)
				return true
	return false

func upgrade_chain(id: int) -> Dictionary:
	var root := find_building(id)
	if root.is_empty():
		return {"ok": false, "reason": "건물이 없습니다", "events": []}
	if root.score < config.score_threshold:
		return {"ok": false, "reason": "성장 수치가 부족합니다", "events": []}
	# Snapshot original edge neighbors so resizing does not create or erase propagation edges.
	var neighbors := {}
	for a in buildings:
		neighbors[a.id] = []
		for b in buildings:
			if a.id != b.id and adjacent(a, b):
				neighbors[a.id].append(b.id)
	var queue := [id]
	var visited := {id: true}
	var events: Array[Dictionary] = []
	while not queue.is_empty() and events.size() < config.max_chain:
		var current: int = queue.pop_front()
		var b := find_building(current)
		var old_size: int = b.size
		if not _upgrade(b):
			continue
		events.append({"id": current, "from_size": old_size, "size": b.size, "level": b.level, "cascade": current != id})
		for other in neighbors[current]:
			if not visited.has(other):
				visited[other] = true
				if rng.randf() < config.neighbor_chance:
					queue.append(other)
	return {"ok": not events.is_empty(), "events": events, "reason": "" if not events.is_empty() else "성장 가능한 공간이 없습니다"}


func _update_zoning_for_road(_road: Dictionary):
	# Rebuild occupied roadside strips only; earlier roads own overlap, deterministically.
	zoning_grid.clear()
	for road_index in range(roads.size()):
		var road: Dictionary=roads[road_index]
		if road.kind!="local":continue
		for frame in Parcels.blocks(road.points,road.width/2,road_index,config.parcel_block_length,config.parcel_turn_degrees,config.parcel_max_deviation):
			for u in range(frame.columns):
				for v in range(int(config.zoning_depth)):
					var polygon_value:=Parcels.polygon(frame,u,v)
					if _polygon_error(polygon_value,-1,false)=="":zoning_grid.add_parcel(frame,u,v)


func place_catalog_building(asset_id: String, x: int, y: int) -> Dictionary:
	# Authored scenario placement of a completed building; normal construction stays 2x2.
	var asset: Dictionary = catalog.get_asset(asset_id)
	if asset.is_empty(): return {"ok":false,"reason":"등록되지 않은 건물입니다"}
	var size: int = asset.footprint[0]
	var error := placement_error(x,y,size)
	if error != "": return {"ok":false,"reason":error}
	var building := {"id":next_id,"x":x,"y":y,"size":size,"level":asset.min_level,"zone":asset.zone,"score":0.0,"asset_id":asset_id}
	next_id += 1
	buildings.append(building)
	return {"ok":true,"building":building}


func _upgrade_parcel_building(b: Dictionary,preferred: int) -> bool:
	var center:=Vector2(b.u+b.size/2.0,b.v+b.size/2.0)
	for size in [8,4,2]:
		if size>preferred:continue
		var candidates: Array[Vector2i]=[]
		for u in range(floori(center.x)-size+1,floori(center.x)+1):
			for v in range(floori(center.y)-size+1,floori(center.y)+1):candidates.append(Vector2i(u,v))
		candidates.sort_custom(func(a,c):return Vector2(a).distance_squared_to(Vector2(b.u,b.v))<Vector2(c).distance_squared_to(Vector2(b.u,b.v)))
		for candidate in candidates:
			if parcel_placement_error(b.frame,candidate.x,candidate.y,size,b.id)!="":continue
			b.u=candidate.x;b.v=candidate.y;b.size=size;b.level+=1
			var origin: Vector2=Parcels.polygon(b.frame,b.u,b.v)[0]
			b.x=origin.x;b.y=origin.y
			catalog.assign(b,appearance_rng)
			return true
	return false
