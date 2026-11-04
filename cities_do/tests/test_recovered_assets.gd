extends SceneTree
var checks:=0
var failures:=0

func verify(value:bool,detail:String) -> void:
	checks+=1
	if value: print("PASS ",detail)
	else:
		failures+=1
		push_error(detail)

func _initialize() -> void:
	root.size=Vector2i(1280,820)
	run.call_deferred()

func run() -> void:
	var facilities:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/services/catalog.json")).facilities
	var recovered:Array=facilities.filter(func(e):return e.get("recovered_original",false))
	verify(recovered.size()==7,"seven approved recovered education/medical assets")
	for entry:Dictionary in recovered:
		var model:Node3D=load(entry.model).instantiate()
		root.add_child(model)
		var meshes:=model.find_children("*","MeshInstance3D",true,false)
		verify(not meshes.is_empty(),entry.id+" has actual imported geometry")
		var bounds:=AABB()
		var first:=true
		for mesh:MeshInstance3D in meshes:
			var box:AABB=mesh.global_transform*mesh.get_aabb()
			bounds=box if first else bounds.merge(box)
			first=false
		verify(bounds.size.is_finite() and absf(bounds.size.x-entry.width*4)<.2 and absf(bounds.size.z-entry.depth*4)<.2,entry.id+" preserves metre footprint")
		verify(not entry.simulation_enabled and entry.status=="asset_preview_only",entry.id+" does not claim operational services")
		model.queue_free()
	await process_frame
	var gallery=load("res://education_medical_showcase.tscn").instantiate()
	root.add_child(gallery)
	await process_frame
	verify(gallery.rigs.size()==7,"education and medical gallery loads all seven models")
	gallery.queue_free()
	await process_frame
	var scene=load("res://bottom_ui_preview.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	root.gui_embed_subwindows=true
	root.size=Vector2i(1280,820)
	await process_frame
	var city_before=scene.city
	var buildings_before:int=scene.city.buildings.size()
	for group in ["education","health"]:
		scene.select_category(group)
		for tool in scene.SERVICE_TOOLS:
			if tool=="crematorium":continue
			var button=scene.find_child("Tool_"+tool,true,false)
			if button==null:continue
			verify(not button.disabled,tool+" is available")
			button.pressed.emit()
			await process_frame
			var windows:Array=scene.find_children("ServiceAssetPreview","Window",true,false)
			verify(windows.size()==1 and windows[0].find_children("*","MeshInstance3D",true,false).size()>0,tool+" opens its own real model")
			if not windows.is_empty():windows[0].close_requested.emit()
			await process_frame
	verify(scene.city==city_before and scene.city.buildings.size()==buildings_before,"asset inspectors preserve city and do not fake service placement")
	scene.queue_free()
	await process_frame
	print("RESULT %d/%d recovered asset checks passed"%[checks-failures,checks])
	quit(1 if failures else 0)
