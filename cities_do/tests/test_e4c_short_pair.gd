extends SceneTree
## Production CityModel -> TrafficNetwork -> TrafficSimulation. No E4c APIs or fake lanes.
const City = preload("res://core/city_model.gd")
const Network = preload("res://core/traffic_network.gd")
const Simulation = preload("res://core/traffic_simulation.gd")
const METRES := 4.0
const EPS := 0.005 # metres (or cells for the exact authored node lookup)
const STEP := 1.0 / 30.0
const MAX_TICKS := 45 * 30
const HOLD_TICKS := 12 * 30
const APPROACH_M := 12.0
const HOST_Y := 40.0
const FIRST_X := 40.0
const WEST := Vector2(12, HOST_Y)
const EAST := Vector2(72, HOST_Y)
var asset: Dictionary
var setup_failures := 0
var control_failures := 0
var behavior_failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, group: String, label: String) -> bool:
	checks += 1
	print("E4C %s %s %s" % [group, "PASS" if ok else "FAIL", label])
	if not ok:
		match group:
			"SETUP": setup_failures += 1
			"CONTROL": control_failures += 1
			"PAIR": behavior_failures += 1
	return ok

func _cross(x: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, 20), Vector2(x, 60)])

func _build_base(city, tag: String) -> bool:
	for points: PackedVector2Array in [PackedVector2Array([WEST, EAST]), _cross(FIRST_X)]:
		var built: Dictionary = city.add_road(points, "local", true, 2, false, true)
		if not _check(built.ok, "SETUP", "%s public construction: %s" % [tag, built.get("reason", "")]):
			return false
	return true

func _road_state(city) -> Array:
	return [var_to_bytes(city.roads), city.road_topology_revision, city.next_road_id, city.funds]

func _below_boundary() -> void:
	var city := City.new(100, 100, 42)
	if not _build_base(city, "13.99m"):
		return
	var before := _road_state(city)
	var points := _cross(FIRST_X + 13.99 / METRES)
	for commit in [false, true]:
		var result: Dictionary = city.add_road(points, "local", commit, 2, false, true)
		_check(not result.ok and "14m" in result.get("reason", "") and _road_state(city) == before
			and city.junctions.size() == 1, "CONTROL", "13.99m rejected by spacing, no mutation (commit=%s)" % commit)

func _pair(gap_m: float, short: bool) -> Dictionary:
	var label := "%.2fm" % gap_m
	var city := City.new(100, 100, 42)
	if not _build_base(city, label):
		return {}
	var second_x := FIRST_X + gap_m / METRES
	var points := _cross(second_x)
	var before := _road_state(city)
	var preview: Dictionary = city.add_road(points, "local", false, 2, false, true)
	if not _check(preview.ok and _road_state(city) == before, "SETUP", "%s pure public preview (%s)" % [label, preview.get("reason", "")]):
		return {}
	var built: Dictionary = city.add_road(points, "local", true, 2, false, true)
	if not _check(built.ok and city.roads.size() == 3 and city.road_topology_revision == before[1] + 1
		and var_to_bytes(city.roads.slice(0, 2)) == before[0] and city.roads[2].points == points
		and city.roads.all(func(road): return road.lanes == 2 and absf(float(road.width) * METRES - 12.0) < EPS)
		and city.junctions.size() == 2, "SETUP", "%s real three-road commit/two junctions (%s)" % [label, built.get("reason", "")]):
		return {}
	var network := Network.new()
	if not _check(network.build(city.roads) and network.junctions.size() == 2, "SETUP", label + " real traffic graph"):
		return {}
	var left := Vector2(FIRST_X, HOST_Y)
	var right := Vector2(second_x, HOST_Y)
	var left_id := _junction_at(network, left)
	var right_id := _junction_at(network, right)
	if not _check(left_id >= 0 and right_id >= 0 and left_id != right_id, "SETUP", label + " two distinct four-arm ground nodes at authored centres"):
		return {}
	var east := _route(network, [WEST, left, right, EAST], 0, [left_id, right_id])
	var west := _route(network, [EAST, right, left, WEST], 0, [right_id, left_id])
	if not _check(east.size() == 5 and west.size() == 5 and east[2] != west[2], "SETUP", label + " two opposite A* paths each using both real connectors"):
		return {}
	for route in [east, west]:
		var sim := Simulation.new(network)
		var car: Dictionary = _spawn(sim, route)
		if not _check(not car.is_empty() and car.asset_id == "car-hatch-01"
			and absf(car.length - 3.65) < EPS and absf(car.min_gap - 2.0) < EPS,
			"SETUP", label + " stock hatchback fits its approach with unchanged 2m gap"):
			return {}
		var middle: Dictionary = network.lanes[route[2]]
		var authored_gap: float = middle.start.distance_to(middle.end)
		# Existing _receiving_clear starts with lane length minus one gap, then
		# requires body length plus two gaps. Classify the actual baked lane.
		var empty_limit: float = car.length + 3.0 * car.min_gap
		var exit_lane: Dictionary = network.lanes[route[-1]]
		if not _check(absf(authored_gap - gap_m) < EPS and middle.length > 0.0
			and (middle.length < empty_limit) == short and exit_lane.length > empty_limit,
			"SETUP", "%s chainage: %.3fm; middle: %.3fm; empty-exit limit: %.3fm" % [label, authored_gap, middle.length, empty_limit]):
			return {}
	return {"network": network, "east": east, "west": west, "second_x": second_x, "second_id": right_id}

func _junction_at(network, p: Vector2) -> int:
	for junction: Dictionary in network.junctions:
		if junction.arms.size() == 4 and absf(junction.height_m) < EPS and junction.position.distance_to(p) < EPS:
			return int(junction.id)
	return -1

func _route(network, nodes: Array, road: int, junction_ids: Array) -> Array:
	# Resolve approach/exit from authored centreline endpoints, not lane IDs.
	var ordinary: Array[int] = []
	for i in range(nodes.size() - 1):
		var matches: Array[int] = []
		for lane: Dictionary in network.lanes:
			if lane.road == road and lane.junction < 0 and lane.start.distance_to(nodes[i] * METRES) < EPS \
				and lane.end.distance_to(nodes[i + 1] * METRES) < EPS:
				matches.append(lane.id)
		if matches.size() != 1:
			return []
		ordinary.append(matches[0])
	var route: Array = network.route(ordinary[0], ordinary[-1])
	if route.size() != ordinary.size() + junction_ids.size():
		return []
	for i in range(ordinary.size()):
		if route[i * 2] != ordinary[i]:
			return []
		if i < junction_ids.size():
			var connector: Dictionary = network.lanes[route[i * 2 + 1]]
			if connector.junction != junction_ids[i] or connector.from != ordinary[i] or connector.to != ordinary[i + 1]:
				return []
	return route

func _spawn(sim, route: Array, approach_m: float = APPROACH_M) -> Dictionary:
	return sim.spawn(asset, route, sim.network.lanes[route[0]].length - approach_m)

func _watch(sim, car: Dictionary, route: Array, atomic: bool) -> Dictionary:
	var edges := PackedFloat64Array([0.0])
	for lane_id: int in route:
		edges.append(edges[-1] + float(sim.network.lanes[lane_id].length))
	var approach: Dictionary = sim.network.lanes[route[0]]
	var axis := Vector2.RIGHT if approach.end.x > approach.start.x else Vector2.LEFT
	return {"car": car, "route": route, "edges": edges, "atomic": atomic,
		"axis": axis, "origin": Vector2(approach.start.x, HOST_Y * METRES + axis.x * 1.75),
		"first": sim.network.lanes[route[1]].junction, "second": sim.network.lanes[route[3]].junction,
		"grant_tick": -1, "entry_tick": -1, "exit_tick": -1, "visited": {}, "last": car.progress,
		"valid": true, "all_or_none": true, "protected": true, "rolling": true, "in_pair": false,
		"protected_after_first": false, "protected_after_second": false}

func _observe(sim, w: Dictionary, tick: int) -> void:
	var car: Dictionary = w.car
	var index := int(car.route_index)
	if index < 0 or index >= w.route.size() or car.lane != w.route[index]:
		w.valid = false
		return
	w.visited[index] = true
	var s: float = w.edges[index] + car.progress
	var half: float = car.length * 0.5
	var clearance: float = half + car.min_gap
	var first_start: float = w.edges[1]
	var first_end: float = w.edges[2]
	var second_end: float = w.edges[4]
	var first_owned: bool = sim.reservations.get(w.first, -1) == car.id
	var second_owned: bool = sim.reservations.get(w.second, -1) == car.id
	var front_in := s + half >= first_start
	var clears_second := s >= second_end + clearance
	w.in_pair = front_in and not clears_second
	# Use geometric route chainage, not sim.clearing or a candidate pair flag.
	var pose: Vector2 = sim.position(car)
	var heading: Vector2 = sim.heading(car)
	var expected_pose: Vector2 = w.origin + w.axis * s
	w.valid = w.valid and is_finite(s) and is_finite(car.speed) and pose.is_finite() \
		and car.speed >= 0.0 and car.speed <= car.max_speed + EPS \
		and car.progress >= -EPS and car.progress <= sim.network.lanes[car.lane].length + EPS \
		and s >= w.last - EPS and s - w.last <= car.speed * STEP + EPS \
		and pose.distance_to(expected_pose) < 0.03 and heading.dot(w.axis) > 0.99
	w.last = s
	if not w.atomic:
		return
	if w.grant_tick < 0 and (first_owned or second_owned):
		w.grant_tick = tick
	if w.entry_tick < 0:
		w.all_or_none = w.all_or_none and first_owned == second_owned
		if front_in:
			w.entry_tick = tick
			w.all_or_none = w.all_or_none and first_owned and second_owned
	if w.in_pair:
		w.rolling = w.rolling and car.speed >= 0.05
		w.protected = w.protected and second_owned and (s >= first_end + clearance - EPS or first_owned)
		w.protected_after_first = w.protected_after_first or (s > first_end + EPS and s < first_end + clearance - EPS and first_owned and second_owned)
		w.protected_after_second = w.protected_after_second or (s > second_end + EPS and s < second_end + clearance - EPS and second_owned)
	elif front_in and clears_second and w.exit_tick < 0:
		w.exit_tick = tick

func _owns_neither(sim, w: Dictionary) -> bool:
	return sim.reservations.get(w.first, -1) != w.car.id and sim.reservations.get(w.second, -1) != w.car.id

func _drive(sim, watchers: Array) -> bool:
	var exclusive := true
	for tick in range(1, MAX_TICKS + 1):
		sim.update(STEP)
		var inside := 0
		for w: Dictionary in watchers:
			_observe(sim, w, tick)
			inside += int(w.in_pair)
		exclusive = exclusive and inside <= 1
		if watchers.all(func(w): return w.car.arrived):
			break
	return exclusive

func _through(sim, w: Dictionary, label: String, require_arrival: bool = true) -> void:
	_check(w.exit_tick >= 0 and w.visited.size() == 5 and w.car.lane == w.route[-1]
		and (w.car.arrived or not require_arrival), "PAIR", label + " traverses both connectors and exits")
	_check(w.grant_tick >= 0 and w.entry_tick >= 0 and w.grant_tick <= w.entry_tick and w.all_or_none,
		"PAIR", label + " all-or-none admission before front entry")
	# These are only meaningful after entry, not vacuous passes for a blocked car.
	if w.entry_tick >= 0:
		_check(w.protected and w.protected_after_first and w.protected_after_second,
			"PAIR", label + " both needed reservations survive rear clearance")
		_check(w.rolling, "PAIR", label + " never stops in the pair")
	if w.exit_tick >= 0:
		_check(_owns_neither(sim, w), "PAIR", label + " releases both after rear clearance")
	_check(w.valid, "PAIR", label + " legal physical poses and continuous movement")
	print("E4C TRACE %s grant=%d front_entry=%d final_rear_clear=%d lane_indices=%s" % [label, w.grant_tick, w.entry_tick, w.exit_tick, w.visited.keys()])

func _solo(pair: Dictionary, direction: String, atomic: bool) -> int:
	var sim := Simulation.new(pair.network)
	var route: Array = pair[direction]
	var car := _spawn(sim, route)
	if not _check(not car.is_empty(), "SETUP", direction + " solo spawn"):
		return -1
	var w := _watch(sim, car, route, atomic)
	_drive(sim, [w])
	if atomic:
		_through(sim, w, "14m solo " + direction)
		if w.entry_tick < 0:
			var nose_gap: float = w.edges[1] - car.progress - car.length * 0.5
			var stopped_at_first: bool = car.lane == route[0] and car.speed < 0.05 and absf(nose_gap - car.min_gap) < 0.04
			print("E4C DIAG 14m solo %s stopped_at_unreserved_first=%s nose_gap_m=%.3f speed_mps=%.3f" % [direction,
				stopped_at_first and w.grant_tick < 0 and _owns_neither(sim, w), nose_gap, car.speed])
	else:
		_check(w.valid and w.visited.size() == 5 and car.arrived and sim.reservations.is_empty(),
			"CONTROL", "28m sufficient-storage pair discharges " + direction)
	return int(w.entry_tick)

func _opposing(pair: Dictionary, solo: Dictionary, first: String, second: String) -> void:
	var sim := Simulation.new(pair.network)
	var watchers: Array[Dictionary] = []
	for direction in [first, second]:
		var route: Array = pair[direction]
		var car := _spawn(sim, route)
		if not _check(not car.is_empty(), "SETUP", "simultaneous " + direction + " spawn"):
			return
		watchers.append(_watch(sim, car, route, true))
	var label := "14m concurrent demand (%s first ID)" % first
	var exclusive := _drive(sim, watchers)
	_check(exclusive, "PAIR", label + " no overlapping protected traversals")
	var ratios: Array[float] = []
	for i in range(2):
		var direction: String = [first, second][i]
		var w: Dictionary = watchers[i]
		_through(sim, w, label + " " + direction)
		if w.entry_tick > 0 and solo[direction] > 0:
			ratios.append(float(w.entry_tick) / float(solo[direction]))
		print("E4C WAIT %s %s solo_entry_ticks=%d concurrent_entry_ticks=%d" % [label, direction, solo[direction], w.entry_tick])
	if ratios.size() == 2:
		var worst := maxf(ratios[0], ratios[1])
		print("E4C WAIT %s max_ratio=%.3fx over_2x=%s" % [label, worst, worst > 2.0])
	else:
		print("E4C WAIT %s max_ratio=unavailable (at least one non-entry)" % label)

func _blocked_exit(pair: Dictionary, direction: String) -> void:
	var sim := Simulation.new(pair.network)
	var route: Array = pair[direction]
	var exit_lane: int = route[-1]
	var blocker: Dictionary = sim.spawn(asset, [exit_lane], 4.0)
	var car := _spawn(sim, route)
	if not _check(not blocker.is_empty() and not car.is_empty(), "SETUP", direction + " real downstream blocker and approach car"):
		return
	var w := _watch(sim, car, route, true)
	var room_needed: float = car.length + 2.0 * car.min_gap
	var held := true
	sim.signals[exit_lane] = {"progress": 9.0, "red": true}
	for tick in range(1, HOLD_TICKS + 1):
		sim.update(STEP)
		_observe(sim, w, tick)
		held = held and _owns_neither(sim, w) and not w.in_pair and car.lane == route[0]
	if not _check(blocker.lane == exit_lane and blocker.speed < 0.05 and blocker.progress > 4.0
		and blocker.progress - blocker.length * 0.5 < room_needed, "CONTROL", direction + " actual stopped blocker removes final receiving room"):
		return
	var bumper_distance: float = w.edges[1] - car.progress - car.length * 0.5
	_check(held and car.speed < 0.05 and bumper_distance >= -EPS and bumper_distance <= car.min_gap + 0.04,
		"PAIR", direction + " blocked at first junction, no partial reservation")
	sim.signals[exit_lane].red = false
	var no_early_grant := true
	for tick in range(HOLD_TICKS + 1, HOLD_TICKS + MAX_TICKS + 1):
		var old_room: float = blocker.progress - blocker.length * 0.5
		sim.update(STEP)
		_observe(sim, w, tick)
		if old_room < room_needed - EPS:
			no_early_grant = no_early_grant and _owns_neither(sim, w) and car.lane == route[0]
		if w.exit_tick >= 0 and _owns_neither(sim, w):
			break
	_check(no_early_grant, "PAIR", direction + " waits for real downstream body clearance after green")
	_through(sim, w, direction + " receiver released by signal", false)

func _occupied_second(pair: Dictionary, atomic: bool) -> void:
	var sim := Simulation.new(pair.network)
	var label := "14m" if atomic else "28m"
	var x: float = pair.second_x
	var cross_route := _route(pair.network, [Vector2(x, 20), Vector2(x, HOST_Y), Vector2(x, 60)], 2, [pair.second_id])
	if not _check(cross_route.size() == 3, "SETUP", label + " perpendicular A* route uses second junction only"):
		return
	var rival := _spawn(sim, cross_route, 4.0)
	if not _check(not rival.is_empty(), "SETUP", label + " spawn second-junction rival"):
		return
	sim.update(STEP)
	if not _check(sim.reservations.get(pair.second_id, -1) == rival.id, "CONTROL", label + " rival acquired downstream junction through ordinary sim"):
		return
	var car := _spawn(sim, pair.east)
	if not _check(not car.is_empty(), "SETUP", label + " spawn contender while second junction is owned"):
		return
	var w := _watch(sim, car, pair.east, atomic)
	var withheld := true
	var rival_safe := true
	var independent_grant := false
	var independent_safe := true
	var conflict_ticks := 0
	var rival_rear_ticks := 0
	var approach_length: float = pair.network.lanes[cross_route[0]].length
	var junction_length: float = pair.network.lanes[cross_route[1]].length
	for tick in range(1, MAX_TICKS + 1):
		sim.update(STEP)
		_observe(sim, w, tick)
		var rival_s: float = rival.progress + (approach_length if rival.route_index > 0 else 0.0)
		if rival.route_index == 2:
			rival_s += junction_length
		var rival_owned: bool = sim.reservations.get(pair.second_id, -1) == rival.id
		var rival_in: bool = rival_s + rival.length * 0.5 >= approach_length \
			and rival_s < approach_length + junction_length + rival.length * 0.5 + rival.min_gap - EPS
		if rival_in:
			rival_safe = rival_safe and rival_owned
			rival_rear_ticks += int(rival.route_index == 2)
		if rival_owned or rival_in:
			conflict_ticks += 1
			withheld = withheld and _owns_neither(sim, w) and not w.in_pair
			independent_grant = independent_grant or sim.reservations.get(w.first, -1) == car.id
			var nose_m: float = w.edges[car.route_index] + car.progress + car.length * 0.5
			independent_safe = independent_safe and nose_m < w.edges[3]
		if car.arrived and rival.arrived:
			break
	_check(rival.arrived and conflict_ticks > 0 and rival_safe and rival_rear_ticks > 0,
		"CONTROL", label + " real cross movement drains with ordinary rear protection")
	if atomic:
		_check(withheld, "PAIR", "occupied second junction never grants the first alone")
		_through(sim, w, "second junction released by crossing rival")
	else:
		_check(independent_grant and independent_safe, "CONTROL", "28m ample lane keeps independent first reservation while second is occupied")
		_check(w.valid and w.visited.size() == 5 and car.arrived and sim.reservations.is_empty(),
			"CONTROL", "28m contended pair remains traversable and releases reservations")

func _catalog_asset() -> Dictionary:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json"))
	if not catalog is Dictionary or not catalog.get("vehicles") is Array:
		return {}
	for entry: Dictionary in catalog.vehicles:
		if entry.get("id") == "car-hatch-01" and is_equal_approx(float(entry.get("length_m", 0.0)), 3.65):
			return entry
	return {}

func _terminal_and_wrong_direction(pair: Dictionary) -> void:
	var sim := Simulation.new(pair.network)
	var reversed := [pair.east[0], pair.east[1], pair.west[2], pair.west[3], pair.west[4]]
	_check(_spawn(sim, reversed).is_empty(), "CONTROL", "opposite middle lane is not a route continuation")
	var route: Array = pair.east.slice(0, 3)
	var car := _spawn(sim, route)
	if not _check(not car.is_empty(), "SETUP", "legal route terminates on the short middle lane"):
		return
	var withheld := true
	for tick in range(HOLD_TICKS):
		sim.update(STEP)
		withheld = withheld and sim.reservations.is_empty() and car.route_index == 0
	_check(withheld and car.speed < 0.05, "PAIR", "terminal short lane fails closed without borrowing an off-route connector")

func _short_chain() -> void:
	var city := City.new(100, 100, 42)
	if not _build_base(city, "three-junction chain"):
		return
	var nodes := [WEST, Vector2(FIRST_X, HOST_Y)]
	for i in [1, 2]:
		var x: float = FIRST_X + i * 14.0 / METRES
		var built: Dictionary = city.add_road(_cross(x), "local", true, 2, false, true)
		if not _check(built.ok, "SETUP", "14m chain public construction: " + str(built.get("reason", ""))):
			return
		nodes.append(Vector2(x, HOST_Y))
	nodes.append(EAST)
	var network := Network.new()
	if not _check(network.build(city.roads) and network.junctions.size() == 3, "SETUP", "real three-junction graph"):
		return
	var ids := [_junction_at(network, nodes[1]), _junction_at(network, nodes[2]), _junction_at(network, nodes[3])]
	var route := _route(network, nodes, 0, ids)
	if not _check(route.size() == 7, "SETUP", "A* route uses all three connectors"):
		return
	var sim := Simulation.new(network)
	var car := _spawn(sim, route)
	if not _check(not car.is_empty(), "SETUP", "three-junction approach spawn"):
		return
	var limit: float = car.length + 3.0 * car.min_gap
	if not _check(network.lanes[route[2]].length < limit and network.lanes[route[4]].length < limit,
		"SETUP", "both intermediate lanes are geometrically too short to receive"):
		return
	var withheld := true
	for tick in range(HOLD_TICKS):
		sim.update(STEP)
		withheld = withheld and sim.reservations.is_empty() and car.route_index == 0
	_check(withheld and car.speed < 0.05, "PAIR", "three-junction short chain fails closed outside the first connector")

func _red_after_grant(pair: Dictionary) -> void:
	var sim := Simulation.new(pair.network)
	var car := _spawn(sim, pair.east)
	if not _check(not car.is_empty(), "SETUP", "red-after-grant approach spawn"):
		return
	var w := _watch(sim, car, pair.east, true)
	sim.update(STEP)
	_observe(sim, w, 1)
	if not _check(sim.reservations.get(w.first) == car.id and sim.reservations.get(w.second) == car.id and not w.in_pair,
		"PAIR", "both grants acquired before the new red signal"):
		return
	var bridge: int = pair.east[2]
	sim.signals[bridge] = {"progress": pair.network.lanes[bridge].length * 0.5, "red": true}
	var withheld := true
	for tick in range(2, HOLD_TICKS + 1):
		sim.update(STEP)
		_observe(sim, w, tick)
		withheld = withheld and _owns_neither(sim, w) and not w.in_pair
	_check(withheld and car.speed < 0.05, "PAIR", "red on the bridge cancels both pre-entry grants and stops the car outside")
	sim.signals[bridge].red = false
	for tick in range(HOLD_TICKS + 1, HOLD_TICKS + MAX_TICKS + 1):
		sim.update(STEP)
		_observe(sim, w, tick)
		if car.arrived:
			break
	_through(sim, w, "cancelled pair reacquires after green")

func _retire_owner(pair: Dictionary) -> void:
	var sim = preload("res://core/commuter_micro.gd").new(pair.network)
	var owner := _spawn(sim, pair.east)
	var contender := _spawn(sim, pair.west)
	if not _check(not owner.is_empty() and not contender.is_empty(), "SETUP", "commuter opponents spawned"):
		return
	var w := _watch(sim, contender, pair.west, true)
	sim.update(STEP)
	if not _check(sim.reservations.get(w.first) == owner.id and sim.reservations.get(w.second) == owner.id,
		"PAIR", "commuter owns both reservations before retirement"):
		return
	sim.remove_vehicle(owner.id)
	_check(sim.reservations.is_empty() and sim.waiting.keys().all(func(key): return not str(key).begins_with(str(owner.id) + ":")),
		"PAIR", "commuter retirement releases both scalar owners and its wait record")
	_drive(sim, [w])
	_through(sim, w, "opposing commuter after retirement")

func _resume_inside_pair(pair: Dictionary) -> void:
	var BusSimulation = preload("res://core/scheduled_bus_simulation.gd")
	var sim = BusSimulation.new(pair.network)
	var car := _spawn(sim, pair.east)
	if not _check(not car.is_empty(), "SETUP", "scheduled simulator checkpoint approach spawn"):
		return
	var w := _watch(sim, car, pair.east, true)
	for tick in range(1, MAX_TICKS + 1):
		sim.update(STEP)
		if car.route_index == 2:
			break
	if not _check(car.route_index == 2 and sim.reservations.get(w.second) == car.id,
		"PAIR", "checkpoint captures the moving car between its two connectors"):
		return
	var restored = BusSimulation.new(pair.network)
	restored.restore(sim.checkpoint())
	var exact := true
	for tick in range(MAX_TICKS):
		sim.update(STEP)
		restored.update(STEP)
		exact = exact and sim.vehicles == restored.vehicles and sim.reservations == restored.reservations and sim.waiting == restored.waiting
		if car.arrived:
			break
	_check(exact and car.arrived and restored.reservations.is_empty(), "PAIR", "mid-pair checkpoint resumes identically and releases both owners")

func _run() -> void:
	asset = _catalog_asset()
	if _check(not asset.is_empty(), "SETUP", "production catalog car-hatch-01 body 3.65m"):
		_below_boundary()
		var long_pair := _pair(28.0, false)
		if not long_pair.is_empty():
			_solo(long_pair, "east", false)
			_solo(long_pair, "west", false)
			_occupied_second(long_pair, false)
		var short_pair := _pair(14.0, true)
		if not short_pair.is_empty():
			var solo := {"east": _solo(short_pair, "east", true), "west": _solo(short_pair, "west", true)}
			_opposing(short_pair, solo, "east", "west")
			_opposing(short_pair, solo, "west", "east")
			_blocked_exit(short_pair, "east")
			_blocked_exit(short_pair, "west")
			_occupied_second(short_pair, true)
			_terminal_and_wrong_direction(short_pair)
			_short_chain()
			_red_after_grant(short_pair)
			_retire_owner(short_pair)
			_resume_inside_pair(short_pair)
	print("E4C RESULT checks=%d setup_failures=%d control_failures=%d pair_failures=%d" % [checks, setup_failures, control_failures, behavior_failures])
	quit(2 if setup_failures or control_failures else (1 if behavior_failures else 0))
