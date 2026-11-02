extends SceneTree
var failed := false
func _initialize():
	call_deferred("run")
func verify(value: bool, label: String):
	if value: print("PASS ", label)
	else:
		failed = true
		push_error(label)
func click(scene, cell: Vector2):
	var event := InputEventMouseButton.new()
	event.position = scene.screen(cell)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	scene._unhandled_input(event)
func run():
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	verify(scene.city.difficulty == "normal" and scene.city.funds == 50000, "normal difficulty starts with 50000 doth")
	verify(scene.treasury_label.text == "자금: 50,000 doth", "treasury displays confirmed currency and starting amount")
	verify(scene.city.width == 100 and scene.city.height == 100 and scene.city.buildings.is_empty() and scene.city.roads.is_empty() and scene.city.zoning_grid.count() == 0, "100x100 scene starts empty with no zoning grid")
	scene.map_zoom = 1.0
	scene.city.add_road(PackedVector2Array([Vector2(1,20),Vector2(39,20)]))
	scene.city.add_building(10,17,"residential",120)
	scene.city.add_building(12,17,"commercial",10)
	scene.city.add_building(14,17,"industrial",5)
	scene.refresh()
	verify(scene.pick_rendered_building(scene.screen(Vector2(11,18)) - Vector2(0,12)).get("id",-1) == 1, "elevated roof can be selected")
	scene.mode = "select"
	click(scene, Vector2(10.5,17.5))
	verify(scene.selected == 1 and "120" in scene.info.text, "isometric click selects building and displays score")
	var panel = scene.controls_panel.get_child(0)
	for child in panel.get_children():
		if child is Button and child.text == "선택 건물 업그레이드": child.emit_signal("pressed")
	verify(scene.city.find_building(1).level == 2, "upgrade button calls simulation")
	scene.mode = "build"
	var before: int = scene.city.buildings.size()
	click(scene, Vector2(27,18))
	verify(scene.city.buildings.size() == before and scene.zoning_drag, "press begins zoning without instant construction")
	scene.finish_zoning(scene.screen(Vector2(31,18)))
	verify(not scene.city.zone_designations.is_empty(), "drag release designates road-local cells")
	scene.city.advance_development(2)
	verify(scene.city.buildings.size() == before + 1, "painted lot develops on simulation tick")

	scene.mode = "road"
	click(scene, Vector2(2.3,3.7))
	for point in [Vector2(4.2,5.1),Vector2(7.8,4.2),Vector2(10.6,7.4)]:
		var motion := InputEventMouseMotion.new()
		motion.position = scene.screen(point)
		scene._unhandled_input(motion)
	scene.finish_road()
	verify(scene.city.roads.size() == 2 and scene.city.roads[1].points.size() == 4, "free road pointer stroke retains fractional geometry")
	scene.city.funds = 12345
	scene.refresh()
	verify(scene.treasury_label.text == "자금: 12,345 doth", "treasury reflects current city balance")
	for child in panel.get_children():
		if child is Button and child.text == "도시 초기화": child.emit_signal("pressed")
	verify(scene.city.funds == 50000 and scene.treasury_label.text == "자금: 50,000 doth", "city reset restores normal starting funds")
	await process_frame
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)
