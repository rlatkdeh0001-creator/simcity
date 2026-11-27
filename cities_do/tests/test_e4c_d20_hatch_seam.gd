extends SceneTree
## Compare retained D20 paint with a one-stroke oracle at a real +10m join.
const City = preload("res://core/city_model.gd")
const Height = preload("res://core/road_height.gd")
const RoadGeometry = preload("res://core/road_geometry.gd")
const LEAD := Vector2(30,75)
const SEAM := Vector2(74,75)
const CUT := Vector2(70,75)
const TAIL := Vector2(110,75)
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures += 1
	print("PASS " + message if ok else "FAIL " + message)
	return ok

func _paint(city) -> Array[PackedVector2Array]:
	var game = load("res://main.tscn").instantiate()
	if game.city.simulation != null: game.city.simulation.shutdown()
	game.city = city
	game.paused = true
	root.add_child(game)
	game.world_renderer.synchronize()
	var result: Array[PackedVector2Array] = []
	for cmd: Array in game.world_renderer.road_shapes:
		if cmd[1] != Color("e8e7dc"): continue
		var shape := PackedVector2Array()
		for p: Vector2 in cmd[0]:
			var q: Vector2 = p / game.tile
			shape.append(Vector2(q.y + q.x, q.y - q.x) * .5)
		# Ignore off-join shapes when testing local paint and overlap.
		for p in shape:
			if absf(p.x-SEAM.x) < 12.0:
				result.append(shape)
				break
	game.free()
	return result

func _multiplicity(shapes: Array[PackedVector2Array], p: Vector2) -> int:
	var count := 0
	for shape in shapes:
		if Geometry2D.is_point_in_polygon(p,shape): count += 1
	return count

func _compare(oracle: Array[PackedVector2Array], paint: Array[PackedVector2Array], width: float, at: Vector2 = SEAM) -> Vector3i:
	var differences := Vector3i.ZERO # missing, extra, double paint
	for i in range(220):
		for j in range(int((width-.15)/.041)):
			var p := Vector2(at.x - 5.5 + (i+.41)*.05, at.y - width*.5 + .075 + (j+.37)*.041)
			# Ignore numerical polygon edges, not visible offset/gaps: only stable neighbouring samples count.
			var ref := _multiplicity(oracle,p)
			if ref != _multiplicity(oracle,p+Vector2(.0031,0)) or ref != _multiplicity(oracle,p-Vector2(.0031,0)): continue
			var actual := _multiplicity(paint,p)
			differences.x += int(ref>0 and actual==0)
			differences.y += int(ref==0 and actual>0)
			differences.z += int(actual>1)
	return differences

func _model(lanes: int, spec: Array, label: String):
	var city := City.new(160,160)
	city.config.zoning_depth = 1
	var built := true
	for stroke in spec:
		var add: Dictionary = city.add_center_flyover(PackedVector2Array(stroke[0]),PackedFloat64Array(stroke[1]),true,lanes)
		if not add.ok:
			built = false
			print("D20 rejected fixture stroke: ",add.reason)
			break
	if not check(built and city.roads.size()==spec.size()*3 and city.junctions.is_empty(),"SETUP: %s legal family or families" % label): return null
	return city

func _rebuild_case(oracle: Array[PackedVector2Array], reversed: bool, width: float) -> void:
	var west := [[SEAM,LEAD],[10,0]] if reversed else [[LEAD,SEAM],[0,10]]
	var label := "4-lane cut/rebuild (reversed west and replacement = %s)" % reversed
	var city = _model(4,[west,[[SEAM,TAIL],[10,0]]],label)
	if city==null: return
	var family: int = city.roads[0].center_family
	var originals: Array[Dictionary] = []
	for road: Dictionary in city.roads:
		if road.center_family==family: originals.append(road)
	var right := true
	for r: Dictionary in originals:
		var y: float = r.points[0].y
		var selection: Dictionary = city.road_demolition_selection(r.parcel_id,Vector2(CUT.x,y),Vector2(SEAM.x,y))
		var removed: Dictionary = city.demolish_road_selection(selection)
		if not removed.ok or not is_equal_approx(float(removed.removed_cells),SEAM.x-CUT.x):
			right = false
			print("D20 rejected cut: ",removed)
	if not check(right and city.roads.size()==6,"SETUP: %s trims only four cells from each west member" % label): return
	# Inspect the same polygon generator before rebuilding, without handing the
	# editable fixture city to a viewport worker prior to the next public edit.
	var pavement: Array[PackedVector2Array] = city.road_pavement + city.junction_pavement
	var gap := RoadGeometry.center_median_hatching(city.roads,Vector2(city.width,city.height),pavement)
	var empty := not gap.is_empty()
	for shape in gap:
		var limits := Vector2(INF,-INF)
		for p in shape: limits=Vector2(minf(limits.x,p.x),maxf(limits.y,p.x))
		if limits.x<SEAM.x-.001 and limits.y>CUT.x+.001: empty=false
	check(empty,"D20 GAP: %s leaves the open gap unpainted" % label)
	var rebuilt: Dictionary = city.add_center_flyover(PackedVector2Array([SEAM,CUT] if reversed else [CUT,SEAM]),PackedFloat64Array([10,10]),true,4)
	if not rebuilt.ok: print("D20 rejected replacement: ",rebuilt.reason)
	if not check(rebuilt.ok and city.roads.size()==9 and city.junctions.is_empty(),"SETUP: %s restores a legal three-member span at +10m" % label): return
	var regenerated := _paint(city)
	var error := _compare(oracle,regenerated,width,CUT)
	check(regenerated.size()>=6 and error==Vector3i.ZERO,"D20 REBUILT: %s matches retained single-stroke phase (missing/extra/duplicate=%s)" % [label,error])

func run() -> void:
	root.size = Vector2i(1280,820)
	for lanes in [4,8]:
		var one := [[ [LEAD,SEAM,TAIL], [0,10,0] ]]
		var single = _model(lanes,one,"%d-lane one stroke" % lanes)
		if single==null: continue
		var reference := _paint(single)
		var width: float = single.roads[0].width
		if not check(reference.size()>=6 and Height.height_at(single.roads[0],SEAM)==10.0,"SETUP: %d-lane one-stroke oracle emits real repeated paint" % lanes): continue
		for reverse_build in [false,true]:
			for reverse_right in [false,true]:
				var pair := [[[LEAD,SEAM],[0,10]], [[TAIL,SEAM],[0,10]] if reverse_right else [[SEAM,TAIL],[10,0]]]
				if reverse_build: pair.reverse()
				var label := "%d lanes, reverse build %s, reverse right %s" % [lanes,reverse_build,reverse_right]
				var city = _model(lanes,pair,label)
				if city==null: continue
				var shapes := _paint(city)
				var error := _compare(reference,shapes,width)
				check(shapes.size()>=6 and error==Vector3i.ZERO,"D20 SEAM: %s matches retained single-stroke phase (missing/extra/duplicate=%s)" % [label,error])
		if lanes==4:
			for reversed in [false,true]: _rebuild_case(reference,reversed,width)
	print("E4C_D20_SEAM checks=%d failed=%d" % [checks,failures])
	quit(1 if failures else 0)
