extends SceneTree
## Real scheduled operations and baked roads. Seed only the contact poses in the veto case.
const City = preload("res://core/city_model.gd")
const Operations = preload("res://core/transit_operations.gd")
const BusNetwork = preload("res://core/scheduled_bus_network.gd")
const BusSimulation = preload("res://core/scheduled_bus_simulation.gd")
const CarSimulation = preload("res://core/traffic_simulation.gd")
const STEP := 1.0 / 30.0
const EPS := 0.005
var checks := 0
var failed := 0
var asset: Dictionary

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failed += 1
	print("BUS_PAIR %s %s" % ["PASS" if ok else "FAIL", message])
	return ok

func _city(first_x: float, lanes: int):
	var city := City.new(100, 100, 42)
	city.population_enabled = false
	city.happiness_enabled = false
	var paths := [[Vector2(10, 40), Vector2(90, 40)], [Vector2(90, 40), Vector2(90, 80)],
		[Vector2(90, 80), Vector2(10, 80)], [Vector2(10, 80), Vector2(10, 40)]]
	for x: float in [first_x, first_x + 3.5]:
		paths.append([Vector2(x, 20), Vector2(x, 60)])
	for path: Array in paths:
		var built: Dictionary = city.add_road(PackedVector2Array(path), "local", true, lanes, false, true)
		if not _check(built.ok, "public road %s (%s)" % [path, built.get("reason", "")]):
			return null
	return city

func _bus_for(state: Dictionary, line_id: int) -> Dictionary:
	for bus: Dictionary in state.vehicles:
		if bus.line_id == line_id:
			return bus
	return {}

func _late_dispatch() -> void:
	var city = _city(39.975, 3)
	if city == null: return
	var curb: float = city.RoadProfile.asphalt_width(city.roads[0]) / 2.0
	var stops: Array[int] = []
	for x: float in [22.0, 50.0, 60.0, 70.0]:
		var placed: Dictionary = city.public_facilities.place("bus-stop-01", Vector2(x, 40.0 + curb))
		if not _check(placed.ok, "public stop %.2f (%s)" % [x, placed.get("reason", "")]): return
		stops.append(placed.record.id)
	if not _check(city.create_transit_line("bus", [stops[0], stops[2]], {"dwell_seconds": 1.0}).ok,
		"scheduled owner line created"):
		return
	var ops := Operations.new()
	ops.advance(city, STEP)
	var front_entered := false
	var exit_id := -1
	var second := -1
	for tick in range(600):
		var owner := _bus_for(city.transit_state.bus, 1)
		if owner.has("short_pair"):
			var start: int = owner.short_pair.approach
			var approach: Dictionary = ops.bus_network.lanes[owner.route[start]]
			second = owner.short_pair.second
			exit_id = owner.route[(start + 4) % owner.route.size()]
			front_entered = owner.route_index != start or owner.progress + owner.length / 2.0 >= approach.length
			if front_entered and city.transit_state.bus.reservations.get(second, -1) == owner.id:
				break
		ops.advance(city, STEP)
	if not _check(front_entered and exit_id >= 0, "scheduled owner nose enters with pair reserved before new dispatch"):
		return
	var near_stop: Dictionary = ops.bus_network.stops[stops[1]]
	var far_stop: Dictionary = ops.bus_network.stops[stops[3]]
	var owner := _bus_for(city.transit_state.bus, 1)
	if not _check(near_stop.lane == exit_id and far_stop.lane == exit_id and absf(near_stop.progress - 20.10) < EPS
		and absf(owner.length - 10.8) < EPS and absf(owner.min_gap - 2.0) < EPS,
		"stock bus, actual same-exit berths at %.3fm / %.3fm" % [near_stop.progress, far_stop.progress]):
		return
	var rear_limit: float = owner.length / 2.0 + owner.min_gap
	var blocked_limit: float = near_stop.progress - owner.length - owner.min_gap
	_check(absf(blocked_limit - 7.30) < EPS and absf(rear_limit - 7.40) < EPS,
		"near dispatch would cap the owner at %.3fm before %.3fm rear clearance" % [blocked_limit, rear_limit])
	var near_plan: Dictionary = ops.bus_network.line_plan([stops[1], stops[0]])
	var far_plan: Dictionary = ops.bus_network.line_plan([stops[3], stops[0]])
	if not _check(near_plan.ok and far_plan.ok, "both late berths have live returning plans"):
		return
	# Isolate receiving-space admission from the legacy spawn rule rejecting
	# a cyclic route whose final lane is a connector. These real route prefixes
	# start at the unchanged plans' first stops; spawn_line calls this same spawn.
	var sim: BusSimulation = ops.bus_simulation
	var near := sim.spawn(asset, near_plan.route.slice(0, 1), near_stop.progress)
	_check(near.is_empty(),
		"late dispatch waits when its body would consume committed receiving space")
	var far := sim.spawn(asset, far_plan.route.slice(0, 1), far_stop.progress)
	_check(not far.is_empty(), "farther berth on the same exit can dispatch immediately")
	for waiting_bus: Dictionary in [near, far]:
		if not waiting_bus.is_empty(): waiting_bus.max_speed = 0.0
	owner = sim.vehicles[0]
	var safe := true
	var protected := true
	var clear := false
	var max_exit_progress := 0.0
	for tick in range(600):
		for i in range(sim.vehicles.size()):
			for j in range(i + 1, sim.vehicles.size()):
				safe = safe and not sim.overlaps(sim.vehicles[i], sim.vehicles[j])
		if owner.lane == exit_id:
			max_exit_progress = maxf(max_exit_progress, owner.progress)
			clear = clear or (owner.progress >= rear_limit and not sim.reservations.has(second))
		if not near.is_empty() and max_exit_progress < rear_limit:
			protected = false
		if clear and not near.is_empty(): break
		if near.is_empty():
			near = sim.spawn(asset, near_plan.route.slice(0, 1), near_stop.progress)
			if not near.is_empty(): near.max_speed = 0.0
		sim.update(STEP)
	_check(clear, "committed owner clears the second grant (exit progress %.3fm)" % max_exit_progress)
	_check(not near.is_empty() and protected, "near berth dispatches only after accepted rear clearance")
	_check(safe, "dispatch and discharge never overlap bus bodies")

func _veto() -> void:
	var city = _city(40.0, 2)
	if city == null: return
	var network := BusNetwork.new()
	if not _check(network.build_city(city), "veto has real baked lanes"):
		return
	var approach: Dictionary = {}
	var exit: Dictionary = {}
	for lane: Dictionary in network.lanes:
		if lane.road == 0 and lane.direction == 1:
			if lane.end.is_equal_approx(Vector2(160, 160)): approach = lane
			if lane.start.is_equal_approx(Vector2(174, 160)): exit = lane
	if not _check(not approach.is_empty() and not exit.is_empty(), "veto resolves directed approach and exit"):
		return
	var route := network.route(approach.id, exit.id)
	if not _check(route.size() == 5, "veto uses both connectors"):
		return
	var first: Dictionary = network.lanes[route[1]]
	var second: Dictionary = network.lanes[route[3]]
	var start: float = approach.length - float(asset.length_m) / 2.0 - 0.20
	var sim := BusSimulation.new(network)
	var owner := sim.spawn(asset, route, start)
	if not _check(not owner.is_empty(), "veto owner spawned before first entry"):
		return
	owner.speed = asset.max_speed
	# Obtain the exact no-body-guard proposal from the base simulator on this
	# graph, then position a stationary body on another real connector to veto it.
	var unguarded := CarSimulation.new(network)
	unguarded.vehicles.append(owner.duplicate(true))
	unguarded.update(STEP)
	var proposed := unguarded.vehicles[0]
	if not _check(unguarded.reservations == {first.junction: owner.id, second.junction: owner.id}
		and proposed.progress > start, "without body interference this tick proposes movement with both grants"):
		return
	var blocker: Dictionary = {}
	for id: int in approach.next:
		if id == first.id: continue
		var alternate: Dictionary = network.lanes[id]
		if alternate.get("junction", -1) != first.junction: continue
		var alternate_route := [approach.id, id, alternate.to]
		var parking := BusSimulation.new(network)
		var candidate := parking.spawn(asset, alternate_route, start)
		candidate.route_index = 1
		candidate.lane = id
		candidate.max_speed = 0.0
		# This contact state is explicit (not admission evidence): the blocker
		# occupies an alternate baked path, with no artificial lane or reservation.
		for sample in range(ceili(alternate.length / 0.025)):
			candidate.progress = sample * 0.025
			if not sim.overlaps(owner, candidate) and sim.overlaps(proposed, candidate):
				blocker = candidate
				break
		if not blocker.is_empty(): break
	if not _check(not blocker.is_empty(), "real polygons are disjoint at rest but overlap on the proposal"):
		return
	blocker.id = sim.next_id
	sim.next_id += 1
	sim.vehicles.append(blocker)
	var old_distance: float = owner.distance
	var old_clearing: Dictionary = owner.clearing.duplicate(true)
	sim.update(STEP)
	_check(is_equal_approx(float(owner.progress), start) and owner.distance == old_distance and owner.clearing == old_clearing
		and owner.speed == 0.0 and not sim.overlaps(owner, blocker), "real body guard vetoes the tentative move")
	_check(sim.reservations == {first.junction: owner.id, second.junction: owner.id} and owner.has("short_pair"),
		"accepted state retains both scalar grants and its pair token after veto")
	var resumed := BusSimulation.new(network)
	resumed.restore(sim.checkpoint())
	resumed.update(STEP)
	_check(resumed.reservations == {first.junction: owner.id, second.junction: owner.id},
		"next arbitration after checkpoint cannot split the vetoed pair")
	resumed.signals[second.id] = {"progress": 0.0, "red": true}
	resumed.update(STEP)
	_check(resumed.reservations.is_empty() and not resumed.vehicles[0].has("short_pair"),
		"outside a real red downstream cancels both grants together")

func _run() -> void:
	for item: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json")).vehicles:
		if item.id == "bus-city-01":
			asset = item.duplicate(true)
			asset.max_speed = 12.0
			break
	if _check(not asset.is_empty(), "stock bus catalog loaded"):
		var cases := OS.get_cmdline_user_args()
		if cases.is_empty() or "dispatch" in cases or "both" in cases: _late_dispatch()
		if cases.is_empty() or "veto" in cases or "both" in cases: _veto()
	print("BUS_PAIR RESULT checks=%d failed=%d" % [checks, failed])
	quit(int(failed > 0))
