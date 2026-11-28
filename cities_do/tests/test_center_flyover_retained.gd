extends SceneTree
## E4c renderer contract using production E1 decks and E4b branch roads. No frame timing.
const City = preload("res://core/city_model.gd")
const Profile = preload("res://core/road_profile.gd")
const FLEET_SIZE := 4800
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func verify(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + "perf: " + label)
	return ok

func path(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a,b])

func scene_for(city):
	var game = load("res://main.tscn").instantiate()
	if game.city.simulation != null: game.city.simulation.shutdown()
	game.city = city
	game.paused = true
	root.add_child(game)
	game.origin = Vector2(640,85)
	game.map_zoom = .085
	return game

func fixture(multiplier: int) -> Dictionary:
	var city := City.new(265,265)
	city.config.zoning_depth = 1
	for i in range(12*multiplier):
		city.roads.append({"kind":"local","lanes":4,"width":5.0,"travel_dir":1,"parcel_id":city.next_road_id,"points":path(Vector2(10,10+5*i),Vector2(230,10+5*i))})
		city.next_road_id += 1
	var first := {}
	for i in range(multiplier):
		var row := 150+65*i
		var base := city.roads.size()
		var edits: Array = [
			city.add_elevated_road(path(Vector2(82,row-16),Vector2(82,row+16)),PackedFloat64Array([0,0])),
			city.add_branch_one_way(path(Vector2(14,row-4),Vector2(74,row-4)),Profile.BranchVariant.SIX_METRE),
			city.add_elevated_road(PackedVector2Array([Vector2(14,row),Vector2(46,row),Vector2(112,row)]),PackedFloat64Array([0,10,10])),
			city.add_elevated_road(path(Vector2(112,row),Vector2(176,row)),PackedFloat64Array([10,10])),
			city.add_elevated_road(path(Vector2(148,row-16),Vector2(148,row+16)),PackedFloat64Array([10,10]))]
		if not edits.all(func(edit): return edit.ok) or city.roads.size()!=base+5:
			print("Fixture edit results: ", edits.map(func(edit): return [edit.ok,edit.get("reason","")]))
			return {}
		if i==0: first={"under":base,"branch":base+1,"ramp":base+2,"extension":base+3}
	return {"game":scene_for(city),"roads":first}

func lane_for(lanes: Array, road: int) -> Dictionary:
	for lane: Dictionary in lanes:
		if lane.road==road and lane.direction==1:return lane
	return {}

func seed_fleet(game, roads: Dictionary, asset: Dictionary) -> Dictionary:
	var sim = game.traffic.simulation
	var lanes: Array = sim.network.lanes
	var fleet: Array[Dictionary] = []
	for lane: Dictionary in lanes:
		if lane.road<0 or lane.road>=12: continue
		# Spawn checks real lane occupancy; unrelated lanes need not participate in setup.
		for i in range(100 if lane.id<43 else 99): sim.spawn(asset,[lane.id],12.0+8.0*i)
		fleet.append_array(sim.vehicles)
		sim.vehicles.clear()
	var probes: Dictionary = {}
	for kind: String in ["under","branch","ramp","extension"]:
		var lane := lane_for(lanes,roads[kind])
		if lane.is_empty():return {}
		probes[kind] = sim.spawn(asset,[lane.id],64.0)
	for connector: Dictionary in lanes:
		if connector.road>=0 or connector.junction<0 or lanes[connector.from].road!=roads.extension: continue
		var vehicle: Dictionary = sim.spawn(asset,[connector.from,connector.id,connector.to],6.0)
		if vehicle.is_empty():return {}
		vehicle.merge({"lane":connector.id,"route_index":1,"progress":connector.length*.45},true)
		probes.connector=vehicle
		break
	if probes.size()!=5 or probes.values().any(func(vehicle): return vehicle.is_empty()):return {}
	sim.vehicles.append_array(fleet)
	return probes

func artwork_and_slot(game, vehicle: Dictionary, asset: Dictionary, owner: Dictionary, height: float, junction: bool=false) -> bool:
	var render = game.world_renderer
	var sim = game.traffic.simulation
	var sprite: Sprite2D = render.cars.get(vehicle.id)
	if sprite==null or not sprite.is_visible_in_tree():return false
	var p: Vector2 = sim.position(vehicle)/4
	var d: Vector2 = sim.heading(vehicle)
	var rect: Rect2 = game.traffic.sprite_rect(asset.id,Vector2.ZERO,game.tile.x/4*sqrt(2.0))
	var projected: Vector2 = render.iso(p)+rect.position-Vector2(0,height*game.tile.x/4*sqrt(1.5))
	if not is_equal_approx(float(sprite.get_meta("road_height_m")),height) or (sprite.position+sprite.offset*sprite.scale).distance_to(projected)>=.002:
		print("Layer artwork: id=",vehicle.id," point=",p," height=",sprite.get_meta("road_height_m")," expected=",height," art=",sprite.position+sprite.offset*sprite.scale," expected=",projected)
		return false
	if height==0.0:return sprite.get_parent()==render.actors and sprite.position.is_equal_approx(render.iso(p))
	var along := d*float(asset.length_m)/8
	var across := d.orthogonal()*float(asset.width_m)/8
	var body := PackedVector2Array([p-along-across,p+along-across,p+along+across,p-along+across])
	var rear := -INF
	var front := -INF
	var overlaps := 0
	var shared := false
	for piece in render.elevated.decks:
		var ids: Array = piece.road.get("source_ids",[piece.road.get("parcel_id",-1)])
		if not ids.has(owner.parcel_id) or Geometry2D.intersect_polygons(piece.footprint,body).is_empty():continue
		if piece.front_face:
			overlaps += 1
			front=maxf(front,piece.position.y)
			shared = shared or (ids.size()>1 and str(piece.name).contains("ElevatedJunctionSide"))
		else:rear=maxf(rear,piece.position.y)
	var ordered := overlaps>0 and is_finite(rear) and rear<sprite.position.y and absf(sprite.position.y-(front-.01))<.002 and (not junction or shared)
	if not ordered:print("Layer slot: id=",vehicle.id," point=",p," rear/car/front=",[rear,sprite.position.y,front]," overlaps=",overlaps," shared=",shared)
	return ordered

func visibility_matches(game) -> bool:
	var viewport := Rect2(Vector2.ZERO,game.get_viewport_rect().size)
	for node in game.world_renderer.elevated.nodes:
		var expected: bool = not game.transit_view.underground and viewport.intersects(Rect2(game.origin+node.world_bounds.position*game.map_zoom,node.world_bounds.size*game.map_zoom))
		if node.is_visible_in_tree()!=expected:return false
	return true

func measure(multiplier: int) -> Array:
	var data := fixture(multiplier)
	if not verify(not data.is_empty(), "%dx real ramp, connected deck, elevated junction, branch and underpass build"%multiplier):return []
	var game = data.game
	if not verify(game.traffic.rebuild(game.city.roads), "%dx real traffic graph builds"%multiplier):
		game.free();return []
	var render = game.world_renderer
	var sim = game.traffic.simulation
	var asset: Dictionary = game.traffic.catalog.filter(func(item):return item.id=="car-hatch-01")[0]
	var probes := seed_fleet(game,data.roads,asset)
	if not verify(sim.vehicles.size()==FLEET_SIZE and not probes.is_empty(), "%dx real fleet of 4,800 with five layer probes, including an elevated junction connector"%multiplier):
		game.free();return []
	var fleet: Array[Dictionary] = sim.vehicles.duplicate()
	render.synchronize()
	var generation: int = render.road_generation
	var structures: int = render.structure_generation
	var mesh: ArrayMesh = render.line_mesh
	# Ground cars include a branch alongside the ramp and one directly under the deck.
	sim.vehicles.assign([probes.branch,probes.under])
	render._process(0)
	verify(render.elevated.get("vehicle_piece_visits")==0 and artwork_and_slot(game,probes.branch,asset,{},0.0) and artwork_and_slot(game,probes.under,asset,{},0.0),"%dx ground branch and underpass stay visible and visit zero raised candidates"%multiplier)
	sim.vehicles.assign(fleet)
	render._process(0)
	var visits: int = int(render.elevated.get("vehicle_piece_visits"))
	var visible: int = render.cars.values().filter(func(sprite): return sprite.is_visible_in_tree()).size()
	verify(visible==FLEET_SIZE and render.vehicle_road_lookups==FLEET_SIZE and visits>0 and visits<=64,"%dx 4,800 visible, 4,800 owner lookups, local raised candidates only (visits=%d)"%[multiplier,visits])
	var ramp: Dictionary = game.city.roads[data.roads.ramp]
	var deck: Dictionary = game.city.roads[data.roads.extension]
	verify(artwork_and_slot(game,probes.ramp,asset,ramp,5.0),"%dx ramp preserves interpolated artwork and rear/body/front order"%multiplier)
	verify(artwork_and_slot(game,probes.extension,asset,deck,10.0),"%dx merged continuation preserves projection and rear/body/front order"%multiplier)
	verify(artwork_and_slot(game,probes.connector,asset,deck,10.0,true),"%dx elevated connector uses its shared junction faces and preserves rear/body/front order"%multiplier)
	var moving: Sprite2D = render.cars[probes.ramp.id]
	var original := moving.position+moving.offset*moving.scale
	var stable := true
	for frame in range(60):
		for vehicle in fleet: vehicle.progress+=.01
		render._process(0)
		stable = stable and render.road_generation==generation and render.structure_generation==structures and render.vehicle_road_lookups==FLEET_SIZE and int(render.elevated.get("vehicle_piece_visits"))<=64 and render.elevated.get("visibility_piece_checks")==0
	verify(stable and (moving.position+moving.offset*moving.scale).distance_to(original)>.01 and render.line_mesh==mesh,"%dx 60 moved frames: bounded local work, zero fixed/structure rebuilds or repeated camera checks"%multiplier)
	game.map_zoom = 1.0
	game.origin = Vector2(640,410)-render.iso(Vector2(82,150))
	render._process(0)
	var nodes: int = render.elevated.nodes.size()
	var decks: int = render.elevated.decks.size()
	var culled_checks: int = int(render.elevated.get("visibility_piece_checks"))
	var exact := visibility_matches(game)
	game.origin += Vector2(400,-300)
	render._process(0)
	exact = exact and visibility_matches(game)
	game.transit_view.underground = true
	render._process(0)
	exact = exact and visibility_matches(game)
	game.transit_view.underground = false
	render._process(0)
	verify(exact and visibility_matches(game) and culled_checks>0 and culled_checks<nodes and render.road_generation==generation and render.structure_generation==structures,"%dx camera pan/zoom and underground toggle match full visibility oracle without a global scan or rebuild (checks=%d/%d)"%[multiplier,culled_checks,nodes])
	var road_count: int = game.city.roads.size()
	verify(game.city.add_branch_one_way(path(Vector2(10,254),Vector2(60,254)),Profile.BranchVariant.SIX_METRE).ok,"%dx real dirty road edit"%multiplier)
	render.synchronize()
	render._process(0)
	verify(render.road_generation==generation+1 and render.structure_generation==structures+1 and render.line_mesh!=mesh and visibility_matches(game),"%dx road edit really rebuilds fixed and structure work and resets visibility"%multiplier)
	if multiplier==1: replace_city(game,deck.parcel_id,asset)
	game.free()
	return [visits,road_count,decks]

func replace_city(game, id: int, asset: Dictionary) -> void:
	# Reuse the old stable ID, but only for a lower road exactly under the old deck.
	var city := City.new(265,265)
	city.config.zoning_depth = 1
	city.next_road_id = id
	var added: Dictionary = city.add_elevated_road(path(Vector2(112,150),Vector2(176,150)),PackedFloat64Array([5,5]))
	if not verify(added.ok and city.roads[0].parcel_id==id,"replacement city reuses a road ID at a different height"):return
	game.city.simulation.shutdown()
	game.city = city
	if not verify(game.traffic.rebuild(city.roads), "replacement city's actual lane graph builds"):return
	var lane := lane_for(game.traffic.network.lanes,0)
	var vehicle: Dictionary = game.traffic.simulation.spawn(asset,[lane.id],64.0)
	var render = game.world_renderer
	game.origin = Vector2(640,410)-render.iso(Vector2(128,150))
	render._process(0)
	verify(not vehicle.is_empty() and artwork_and_slot(game,vehicle,asset,city.roads[0],5.0) and visibility_matches(game) and render.elevated.decks.all(func(piece):return piece.height_m==5.0),"city replacement drops stale ownership and culling entries")

func run() -> void:
	root.size=Vector2i(1280,820)
	var once := measure(1)
	var twice := measure(2)
	verify(once.size()==3 and twice.size()==3 and once[0]>0 and once[0]==twice[0] and twice[1]==2*once[1] and twice[2]==2*once[2],"doubling actual roads and deck faces leaves local raised work unchanged")
	print("RESULT %d/%d elevated retained work checks passed"%[checks-failures,checks])
	quit(1 if failures else 0)
