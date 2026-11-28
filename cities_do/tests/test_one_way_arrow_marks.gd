extends SceneTree

const City = preload("res://core/city_model.gd")
const Geometry = preload("res://core/road_geometry.gd")
const Parcels = preload("res://core/road_parcels.gd")
const Profile = preload("res://core/road_profile.gd")
const Transitions = preload("res://core/road_transitions.gd")

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

func overlap_area(lines: Array, arrows: Array, half_stroke: float = 1.325) -> float:
	# Reconstruct the retained paint shader's butt-ended screen-space stroke.
	# Existing clear cases also check its full 1px AA fringe.
	var area := 0.0
	for line: PackedVector2Array in lines:
		var a := iso(line[0]); var b := iso(line[-1])
		var normal := (b-a).orthogonal().normalized()*half_stroke
		var quad := PackedVector2Array([a-normal, b-normal, b+normal, a+normal])
		var box := Parcels.bounds(quad)
		for arrow: PackedVector2Array in arrows:
			var projected := PackedVector2Array()
			for point in arrow: projected.append(iso(point))
			if not box.intersects(Parcels.bounds(projected)): continue
			for piece in Geometry2D.intersect_polygons(quad, projected):
				area += Parcels.area(piece)
	return area

func arrow_centers(arrows: Array) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	for arrow: PackedVector2Array in arrows: centers.append((arrow[1]+arrow[-1])/2)
	return centers

func has_center(centers: Array[Vector2], expected: Vector2) -> bool:
	return centers.any(func(center): return center.distance_to(expected)<.001)

func isolated_lane_arrows() -> void:
	for lanes in [2,3,4]:
		for heading: Vector2 in [Vector2.RIGHT,Vector2(-.6,.8)]:
			var start := Vector2(58,24)
			var city := City.new(130,110)
			verify(add(city,start,start+heading*60,lanes), "construct %d-lane stroke facing %s" % [lanes,heading])
			var road: Dictionary = city.roads[0]
			var arrows: Array = city.road_direction_arrows
			var centers := arrow_centers(arrows)
			var found := 0
			var forward := true
			for chainage: float in [2.,16.,32.,48.,58.]:
				for lane in range(lanes):
					var expected := start+heading*chainage-heading.orthogonal()*Profile.lane_center_metres(road,1,lane)/4
					if has_center(centers,expected):found+=1
			for arrow: PackedVector2Array in arrows:
				forward = forward and (arrow[0]-(arrow[3]+arrow[4])/2).normalized().dot(heading)>.999
			verify(found==5*lanes and arrows.size()==found, "every endpoint/64m station emits exactly one glyph at each of %d lane centres (%d found)" % [lanes,found])
			verify(forward and not arrows.is_empty(), "each glyph points in actual travel direction")
			verify(arrows==Geometry.direction_arrows(road), "preview and retained isolated stroke emit the same per-lane glyphs")
			var raw: Array[PackedVector2Array] = []
			for line in Geometry.lane_marks(road)+Geometry.shoulder_marks(road):
				raw.append_array(Geometry.visible_lines(line,Vector2(130,110),[]))
			verify(raw==city.road_lane_marks, "arrows must not clip any white dash or shoulder")
			var area := overlap_area(city.road_lane_marks,arrows)
			verify(area<.0001, "per-lane glyphs clear the full projected white stroke (%.6f px²)" % area)

func curved_lane_arrows() -> void:
	var points := PackedVector2Array()
	for i in range(33):points.append(Vector2(58,57)+Vector2.from_angle(i*TAU/96-PI/3)*30)
	var city := City.new(120,120,42)
	verify(city.add_road(points,"local",true,3,false,false,1,{},1).ok, "construct sampled 3-lane curve")
	if city.road_visuals.is_empty():return
	var visual: Dictionary = city.road_visuals[0]
	var junctions = preload("res://core/road_junctions.gd")
	var center: Vector2 = junctions.sample(visual.points,32.)
	# Use the containing chord instead of subtracting nearly identical world-space
	# float32 samples (a .002-cell baseline shifts the outer targets by .002 cells).
	var distance := 32.0
	var tangent := Vector2.ZERO
	var curve: PackedVector2Array = visual.points
	for i in range(1,curve.size()):
		var chord := curve[i]-curve[i-1]
		if distance<=chord.length():
			tangent=chord.normalized()
			break
		distance-=chord.length()
	var centers := arrow_centers(city.road_direction_arrows)
	var expected := []
	for lane in range(3):expected.append(center-tangent.orthogonal()*Profile.lane_center_metres(visual,1,lane)/4)
	verify(centers.size()==15 and expected.all(func(p):return has_center(centers,p)) and city.road_direction_arrows==Geometry.direction_arrows(visual), "curved stations emit all glyphs; the 64m centres use the local tangent in preview and retained paint")
	var area := overlap_area(city.road_lane_marks,city.road_direction_arrows)
	verify(area<.0001, "curved glyphs clear actual white stroke geometry (%.6f px²)" % area)

func separator_at(lines: Array, x: float, y: float) -> bool:
	return lines.any(func(line):
		var a: Vector2=line[0];var b: Vector2=line[-1]
		return x>minf(a.x,b.x)+.0001 and x<maxf(a.x,b.x)-.0001 and absf(lerpf(a.y,b.y,(x-a.x)/(b.x-a.x))-y)<.002)

func branch_marking_seam() -> void:
	for reverse_order in [false,true]:
		var city := City.new(120,120,42)
		var start:=Vector2(32.25,40.25);var seam:=Vector2(48.25,40.25);var finish:=Vector2(73.25,40.25)
		var branch := func():return city.add_branch_one_way(path(start,seam),Profile.BranchVariant.EIGHT_METRE).ok
		var normal := func():return add(city,seam,finish,2)
		verify((normal.call() and branch.call()) if reverse_order else (branch.call() and normal.call()), "construct screenshot's exact 8→12m seam (reverse insertion %s)" % reverse_order)
		verify(city.road_joins.size()==1 and city.road_joins[0].taper, "fixture reaches the real two-arm taper")
		if city.road_joins.size()!=1:continue
		var join: Dictionary = city.road_joins[0]
		var raw := Transitions.paint(join)
		var paint: Array = city.road_lane_marks
		# Existing 1920x1080 composition: focus (53.25,46.75) maps to (960,411),
		# with 1.76 zoom and a (14,7) tile. Invert x1043,y292 to its world sample.
		var d := Vector2(83,-119)/1.76/Vector2(14,7)
		var sample := Vector2(53.25,46.75)+Vector2(d.x+d.y,d.y-d.x)/2
		var raw_near: Array = raw.white.filter(func(line):return absf(line[-1].y-sample.y)<.03 and minf(line[0].x,line[-1].x)>49.5)
		var final_near: Array = paint.filter(func(line):return absf(line[-1].y-sample.y)<.03 and minf(line[0].x,line[-1].x)>49.5 and maxf(line[0].x,line[-1].x)<51.80)
		var near_arrows: Array = city.road_direction_arrows.filter(func(poly):return Parcels.bounds(poly).grow(.1).has_point(sample))
		print("SEAM pixel world=%s standalone taper=%s final white=%s arrow neighbourhood=%d" % [sample,raw_near,final_near,near_arrows.size()])
		# Cumulative phase from x32.25 has a dash at 49.75..50.50 across
		# the taper mouth, followed by a gap to 51.00. Probe well inside pieces.
		verify(separator_at(paint,50.1,40.2453125) and separator_at(paint,50.375,40.25)
			and not separator_at(paint,50.875,40.25), "cumulative dash crosses the outgoing taper mouth without restarting")
		var centers := arrow_centers(city.road_direction_arrows)
		verify(centers.size()==8 and has_center(centers,seam+Vector2(0,-.5)) and has_center(centers,seam+Vector2(0,.375)), "taper 64m station contributes two interpolated lane centres, not a seam duplicate")
		var area := overlap_area(paint,city.road_direction_arrows)
		verify(area<.0001, "taper glyphs and all white paint are disjoint (%.6f px²)" % area)
		verify(near_arrows.is_empty(), "the historical short-dash location is beyond the seam glyphs")
		var straight: Array = city.road_branch_edge_marks.filter(func(poly):return Parcels.bounds(poly).position.x<33.)
		var quad: PackedVector2Array = straight[0] if not straight.is_empty() else PackedVector2Array()
		var ax := (iso(Vector2.RIGHT)-iso(Vector2.ZERO)).normalized()
		var width := 0.0
		for p in quad:
			for q in quad:width=maxf(width,absf((iso(p)-iso(q)).cross(ax)))
		verify(is_equal_approx(width,.65) or absf(width-.65)<.001, "amber stripe matches the actual white shoulder's projected opaque width at .65 zoom (%.5f px)" % width)
		verify(not quad.is_empty() and absf(Parcels.bounds(quad).end.y-40.98)<.0001, "amber outer edge retains exactly 8cm curb setback")

func equal_width_marking_seam() -> void:
	for reverse_order in [false,true]:
		var city := City.new(110,100,42)
		var start := Vector2(10,40); var seam := Vector2(41,40); var finish := Vector2(90,40)
		var before := func(): return add(city,start,seam,2)
		var after := func(): return add(city,seam,finish,3)
		var order := " (reverse insertion %s)" % reverse_order
		verify((after.call() and before.call()) if reverse_order else (before.call() and after.call()), "construct legal 12→12m one-way 2→3 seam"+order)
		verify(city.road_joins.size()==1 and city.road_joins[0].arms.all(func(arm): return arm.width==3.)
			and not city.road_joins[0].get("taper",false) and city.junctions.is_empty()
			and city.junction_asphalt.is_empty() and city.junction_pavement.is_empty(), "equal-width seam needs marking geometry, not a physical taper or controlled junction"+order)
		var paint: Array = city.road_lane_marks
		# Run chainage starts at x=10: phase 29.6 is in a gap; phase 30.1 is in a dash.
		# The paired separator interpolates from y=40 at x=39 to y=39.5625 at x=43.
		verify(not separator_at(paint,39.6,39.934375) and separator_at(paint,40.1,39.8796875)
			and separator_at(paint,42.9,39.5734375) and separator_at(paint,43.1,39.5625), "equal-width taper preserves cumulative dash phase through its mouth"+order)
		# At the 64m station x=42, the travel edges are ±1.203125 cells and
		# the two active separator offsets are -0.328125 and +0.4375 cells.
		var centers := arrow_centers(city.road_direction_arrows)
		var station := centers.filter(func(p): return absf(p.x-42)<.001)
		verify(station.size()==3 and has_center(station,Vector2(42,39.234375))
			and has_center(station,Vector2(42,40.0546875)) and has_center(station,Vector2(42,40.8203125)),
			"equal-width 64m station emits exactly the three interpolated lane centres (got %s)" % str(station)+order)
		var area := overlap_area(paint,city.road_direction_arrows)
		verify(area<.0001, "equal-width station clears the reference white paint (%.6f px²)" % area+order)

func diagonal_amber_width() -> void:
	var city := City.new(100,100,42)
	var heading := Vector2(-.6,.8)
	var start := Vector2(45,15)
	var finish := start+heading*40
	verify(city.add_branch_one_way(path(start,finish),Profile.BranchVariant.SIX_METRE).ok, "construct diagonal 6m branch with real shoulder")
	var projected_axis := iso(heading).normalized()
	var outer := -INF
	var inner := INF
	var projected_min := INF
	var projected_max := -INF
	var normal := -heading.orthogonal()
	for poly: PackedVector2Array in city.road_branch_edge_marks:
		for p in poly:
			var lateral := (p-start).dot(normal)
			outer = maxf(outer,lateral);inner = minf(inner,lateral)
			var projected := projected_axis.cross(iso(p-start))
			projected_min = minf(projected_min,projected);projected_max = maxf(projected_max,projected)
	verify(absf(projected_max-projected_min-.65)<.001 and not city.road_lane_marks.is_empty(), "6m diagonal amber matches the actual white shoulder projected opaque width (%.5f px)" % (projected_max-projected_min))
	verify(absf(outer-.5425)<.0001 and inner>.125, "6m diagonal amber preserves the curb setback and does not reach the white shoulder")

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
		verify(arrows.size() == 6*lanes and arrows == Geometry.direction_arrows(city.roads[0]) and city.road_medians.is_empty(), "%d-lane end and 64m stations are unchanged and shared by preview" % lanes)
		verify(raw.filter(func(line): return overlap_area([line], arrows) == 0.0).all(paint.has), "%d-lane nonconflicting dashes retain their exact position and phase" % lanes)
		if lanes % 2 == 0:
			verify(paint.any(func(line): return line[0].is_equal_approx(Vector2(11.25001,40)) and line[-1].is_equal_approx(Vector2(12,40))), "the previously cut dash is retained at full length")
	for reverse_order in [false, true]:
		var city := City.new(110, 100)
		var parts := [[Vector2(10,40), Vector2(41,40), 1], [Vector2(41,40), Vector2(90,40), 2]]
		if reverse_order: parts.reverse()
		for part in parts:
			verify(add(city, part[0], part[1], part[2]), "construct one-way taper arm")
		var arrows: Array = city.road_direction_arrows
		var area := overlap_area(city.road_lane_marks, arrows)
		verify(area < .0001, "taper and ordinary marking pieces both clear the retained arrows (area %.6f px²)" % area)
		var centers := arrow_centers(arrows)
		verify(arrows.size() == 10 and has_center(centers,Vector2(42,39.578125)) and has_center(centers,Vector2(42,40.34375)), "a taper keeps the original 64m station and paints its two active lanes")
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

func tight_taper_arrow() -> void:
	var start := Vector2(22,95)
	var forward := Vector2(1,-1).normalized()
	var right := -forward.orthogonal()
	var seam := start+47.9*forward
	var finish := seam+5.0*forward
	var expected := [-.95625,-.259375,.4375,1.075]
	for reverse_order: bool in [false,true]:
		var city := City.new(130,130,42)
		var built: bool
		if reverse_order:
			built = add(city,seam,finish,4) and city.add_branch_one_way(path(start,seam),Profile.BranchVariant.EIGHT_METRE).ok
		else:
			built = city.add_branch_one_way(path(start,seam),Profile.BranchVariant.EIGHT_METRE).ok and add(city,seam,finish,4)
		verify(built and city.road_joins.size()==1 and city.junctions.is_empty(), "tight 8→20m diagonal taper is legal in order %s" % reverse_order)
		if not built: continue
		var at_station: Array[PackedVector2Array] = []
		for glyph: PackedVector2Array in city.road_direction_arrows:
			var center := (glyph[1]+glyph[-1])*.5
			if absf((center-start).dot(forward)-48.0)<.001: at_station.append(glyph)
		var centers := arrow_centers(at_station)
		verify(centers.size()==4 and expected.all(func(offset): return has_center(centers,start+forward*48.0+right*offset)), "tight 64m station keeps all four exact lane centres in order %s" % reverse_order)
		verify(at_station.size()==4 and at_station.all(func(glyph): return (glyph[0]-(glyph[1]+glyph[-1])*.5).normalized().dot(forward)>.999), "all four tight-taper arrows retain the travel tangent")
		verify(at_station.size()==4 and overlap_area(city.road_lane_marks,at_station,.325)<.0001, "tight taper glyphs clear the opaque white stroke at .65 zoom")
		verify(at_station.size()==4 and overlap_area(city.road_lane_marks,at_station)>0.01, "positive AA contact exercises the approved distinction")

func run() -> void:
	root.size = Vector2i(1280,820)
	mark_geometry()
	isolated_lane_arrows()
	curved_lane_arrows()
	branch_marking_seam()
	equal_width_marking_seam()
	diagonal_amber_width()
	tight_taper_arrow()
	await preview_redraw()
	print("RESULT %d/%d one-way arrow marking and preview redraw checks passed" % [checks-failures, checks])
	quit(1 if failures else 0)
