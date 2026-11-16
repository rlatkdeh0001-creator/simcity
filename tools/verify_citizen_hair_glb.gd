extends SceneTree
## Source-format smoke only: optional bind-pose GLBs, not3D game integration.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var base := String(args[0]).get_base_dir()
	var count := 0
	for entry in catalog.parts:
		var path := base.path_join(String(entry.id)).path_join("hair.glb")
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(path, state) == OK)
		var model := document.generate_scene(state)
		assert(model != null)
		root.add_child(model)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var skeletons := model.find_children("*", "Skeleton3D", true, false)
		assert(meshes.size() == 1 and skeletons.size() == 1)
		assert(skeletons[0].get_bone_count() == 14)
		var bound: AABB = meshes[0].global_transform * meshes[0].mesh.get_aabb()
		assert(bound.position.y >= 1.4299 and absf(bound.end.y-1.75) < 0.0001)
		model.free()
		count += 1
	assert(count == 10)
	print("CITIZEN_HAIR_GLB_LOAD_OK parts=", count, " skeleton=14 height_endpoint=1.75")
	quit(0)
