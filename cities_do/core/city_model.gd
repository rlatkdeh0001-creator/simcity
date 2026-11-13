extends RefCounted
const Economy = preload("res://core/economy_config.gd")
var difficulty := Economy.DEFAULT_DIFFICULTY
signal funds_changed
signal society_changed
signal city_name_changed
var city_name := "CITIESDO":
	set(value):
		if city_name==value:return
		city_name=value
		city_name_changed.emit()
var funds: int = Economy.NORMAL_STARTING_FUNDS:
	set(value):
		if funds==value:return
		funds=value
		funds_changed.emit()
const Frontage = preload("res://core/building_frontage.gd")
const Parcels = preload("res://core/road_parcels.gd")
const ZoningGrid = preload("res://core/zoning_grid.gd")
const RoadGeometry=preload("res://core/road_geometry.gd")
const RoadProfile=preload("res://core/road_profile.gd")
var zoning_grid = ZoningGrid.new()
var zoning_lattices: Array[Dictionary]=[]
var road_crosswalks: Array[PackedVector2Array]=[]
var road_stop_lines: Array[PackedVector2Array]=[]
var intersection_regions: Array[PackedVector2Array]=[]
var road_pavement: Array[PackedVector2Array]=[]
var road_asphalt: Array[PackedVector2Array]=[]
var road_medians: Array[PackedVector2Array]=[]
var road_lane_marks: Array[PackedVector2Array]=[]
var junction_pavement: Array[PackedVector2Array]=[]
var junction_asphalt: Array[PackedVector2Array]=[]
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
const Clock=preload("res://core/city_clock.gd")
const Population=preload("res://core/population.gd")
var clock=Clock.new()
var population
var population_enabled := true
var society_elapsed := 0.0
var zone_designations := {} # Stable parcel ID -> residential/commercial/industrial.
var development_elapsed := 0.0
var development_cursor := 0
var next_id := 1
var next_road_id := 0
const RoadJunctions = preload("res://core/road_junctions.gd")
const RoadUnits = preload("res://core/road_length_units.gd")
var junctions: Array = []
var road_joins: Array = []
var road_visuals: Array = []
const RegionalExchange = preload("res://core/regional_exchange.gd")
var external_infrastructure: Array[Dictionary] = []
var next_external_link_id := 1
const PowerGrid = preload("res://core/power_grid.gd")
var power
const WaterGrid = preload("res://core/water_grid.gd")
var water
const PublicFacilities=preload("res://core/public_facilities.gd")
var public_facilities
const PROTOTYPE_POWER_LOADS := {"residential":1.6,"commercial":1.5,"industrial":3.0}

func _init(w: int = 40, h: int = 40, seed_value: int = 42):
	width = w
	height = h
	population=Population.new(seed_value)
	rng.seed = seed_value
	appearance_rng.seed = seed_value ^ 0x5f3759df
	power = PowerGrid.new(Vector2(w,h)*4.0)
	water = WaterGrid.new(Vector2(w,h)*4.0)
	public_facilities=PublicFacilities.new(self)
	clock.day_changed.connect(public_facilities.bill_months)

func _rect(b: Dictionary) -> Rect2:
	return Rect2(Vector2(b.x, b.y), Vector2(b.size, b.size))

func _point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))

func footprint(b: Dictionary) -> PackedVector2Array:
	if b.has("public_asset_id"):return b.polygon
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
		if public_facilities!=null:
			for record: Dictionary in public_facilities.lots:
				if record.id!=ignore_id and Parcels.overlap(polygon_value,record.polygon):return "공공시설과 충돌합니다"
		for b in buildings:
			if b.id!=ignore_id and Parcels.overlap(polygon_value,footprint(b)):return "다른 건물이 있습니다"
		for plant in power.plants:
			if plant.get("public_lot_id",-2)==ignore_id:continue
			if Parcels.overlap(polygon_value,power_plant_footprint(plant)):return "발전소가 있습니다"
		for facility in water.facilities:
			if facility.get("public_lot_id",-2)==ignore_id:continue
			if Parcels.overlap(polygon_value,power_plant_footprint(facility)):return "상하수도 시설이 있습니다"
	for junction in junctions+road_joins:
		if Parcels.overlap(polygon_value,RoadJunctions.patch(junction)):return "교차로와 충돌합니다"
	for road in roads:
		var distance:=_polygon_road_distance(polygon_value,road)
		if distance< -0.0005:return "도로와 충돌합니다"
	# Revealed cells may extend deeper than building frontage range.
	if not check_buildings:return ""
	return "" if not Frontage.candidates(polygon_value,roads,config.road_access_distance).is_empty() else "도로 바로 옆 구획이 필요합니다"

func placement_error(x: int,y: int,size: int,ignore_id: int=-1) -> String:
	if size not in [2,4,8]:return "크기는 2·4·8만 가능합니다"
	var shape:=footprint({"x":x,"y":y,"size":size})
	if size==8 and not zoning_grid.has_opposing_lot(shape):return "8×8 부지는 마주 보는 두 도로의 4칸 구획이 필요합니다"
	return _polygon_error(shape,ignore_id)

func parcel_placement_error(frame: Dictionary,u: int,v: int,size: int,ignore_id: int=-1) -> String:
	if size not in [2,4,8]:return "크기는 2·4·8만 가능합니다"
	if size==8:
		if zoning_grid.opposing_lot_cells(frame,u,v).size()!=64:return "8×8 부지는 마주 보는 두 도로의 4칸 구획이 필요합니다"
		return _polygon_error(Parcels.polygon(frame,u,v,size),ignore_id)
	for x in range(u,u+size):
		for y in range(v,v+size):
			if not zoning_grid.has_parcel(frame.id,x,y):return "한 도로 블록 안에 반듯한 부지가 필요합니다"
	return _polygon_error(Parcels.polygon(frame,u,v,size),ignore_id)

func add_building_at(point: Vector2,zone: String="residential",score: float=0.0,size: int=2) -> Dictionary:
	if zone not in ["residential","commercial","industrial"]:return {"ok":false,"reason":"지원하지 않는 구획입니다"}
	if size not in [2,4]:return {"ok":false,"reason":"신축 부지는 2·4만 가능합니다"}
	var parcel: Dictionary=zoning_grid.parcel_at(point)
	if parcel.is_empty():return {"ok":false,"reason":"도로 주변 건설 구획을 선택하세요"}
	var error:=parcel_placement_error(parcel.frame,parcel.u,parcel.v,size)
	if error!="":return {"ok":false,"reason":error}
	var origin: Vector2=parcel.polygon[0]
	var building:={"id":next_id,"x":origin.x,"y":origin.y,"u":parcel.u,"v":parcel.v,"frame":parcel.frame.duplicate(),"size":size,"level":1,"zone":zone,"score":score,"asset_id":""}
	orient_building(building)
	catalog.assign(building,appearance_rng)
	next_id+=1;buildings.append(building)
	return {"ok":true,"building":building}

func paint_zones(selection: PackedVector2Array, zone_type: String) -> Dictionary:
	if zone_type not in ["residential","commercial","industrial",""] or selection.size()<3:
		return {"ok":false,"changed":0,"reason":"구획을 선택하세요"}
	var bounds := Parcels.bounds(selection)
	var changed := 0
	for parcel in zoning_grid.parcels_in(Rect2i(Vector2i(bounds.position.floor())-Vector2i.ONE,Vector2i(bounds.size.ceil())+Vector2i(3,3))):
		if not Geometry2D.is_point_in_polygon(parcel.center,selection):continue
		if zone_designations.get(parcel.id,"")==zone_type:continue
		if not zone_type.is_empty() and not str(zone_designations.get(parcel.id,"")).is_empty():continue
		if zone_type.is_empty():zone_designations.erase(parcel.id)
		else:zone_designations[parcel.id]=zone_type
		changed+=1
	return {"ok":true,"changed":changed,"reason":"%d칸 %s" % [changed,"해제" if zone_type.is_empty() else "지정"]}

func zoned_lot_matches(frame: Dictionary,u: int,v: int,size: int,zone_type: String) -> bool:
	if size==8:
		var cells: Array[Dictionary]=zoning_grid.opposing_lot_cells(frame,u,v)
		return cells.size()==64 and cells.all(func(cell):return zone_designations.get(cell.id,"")==zone_type)
	for x in range(u,u+size):
		for y in range(v,v+size):
			if zone_designations.get(zoning_grid.key(frame.id,x,y),"")!=zone_type:return false
	return true

func advance_development(seconds: float) -> Array[Dictionary]:
	var created: Array[Dictionary]=[]
	if seconds<=0 or not is_finite(seconds) or config.development_interval_seconds<=0:return created
	if zone_designations.is_empty():
		development_elapsed=0
		return created
	development_elapsed+=seconds
	var steps := 0
	while development_elapsed>=config.development_interval_seconds and steps<config.development_max_steps:
		development_elapsed-=config.development_interval_seconds
		steps+=1
		var ids: Array=zone_designations.keys()
		ids.sort()
		var start:=development_cursor
		var checks:=mini(ids.size(),config.development_checks_per_step)
		development_cursor=start+checks
		var built:=false
		# Check larger lots across this bounded fair scan before considering small lots.
		for size in [4,2]:
			for attempt in range(checks):
				var id: String=ids[(start+attempt)%ids.size()]
				var parcel: Dictionary=zoning_grid.parcels.get(id,{})
				if parcel.is_empty():continue
				var zone_type: String=zone_designations[id]
				if population_enabled and population.demand(buildings)[zone_type]<=0:continue
				if not zoned_lot_matches(parcel.frame,parcel.u,parcel.v,size,zone_type):continue
				if parcel_placement_error(parcel.frame,parcel.u,parcel.v,size)!="":continue
				var result:=add_building_at(parcel.center,zone_type,0.0,size)
				if not result.ok:continue
				result.building.automatically_developed=true
				created.append(result.building)
				if population_enabled:population.sync(buildings)
				development_cursor=start+attempt+1
				built=true
				break
			if built:break
	return created

func advance_society(seconds: float) -> void:
	if seconds<=0 or not is_finite(seconds):return
	clock.advance_real(seconds)
	society_elapsed+=seconds
	var steps := 0
	while society_elapsed>=config.development_interval_seconds and steps<config.development_max_steps:
		society_elapsed-=config.development_interval_seconds
		steps+=1
		if population_enabled:population.advance(config.development_interval_seconds*Clock.SCALE,buildings)
		advance_development(config.development_interval_seconds)
	if steps>0:society_changed.emit()

func orient_building(b: Dictionary) -> void:
	Frontage.resolve(b,footprint(b),roads,config.road_access_distance)

func front_direction(b: Dictionary) -> Vector2:
	return Frontage.direction(b)

func supports_static_sprite(b: Dictionary) -> bool:
	if front_direction(b).distance_to(Vector2.DOWN)>.00001:return false
	var polygon_value:=footprint(b)
	var bounds:=Parcels.bounds(polygon_value)
	return absf(bounds.size.x-b.size)<.00001 and absf(bounds.size.y-b.size)<.00001

func add_building(x: int, y: int, zone: String = "residential", score: float = 0.0) -> Dictionary:
	if zone not in ["residential", "commercial", "industrial"]:
		return {"ok": false, "reason": "지원하지 않는 구획입니다"}
	var error := placement_error(x, y, 2)
	if error != "":
		return {"ok": false, "reason": error}
	var b := {"id": next_id, "x": x, "y": y, "size": 2, "level": 1, "zone": zone, "score": score, "asset_id": ""}
	orient_building(b)
	catalog.assign(b,appearance_rng)
	next_id += 1
	buildings.append(b)
	return {"ok": true, "building": b}

func add_road(points: PackedVector2Array, kind: String = "local", commit: bool = true, lanes: int = 2, connect_ends: bool = false, enforce_units: bool = false, major_side: int = 1, grid_frame: Dictionary = {}) -> Dictionary:
	if kind not in ["local", "highway"] or points.size() < 2 or lanes not in (preload("res://core/road_profile.gd").LOCAL_LANES if kind=="local" else [2,4]) or major_side not in [-1,1]:
		return {"ok": false, "reason": "도로 경로가 필요합니다"}
	# Player strokes opt in; authored scenarios retain exact supplied geometry.
	if connect_ends:points=RoadJunctions.snap_path(points,roads)
	var total := 0.0
	for i in range(points.size()):
		var p := points[i]
		if not p.is_finite() or p.x < 0 or p.y < 0 or p.x > width or p.y > height:
			return {"ok": false, "reason": "지도 경계 밖입니다"}
		if i > 0:
			total += points[i - 1].distance_to(p)
	if total < 0.1:
		return {"ok": false, "reason": "도로가 너무 짧습니다"}
	var road := {"points": points.duplicate(), "kind": kind, "lanes": lanes, "width": RoadProfile.width_for(kind,lanes,config.road_width),"major_side":major_side}
	if not grid_frame.is_empty():road.grid_frame=grid_frame.duplicate(true)
	var plan: Dictionary={"ok":true,"new_roads":[road],"new_length_m":total*4,"retained_length_m":0.0,"construction_cost":0,"reason":""}
	# Authored/restored scenarios retain their supplied geometry; all player modes share this transaction.
	if enforce_units:plan=preload("res://core/road_construction.gd").plan(roads,road)
	if not plan.ok:return plan
	var new_roads: Array=plan.new_roads
	for candidate: Dictionary in new_roads:
		if enforce_units:
			var valid_units: bool=preload("res://core/road_grid_snap.gd").valid_length(candidate.points,roads) if not grid_frame.is_empty() else RoadUnits.is_build_length(RoadJunctions.length_of(candidate.points),RoadUnits.build_step(candidate.points,roads))
			if not valid_units:return {"ok":false,"reason":"기본 8m, 기존 도로 연결은 4m 단위로 건설해야 합니다"}
		for b in buildings:
			if _polygon_road_distance(footprint(b),candidate)<-0.0005:return {"ok":false,"reason":"건물과 충돌합니다"}
		for record: Dictionary in public_facilities.lots:
			if _polygon_road_distance(record.polygon,candidate)<-0.0005:return {"ok":false,"reason":"공공시설과 충돌합니다"}
		for plant in power.plants:
			if _polygon_road_distance(power_plant_footprint(plant),candidate)<-0.0005:return {"ok":false,"reason":"발전소와 충돌합니다"}
		for facility in water.facilities:
			if _polygon_road_distance(power_plant_footprint(facility),candidate)<-0.0005:return {"ok":false,"reason":"상하수도 시설과 충돌합니다"}
	var occupied := []
	for building in buildings: occupied.append(footprint(building))
	for record: Dictionary in public_facilities.lots:occupied.append(record.polygon)
	for facility in power.plants+water.facilities: occupied.append(power_plant_footprint(facility))
	if not occupied.is_empty():
		var topology: Dictionary=RoadJunctions.analyze(roads+new_roads)
		for junction in topology.junctions+topology.joins:
			var polygon_value: PackedVector2Array=RoadJunctions.patch(junction)
			for existing in occupied:
				if Parcels.overlap(existing,polygon_value):return {"ok":false,"reason":"교차로가 기존 건물과 충돌합니다"}
	if commit:
		for candidate: Dictionary in new_roads:
			candidate.parcel_id=next_road_id
			next_road_id+=1
			roads.append(candidate)
		_update_zoning_for_road(road)
		for building in buildings:orient_building(building)
	return plan

func demolish_road_unit(id: int,point: Vector2) -> Dictionary:
	for i in range(roads.size()):
		var road: Dictionary=roads[i]
		if int(road.parcel_id)!=id:continue
		var cut:=RoadUnits.cut_target(road,point)
		if cut.distance>float(road.width)/2+RoadUnits.EPS:return {"ok":false,"reason":"도로를 선택하세요"}
		var length:=RoadJunctions.length_of(road.points)
		var offset: float=road.get("source_start",0.0)
		var first: float=cut.first-offset;var last: float=cut.last-offset
		if last-first<RoadUnits.EPS:return {"ok":false,"reason":"철거할 도로가 없습니다"}
		var pieces: Array[Dictionary]=[]
		if first>RoadUnits.EPS:pieces.append(RoadUnits.fragment(road,0,first))
		if length-last>RoadUnits.EPS:pieces.append(RoadUnits.fragment(road,last,length))
		roads.remove_at(i)
		for j in range(pieces.size()):
			if j==0:pieces[j].parcel_id=id
			else:pieces[j].parcel_id=next_road_id;next_road_id+=1
			roads.insert(i+j,pieces[j])
		_update_zoning_for_road({})
		for building in buildings:orient_building(building)
		population.sync(buildings);power_state();water_state()
		return {"ok":true,"reason":"철거 완료","removed_cells":last-first}
	return {"ok":false,"reason":"철거할 도로가 없습니다"}

func demolish(kind: String, id: int) -> Dictionary:
	var removed := false
	match kind:
		"public_facility":removed=public_facilities.remove(id)
		"building":
			for i in range(buildings.size()):
				if buildings[i].id==id:
					buildings.remove_at(i)
					removed=true
					break
		"road":
			for i in range(roads.size()):
				if int(roads[i].get("parcel_id",i))==id:
					roads.remove_at(i)
					_update_zoning_for_road({})
					for building in buildings:orient_building(building)
					removed=true
					break
		"power_plant": removed=power.remove_plant(id)
		"power_wire": removed=power.remove_wire(id)
		"water_facility": removed=water.remove_facility(id)
		"water_pipe": removed=water.remove_pipe(id)
	if removed:
		population.sync(buildings)
		power_state()
		water_state()
	return {"ok":removed,"reason":"철거 완료" if removed else "철거할 대상을 선택하세요"}

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
	if plant.has("public_polygon"):return plant.public_polygon
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

func utility_balance() -> float:
	return maxf(0,float(funds)+power.pending_doth+water.pending_doth)

func power_state() -> Dictionary:
	var state: Dictionary = power.solve(power_consumers(),utility_balance())
	_apply_power_state(state)
	return state

func _apply_power_state(state: Dictionary):
	for building in buildings:
		var supply: Dictionary = state.consumers[building.id]
		building.has_power = supply.powered
		building.power_ratio = supply.ratio

func advance_power(hours: float) -> Dictionary:
	if not is_finite(hours) or hours<=0: return power_state()
	var state: Dictionary = power.solve(power_consumers(),utility_balance(),hours)
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
	var state: Dictionary=water.solve(water_consumers(),utility_balance())
	_apply_water_state(state)
	return state

func advance_water(days: float) -> Dictionary:
	var state: Dictionary=water.advance(water_consumers(),days,utility_balance())
	water.pending_doth+=state.revenue_doth-state.cost_doth
	var nearest_integer := roundf(water.pending_doth)
	if absf(water.pending_doth-nearest_integer)<.000000001: water.pending_doth=nearest_integer
	var settled := int(water.pending_doth)
	funds+=settled
	water.pending_doth-=settled
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

func _upgrade(b: Dictionary) -> bool:
	if int(b.level)>=5:return false
	# Legacy 8x8 lots stay intact; newly reached stages1-4 cannot choose 8x8.
	var preferred:=maxi(int(b.size),8 if int(b.level)+1>=5 else 4)
	if b.has("frame"):return _upgrade_parcel_building(b,preferred)
	for size in [8, 4, 2]:
		if size > preferred or size<int(b.size):
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
				orient_building(b)
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
	# Upgrade saved footprints only; never remove/move authored roads or buildings.
	for road in roads:
		if road.kind!="local":continue
		var target:=RoadProfile.width_for(road.kind,road.lanes,config.road_width)
		if not is_equal_approx(road.width,target):road.width=target;road.erase("grid_frame")
	var topology: Dictionary=RoadJunctions.analyze(roads)
	junctions=topology.junctions
	road_joins=topology.joins
	road_visuals=RoadGeometry.continuous_roads(roads,topology)
	# Pavement owns its render box; approach lines use the actual stop-line boundaries.
	for cache in [road_crosswalks,road_stop_lines,intersection_regions,road_pavement,road_asphalt,road_medians,road_lane_marks,junction_pavement,junction_asphalt]:cache.clear()
	var bounds:=Vector2(width,height)
	var border:=PackedVector2Array([Vector2.ZERO,Vector2(width,0),bounds,Vector2(0,height)])
	var line_regions: Array[PackedVector2Array]=[]
	for junction in junctions+road_joins:
		if not junction.has("box"):continue
		intersection_regions.append(junction.box)
		junction_pavement.append_array(Geometry2D.intersect_polygons(junction.footprint,border))
		junction_asphalt.append_array(Geometry2D.intersect_polygons(junction.asphalt,border))
		line_regions.append_array(RoadJunctions.lane_mark_regions(junction))
	for visual in road_visuals:
		road_pavement.append_array(RoadGeometry.outside_regions(RoadGeometry.clipped_ribbons(visual.points,visual.width,bounds,visual.flat_start,visual.flat_end),intersection_regions))
		road_asphalt.append_array(RoadGeometry.outside_regions(RoadGeometry.clipped_ribbons(visual.points,RoadProfile.asphalt_width(visual),bounds,visual.flat_start,visual.flat_end),intersection_regions))
		road_medians.append_array(RoadGeometry.visible_lines(RoadProfile.offset_path(visual.points,RoadProfile.median_offset(visual)),bounds,line_regions))
		for dash in RoadGeometry.lane_marks(visual):road_lane_marks.append_array(RoadGeometry.visible_lines(dash,bounds,line_regions))
		for line in RoadGeometry.shoulder_marks(visual):road_lane_marks.append_array(RoadGeometry.visible_lines(line,bounds,line_regions))
	# Crossings can lie inside the render box: clip against all actually visible asphalt.
	var paint_surfaces: Array[PackedVector2Array]=road_asphalt.duplicate()
	paint_surfaces.append_array(junction_asphalt)
	for junction in junctions:
		road_crosswalks.append_array(RoadJunctions.crosswalk_polygons(junction,paint_surfaces))
		road_stop_lines.append_array(RoadJunctions.stop_line_polygons(junction,paint_surfaces))
	zoning_lattices=preload("res://core/road_grid_snap.gd").shared_grids(roads,topology)
	# Rebuild occupied roadside strips only; earlier roads own overlap, deterministically.
	zoning_grid.clear()
	for road_index in range(roads.size()):
		var road: Dictionary=roads[road_index]
		if road.kind!="local":continue
		var source: PackedVector2Array=road.get("zoning_source_points",road.points)
		var source_id: int=road.get("zoning_source_id",road.get("parcel_id",road_index))
		var frames: Array[Dictionary]=Parcels.blocks(source,road.width/2,source_id,config.parcel_block_length,config.parcel_turn_degrees,config.parcel_max_deviation)
		for frame in preload("res://core/road_grid_snap.gd").aligned_blocks(frames,zoning_lattices[road_index]):
			for u in range(frame.columns):
				if not RoadUnits.supports_column(road,frame,u):continue
				for v in range(clampi(int(config.zoning_depth),0,Config.MAX_ZONING_DEPTH)):
					var polygon_value:=Parcels.polygon(frame,u,v)
					if _polygon_error(polygon_value,-1,false)=="":zoning_grid.add_parcel(frame,u,v)


	# Keep designations only on surviving stable road-local cells.
	for id in zone_designations.keys():
		if not zoning_grid.parcels.has(id):zone_designations.erase(id)

func place_catalog_building(asset_id: String, x: int, y: int) -> Dictionary:
	# Authored scenario placement; automatic birth uses the separate 4x4-first zoning path.
	var asset: Dictionary = catalog.get_asset(asset_id)
	if asset.is_empty(): return {"ok":false,"reason":"등록되지 않은 건물입니다"}
	var size: int = asset.footprint[0]
	var error := placement_error(x,y,size)
	if error != "": return {"ok":false,"reason":error}
	var building := {"id":next_id,"x":x,"y":y,"size":size,"level":5 if size==8 else asset.min_level,"zone":asset.zone,"score":0.0,"asset_id":asset_id}
	orient_building(building)
	next_id += 1
	buildings.append(building)
	return {"ok":true,"building":building}


func _upgrade_parcel_building(b: Dictionary,preferred: int) -> bool:
	var center:=Vector2(b.u+b.size/2.0,b.v+b.size/2.0)
	for size in [8,4,2]:
		if size>preferred or size<int(b.size):continue
		var candidates: Array[Vector2i]=[]
		for u in range(floori(center.x)-size+1,floori(center.x)+1):
			for v in range(floori(center.y)-size+1,floori(center.y)+1):candidates.append(Vector2i(u,v))
		candidates.sort_custom(func(a,c):return Vector2(a).distance_squared_to(Vector2(b.u,b.v))<Vector2(c).distance_squared_to(Vector2(b.u,b.v)))
		for candidate in candidates:
			if parcel_placement_error(b.frame,candidate.x,candidate.y,size,b.id)!="":continue
			if b.get("automatically_developed",false) and not zoned_lot_matches(b.frame,candidate.x,candidate.y,size,b.zone):continue
			b.u=candidate.x;b.v=candidate.y;b.size=size;b.level+=1
			var origin: Vector2=Parcels.polygon(b.frame,b.u,b.v)[0]
			b.x=origin.x;b.y=origin.y
			orient_building(b)
			catalog.assign(b,appearance_rng)
			return true
	return false
