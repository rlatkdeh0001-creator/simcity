extends SceneTree

var checked := 0
var failed := 0

func _initialize():
	run.call_deferred()

func verify(condition: bool, detail: String):
	checked += 1
	if not condition:
		failed += 1
		push_error("FAIL " + detail)
	else: print("PASS " + detail)

func run():
	var doc = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json"))
	verify(doc is Dictionary and doc.vehicles.size() == 41, "catalog contains 23 registered plus 18 original variants")
	var categories := {}
	var ids := {}
	for entry in doc.vehicles:
		verify(not ids.has(entry.id), entry.id + " unique ID")
		ids[entry.id] = true
		categories[entry.category] = categories.get(entry.category, 0) + 1
		var resource = load(entry.model)
		verify(resource is PackedScene, entry.id + " imports as PackedScene")
		if not resource is PackedScene: continue
		var model: Node3D = resource.instantiate()
		root.add_child(model)
		var spins := model.find_children("Wheel_*_Spin", "Node3D", true, false)
		verify(spins.size() >= 4, entry.id + " has at least four wheel spin pivots")
		var hierarchy_ok := true
		var has_front := false
		for spin in spins:
			hierarchy_ok = hierarchy_ok and spin.get_parent().name.begins_with("Wheel_") and spin.get_child_count() >= 2
			if spin.name == "Wheel_FL_Spin": has_front = spin.global_position.x > 0 and spin.global_position.z > 0
		verify(hierarchy_ok and has_front, entry.id + " spin hierarchy; +X left and +Z nose")
		var seats := model.find_children("Seat_FL", "Node3D", true, false)
		verify(seats.size() == 1 and seats[0].global_position.x > 0, entry.id + " left-hand driver anchor")
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var bounds := AABB()
		var first := true
		for node in meshes:
			var transformed: AABB = node.global_transform * node.get_aabb()
			bounds = transformed if first else bounds.merge(transformed)
			first = false
		verify(absf(bounds.position.y) < 0.025, entry.id + " tyres meet ground at y=0")
		verify(bounds.size.z >= float(entry.length_m) * 0.95 and bounds.size.z <= float(entry.length_m) * 1.15, entry.id + " length remains metres after GLB import")
		if entry.category == "bus":
			var doors := model.find_children("PassengerDoor_R*", "MeshInstance3D", true, false)
			var right := doors.size() == 4
			# Procedural boxes store their position in mesh vertices, with origin at
			# the root. Check the actual door geometry, not its transform origin.
			for door in doors:
				var center: Vector3 = door.global_transform * door.get_aabb().get_center()
				right = right and center.x < 0
			verify(right, "bus has front and middle right-side double doors")
		if entry.style in ["container", "tanker"]:
			var pivot_name: String="Trailer_Pivot" if entry.get("rig_schema","")=="recovered-original" else "TrailerHitch"
			verify(model.find_children(pivot_name, "Node3D", true, false).size() == 1, entry.id + " articulation pivot")
		if entry.style in ["dump", "heavy_dump"]:
			var pivot_name: String="Dump_Bed_Pivot" if entry.get("rig_schema","")=="recovered-original" else "DumpBedPivot"
			verify(model.find_children(pivot_name, "Node3D", true, false).size() == 1, entry.id + " dump bed hinge")
		if entry.style == "mixer":
			var pivot_name: String="Mixer_Drum_Pivot" if entry.get("rig_schema","")=="recovered-original" else "MixerSpin"
			verify(model.find_children(pivot_name, "Node3D", true, false).size() == 1, entry.id + " mixer drum spin pivot")
		model.free()
	verify(categories == {"bus":1, "taxi":1, "civilian":20, "industrial":16, "service":3}, "required category counts; bus and taxi originals excluded")
	var main: Node2D = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main.map_zoom = 1.23
	main.origin = Vector2(501, 211)
	var saved_city = main.city
	var buttons := main.find_children("VehicleShowcaseButton", "Button", true, false)
	verify(buttons.size() == 1 and buttons[0].visible, "main screen offers vehicle showcase button")
	buttons[0].pressed.emit()
	await process_frame
	await process_frame
	var showcase = current_scene
	verify(showcase != null and showcase.scene_file_path == "res://vehicle_showcase.tscn", "button opens actual vehicle showcase scene")
	verify(showcase.rigs.size() == 41 and showcase.cameras.size() == 41, "showcase creates forty-one real model viewports")
	showcase.same_scale = true
	showcase.update_scale()
	verify(is_equal_approx(showcase.cameras[0].size, showcase.cameras[19].size), "same-scale mode uses identical camera scale")
	showcase.same_scale = false
	showcase.update_scale()
	verify(showcase.cameras[0].size > showcase.cameras[2].size, "auto-fit respects bus and hatchback size")
	showcase.rotating = true
	showcase.spinning = true
	var before: float = showcase.rigs[0].rotation.y
	showcase._process(0.1)
	verify(showcase.rigs[0].rotation.y > before, "turntable rotates models")
	var spin = showcase.rigs[0].find_children("Wheel_FL_Spin", "Node3D", true, false)[0]
	verify(absf(spin.rotation.x) > 0, "wheel toggle rotates spin pivot")
	showcase.find_children("ReturnToConstruction", "Button", true, false)[0].pressed.emit()
	await process_frame
	await process_frame
	verify(current_scene.city == saved_city and is_equal_approx(current_scene.map_zoom, 1.23) and current_scene.origin == Vector2(501, 211), "return restores original city and camera")
	current_scene.queue_free()
	await process_frame
	print("RESULT %d/%d vehicle checks passed" % [checked - failed, checked])
	quit(1 if failed else 0)
