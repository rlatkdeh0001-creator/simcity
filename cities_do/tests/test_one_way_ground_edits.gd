extends SceneTree
## Headless regression for the ground API and the player's 0m model transaction.
const City = preload("res://core/city_model.gd")
const Topology = preload("res://core/road_junctions.gd")
var tunnel_heights := PackedFloat64Array([-10, -10])
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS " + label)
	else:
		failures += 1
		printerr("FAIL " + label)

func run() -> void:
	layered_build_orders()
	vertical_clearance()
	ground_endpoint_rules()
	ramp_endpoint_connection()
	mixed_height_record()
	covered_junction_under_lot()
	at_grade_overpaint()
	shared_junction_spacing()
	player_frontage_restoration()
	print("RESULT %d/%d one-way ground edit checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)

func line(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b])

func build_ground(city, points: PackedVector2Array, player: bool, commit: bool, lanes: int, direction: int, connect_ends: bool = false, grid: Dictionary = {}) -> Dictionary:
	if player:
		var heights := PackedFloat64Array()
		heights.resize(points.size())
		return city.add_elevated_road(points, heights, "local", commit, lanes, false, 1, grid, null, direction)
	return city.add_road(points, "local", commit, lanes, connect_ends, true, 1, grid, direction)

func ground_endpoint_rules() -> void:
	var tunnel := line(Vector2(30, 40), Vector2(70, 40))
	var frame := {"origin": Vector2.ZERO, "along": Vector2.RIGHT, "outward": Vector2.DOWN}
	# The height API receives already fitted paths; length admission here belongs to add_road.
	for commit in [false, true]:
		for grid in [{}, frame]:
			var city := City.new(100, 100)
			check(city.add_elevated_road(tunnel, tunnel_heights).ok, "length tunnel fixture")
			var before := city.roads.duplicate(true)
			var revision := city.road_topology_revision
			var end := Vector2(39, 40) if grid.is_empty() else Vector2(33, 40)
			var result := build_ground(city, line(Vector2(32, 40), end), false, commit, 1, 1, false, grid)
			check(not result.ok and result.reason == "기본 8m, 기존 도로 연결은 4m 단위로 건설해야 합니다", "tunnel projection cannot grant ground connection units: grid=%s commit=%s" % [not grid.is_empty(), commit])
			check(city.roads == before and city.road_topology_revision == revision and city.next_road_id == 1, "failed length check has no side effects")
	for player in [false, true]:
		var city := City.new(100, 100)
		check(city.add_elevated_road(tunnel, tunnel_heights).ok, "snap tunnel fixture")
		var before := city.roads.duplicate(true)
		var revision := city.road_topology_revision
		var stroke := line(Vector2(30, 40.5), Vector2(42, 40.5))
		for commit in [false, true]:
			var result := build_ground(city, stroke, player, commit, 1, 1, true)
			check(result.ok and result.new_roads.size() == 1 and result.new_roads[0].points == stroke, "ground stroke never snaps to a tunnel endpoint or centerline: player=%s commit=%s" % [player, commit])
			check(city.roads.size() == 1 + int(commit) and city.roads[0] == before[0] and city.next_road_id == 1 + int(commit) and city.road_topology_revision == revision + int(commit), "endpoint edit preserves tunnel ID and revision contract")
		var extension := line(Vector2(42, 40.5), Vector2(43, 40.5))
		var same_grade := build_ground(city, extension, player, false, 1, 1)
		check(same_grade.ok and same_grade.new_roads[0].points == extension, "real ground endpoint still permits a 4m extension: player=%s" % player)
		if not player:
			var snapped := build_ground(city, line(Vector2(42, 40.75), Vector2(45, 40.5)), false, false, 1, 1, true)
			check(snapped.ok and snapped.new_roads[0].points == line(stroke[-1], Vector2(45, 40.5)), "actual ground endpoint still wins when snapping")

func ramp_endpoint_connection() -> void:
	for player in [false, true]:
		var city := City.new(100, 100)
		var ramp := line(Vector2(30, 40), Vector2(62, 40))
		check(city.add_elevated_road(ramp, PackedFloat64Array([0, -10])).ok, "bare ramp endpoint fixture")
		var short := line(Vector2(29, 40), ramp[0])
		var preview := build_ground(city, short, player, false, 2, 0)
		check(preview.ok and preview.new_roads[0].points == short, "bare 0m ramp endpoint grants a 4m connection: player=%s %s" % [player, preview.reason])
		var connect := line(Vector2(28, 40), ramp[0])
		var requested := connect if player else line(connect[0], Vector2(30, 40.25))
		var result := build_ground(city, requested, player, true, 2, 0, true)
		var graph := Topology.analyze(city.roads)
		check(result.ok and city.roads.size() == 2 and city.roads[-1].points == connect and graph.errors.is_empty() and graph.nodes.size() == 3, "bare 0m ramp endpoint still snaps and joins: player=%s %s" % [player, result.reason])

func mixed_height_record() -> void:
	var mixed := PackedVector2Array([Vector2(12, 40), Vector2(24, 40), Vector2(56, 40), Vector2(90, 40)])
	var levels := PackedFloat64Array([0, 0, -10, -10])
	var contact := Vector2(16, 40)
	# Connect at the ground end, go around the ramp, and overlap only the covered end.
	var stroke := PackedVector2Array([contact, Vector2(16, 60), Vector2(64, 60), Vector2(64, 40), Vector2(84, 40)])
	for player in [false, true]:
		var city := City.new(100, 100)
		var built := city.add_elevated_road(mixed, levels)
		check(built.ok and city.roads.size() == 1, "mixed record fixture: " + built.reason)
		if not built.ok:
			continue
		var before := city.roads.duplicate(true)
		var revision := city.road_topology_revision
		var overpaint := build_ground(city, line(Vector2(14, 40), Vector2(22, 40)), player, false, 1, 1)
		check(not overpaint.ok and overpaint.reason == "다른 종류·차로·방향의 도로와 겹칩니다", "the same mixed record still rejects incompatible 0m overpaint: " + overpaint.reason)
		var matching := build_ground(city, line(Vector2(6, 40), Vector2(20, 40)), player, false, 2, 0)
		check(matching.ok and matching.new_roads.size() == 1 and matching.new_roads[0].points == line(Vector2(6, 40), mixed[0]), "matching 0m overpaint retains the host and adds only the uncovered tail: " + matching.reason)
		var encroach := build_ground(city, line(Vector2(56.5, 20), Vector2(56.5, 60)), player, false, 1, 1)
		check(not encroach.ok and encroach.reason == "수직 간격 부족", "full width must clear 10m, even where the centerline is over the flat tunnel: " + encroach.reason)
		var boundary := build_ground(city, line(Vector2(56.75, 20), Vector2(56.75, 60)), player, false, 1, 1)
		check(boundary.ok, "exactly 10m under the whole ground ribbon remains legal: " + boundary.reason)
		var lateral := stroke.duplicate()
		lateral[-2] += Vector2.DOWN
		lateral[-1] += Vector2.DOWN
		var side := build_ground(city, lateral, player, false, 1, 1)
		check(side.ok and side.new_roads[0].points == lateral, "covered pavement overlap does not count as a ground side contact: " + side.reason)
		for commit in [false, true]:
			var result := build_ground(city, stroke, player, commit, 1, 1)
			var label := " player=%s commit=%s: %s" % [player, commit, result.reason]
			check(result.ok and result.new_roads.size() == 1 and result.new_roads[0].points == stroke, "one real ground contact does not expose the record's covered overlap" + label)
			check(city.roads.size() == 1 + int(commit) and city.roads[0] == before[0] and city.next_road_id == 1 + int(commit) and city.road_topology_revision == revision + int(commit), "mixed record keeps exact stored points, heights and ID" + label)
		var topology := Topology.analyze(city.roads)
		check(topology.errors.is_empty() and topology.junctions.size() == 1 and topology.junctions[0].position == contact and topology.junctions[0].height_m == 0, "only the real ground contact yields a junction: player=%s" % player)

func covered_junction_under_lot() -> void:
	for player in [false, true]:
		var city := City.new(100, 100)
		var trunk := line(Vector2(20, 40), Vector2(80, 40))
		var branch := line(Vector2(50, 20), Vector2(50, 60))
		var frontage := line(Vector2(20, 42.5), Vector2(80, 42.5))
		check(city.add_elevated_road(trunk, tunnel_heights).ok and city.add_elevated_road(branch, tunnel_heights).ok and city.add_road(frontage).ok, "covered junction and surface frontage fixture")
		var lot := city.add_building(49, 39)
		var topology := Topology.analyze(city.roads)
		check(lot.ok and topology.junctions.size() == 1 and topology.junctions[0].height_m == -10 and city.Parcels.overlap(city.footprint(lot.building), topology.junctions[0].footprint), "legal surface lot really overlaps covered junction patch: " + lot.get("reason", ""))
		if not lot.ok:
			continue
		var before := city.roads.duplicate(true)
		var buildings := city.buildings.duplicate(true)
		var revision := city.road_topology_revision
		var stroke := line(Vector2(20, 70), Vector2(60, 70))
		for commit in [false, true]:
			var result := build_ground(city, stroke, player, commit, 1, 1)
			var label := " player=%s commit=%s: %s" % [player, commit, result.reason]
			check(result.ok and not result.get("warning", false) and result.get("demolish_ids", []).is_empty() and result.new_roads[0].points == stroke, "unrelated ground edit ignores unchanged covered junction under a lot" + label)
			check(city.roads.slice(0, 3) == before and city.buildings == buildings and city.next_road_id == 3 + int(commit) and city.road_topology_revision == revision + int(commit), "covered junction and surface lot records survive" + label)

func layered_build_orders() -> void:
	var surface := line(Vector2(30, 40), Vector2(70, 40))
	var tunnel := line(Vector2(20, 40), Vector2(80, 40))
	for player in [false, true]:
		for tunnel_first in [false, true]:
			var label := "player=%s tunnel_first=%s" % [player, tunnel_first]
			var city := City.new(100, 100)
			var first: Dictionary
			if tunnel_first:
				first = city.add_elevated_road(tunnel, tunnel_heights)
			else:
				first = build_ground(city, surface, player, true, 1, 1)
			check(first.ok and city.roads.size() == 1, "layer fixture: " + label)
			if not first.ok or city.roads.size() != 1:
				continue
			var before := city.roads.duplicate(true)
			var revision := city.road_topology_revision
			var preview := city.add_elevated_road(tunnel, tunnel_heights, "local", false) if not tunnel_first else build_ground(city, surface, player, false, 1, 1)
			check(preview.ok and preview.get("new_roads", []).size() == 1 and preview.new_roads[0].points == (surface if tunnel_first else tunnel), "separated collinear preview keeps the complete stroke: " + label + " " + preview.reason)
			check(city.roads == before and city.next_road_id == 1 and city.road_topology_revision == revision, "preview leaves existing road and revision intact: " + label)
			var result := city.add_elevated_road(tunnel, tunnel_heights) if not tunnel_first else build_ground(city, surface, player, true, 1, 1)
			check(result.ok and city.roads.size() == 2 and city.roads[0] == before[0] and city.next_road_id == 2 and city.road_topology_revision == revision + 1, "separated collinear commit adds exactly one record: " + label + " " + result.reason)
			if not result.ok or city.roads.size() != 2:
				continue
			var ground_road := city.roads[int(tunnel_first)]
			var tunnel_road := city.roads[int(not tunnel_first)]
			check(ground_road.points == surface and ground_road.travel_dir == 1 and ground_road.width == 1.5 and tunnel_road.points == tunnel and tunnel_road.heights_m == tunnel_heights and not tunnel_road.has("travel_dir") and tunnel_road.width == 3.0, "both layers retain exact geometry, direction and widths: " + label)
			var graph := Topology.analyze(city.roads)
			check(graph.errors.is_empty() and graph.junctions.is_empty() and graph.joins.is_empty() and graph.sections.size() == 2, "stacked roads have no common topology: " + label)

func vertical_clearance() -> void:
	var surface := line(Vector2(36, 20), Vector2(36, 60))
	var ramp := line(Vector2(20, 40), Vector2(52, 40))
	var ramp_heights := PackedFloat64Array([0, -10])
	for player in [false, true]:
		for ramp_first in [false, true]:
			var city := City.new(100, 100)
			var first := city.add_elevated_road(ramp, ramp_heights) if ramp_first else build_ground(city, surface, player, true, 1, 1)
			var label := "player=%s ramp_first=%s" % [player, ramp_first]
			check(first.ok, "clearance fixture: " + label)
			var before := city.roads.duplicate(true)
			var result := build_ground(city, surface, player, true, 1, 1) if ramp_first else city.add_elevated_road(ramp, ramp_heights)
			check(not result.ok and result.reason == "수직 간격 부족" and city.roads == before and city.next_road_id == 1, "the crossing still needs 10m clearance: " + label + " " + result.reason)

func at_grade_overpaint() -> void:
	var points := line(Vector2(20, 40), Vector2(80, 40))
	for player in [false, true]:
		for two_way_first in [false, true]:
			var label := "player=%s two_way_first=%s" % [player, two_way_first]
			var city := City.new(100, 100)
			var first := build_ground(city, points, player, true, 2 if two_way_first else 1, 0 if two_way_first else 1)
			check(first.ok and city.roads.size() == 1 and city.roads[0].width == (3.0 if two_way_first else 1.5) and city.roads[0].has("travel_dir") == not two_way_first, "at-grade fixture preserves explicit zero/one-way shape: " + label)
			var before := city.roads.duplicate(true)
			var revision := city.road_topology_revision
			for commit in [false, true]:
				var result := build_ground(city, points, player, commit, 1 if two_way_first else 2, 1 if two_way_first else 0)
				check(not result.ok and result.reason == "다른 종류·차로·방향의 도로와 겹칩니다" and city.roads == before and city.next_road_id == 1 and city.road_topology_revision == revision, "mixed-profile overpaint still rejected at grade: %s commit=%s" % [label, commit])

func shared_junction_spacing() -> void:
	for player in [false, true]:
		var city := City.new(100, 100)
		var trunk := line(Vector2(20, 50), Vector2(80, 50))
		var side := line(Vector2(40, 50), Vector2(40, 70))
		var legacy := city.add_road(trunk)
		check(legacy.ok and not city.roads[0].has("travel_dir") and city.roads[0].width == 3.0 and city.add_road(side).ok, "omitted direction retains the legacy record and width")
		for metres in [15.99, 16.0]:
			var start := Vector2(40 + metres / 4.0, 50)
			var result := build_ground(city, line(start, start + Vector2.UP * 20), player, false, 1, 1)
			check(result.ok == (metres == 16.0) and (result.ok or result.reason == "교차로 사이 간격은 4칸 이상이어야 합니다"), "common junction spacing %sm player=%s: %s" % [metres, player, result.reason])

func player_frontage_restoration() -> void:
	for reverse in [false, true]:
		var label := "reversed=%s" % reverse
		var city := City.new(64, 64)
		var north := line(Vector2(10, 26.5), Vector2(42, 26.5))
		var south := line(Vector2(10, 35.5), Vector2(42, 35.5))
		check(city.add_road(north).ok and city.add_road(south).ok, "frontage fixture roads: " + label)
		var first := city.add_building(20, 28)
		var second := city.add_building(20, 32)
		check(first.ok and second.ok and first.building.front_road_id == 0 and second.building.front_road_id == 1, "two legitimate existing buildings: " + label)
		if not first.ok or not second.ok:
			continue
		var shapes := city.buildings.map(city.footprint)
		var ids := city.buildings.map(func(b): return b.id)
		var eligible: Dictionary = first.building if reverse else second.building
		var ineligible: Dictionary = second.building if reverse else first.building
		var old_ineligible_front := city.front_direction(ineligible)
		check(city.demolish("road", 0).ok and city.demolish("road", 1).ok and eligible.front_road_id == -1 and ineligible.front_road_id == -1, "demolition orphans both buildings without moving them: " + label)
		var replacement := line(Vector2(10, 31), Vector2(42, 31))
		if reverse:
			replacement.reverse()
		var before := city.buildings.duplicate(true)
		var revision := city.road_topology_revision
		var clock: float = city.clock.game_seconds
		var preview := build_ground(city, replacement, true, false, 1, 1)
		check(preview.ok and preview.demolish_ids.is_empty() and city.buildings == before and city.roads.is_empty() and city.next_road_id == 2 and city.road_topology_revision == revision, "0m player preview leaves both orphans untouched: " + label)
		var result := build_ground(city, replacement, true, true, 1, 1)
		check(result.ok and city.roads.size() == 1 and city.roads[0].parcel_id == 2 and city.road_topology_revision == revision + 1, "0m player commit gives the replacement a stable ID and one revision: " + label)
		check(eligible.front_road_id == 2 and city.front_direction(eligible) == (Vector2.DOWN if reverse else Vector2.UP) and city.clock.game_seconds == clock, "0m player commit immediately restores the valid sidewalk frontage without ticking: " + label)
		check(ineligible.front_road_id == -1 and city.front_direction(ineligible) == old_ineligible_front, "the equally near sidewalkless side stays unbound: " + label)
		check(city.buildings.map(city.footprint) == shapes and city.buildings.map(func(b): return b.id) == ids, "both building IDs and footprints survive: " + label)
