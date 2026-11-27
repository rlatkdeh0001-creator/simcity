extends "res://tests/test_e4c_short_pair.gd"
## Integration companion: the short pair is produced by a real flyover and undercrossing.

const Height = preload("res://core/road_height.gd")
const HOST_X := 70.0
const SPINE_Y := 75.0
const CROSS_NORTH := 57.0
const CROSS_SOUTH := 93.0
const BRANCH_OFFSET := 1.75
const BAKED_MIDDLE_M := 2.8 # 14m minus 5.6m (40% cap) at each end.
const BAKED_CONNECTOR_M := 11.6 # 5.6m on the short side, 6m on the long side.

func _build_flyover_pair() -> Dictionary:
	var city := City.new(160, 160, 42)
	# Match the flyover-first, legal transverse crossing in test_center_flyover_edits.gd.
	var spine := PackedVector2Array([Vector2(30, SPINE_Y), Vector2(74, SPINE_Y), Vector2(110, SPINE_Y)])
	var flyover: Dictionary = city.add_center_flyover(spine, PackedFloat64Array([0, 10, 0]), true, 4)
	if not _check(flyover.ok and city.roads.size() == 3, "SETUP", "public four-lane flyover commit: " + str(flyover.reason)):
		return {}
	for role in range(3):
		var member: Dictionary = city.roads[role]
		if not _check(member.get("center_family", -1) == city.roads[0].parcel_id
			and member.get("center_role", -1) == role and member.get("center_lanes", 0) == 4
			and member.lanes == (2 if role == 0 else 1)
			and member.get("road_variant", "") == ("center-flyover-deck" if role == 0 else "branch-one-way-6m"),
			"SETUP", "constructed flyover member %d" % role):
			return {}
	var north := Vector2(HOST_X, CROSS_NORTH)
	var south := Vector2(HOST_X, CROSS_SOUTH)
	var near_node := Vector2(HOST_X, SPINE_Y - BRANCH_OFFSET)
	var far_node := Vector2(HOST_X, SPINE_Y + BRANCH_OFFSET)
	if not _check(is_equal_approx(Height.height_at(city.roads[0], Vector2(HOST_X, SPINE_Y)), 10.0)
		and is_zero_approx(Height.height_at(city.roads[2], near_node))
		and is_zero_approx(Height.height_at(city.roads[1], far_node)), "SETUP", "crossing elevation is +10m on the deck, 0m on the branches"):
		return {}
	var points := PackedVector2Array([north, south])
	var cross_road: int = city.roads.size()
	var built: Dictionary = city.add_road(points, "local", true, 2, false, true)
	if not _check(built.ok and city.roads.size() == cross_road + 1 and city.roads[cross_road].points == points
		and absf(city.roads[cross_road].width * METRES - 12.0) < EPS and city.junctions.size() == 2, "SETUP", "public 2-lane undercrossing creates exactly two junctions: " + str(built.reason)):
		return {}
	var network := Network.new()
	if not _check(network.build(city.roads) and network.junctions.size() == 2,
		"SETUP", "bake the committed traffic network: " + str(network.errors)):
		return {}
	var near_id := _junction_at(network, near_node)
	var far_id := _junction_at(network, far_node)
	if not _check(near_id >= 0 and far_id >= 0 and near_id != far_id, "SETUP", "only the two branch contacts are at-grade four-arm junctions"):
		return {}
	var centre_gap: float = network.junctions[near_id].position.distance_to(network.junctions[far_id].position) * METRES
	if not _check(absf(centre_gap - 14.0) < EPS, "SETUP", "actual junction centres are 14m apart"):
		return {}
	for id: int in [near_id, far_id]:
		var arms: Array = network.junctions[id].arms
		var branch_arms := arms.filter(func(arm): return arm.get("road_variant", "") == "branch-one-way-6m")
		if not _check(branch_arms.size() == 2 and absi(branch_arms[0].get("travel_dir", 0)) == 1
			and branch_arms[0].get("travel_dir") == -int(branch_arms[1].get("travel_dir", 0)),
			"SETUP", "junction %d has the two local arms of a one-way frontage road" % id):
			return {}
	var southbound := _route(network, [north, near_node, far_node, south], cross_road, [near_id, far_id])
	var northbound := _route(network, [south, far_node, near_node, north], cross_road, [far_id, near_id])
	if not _check(southbound.size() == 5 and northbound.size() == 5 and southbound[2] != northbound[2],
		"SETUP", "opposite A* routes use their own undercrossing lanes and both correct, ordered junction connectors"):
		return {}
	var deck_lanes: Array[int] = []
	for lane: Dictionary in network.lanes:
		if lane.road == 0:
			deck_lanes.append(lane.id)
	if not _check(deck_lanes.size() == 2, "SETUP", "the grade-separated deck also bakes two real lanes"):
		return {}
	for route: Array in [southbound, northbound]:
		for deck_lane: int in deck_lanes:
			if not _check(network.route(route[0], deck_lane).is_empty() and network.route(deck_lane, route[-1]).is_empty(),
				"SETUP", "no A* transfer between the ground crossing and the deck"):
				return {}
		if not _check(_baked_route_matches(network, route), "SETUP",
			"metre-based curve endpoints join; baked lengths %.3f / %.3f / %.3fm (connector / bridge / connector)"
			% [network.lanes[route[1]].length, network.lanes[route[2]].length, network.lanes[route[3]].length]):
			return {}
	return {"network": network, "southbound": southbound, "northbound": northbound}

func _baked_route_matches(network, route: Array) -> bool:
	for i in range(route.size() - 1):
		var lane: Dictionary = network.lanes[route[i]]
		if not route[i + 1] in lane.next or network.sample(lane.id, lane.length).distance_to(network.sample(route[i + 1], 0.0)) >= EPS:
			return false
	return absf(network.lanes[route[1]].length - BAKED_CONNECTOR_M) < EPS \
		and absf(network.lanes[route[2]].length - BAKED_MIDDLE_M) < EPS \
		and absf(network.lanes[route[3]].length - BAKED_CONNECTOR_M) < EPS

func _watch(sim, car: Dictionary, route: Array, atomic: bool) -> Dictionary:
	# The inherited front/rear chainage checks are axis-independent; rotate only
	# the independent pose/heading oracle from the flat fixture's horizontal road.
	var watch := super._watch(sim, car, route, atomic)
	var approach: Dictionary = sim.network.lanes[route[0]]
	var axis := Vector2.DOWN if approach.end.y > approach.start.y else Vector2.UP
	watch.axis = axis
	watch.origin = approach.start + Vector2(-axis.y, axis.x) * 1.75
	return watch

func _flyover_solo(pair: Dictionary, direction: String) -> int:
	var sim := Simulation.new(pair.network)
	var route: Array = pair[direction]
	var car := _spawn(sim, route)
	if not _check(not car.is_empty(), "SETUP", direction + " stock hatchback spawn"):
		return -1
	var middle_m: float = pair.network.lanes[route[2]].length
	var receiver_min_m: float = car.length + 3.0 * car.min_gap
	if not _check(absf(car.length - 3.65) < EPS and absf(car.min_gap - 2.0) < EPS
		and middle_m > 0.0 and middle_m < receiver_min_m
		and pair.network.lanes[route[-1]].length > receiver_min_m, "SETUP",
		"%s actual %.3fm bridge cannot receive this car (%.3fm required); final lane can" % [direction, middle_m, receiver_min_m]):
		return -1
	var watch := _watch(sim, car, route, true)
	_drive(sim, [watch])
	_check(watch.grant_tick == 1 and watch.all_or_none and watch.entry_tick > 1,
		"PAIR", direction + " both scalar reservations granted on the first tick, before front entry")
	_through(sim, watch, "14m flyover solo " + direction)
	return int(watch.entry_tick)

func _run() -> void:
	asset = _catalog_asset()
	if _check(not asset.is_empty(), "SETUP", "production car-hatch-01 catalog record"):
		var pair := _build_flyover_pair()
		if not pair.is_empty():
			var solo := {"southbound": _flyover_solo(pair, "southbound"), "northbound": _flyover_solo(pair, "northbound")}
			_opposing(pair, solo, "southbound", "northbound")
			_opposing(pair, solo, "northbound", "southbound")
			_blocked_exit(pair, "southbound")
			_blocked_exit(pair, "northbound")
	print("E4C FLYOVER RESULT checks=%d setup_failures=%d control_failures=%d pair_failures=%d" % [checks, setup_failures, control_failures, behavior_failures])
	quit(2 if setup_failures or control_failures else (1 if behavior_failures else 0))
