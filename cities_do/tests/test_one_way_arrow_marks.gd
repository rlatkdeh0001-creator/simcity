extends SceneTree

const City = preload("res://core/city_model.gd")
const Geometry = preload("res://core/road_geometry.gd")
const Parcels = preload("res://core/road_parcels.gd")

class CountedDrawer extends "res://core/road_drawing.gd":
	var ribbon_builds := 0
	var arrow_builds := 0
	func preview_polygons(points: PackedVector2Array, width: float) -> Array[PackedVector2Array]:
		ribbon_builds += 1
		return super.preview_polygons(points, width)
	func preview_arrow_polygons(result: Dictionary) -> Array[PackedVector2Array]:
		arrow_builds += 1
		return super.preview_arrow_polygons(result)

var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func path(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b])

func add(city, a: Vector2, b: Vector2, lanes: int, travel: int = 1) -> bool:
	return city.add_road(path(a, b), "local", true, lanes, false, false, 1, {}, travel).ok

func iso(p: Vector2) -> Vector2:
	return Vector2((p.x-p.y)*14, (p.x+p.y)*7)*.65

func overlap_area(lines: Array, arrows: Array) -> float:
	# Reconstruct the retained paint shader's full stroke (including its 1px AA
	# footprint), not just the centerline or a few sampled points on the arrow.
	var area := 0.0
	for line: PackedVector2Array in lines:
		var a := iso(line[0]); var b := iso(line[-1])
		var normal := (b-a).orthogonal().normalized()*1.325
		var quad := PackedVector2Array([a-normal, b-normal, b+normal, a+normal])
		var box := Parcels.bounds(quad)
		for arrow: PackedVector2Array in arrows:
			var projected := PackedVector2Array()
			for point in arrow: projected.append(iso(point))
			if not box.intersects(Parcels.bounds(projected)): continue
			for piece in Geometry2D.intersect_polygons(quad, projected):
				area += Parcels.area(piece)
	return area

func mark_geometry() -> void:
	for lanes in [1, 2, 3, 4]:
		var city := City.new(110, 100)
		verify(add(city, Vector2(10,40), Vector2(90,40), lanes), "construct isolated one-way %d-lane road" % lanes)
		var arrows: Array = city.road_direction_arrows
		var raw := Geometry.lane_marks(city.roads[0])
		for shoulder in Geometry.shoulder_marks(city.roads[0]): raw.append(shoulder)
		var paint: Array[PackedVector2Array] = city.road_lane_marks
		var area := overlap_area(paint, arrows)
		verify(area < .0001, "%d-lane emitted dash/shoulder polygons never cover an arrow (area %.6f px²)" % [lanes, area])
		verify(arrows.size() == 6 and arrows == Geometry.direction_arrows(city.roads[0]) and city.road_medians.is_empty(), "%d-lane end and 64m arrows are unchanged and shared by preview" % lanes)
		verify(raw.filter(func(line): return overlap_area([line], arrows) == 0.0).all(paint.has), "%d-lane nonconflicting dashes retain their exact position and phase" % lanes)
		if lanes % 2 == 0:
			verify(paint.any(func(line): return line[0].is_equal_approx(Vector2(11.25001,40)) and line[-1].x > 11.3 and line[-1].x < 11.51), "the conflicting dash keeps its clear fragment rather than disappearing")
	for reverse_order in [false, true]:
		var city := City.new(110, 100)
		var parts := [[Vector2(10,40), Vector2(41,40), 1], [Vector2(41,40), Vector2(90,40), 2]]
		if reverse_order: parts.reverse()
		for part in parts:
			verify(add(city, part[0], part[1], part[2]), "construct one-way taper arm")
		var arrows: Array = city.road_direction_arrows
		var area := overlap_area(city.road_lane_marks, arrows)
		verify(area < .0001, "taper and ordinary marking pieces both clear the retained arrows (area %.6f px²)" % area)
		verify(arrows.size() == 6 and arrows.any(func(poly): return Geometry2D.is_point_in_polygon(Vector2(42,40), poly)), "a taper keeps the original 64m arrow on its seam approach")
	var legacy := City.new(110, 100)
	verify(add(legacy, Vector2(10,40), Vector2(90,40), 4, 0), "construct legacy two-way road")
	var expected := Geometry.lane_marks(legacy.road_visuals[0])
	expected.append_array(Geometry.shoulder_marks(legacy.road_visuals[0]))
	verify(legacy.road_lane_marks == expected and not legacy.road_medians.is_empty(), "a two-way road retains its existing dashes, shoulders and median")

func settle() -> void:
	for i in range(3): await process_frame

func preview_redraw() -> void:
	var game = load("res://main.tscn").instantiate()
	game.city = City.new(110, 100); game.paused = true
	root.add_child(game); current_scene = game
	await settle()
	game.activate_tool("road")
	var drawer := CountedDrawer.new(game)
	game.road_drawer = drawer
	game.road_grid_enabled = false
	game.road_lanes = 2; drawer.travel_dir = 1
	drawer.click(Vector2(10,35)); game.pointer = Vector2(90,35)
	var draw_calls := [0]
	game.draw.connect(func(): draw_calls[0] += 1)
	game.queue_redraw(); await settle()
	var initial := Vector2i(drawer.ribbon_builds, drawer.arrow_builds)
	var initial_draws: int = draw_calls[0]
	var admissions := drawer.preview_computations
	verify(initial == Vector2i.ONE and admissions == 1, "first drawn directed preview builds one ribbon and one arrow set")
	for i in range(3):
		game.origin += Vector2.ONE
		game.map_zoom *= 1.1
		game.queue_redraw(); await settle()
	verify(draw_calls[0] >= initial_draws+3 and drawer.preview_computations == admissions, "three camera-only redraws keep the real admission cache hot")
	verify(Vector2i(drawer.ribbon_builds, drawer.arrow_builds) == initial, "steady redraw performs zero ribbon/arrow geometry work (observed %s)" % Vector2i(drawer.ribbon_builds, drawer.arrow_builds))
	game.pointer = Vector2(86,35)
	game.queue_redraw(); await settle()
	verify(Vector2i(drawer.ribbon_builds, drawer.arrow_builds) == initial+Vector2i.ONE and drawer.preview_computations == admissions+1, "changed plan rebuilds each world-space polygon set exactly once")
	var copy := drawer.preview()
	var expected_arrows: Array = Geometry.direction_arrows({"kind":"local", "width":copy.width, "lanes":copy.lanes, "travel_dir":copy.travel_dir, "points":copy.points})
	verify(not expected_arrows.is_empty() and copy.get("arrow_polygons",[]) == expected_arrows, "cached preview arrows match the shared glyphs on the resolved path")
	if copy.has("arrow_polygons"): copy.arrow_polygons.clear()
	verify(drawer.preview().get("arrow_polygons",[]) == expected_arrows, "a caller cannot mutate the draw cache through the public preview copy")
	drawer.travel_dir = 0
	game.queue_redraw(); await settle()
	verify(drawer.preview().get("arrow_polygons",null) == [] and drawer.preview_computations == admissions+2 and Vector2i(drawer.ribbon_builds, drawer.arrow_builds) == initial+Vector2i(2,2), "changing the selected travel direction invalidates cached polygons even at a fixed pointer")
	game.free()
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,820)
	mark_geometry()
	await preview_redraw()
	print("RESULT %d/%d one-way arrow marking and preview redraw checks passed" % [checks-failures, checks])
	quit(1 if failures else 0)
