extends SceneTree

const Profile = preload("res://core/road_profile.gd")
const City = preload("res://core/city_model.gd")
const Construction = preload("res://core/road_construction.gd")
const Topology = preload("res://core/road_junctions.gd")
const Adapter = preload("res://core/city_simulation_worker.gd")
const Net = preload("res://core/traffic_network.gd")
const Transitions = preload("res://core/road_transitions.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func verify(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS " + label)
	else:
		failures += 1
		print("FAIL " + label)

func path(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b])

func run() -> void:
	sections()
	construction()
	record_lifecycle()
	queued_road_edits()
	directed_graph()
	junction_geometry()
	print("RESULT %d/%d one-way road checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)

func sections() -> void:
	# All dimensions here are metres. Side pairs are left, right in point order.
	var cases := [
		[6.0, Vector2(-3, 2.25), Vector2(0, .75), Vector2(0, 1.75), [-1.25], [0.5]],
		[12.0, Vector2(-5.25, 5.25), Vector2(.75, .75), Vector2(1.75, 1.75), [-1.75, 1.75], [-3.5, 3.5]],
		[12.0, Vector2(-5.25, 5.25), Vector2(.75, .75), Vector2.ZERO, [-3.5, 0.0, 3.5], []],
		[20.0, Vector2(-8.75, 8.75), Vector2(1.25, 1.25), Vector2(1.75, 1.75), [-5.25, -1.75, 1.75, 5.25], [-7.0, 7.0]],
	]
	# Dynamic dispatch lets the unchanged baseline reach assertions, not parser errors.
	var profile: Variant = Profile.new()
	for lanes in range(1, 5):
		var expected: Array = cases[lanes - 1]
		var road := {"kind": "local", "lanes": lanes, "width": expected[0] / 4.0, "travel_dir": 1, "major_side": -1}
		verify(Profile.direction_count(road, 1) == lanes and Profile.direction_count(road, -1) == 0, "lane allocation ignores major_side for one-way %d" % lanes)
		if not profile.has_method("asphalt_edges"):
			verify(false, "one-way %d has no cross-section API" % lanes)
			continue
		verify(is_equal_approx(profile.width_for_record(road) * 4, expected[0]), "exact footprint width %d" % lanes)
		verify(is_equal_approx(Profile.lane_width_metres(road), 3.5), "3.5m lanes %d" % lanes)
		verify((profile.asphalt_edges(road) * 4).is_equal_approx(expected[1]), "signed asphalt edges %d" % lanes)
		verify((Vector2(profile.sidewalk_width(road, -1), profile.sidewalk_width(road, 1)) * 4).is_equal_approx(expected[2]), "left/right sidewalk widths %d" % lanes)
		verify((Vector2(profile.shoulder_width(road, -1), profile.shoulder_width(road, 1)) * 4).is_equal_approx(expected[3]), "left/right shoulder widths %d" % lanes)
		verify(not profile.has_median(road) and Profile.separators(road).size() == lanes - 1, "no median, only between-lane markings %d" % lanes)
		var shoulders: Array = []
		for offset in Profile.shoulder_offsets(road):
			shoulders.append(offset * 4)
		verify(shoulders == expected[5], "shoulder marking offsets %d" % lanes)
		var centres: Array = []
		for index in range(lanes):
			centres.append(profile.lane_center_metres(road, 1, index))
		verify(centres == expected[4], "signed lane centres %d" % lanes)
		road.travel_dir = -1
		verify(Profile.direction_count(road, -1) == lanes and Profile.direction_count(road, 1) == 0 and (profile.asphalt_edges(road) * 4).is_equal_approx(Vector2(-expected[1].y, -expected[1].x)), "outward arm reverses profile in point-order coordinates %d" % lanes)
	verify(Profile.direction_count({"lanes": 3, "major_side": -1}, -1) == 2 and Profile.direction_count({"lanes": 3, "major_side": -1, "travel_dir": 0}, 1) == 1, "legacy odd distribution with absent or zero travel_dir")

func record(a: Vector2, b: Vector2, lanes: int = 1, travel: int = 1) -> Dictionary:
	var road := {"kind": "local", "lanes": lanes, "width": Profile.width_for("local", lanes, 2, travel), "points": path(a, b), "major_side": 1}
	if travel != 0: road.travel_dir = travel
	return road

func construction() -> void:
	var a := Vector2(20, 40)
	var b := Vector2(40, 40)
	var c := Vector2(60, 40)
	var first := record(a, b)
	var overlay := Construction.plan([first], record(a, c))
	verify(overlay.ok and overlay.new_roads.size() == 1 and overlay.new_roads[0].points == path(b, c), "same-flow exact overpaint retains old road and adds only uncovered tail")
	verify(not Construction.plan([first], record(c, a)).ok and not Construction.plan([first], record(a, c, 2)).ok, "opposite-flow or different-profile overpaint rejected")
	var old_way := record(a, b, 2, 0)
	verify(not Construction.plan([old_way], record(a, c, 2)).ok, "equal pavement width and lanes cannot overpaint a different traffic profile")
	for pair in [[first, record(c, b)], [record(b, a), record(b, c)], [first, record(Vector2(56, 56), b)]]:
		for order in [[0, 1], [1, 0]]:
			var plan := Construction.plan([pair[order[0]]], pair[order[1]])
			verify(not plan.ok and plan.reason == "통행 방향이 맞지 않습니다", "direction mismatch rejected at two-arm join %s" % [order])
	for spec in [[2, 1, true], [3, 1, true], [4, 1, false], [2, 0, true], [4, 0, false]]:
		verify(Construction.plan([first], record(b, c, spec[0], spec[1])).ok == spec[2], "6m straight extension width grades %s" % [spec])
	verify(Construction.plan([record(a, b, 2)], record(b, c, 4)).ok and not Construction.plan([record(a, b, 2)], record(b, c, 6, 0)).ok, "12m accepts 20m but rejects skipping to 28m")
	var true_t := Topology.analyze([first, record(c, b), record(b, Vector2(40, 60))])
	verify(true_t.junctions.size() == 1 and Construction.plan([first, record(b, Vector2(40, 60))], record(c, b)).ok, "inbound pair remains legal at a true T")
	var freeway := record(Vector2(20, 50), Vector2(80, 50), 1)
	var branch := record(Vector2(40, 50), Vector2(40, 70), 2, 0)
	for metres in [15.99, 16.0]:
		var second := record(Vector2(40 + metres / 4, 50), Vector2(40 + metres / 4, 30), 2, 0)
		verify(Construction.plan([freeway, branch], second).ok == (metres == 16.0), "common 16m junction spacing unchanged: %s" % metres)

func record_lifecycle() -> void:
	var city: Variant = City.new(100, 100)
	var points := path(Vector2(20, 40), Vector2(42, 40))
	var height := PackedFloat64Array([0, 0])
	if not city.get_method_list().any(func(m): return m.name == "add_road" and m.args[-1].name == "travel_dir"):
		verify(false, "missing opt-in construction and replay API")
		return
	var preview: Dictionary = city.add_road(points, "local", false, 1, false, true, 1, {}, 1)
	verify(preview.ok and preview.get("new_roads", []).size() == 1 and preview.new_roads[0].get("travel_dir") == 1 and city.roads.is_empty(), "ground preview supplies direction without mutating the city")
	var commit: Dictionary = city.add_elevated_road(points, height, "local", true, 1, false, 1, {}, null, 1)
	verify(commit.ok and city.roads.size() == 1 and city.roads[0].points == points and city.roads[0].get("travel_dir") == 1 and city.roads[0].width == 1.5, "0m player height transaction preserves exact authored endpoints and width")
	verify(city.roads.size() == 1 and not city.roads[0].has("major_side"), "one-way records do not store a two-way lane split")
	verify(not city.add_elevated_road(path(Vector2(20, 60), Vector2(60, 60)), PackedFloat64Array([0, 10]), "local", false, 2, false, 1, {}, null, 1).ok, "nonzero heights reject E4a direction")
	verify(not city.add_road(points, "local", false, 1, false, false, 1, {}, -1).ok and not city.add_road(points, "highway", false, 2, false, false, 1, {}, 1).ok, "new roads cannot author a reversed direction or a one-way highway")
	var checkpoint: Variant = bytes_to_var(var_to_bytes(Adapter.capture(city)))
	var restored := Adapter.new()
	verify(restored.boot(checkpoint).ok and restored.city.roads == city.roads and restored.city.next_road_id == city.next_road_id, "checkpoint binary round trip preserves road record, exact width and ID watermark")
	var selected: Dictionary = city.road_demolition_selection(0, Vector2(28, 40), Vector2(32, 40))
	verify(selected.ok and city.demolish_road_selection(selected).ok and city.roads.size() == 2 and city.roads.all(func(road): return road.get("travel_dir") == 1 and road.width == 1.5), "model drag demolition keeps width and direction on both survivors")
	verify(city.roads.size() == 2 and city.roads[0].parcel_id == 0 and city.roads[1].parcel_id == 1 and city.roads[0].points == path(points[0], Vector2(28, 40)) and city.roads[1].points == path(Vector2(32, 40), points[-1]), "drag removes 16m only, preserves authored point order and survivor IDs")
	var legacy := City.new(100, 100)
	verify(legacy.add_road(points).ok and not legacy.roads[0].has("travel_dir"), "legacy construction does not materialize the optional direction field")
	var second := path(Vector2(20, 70), Vector2(60, 70))
	verify(legacy.add_elevated_road(second, height, "local", true, 3, false, -1).ok, "legacy 0m player construction retains the chosen two-way split")
	for i in range(legacy.roads.size()):
		var restored_road: Dictionary = bytes_to_var(var_to_bytes(legacy.roads[i]))
		var matching := restored_road.keys().filter(func(key): return str(key)=="major_side")
		verify(matching.size()==1 and typeof(matching[0])==TYPE_STRING and restored_road["major_side"]== (1 if i==0 else -1) and not restored_road.has("travel_dir"), "legacy API %d preserves the serialized String major_side key, value and absent travel_dir" % i)

func queued_road_edits() -> void:
	var city := City.new(100, 100)
	city.population_enabled = false
	city.happiness_enabled = false
	city.enable_simulation_worker()
	city.simulation.worker.Suspend()
	city.simulation.worker.SetValidationGate(true)
	city.advance_society(2)
	var a := path(Vector2(20, 40), Vector2(40, 40))
	var b := path(Vector2(40, 40), Vector2(60, 40))
	verify(city.add_road(a, "local", true, 1, false, true, 1, {}, 1).get("queued", false), "real outstanding worker queues directed ground API")
	verify(city.add_elevated_road(b, PackedFloat64Array([0, 0]), "local", true, 2, false, 1, {}, null, 1).get("queued", false), "real outstanding worker queues directed 0m height API")
	verify(city.roads.is_empty(), "deferred road edits do not publish prematurely")
	city.simulation.validation_publish()
	city.simulation.resume()
	city.advance_society(2)
	city.simulation.validation_publish()
	verify(city.roads.size() == 2 and city.roads[0].points == a and city.roads[1].points == b and city.roads.all(func(road): return road.get("travel_dir") == 1), "both bound API calls replay in FIFO order with direction")
	verify(city.simulation.get_fault().is_empty(), "directed edits replay with no worker fault")
	city.simulation.shutdown()

func lanes_on(network: RefCounted, road: int, direction: int) -> Array:
	return network.lanes.filter(func(lane): return lane.road == road and lane.direction == direction)

func directed_graph() -> void:
	var a := Vector2(20, 40)
	var b := Vector2(40, 40)
	var c := Vector2(60, 40)
	var network := Net.new()
	for lanes in range(1, 5):
		var built := network.build([record(a, b, lanes)])
		var forward := lanes_on(network, 0, 1)
		verify(built and forward.size() == lanes and lanes_on(network, 0, -1).is_empty(), "no reverse edges for one-way %d" % lanes)
		var expected: Array = [[-1.25], [-1.75, 1.75], [-3.5, 0.0, 3.5], [-5.25, -1.75, 1.75, 5.25]][lanes-1]
		for lane in forward:
			verify(absf(network.sample(lane.id, lane.length / 2).y - 160 - expected[lane.index]) < .001, "actual lane offset %d/%d metres" % [lanes, lane.index])
	var slight_bend := Vector2(59, 44)
	for next in [record(b, c), record(b, slight_bend), record(b, c, 2), record(b, c, 2, 0)]:
		var pair := [record(a, b), next]
		for order in [[0, 1], [1, 0]]:
			var built := network.build([pair[order[0]], pair[order[1]]])
			var from := lanes_on(network, order[0], 1)
			var to := lanes_on(network, order[1], 1)
			var reverse := lanes_on(network, order[1], -1)
			verify(built and network.junctions.is_empty() and not from.is_empty() and not to.is_empty() and to.any(func(lane): return not network.route(from[0].id, lane.id).is_empty()), "head-to-tail routes via uncontrolled seam %s %s" % [next.points[-1], order])
			verify(not from.is_empty() and to.all(func(lane):return network.route(lane.id, from[0].id).is_empty()) and reverse.all(func(lane):return lane.next.is_empty()), "cannot route back through seam or wrong-way exit %s" % [order])
	# Equal lane count AND equal pavement width, but not the same lane centres.
	verify(network.build([record(a, b, 2), record(b, c, 2, 0)]) and not network.route(1, 2).is_empty() and network.junctions.is_empty(), "equal-width mixed-flow seam connects an offset lane instead of dropping it")
	for branch in [record(Vector2(40, 20), Vector2(40, 60), 2, 0), record(b, Vector2(40, 60), 2, 0), record(Vector2(40, 20), Vector2(40, 60))]:
		var pair := [record(a, c), branch]
		var movement_counts: Array[int] = []
		for order in [[0, 1], [1, 0]]:
			verify(Construction.plan([pair[order[0]]], pair[order[1]]).ok and network.build([pair[order[0]], pair[order[1]]]) and network.junctions.size() == 1, "true crossing construction and graph in either order %s" % [order])
			var through := lanes_on(network, order[0], 1)
			verify(through.size() == 2 and not network.route(through[0].id, through[1].id).is_empty() and network.route(through[1].id, through[0].id).is_empty(), "crossing splits one-way into directed through sections")
			var connectors: Array = network.lanes.filter(func(lane): return lane.road < 0)
			movement_counts.append(connectors.size())
			var legal := true
			for turn in connectors:
				var incoming: Dictionary = network.lanes[turn.from]
				var outgoing: Dictionary = network.lanes[turn.to]
				legal = legal and incoming.end_node == outgoing.start_node and network.tangent(turn.from, incoming.length).dot(network.tangent(turn.to, 0)) > -.95
			verify(legal and connectors.size() == (4 if branch.has("travel_dir") else 3 if branch.points[0] == b else 7), "only supported through/turn movements; no U-turn")
		verify(movement_counts[0] == movement_counts[1], "turn count independent of insertion order")

func junction_geometry() -> void:
	var a := Vector2(20, 40)
	var b := Vector2(40, 40)
	var c := Vector2(60, 40)
	var topology := Topology.analyze([record(a, b), record(b, c, 2)])
	verify(topology.joins.size() == 1 and topology.junctions.is_empty(), "width-change derived as an uncontrolled join")
	if topology.joins.is_empty(): return
	var join: Dictionary = topology.joins[0]
	var upstream := Vector2(38.01, 40)
	verify(Geometry2D.is_point_in_polygon(upstream + Vector2(0, -.72), join.asphalt) and not Geometry2D.is_point_in_polygon(upstream + Vector2(0, .65), join.asphalt), "taper asphalt meets the narrow signed asphalt edges")
	var paint := Transitions.paint(join)
	verify(paint.get("median", PackedVector2Array()).is_empty(), "one-way transition never paints a centreline")
	var right_shoulder := false
	for line in paint.white:
		if line[0].is_equal_approx(Vector2(38, 40.125)) and line[-1].is_equal_approx(Vector2(42, 40.875)):
			right_shoulder = true
	verify(right_shoulder, "single shoulder connects to the same physical side on the wider road")
	for mixed in [[record(Vector2(38, 40), b, 2, 0), record(b, c, 1)], [record(b, c, 1), record(Vector2(38, 40), b, 2, 0)]]:
		var mixed_join: Dictionary = Topology.analyze(mixed).joins[0]
		var median: PackedVector2Array = Transitions.paint(mixed_join).median
		verify(median.size() >= 2 and Array(median).all(func(point): return point.x <= 40.0001), "legacy median never crosses the authored seam into the one-way side")
	var crossing := Topology.analyze([record(a, c), record(Vector2(40, 20), Vector2(40, 60), 2, 0)])
	if crossing.junctions.is_empty():
		verify(false, "missing asymmetric junction for approach paint")
		return
	var junction: Dictionary = crossing.junctions[0]
	var unrestricted: Array[PackedVector2Array] = [PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])]
	var stops := Topology.stop_line_polygons(junction, unrestricted)
	var inbound := stops.filter(func(poly): return absf(poly[0].y - 40) < 1 and poly[0].x < 38)
	var outbound := stops.filter(func(poly): return absf(poly[0].y - 40) < 1 and poly[0].x > 42)
	verify(inbound.size() == 1 and outbound.is_empty(), "one-way X has an incoming stop line and none on the outgoing arm")
	if inbound.size() == 1:
		var ys := Array(inbound[0]).map(func(p): return p.y)
		verify(absf(ys.min() - (40 - .75 + .08)) < .001 and absf(ys.max() - (40 + .5625 - .08)) < .001, "incoming stop line spans the full asymmetric asphalt")
