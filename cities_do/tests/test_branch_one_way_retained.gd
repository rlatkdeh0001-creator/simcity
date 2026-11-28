extends SceneTree

const City = preload("res://core/city_model.gd")
const Profile = preload("res://core/road_profile.gd")
const FLEET_SIZE := 4800
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + "perf: " + label)

func road_segment(x: float, end: float, row: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x,row),Vector2(end,row)])

func fixture(multiplier: int) -> Dictionary:
	var city := City.new(265,265)
	city.config.zoning_depth=1
	for i in range(12*multiplier):
		city.roads.append({"kind":"local","lanes":4,"width":5.0,"travel_dir":1,"parcel_id":city.next_road_id,"points":road_segment(10,230,10+9*i)})
		city.next_road_id+=1
	for i in range(multiplier):
		var row := 230+8*i
		if not city.add_branch_one_way(road_segment(15,60,row),Profile.BranchVariant.EIGHT_METRE).ok: return {}
		if not city.add_elevated_road(road_segment(60,95,row),PackedFloat64Array([0,0]),"local",true,2,false,1,{},null,1).ok: return {}
		if not city.add_branch_one_way(road_segment(108,155,row),Profile.BranchVariant.SIX_METRE).ok: return {}
		if not city.add_elevated_road(road_segment(174,215,row),PackedFloat64Array([10,10])).ok: return {}
	var game = load("res://main.tscn").instantiate()
	if game.city!=null and game.city.simulation!=null:game.city.simulation.shutdown()
	game.city=city
	game.paused=true
	root.add_child(game)
	game.origin=Vector2(640,85)
	game.map_zoom=.085
	var built: bool = game.traffic.rebuild(city.roads)
	return {"game":game,"built":built}

func measure_work(multiplier: int) -> Array:
	var data := fixture(multiplier)
	verify(not data.is_empty() and data.built,"%dx branch/taper city and off-ground structures build" % multiplier)
	if data.is_empty(): return []
	var game = data.game
	if not data.built:
		game.free()
		return []
	var render = game.world_renderer
	var network = game.traffic.network
	var simulation = game.traffic.simulation
	var asset: Dictionary = game.traffic.catalog.filter(func(item):return item.id=="car-hatch-01")[0]
	var fleet: Array[Dictionary] = []
	var per_lane := int(FLEET_SIZE/float(48*multiplier))
	for lane: Dictionary in network.lanes:
		if lane.road<0 or lane.road>=12*multiplier:continue
		# Spawn against this lane's real occupancy only; then retain the full fleet.
		for i in range(per_lane):simulation.spawn(asset,[lane.id],12.0+8.0*i)
		fleet.append_array(simulation.vehicles)
		simulation.vehicles.clear()
	simulation.vehicles.append_array(fleet)
	var connectors: Array=network.lanes.filter(func(l):return l.road<0 and l.transition and network.lanes[l.from].road==12*multiplier)
	verify(fleet.size()==FLEET_SIZE and connectors.size()==2,"%dx seeded 4,800 actual vehicles and two branch taper lanes" % multiplier)
	if fleet.size()!=FLEET_SIZE or connectors.size()!=2:
		game.free()
		return []
	var connector: Dictionary=connectors[0]
	fleet[0].merge({"route":[connector.from,connector.id,connector.to],"route_index":1,"lane":connector.id,"progress":connector.length*.2},true)
	render.synchronize()
	var generation: int=render.road_generation
	var structures: int=render.structure_generation
	var mesh: ArrayMesh=render.line_mesh
	var shape_refs: Array=render.road_shapes.duplicate()
	var branches: Array=game.city.road_branch_edge_marks.duplicate()
	var yellow: Array=render.road_shapes.filter(func(shape):return shape[1]==Color("e4bd5f")).map(func(shape):return shape[0])
	verify(not branches.is_empty() and yellow==branches.map(render.project),"%dx retained road commands carry projected branch stripes" % multiplier)
	render._process(0)
	var lookups: int=render.vehicle_road_lookups
	var visible: int=render.cars.values().filter(func(sprite):return sprite.visible).size()
	var taper_sprite: Sprite2D=render.cars.get(fleet[0].id)
	verify(visible==FLEET_SIZE and lookups==FLEET_SIZE and taper_sprite!=null and taper_sprite.get_meta("road_height_m")==0.0,"%dx 4,800 visible sprites, one indexed owner lookup each including taper" % multiplier)
	var moving: Sprite2D=render.cars.get(fleet[1].id)
	var original := moving.position if moving!=null else Vector2.ZERO
	var stable := true
	for frame in range(60):
		for vehicle in fleet:vehicle.progress+=.01
		render._process(0)
		stable=stable and render.road_generation==generation and render.structure_generation==structures and render.vehicle_road_lookups==FLEET_SIZE
	verify(stable and moving!=null and moving.position!=original and render.line_mesh==mesh and render.road_shapes==shape_refs and game.city.road_branch_edge_marks==branches,"%dx 60 moving pose-only frames reuse fixed paint and structure work" % multiplier)
	var road_count: int=game.city.roads.size()
	var deck_count: int=render.elevated.decks.size()
	verify(game.city.add_branch_one_way(road_segment(10,60,254),Profile.BranchVariant.SIX_METRE).ok,"%dx real branch road dirty control" % multiplier)
	render.synchronize()
	verify(render.road_generation==generation+1 and render.structure_generation==structures+1 and game.city.road_branch_edge_marks.size()>branches.size() and render.line_mesh!=mesh,"%dx one road and structure rebuild advances retained stripes" % multiplier)
	game.free()
	return [lookups,road_count,deck_count]

func run() -> void:
	root.size=Vector2i(1280,820)
	var once := measure_work(1)
	var twice := measure_work(2)
	verify(once.size()==3 and twice.size()==3 and once[0]==twice[0] and twice[1]==2*once[1] and once[2]>0 and twice[2]==2*once[2],"doubling roads and decks preserves exactly 4,800 lookups")
	print("RESULT %d/%d branch retained work checks passed" % [checks-failures, checks])
	quit(1 if failures else 0)
