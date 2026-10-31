extends SceneTree
const Model = preload("res://core/city_model.gd")
const Geometry = preload("res://core/road_geometry.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String):
	checks += 1
	if value: print("PASS ",label)
	else:
		failures += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var city = Model.new(100,100)
	check(city.zoning_grid.count() == 0 and city.zoning_grid.chunks.is_empty(),"empty map allocates no zoning cells")
	var points := PackedVector2Array([Vector2(20,50),Vector2(80,50)])
	city.add_road(points,"local",false,2)
	check(city.zoning_grid.count() == 0,"preview does not reveal zoning")
	check(city.add_road(points,"local",true,2).ok and city.roads[0].width == 2 and city.roads[0].lanes == 2,"1+1 road occupies 2 cells / 8m")
	check(city.zoning_grid.has_cell(Vector2i(40,48)) and city.zoning_grid.has_cell(Vector2i(40,51)),"road reveals adjacent zoning on both sides")
	check(not city.zoning_grid.has_cell(Vector2i(40,49)) and not city.zoning_grid.has_cell(Vector2i(40,50)),"road surface has no zoning grid")
	check(not city.zoning_grid.has_cell(Vector2i(40,20)),"distant terrain remains grid-free")
	var visible: Array = city.zoning_grid.cells_in(Rect2i(38,46,5,4))
	var inside := not visible.is_empty()
	for cell in visible:
		if not Rect2i(38,46,5,4).has_point(cell):inside = false
	check(inside,"chunk query returns only visible world bounds")
	check(city.add_road(PackedVector2Array([Vector2(40,20),Vector2(40,80)]),"local",true,4).ok and city.roads[1].width == 4,"2+2 road occupies 4 cells / 16m")
	check(not city.zoning_grid.has_cell(Vector2i(40,48)),"new road removes grid under its corridor")
	check(not city.add_building(39,43).ok,"wide road corridor blocks building placement")
	var highway = Model.new(100,100)
	highway.add_road(points,"highway",true,4)
	check(highway.zoning_grid.count() == 0,"highway reveals no zoning")
	var diagonal = Model.new(100,100)
	diagonal.add_road(PackedVector2Array([Vector2(10.3,10.7),Vector2(30.6,27.4),Vector2(48.1,22.8)]),"local",true,2)
	check(diagonal.zoning_grid.count() > 0 and not diagonal.zoning_grid.has_cell(Vector2i(80,80)),"fractional curved stroke reveals local grid only")
	var big = Model.new(1024,1024)
	check(big.zoning_grid.chunks.is_empty(),"1024x1024 empty map remains sparse")
	var started := Time.get_ticks_msec()
	big.add_road(PackedVector2Array([Vector2(500.3,500.7),Vector2(520.2,515.4)]),"local",true,4)
	check(big.zoning_grid.count() > 0 and big.zoning_grid.count() < 2000 and big.zoning_grid.chunks.size() < 10,"1024 map short road allocates bounded local chunks")
	print("1024-map short-stroke zoning update ms: ",Time.get_ticks_msec()-started)
	check(Geometry.ribbons(points,2).size() > 0 and Geometry.lane_marks(city.roads[1]).size() > 0,"road ribbons and 4-lane dividers generated")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var screen_point := Vector2(850,350)
	var before: Vector2 = scene.world(screen_point)
	var wheel := InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;wheel.position=screen_point
	scene._unhandled_input(wheel)
	check(scene.world(screen_point).distance_to(before)<0.001,"zoom keeps cursor world position anchored")
	check(scene.world(scene.screen(Vector2(60.25,40.75))).distance_to(Vector2(60.25,40.75))<0.001,"zoomed projection inverse matches input")
	scene.road_lanes = 4
	scene.stroke = PackedVector2Array([Vector2(20,50),Vector2(80,50)]);scene.drawing=true;scene.finish_road()
	check(scene.city.roads.size()==1 and scene.city.roads[0].lanes==4 and scene.city.zoning_grid.count()>0,"UI commits chosen width and reveals zoning")
	await process_frame
	scene.queue_free();await process_frame
	print("RESULT ",checks-failures,"/",checks," road/zoning checks passed")
	quit(1 if failures else 0)
