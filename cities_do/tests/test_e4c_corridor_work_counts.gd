extends "res://tests/test_center_flyover_retained.gd"
## E4c §6.5 / §8.3. Run separately from the E1 owner regression. No timing.
## Copy to the imported candidate's tests/ directory, then from its repository root:
## python tools/run_dotnet.py --timeout 240 godot --headless --path cities_do --script res://tests/test_e4c_corridor_work_counts.gd

const Height = preload("res://core/road_height.gd")
const SPINE_Y := 75.0
const CROSS_X := 70.0
const CROSS_NORTH := 57.0
const CROSS_SOUTH := 93.0
const COPY_OFFSET := 160.0
const BRANCH_OFFSET := 1.75
const FLEET_ROADS := 6
const CARS_PER_LANE := 100
const MOVED_FRAMES := 60
const STEP_M := 0.01
const MAX_DECK_VISITS := 64
const EPS := 0.001

func _build_city(copies: int, tag: String):
	var city := City.new(265, 352, 42)
	city.config.zoning_depth = 1 # Keep unrelated parcel generation bounded.
	for copy in range(copies):
		var dy := float(copy) * COPY_OFFSET
		for i in range(FLEET_ROADS):
			var lane_row := 108.0 + 12.0 * i + dy
			var road: Dictionary = city.add_road(path(Vector2(10, lane_row), Vector2(230, lane_row)), "local", true, 8, false, true)
			if not road.ok:
				verify(false, tag + " isolated fleet road: " + str(road.reason))
				return null
		# Same 4-lane spine and transverse crossing as the E4c edit regression.
		# Build the crossing first so the public support planner must route around it.
		var base: int = city.roads.size()
		var cross: Dictionary = city.add_road(path(Vector2(CROSS_X, CROSS_NORTH + dy), Vector2(CROSS_X, CROSS_SOUTH + dy)), "local", true, 2, false, true)
		var y := SPINE_Y + dy
		var spine := PackedVector2Array([Vector2(30, y), Vector2(74, y), Vector2(110, y)])
		var flyover: Dictionary = city.add_center_flyover(spine, PackedFloat64Array([0, 10, 0]), true, 4)
		if not verify(cross.ok and flyover.ok and not flyover.get("warning", false) and city.roads.size() == base + 4,
			tag + " real undercrossing and three-member flyover: " + str([cross.reason, flyover.reason])):
			return null
		var deck: Dictionary = city.roads[base + 1]
		var first: Dictionary = city.roads[base + 2]
		var second: Dictionary = city.roads[base + 3]
		var pair: Array = city.junctions.filter(func(j): return j.position.distance_to(Vector2(CROSS_X, y)) < 2.0)
		if not verify(Profile.is_center_deck(deck) and deck.center_family == deck.parcel_id and deck.center_lanes == 4
			and first.center_family == deck.parcel_id and second.center_family == deck.parcel_id and first.center_role == 1 and second.center_role == 2
			and Profile.travel_direction(first) == 1 and Profile.travel_direction(second) == 1
			and not deck.piers.is_empty() and not Height.intersects_support(city.roads[base], deck)
			and city.junctions.size() == 2 * (copy + 1) and pair.size() == 2
			and pair.all(func(j): return j.arms.size() == 4 and is_zero_approx(j.height_m))
			and absf(pair[0].position.distance_to(pair[1].position) * 4.0 - 14.0) < EPS,
			tag + " supported E4c family with real 14m ground junction pair"):
			return null
	return city

func _spawn_at(sim, asset: Dictionary, road: int, world_point: Vector2) -> Dictionary:
	var lane := lane_for(sim.network.lanes, road)
	if lane.is_empty():
		return {}
	var curve: Curve3D = lane.curve
	var progress := curve.get_closest_offset(Vector3(world_point.x * 4.0, 0, world_point.y * 4.0))
	return sim.spawn(asset, [lane.id], progress)

func _crossing_route(network) -> Array:
	var entry := -1
	var exit := -1
	for lane: Dictionary in network.lanes:
		if lane.road != FLEET_ROADS or lane.direction != 1:
			continue
		if lane.start.is_equal_approx(Vector2(CROSS_X, CROSS_NORTH) * 4.0):
			entry = lane.id
		if lane.end.is_equal_approx(Vector2(CROSS_X, CROSS_SOUTH) * 4.0):
			exit = lane.id
	var route: Array = network.route(entry, exit)
	if route.size() != 5:
		return []
	for i in [1, 3]:
		var connector: Dictionary = network.lanes[route[i]]
		if connector.road >= 0 or connector.junction < 0 or connector.from != route[i - 1] or connector.to != route[i + 1]:
			return []
	if network.lanes[route[2]].road != FLEET_ROADS or network.lanes[route[1]].junction == network.lanes[route[3]].junction:
		return []
	return route

func _seed_corridor_fleet(sim, asset: Dictionary) -> Dictionary:
	var route := _crossing_route(sim.network)
	if route.is_empty():
		return {}
	var ground: Array[Dictionary] = []
	# Spawn on a legal normal approach before posing on a real connector/short lane.
	# Renderer work only: no simulation ticks or reservation shortcuts are needed.
	for index in [1, 2]:
		var car: Dictionary = sim.spawn(asset, route, 8.0)
		if car.is_empty():
			return {}
		car.lane = route[index]
		car.route_index = index
		car.progress = float(sim.network.lanes[car.lane].length) * 0.5
		ground.append(car)
	ground.append(_spawn_at(sim, asset, FLEET_ROADS + 2, Vector2(50, SPINE_Y + BRANCH_OFFSET)))
	var ramp := _spawn_at(sim, asset, FLEET_ROADS + 1, Vector2(50, SPINE_Y))
	var plateau := _spawn_at(sim, asset, FLEET_ROADS + 1, Vector2(CROSS_X, SPINE_Y))
	if ground[2].is_empty() or ramp.is_empty() or plateau.is_empty():
		return {}
	var fleet: Array[Dictionary] = sim.vehicles.duplicate()
	sim.vehicles.clear()
	var bulk_lane_count := 0
	for lane: Dictionary in sim.network.lanes:
		if lane.road < 0 or lane.road >= FLEET_ROADS:
			continue
		# Spawn checks occupancy only within this lane. Batch the real records by
		# lane, then combine them; leave the translated copy empty in the 2x case.
		for i in range(CARS_PER_LANE):
			if fleet.size() + sim.vehicles.size() == FLEET_SIZE:
				break
			if sim.spawn(asset, [lane.id], 12.0 + 8.0 * i).is_empty():
				return {}
		if not sim.vehicles.is_empty():
			bulk_lane_count += 1
		fleet.append_array(sim.vehicles)
		sim.vehicles.clear()
	if fleet.size() != FLEET_SIZE or bulk_lane_count != FLEET_ROADS * 8:
		return {}
	sim.vehicles.assign(fleet)
	return {"ground": ground, "ramp": ramp, "plateau": plateau, "fleet": fleet}

func _all_displayed(render, fleet: Array) -> bool:
	if render.cars.size() != FLEET_SIZE:
		return false
	for car: Dictionary in fleet:
		var sprite: Sprite2D = render.cars.get(car.id)
		if sprite == null or sprite.texture == null or not sprite.is_visible_in_tree():
			return false
	return true

func _pose_signature(sim, fleet: Array) -> String:
	# The second copy may change baked IDs. Compare displayed vehicles in spawn
	# order by actual pose, heading, asset and progress, not by baked lane index.
	var records := []
	for car: Dictionary in fleet:
		records.append([car.id, car.asset_id, car.progress, sim.position(car), sim.heading(car)])
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(records))
	return digest.finish().hex_encode()

func _art_origin(sprite: Sprite2D) -> Vector2:
	return sprite.position + sprite.offset * sprite.scale

func _corridor_work(copies: int) -> Dictionary:
	var tag := "%dx E4c" % copies
	var city = _build_city(copies, tag)
	if city == null:
		return {}
	var game = scene_for(city)
	if not verify(game.traffic.rebuild(city.roads) and game.traffic.network.junctions.size() == 2 * copies,
		tag + " production traffic graph with both junctions per corridor"):
		game.free()
		return {}
	var sim = game.traffic.simulation
	sim.paused = true
	var assets: Array = game.traffic.catalog.filter(func(item): return item.id == "car-hatch-01")
	var seeded: Dictionary = _seed_corridor_fleet(sim, assets[0]) if assets.size() == 1 else {}
	if not verify(not seeded.is_empty(), tag + " 4,800 real spawn records including ramp, plateau, branch, undercrossing and connector"):
		game.free()
		return {}
	var asset: Dictionary = assets[0]
	var fleet: Array = seeded.fleet
	var render = game.world_renderer
	var deck: Dictionary = city.roads[FLEET_ROADS + 1]
	var under: Vector2 = sim.position(seeded.ground[1]) / 4.0
	verify(absf(under.y - SPINE_Y) < EPS and absf(under.x - CROSS_X) < float(deck.width) / 2.0
		and is_equal_approx(Height.height_at(deck, under), 10.0), tag + " short ground lane is physically under the +10m plateau")

	render.synchronize()
	var road_gen: int = render.road_generation
	var structure_gen: int = render.structure_generation
	var mesh: ArrayMesh = render.line_mesh
	var counts := PackedInt32Array([city.roads.size(), sim.network.lanes.size(), city.junctions.size(), render.elevated.decks.size(), render.elevated.nodes.size()])
	verify(mesh != null and counts[3] > 0 and counts[4] > counts[3], tag + " retained line mesh, deck faces and other structure nodes")
	sim.vehicles.assign(seeded.ground)
	render._process(0.0)
	verify(render.vehicle_road_lookups == seeded.ground.size() and render.elevated.vehicle_piece_visits == 0
		and seeded.ground.all(func(car): return artwork_and_slot(game, car, asset, {}, 0.0)),
		tag + " ground branch, undercrossing and real connector stay visible at 0m with zero deck candidate visits")

	sim.vehicles.assign(fleet)
	render.synchronize() # The warmed retained path must not rebuild even when explicitly synchronized.
	render._process(0.0)
	var lookups: int = render.vehicle_road_lookups
	var visits: int = render.elevated.vehicle_piece_visits
	verify(_all_displayed(render, fleet) and lookups > 0 and lookups <= FLEET_SIZE and visits > 0 and visits <= MAX_DECK_VISITS
		and render.road_generation == road_gen and render.structure_generation == structure_gen and render.line_mesh == mesh,
		"%s 4,800 visible, %d owner lookups, %d local deck visits, no rebuild" % [tag, lookups, visits])
	verify(artwork_and_slot(game, seeded.ramp, asset, deck, 5.0), tag + " actual ramp sprite has its interpolated 5m lift and deck sort slot")
	verify(artwork_and_slot(game, seeded.plateau, asset, deck, 10.0), tag + " actual plateau sprite has its 10m lift and deck sort slot")
	var pose_before := _pose_signature(sim, fleet)
	var ramp_sprite: Sprite2D = render.cars.get(seeded.ramp.id)
	var work := PackedInt32Array([lookups, visits])
	var bad_frame := 0
	if ramp_sprite != null:
		for frame in range(1, MOVED_FRAMES + 1):
			var before := _art_origin(ramp_sprite)
			for car: Dictionary in fleet:
				car.progress += STEP_M
			render._process(0.0)
			lookups = render.vehicle_road_lookups
			visits = render.elevated.vehicle_piece_visits
			work.append(lookups)
			work.append(visits)
			if bad_frame == 0 and not (_all_displayed(render, fleet) and lookups > 0 and lookups <= FLEET_SIZE and visits > 0 and visits <= MAX_DECK_VISITS
				and render.road_generation == road_gen and render.structure_generation == structure_gen and render.line_mesh == mesh
				and render.elevated.visibility_piece_checks == 0 and _art_origin(ramp_sprite).distance_to(before) > EPS):
				bad_frame = frame
	verify(work.size() == 2 * (MOVED_FRAMES + 1) and bad_frame == 0,
		"%s 60 moved frames with all sprites visible, bounded work and zero fixed/structure rebuilds (first bad frame: %d)" % [tag, bad_frame])
	var pose_after := _pose_signature(sim, fleet)

	# Positive control: an actual edit appends an elevated road far from the fleet;
	# existing baked lane owner indices still address the same authored records.
	var dirty: Dictionary = city.add_elevated_road(path(Vector2(156, 216), Vector2(216, 216)), PackedFloat64Array([10, 10]))
	verify(dirty.ok and city.roads.size() == counts[0] + 1, tag + " real elevated road edit: " + str(dirty.reason))
	render.synchronize()
	render.synchronize()
	verify(render.road_generation == road_gen + 1 and render.structure_generation == structure_gen + 1 and render.line_mesh != mesh
		and render.elevated.decks.size() > counts[3], tag + " dirty edit rebuilds each layer exactly once and adds deck faces")
	game.free()
	return {"counts": counts, "work": work, "before": pose_before, "after": pose_after}

func run() -> void:
	root.size = Vector2i(1280, 820)
	var once := _corridor_work(1)
	var twice := _corridor_work(2)
	var complete := not once.is_empty() and not twice.is_empty()
	var doubled := complete
	if complete:
		for i in range(once.counts.size()):
			doubled = doubled and twice.counts[i] == 2 * once.counts[i]
	verify(doubled, "2x actual authored roads, baked lanes/junctions, retained deck faces and structure nodes")
	verify(complete and once.before == twice.before and once.after == twice.after and once.before != once.after,
		"same 4,800 vehicles and poses in both cities before and after movement")
	verify(complete and once.work == twice.work and once.work.size() == 2 * (MOVED_FRAMES + 1),
		"doubling geometry adds zero owner lookups or deck candidate visits at any of the same 61 poses")
	print("RESULT %d/%d E4c corridor work checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
