extends SceneTree

const City = preload("res://core/city_model.gd")
const Network = preload("res://core/traffic_network.gd")
const Renderer = preload("res://core/cached_world_renderer.gd")
const SEAM := Vector2(50, 50)
const TILE := Vector2(64, 32)

class MarkView:
	var city: RefCounted
	var tile := TILE

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for reverse in [false, true]:
		check_connectors(false, reverse)
		check_connectors(true, reverse)
		for angle in [-150, -90, -45, -22, 22, 45, 90, 150]:
			for inbound in range(1, 5):
				for outbound in range(1, 5):
					if inbound != outbound:
						check_connectors(false, reverse, angle, Vector2i(inbound, outbound), 16.0)
	check_directed_marks(1)
	check_directed_marks(-1)
	print("RESULT %d/%d one-way connector and taper checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func add_roads(city: RefCounted, specs: Array, reverse: bool) -> bool:
	var ordered := specs.duplicate()
	if reverse: ordered.reverse()
	for spec in ordered:
		var result: Dictionary = city.add_road(PackedVector2Array([spec[0], spec[1]]), "local", true, spec[2], false, false, 1, {}, 1)
		if not result.ok:
			print("Fixture road rejected: ", result)
			return false
	return true

func check_connectors(crossing: bool, reverse: bool, angle: int = 150, counts: Vector2i = Vector2i(4, 4), arm_length: float = 24.0) -> void:
	var label := "%d-degree %s %d-to-%d, %s inserted first" % [angle, "junction" if crossing else "seam", counts.x, counts.y, "outbound" if reverse else "inbound"]
	var city := City.new(100, 100)
	var arm := Vector2.from_angle(deg_to_rad(angle)) * arm_length
	var lead := Vector2(arm_length, 0)
	var built := add_roads(city, [[SEAM - lead, SEAM + lead if crossing else SEAM, counts.x], [SEAM - arm if crossing else SEAM, SEAM + arm, counts.y]], reverse)
	var topology_ok: bool = city.junctions.size() == int(crossing) and city.road_joins.size() == int(not crossing)
	verify(built and topology_ok, "%s: real road construction and intended topology" % label)
	if not built or not topology_ok: return
	var network := Network.new()
	var graph_ok := network.build(city.roads)
	verify(graph_ok, "%s: builds directed graph" % label)
	if not graph_ok: return
	var inbound: int = int(reverse)
	var outbound: int = 1 - inbound
	var start_lanes := network.lanes.filter(func(lane): return lane.road == inbound and lane.end.is_equal_approx(SEAM * 4.0))
	var end_lanes := network.lanes.filter(func(lane): return lane.road == outbound and lane.start.is_equal_approx(SEAM * 4.0))
	var legal := start_lanes.size() == counts.x and end_lanes.size() == counts.y
	var asphalt: Array = city.road_asphalt + city.junction_asphalt
	var outside := 0
	var farthest := 0.0
	for first in start_lanes:
		var destinations := end_lanes.filter(func(lane): return lane.index == mini(first.index, counts.y - 1))
		if destinations.size() != 1:
			legal = false
			continue
		var last: Dictionary = destinations[0]
		var route := network.route(first.id, last.id)
		if route.size() != 3:
			legal = false
			continue
		var connector: Dictionary = network.lanes[route[1]]
		legal = legal and connector.get("from") == first.id and connector.get("to") == last.id
		if not crossing:
			legal = legal and first.next == [connector.id] and connector.next == [last.id]
		legal = legal and connector.transition == not crossing and (connector.junction >= 0) == crossing and connector.length > 0
		legal = legal and network.sample(connector.id, 0).distance_to(network.sample(first.id, first.length)) < .001
		legal = legal and network.sample(connector.id, connector.length).distance_to(network.sample(last.id, 0)) < .001
		legal = legal and network.route(last.id, first.id).is_empty()
		# Check what vehicles actually traverse, not only the authored Bézier vertices.
		var samples := maxi(1, ceili(connector.length / .05))
		for step in range(samples + 1):
			var point := network.sample(connector.id, connector.length * step / samples) / 4.0
			if asphalt.any(func(poly): return Geometry2D.is_point_in_polygon(point, poly)):
				continue
			outside += 1
			farthest = maxf(farthest, point.distance_to(SEAM) * 4.0)
	verify(legal, "%s: all legal lane-index pairs stay connected with exact joins and no reverse route" % label)
	verify(legal and outside == 0, "%s: traversed connectors stay on rendered asphalt (%d outside samples, farthest %.2fm from seam)" % [label, outside, farthest])

func check_directed_marks(direction: int) -> void:
	var polygon_sets := []
	for reverse in [false, true]:
		var label := "%s 2-to-3 taper, reverse insertion=%s" % ["eastbound" if direction == 1 else "westbound", reverse]
		var city := City.new(100, 100)
		var built := add_roads(city, [[SEAM - Vector2(20 * direction, 0), SEAM, 2], [SEAM, SEAM + Vector2(20 * direction, 0), 3]], reverse)
		var valid: bool = built and city.road_joins.size() == 1 and city.junctions.is_empty() and city.road_medians.is_empty()
		verify(valid, "%s: constructs an uncontrolled one-way taper without a median" % label)
		if not valid: return
		var marks := taper_polygons(city, direction)
		polygon_sets.append(marks.polygons)
		verify(marks.paired >= 2 and marks.added >= 1 and marks.wrong_side == 0, "%s: the existing separator tracks the left lane and the added separator stays on the downstream right (matched %d, added %d, wrong side %d)" % [label, marks.paired, marks.added, marks.wrong_side])
	verify(not polygon_sets[0].is_empty() and polygon_sets[0] == polygon_sets[1], "%s 2-to-3 taper: identical emitted dash polygons in both insertion orders" % ("eastbound" if direction == 1 else "westbound"))

func taper_polygons(city: RefCounted, direction: int) -> Dictionary:
	var renderer := Renderer.new()
	var view := MarkView.new()
	view.city = city
	renderer.view = view
	renderer.build_marks()
	var result := {"polygons": [], "paired": 0, "added": 0, "wrong_side": 0}
	if renderer.line_mesh.get_surface_count() == 0:
		renderer.free()
		return result
	var mesh: Array = renderer.line_mesh.surface_get_arrays(0)
	renderer.free()
	var vertices: PackedVector3Array = mesh[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = mesh[Mesh.ARRAY_TEX_UV]
	for i in range(0, vertices.size(), 6):
		var a := unproject(vertices[i], direction)
		var b := unproject(vertices[i + 2], direction)
		if maxf(absf(a.x), absf(b.x)) > 2.0001 or absf(a.y - b.y) < .0001 and absf(a.y) > .8: continue
		if a.x > b.x:
			var swap := a
			a = b
			b = swap
		# Separator-only region. Exclude the taper's unchanged shoulder strokes.
		if minf(absf(a.y), absf(b.y)) > .44: continue
		if b.y < a.y and a.y <= .001: result.paired += 1
		elif a.x >= -.0001 and absf(a.y - .4375) < .001 and absf(b.y - .4375) < .001: result.added += 1
		else: result.wrong_side += 1
		# Same six vertices and UV extrusion as the actual line shader at zoom 1.
		# Canonicalize the four physical corners, not the arm or draw order.
		var corners: Array[String] = []
		for j in [i, i + 1, i + 2, i + 5]:
			var vertex := Vector2(vertices[j].x, vertices[j].y)
			vertex += Vector2.from_angle(uv[j].x) * uv[j].y * 1.5
			corners.append(str((vertex * 1000).round()))
		corners.sort()
		result.polygons.append(str(corners))
	result.polygons.sort()
	return result

func unproject(vertex: Vector3, direction: int) -> Vector2:
	var x := vertex.x / TILE.x
	var y := vertex.y / TILE.y
	return (Vector2((x + y) * .5, (y - x) * .5) - SEAM) * direction
