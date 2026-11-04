extends SceneTree
## Actual category buttons and modal inspectors. No game data is saved or modified.
func _initialize():run.call_deferred()
func capture(path: String):
	for frame in range(8):await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path)==OK)
func run():
	root.gui_embed_subwindows=true
	var output:=OS.get_cmdline_user_args()[0]
	var scene=load("res://bottom_ui_preview.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	var city=scene.city
	var count: int=city.buildings.size()
	for group in ["health","education"]:
		scene.select_category(group)
		await capture(output+"/"+group+"-tab.png")
		if group!="health":continue
		for tool in ["hospital","clinic","large_hospital","crematorium"]:
			var button=scene.find_child("Tool_"+tool,true,false)
			assert(button!=null and not button.disabled)
			button.pressed.emit()
			await process_frame
			var windows=scene.find_children("ServiceAssetPreview","Window",true,false)
			assert(windows.size()==1)
			await capture(output+"/"+tool+".png")
			print("SERVICE_UI_CAPTURE ",tool," title=",windows[0].title)
			windows[0].close_requested.emit()
			await process_frame
	assert(scene.city==city and scene.city.buildings.size()==count)
	print("SERVICE_UI_PRESERVED_CITY ",count)
	quit()
