extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var base := String(args[0]).get_base_dir()
	var count := 0
	for entry in catalog.parts:
		var folder := base.path_join(String(entry.id))
		var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("spec.json")))
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(folder.path_join(spec.part_model), state) == OK)
		var model := document.generate_scene(state)
		assert(model != null)
		root.add_child(model)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var skeletons := model.find_children("*", "Skeleton3D", true, false)
		assert(meshes.size() == 1 and skeletons.size() == 1 and skeletons[0].get_bone_count() == 14)
		var bound: AABB = meshes[0].global_transform * meshes[0].mesh.get_aabb()
		var expected: Array = spec.layer_z_bounds[spec.variant_layer]
		assert(absf(bound.position.y-float(expected[0])) < 0.0001 and absf(bound.end.y-float(expected[1])) < 0.0001)
		model.free()
		count += 1
	assert(count == {"adult-tops":6,"adult-bottoms":4,"child":14}[catalog.batch])
	print("CITIZEN_REMAINING_GLB_OK batch=",catalog.batch," source_models=",count," bones=14")
	quit(0)
