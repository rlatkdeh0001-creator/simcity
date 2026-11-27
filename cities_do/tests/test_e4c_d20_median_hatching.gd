extends SceneTree
## D20: check production retained ground polygons, not a new cache API or framebuffer.
const City = preload("res://core/city_model.gd")
const Parcels = preload("res://core/road_parcels.gd")
const SPINE_Y := 75.0
const EPS := .0002
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
	return ok

func _white_ground(game) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for command: Array in game.world_renderer.road_shapes:
		var color: Color = command[1]
		if minf(color.r, minf(color.g, color.b)) < .83 or absf(color.r-color.b) > .08: continue
		var polygon := PackedVector2Array()
		for p: Vector2 in command[0]:
			var q: Vector2 = p / game.tile
			polygon.append(Vector2(q.y+q.x,q.y-q.x)*.5)
		result.append(polygon)
	return result

func _overlap(polygons: Array[PackedVector2Array], masks: Array[PackedVector2Array]) -> float:
	var area := 0.0
	for polygon in polygons:
		for mask in masks:
			for piece in Geometry2D.intersect_polygons(polygon,mask):
				area += Parcels.area(piece)
	return area

func _diagonals(polygons: Array[PackedVector2Array], low: float, high: float) -> int:
	var count := 0
	for polygon in polygons:
		for i in range(polygon.size()):
			var a := polygon[i]
			var b := polygon[(i+1)%polygon.size()]
			var d := b-a
			if (a.x+b.x)*.5 > low and (a.x+b.x)*.5 < high and absf(d.x) > .45 and absf(d.y) > .45:
				count += 1
				break
	return count

func _fixture(lanes: int) -> void:
	var city := City.new(160,160)
	city.config.zoning_depth = 1
	if lanes == 4:
		var crossing := city.add_road(PackedVector2Array([Vector2(70,57),Vector2(70,93)]),"local",true,2,false,true)
		if not _check(crossing.ok,"SETUP: commit transverse ground road: " + crossing.reason): return
	var spine := PackedVector2Array([Vector2(30,SPINE_Y),Vector2(74,SPINE_Y),Vector2(110,SPINE_Y)])
	var built: Dictionary = city.add_center_flyover(spine,PackedFloat64Array([0,10,0]),true,lanes)
	if not _check(built.ok and city.roads.size() == (4 if lanes == 4 else 3) and city.junctions.size() == (2 if lanes == 4 else 0),
		"SETUP: %d-lane flyover has three members and the expected ground junctions: %s" % [lanes,built.reason]): return
	var game = load("res://main.tscn").instantiate()
	if game.city.simulation != null: game.city.simulation.shutdown()
	game.city = city
	game.paused = true
	root.add_child(game)
	game.world_renderer.synchronize()
	var hatch := _white_ground(game)
	var before := _diagonals(hatch,54,65)
	var after := _diagonals(hatch,76,86)
	var present := _check(before >= 2 and after >= 2,
		"D20: %d lanes, repeated white diagonal ground paint on both sides of the crossing station (%d/%d)" % [lanes,before,after])
	if present:
		var half_width := 1.0 if lanes == 4 else 2.0
		var inside := true
		for polygon in hatch:
			inside = inside and Parcels.area(polygon) > 0 and not Geometry2D.triangulate_polygon(polygon).is_empty()
			for p: Vector2 in polygon:
				inside = inside and p.x >= 34-EPS and p.x <= 106+EPS and absf(p.y-SPINE_Y) <= half_width+EPS
		_check(inside,"D20: %d lanes, positive drawable paint only within the median, off both at-grade split leads" % lanes)
		var overlap := _overlap(hatch,city.road_pavement+city.junction_pavement)
		_check(overlap < EPS,"D20: %d lanes, no positive paint area on branch pavement or the undercrossing/junctions (%.6f cells²)" % [lanes,overlap])
	if lanes == 4:
		var branch: Dictionary = built.new_roads[2] # Opposite authored direction; cut must map back to the median.
		if _check(city.demolish_road_unit(branch.parcel_id,Vector2(60.5,73.25)).ok,"SETUP: remove one cell of the reverse-direction branch"):
			game.world_renderer.synchronize()
			var cut := _white_ground(game)
			var gap: Array[PackedVector2Array] = [PackedVector2Array([Vector2(60,74),Vector2(61,74),Vector2(61,76),Vector2(60,76)])]
			if present:
				_check(_overlap(hatch,gap) > EPS and _overlap(cut,gap) < EPS and _diagonals(cut,76,86) >= 2,
					"D20: a real reverse-branch cut clears only the unsupported median span")
		var deck: Dictionary = built.new_roads[0]
		if _check(city.demolish("road",deck.parcel_id).ok,"SETUP: remove only the deck while retaining branch/ground roads"):
			game.world_renderer.synchronize()
			_check(_white_ground(game).is_empty(),"D20: ordinary and surviving branch roads emit no orphaned hatch")
	game.free()

func _run() -> void:
	root.size = Vector2i(1280,820)
	for lanes: int in [4,6,8]: _fixture(lanes)
	print("E4C_D20 checks=%d failed=%d" % [checks,failures])
	quit(1 if failures else 0)
