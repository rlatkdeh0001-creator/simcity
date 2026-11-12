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
	var recovered:Array=facilities.filter(func(e):return e.get("recovered_original",false) and e.get("group","") in ["education","medical"])
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
	scene.paused=true
	root.add_child(scene)
	current_scene=scene
	root.gui_embed_subwindows=true
	root.size=Vector2i(1280,820)
	await process_frame
	var city_before=scene.city
	var buildings_before:int=scene.city.buildings.size()
	verify(not scene.NAMES.has("other"),"empty other tab remains removed")
	var groups:={"education":["elementary","high_school","college","university"],"health":["hospital","clinic","large_hospital","crematorium"]}
	# This exercises successful asset selection, not the separately tested cash rejection.
	var required_balance:=0.0
	for group in groups:
		for tool in groups[group]:required_balance=maxf(required_balance,scene.city.public_facilities.price(scene.SERVICE_TOOLS[tool]))
	scene.city.funds=maxi(scene.city.funds,ceili(required_balance))
	var funds_before: int=scene.city.funds
	for group in groups:
		scene.select_category(group)
		var expected: Array=groups[group]
		var buttons: Array=scene.drawer_box.get_children().filter(func(node):return node is Button and String(node.name).begins_with("Tool_"))
		verify(buttons.size()==expected.size(),group+" has exactly its four facilities")
		for tool in expected:
			var button=scene.find_child("Tool_"+tool,true,false)
			verify(button!=null,tool+" has a visible category button")
			if button==null:continue
			verify(not button.disabled,tool+" is available")
			var entry: Dictionary=facilities.filter(func(e):return e.id==scene.SERVICE_TOOLS[tool])[0]
			button.pressed.emit()
			await process_frame
			var windows:Array=scene.find_children("ServiceAssetPreview","Window",true,false)
			verify(windows.is_empty() and scene.mode=="public_placement" and scene.public_controller.asset_id==entry.id,tool+" selects its approved city-placement model")
			var placed_model=load(entry.model).instantiate()
			verify(not placed_model.find_children("*","MeshInstance3D",true,false).is_empty(),tool+" placement source contains real geometry")
			placed_model.free()
			await process_frame
	verify(scene.city==city_before and scene.city.buildings.size()==buildings_before and scene.city.funds==funds_before,"asset selection preserves city and funds without fake service placement")
	scene.queue_free()
	await process_frame
	print("RESULT %d/%d recovered asset checks passed"%[checks-failures,checks])
	quit(1 if failures else 0)
