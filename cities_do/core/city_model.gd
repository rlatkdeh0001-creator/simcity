extends RefCounted
const Economy = preload("res://core/economy_config.gd")
var difficulty := Economy.DEFAULT_DIFFICULTY
var funds: int = Economy.NORMAL_STARTING_FUNDS
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
var roads: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var next_id := 1
const RegionalExchange = preload("res://core/regional_exchange.gd")
var external_infrastructure: Array[Dictionary] = []
var next_external_link_id := 1
const PowerGrid = preload("res://core/power_grid.gd")
var power
const WaterGrid = preload("res://core/water_grid.gd")
var water
const PROTOTYPE_POWER_LOADS := {"residential":1.6,"commercial":1.5,"industrial":3.0}

func _init(w: int = 40, h: int = 40, seed_value: int = 42):
	width = w
	height = h
	rng.seed = seed_value
	appearance_rng.seed = seed_value ^ 0x5f3759df
	power = PowerGrid.new(Vector2(w,h)*4.0)
	water = WaterGrid.new(Vector2(w,h)*4.0)

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
		for plant in power.plants:
			if Parcels.overlap(polygon_value,power_plant_footprint(plant)):return "발전소가 있습니다"
		for facility in water.facilities:
			if Parcels.overlap(polygon_value,power_plant_footprint(facility)):return "상하수도 시설이 있습니다"
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
	buildings.append(b)
	return {"ok": true, "building": b}

func add_road(points: PackedVector2Array, kind: String = "local", commit: bool = true, lanes: int = 2) -> Dictionary:
	if kind not in ["local", "highway"] or points.size() < 2 or lanes not in [2, 4]:
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
	var road := {"points": points.duplicate(), "kind": kind, "lanes": lanes, "width": config.road_width * lanes / 2.0}
	for b in buildings:
		if _polygon_road_distance(footprint(b), road) < -0.0005:
			return {"ok": false, "reason": "건물과 충돌합니다"}
	for plant in power.plants:
		if _polygon_road_distance(power_plant_footprint(plant),road)<-0.0005:
			return {"ok":false,"reason":"발전소와 충돌합니다"}
	for facility in water.facilities:
		if _polygon_road_distance(power_plant_footprint(facility),road)<-0.0005:
			return {"ok":false,"reason":"상하수도 시설과 충돌합니다"}
	if commit:
		roads.append(road)
		_update_zoning_for_road(road)
	return {"ok": true}

func find_building(id: int) -> Dictionary:
	for b in buildings:
		if b.id == id:
			return b
	return {}

func regional_exchange() -> Dictionary:
	# Re-evaluate current paths: removing the last terminal closes its channel.
	var links: Array = external_infrastructure.duplicate()
	for wire in power.wires:
		var points := PackedVector2Array()
		for point in wire.points: points.append(point/4.0)
		links.append({"kind":"power","points":points})
	# Report actual paired neighbor ports even when the last pipe segment runs
	# along the map edge. Arbitrary boundary touches are not operating ports.
	water.geometry.rebuild()
	for port in water.geometry.ports:
		var node: int=water.geometry._find_node(port.position)
		if water.geometry.adjacency[node].is_empty(): continue
		var endpoint: Vector2=port.position/4.0
		var inward := Vector2.ZERO
		match port.edge:
			"x_min": inward=Vector2.RIGHT
			"x_max": inward=Vector2.LEFT
			"y_min": inward=Vector2.DOWN
			"y_max": inward=Vector2.UP
		var points := PackedVector2Array([endpoint+inward,endpoint])
		for kind in ["water","sewage"]: links.append({"kind":kind,"points":points})
	return RegionalExchange.evaluate(width,height,roads,links)

func power_plant_footprint(plant: Dictionary) -> PackedVector2Array:
	var p: Vector2 = plant.position/4.0-Vector2.ONE
	return footprint({"x":p.x,"y":p.y,"size":2})

func add_power_plant(point: Vector2, output_kw: float = 300.0) -> Dictionary:
	var center := Vector2(floorf(point.x)+1,floorf(point.y)+1)
	var polygon_value := footprint({"x":center.x-1,"y":center.y-1,"size":2})
	var error := _polygon_error(polygon_value)
	if error != "": return {"ok":false,"reason":error}
	var id: int = power.add_plant(center*4.0,output_kw)
	return {"ok":id!=-1,"id":id,"reason":"발전소를 설치했습니다" if id!=-1 else "발전소 위치/출력을 확인하세요"}

func power_consumers() -> Array:
	var result := []
	for building in buildings:
		var corners := footprint(building)
		var center := Vector2.ZERO
		for corner in corners: center += corner
		center /= corners.size()
		var provisional: float = PROTOTYPE_POWER_LOADS[building.zone]*building.size*building.size/4.0*maxi(1,building.level)
		result.append({"id":building.id,"position":center*4.0,"demand_kw":float(building.get("power_demand_kw",provisional))})
	return result

func power_state() -> Dictionary:
	var state: Dictionary = power.solve(power_consumers(),maxf(0,float(funds)+power.pending_doth))
	_apply_power_state(state)
	return state

func _apply_power_state(state: Dictionary):
	for building in buildings:
		var supply: Dictionary = state.consumers[building.id]
		building.has_power = supply.powered
		building.power_ratio = supply.ratio

func advance_power(hours: float) -> Dictionary:
	if not is_finite(hours) or hours<=0: return power_state()
	var state: Dictionary = power.solve(power_consumers(),maxf(0,float(funds)+power.pending_doth),hours)
	power.imported_kwh += state.import_kw*hours
	power.exported_kwh += state.export_kw*hours
	power.pending_doth += state.revenue_doth-state.cost_doth
	# Normalize floating-point noise only at an integer boundary; preserve real
	# fractional charges instead of rounding each frame's transaction.
	var nearest_integer := roundf(power.pending_doth)
	if absf(power.pending_doth-nearest_integer)<0.000000001:
		power.pending_doth=nearest_integer
	var settled := int(power.pending_doth)
	funds += settled
	power.pending_doth -= settled
	_apply_power_state(state)
	return state

func add_water_facility(point: Vector2, kind: String, capacity: float = 300.0) -> Dictionary:
	var center := Vector2(floorf(point.x)+1,floorf(point.y)+1)
	var error := _polygon_error(footprint({"x":center.x-1,"y":center.y-1,"size":2}))
	if error!="": return {"ok":false,"reason":error}
	var id: int=water.add_facility(center*4,kind,capacity)
	return {"ok":id!=-1,"id":id,"reason":"상하수도 시험 시설 설치" if id!=-1 else "시설 종류/용량을 확인하세요"}

func water_consumers() -> Array:
	var consumers := []
	# Provisional per-lot water loads, not a completed population simulation.
	var loads := {"residential":1.6,"commercial":.15,"industrial":.3}
	for building in buildings:
		var center := Vector2.ZERO
		var corners := footprint(building)
		for corner in corners: center+=corner
		center/=corners.size()
		var demand: float=loads[building.zone]*building.size*building.size/4.0*maxi(1,building.level)
		consumers.append({"id":building.id,"position":center*4,"demand_m3_day":float(building.get("water_demand_m3_day",demand)),"return_ratio":float(building.get("sewage_return_ratio",.8))})
	return consumers

func _apply_water_state(state: Dictionary):
	for building in buildings:
		var service: Dictionary=state.consumers[building.id]
		building.has_water=service.has_water
		building.has_sewage=service.has_sewage
		building.water_ratio=service.water_ratio
		building.sewage_ratio=service.sewage_ratio

func water_state() -> Dictionary:
	var state: Dictionary=water.solve(water_consumers())
	_apply_water_state(state)
	return state

func advance_water(days: float) -> Dictionary:
	var state: Dictionary=water.advance(water_consumers(),days)
	_apply_water_state(state)
	return state

func add_external_link(kind: String, points: PackedVector2Array, commit: bool = true) -> Dictionary:
	if kind not in ["rail","power","metro","water","sewage"]:
		return {"ok":false,"reason":"지원하지 않는 기반 시설입니다. 도로는 add_road를 사용하세요"}
	var error := RegionalExchange.path_error(points,width,height)
	if error != "": return {"ok":false,"reason":error}
	var link := {"id":next_external_link_id,"kind":kind,"points":points.duplicate()}
	if commit:
		external_infrastructure.append(link)
		next_external_link_id += 1
	return {"ok":true,"link":link}

func remove_external_link(id: int) -> bool:
	for i in range(external_infrastructure.size()):
		if external_infrastructure[i].id == id:
			external_infrastructure.remove_at(i)
			return true
	return false

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
