extends SceneTree
## Match the existing traffic manifest: 000 = nose, +45 towards left (+X).
## Only render recovered variants; do not touch any existing registered sprite.
var stage: SubViewport

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	stage=SubViewport.new()
	stage.size=Vector2i(430,245)
	stage.own_world_3d=true
	stage.transparent_bg=true
	stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	stage.msaa_3d=Viewport.MSAA_2X
	root.add_child(stage)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.65
	stage.add_child(environment)
	for setup in [[Vector3(-55,-35,0),.95],[Vector3(-25,140,0),.35]]:
		var light:=DirectionalLight3D.new()
		light.rotation_degrees=setup[0]
		light.light_energy=setup[1]
		stage.add_child(light)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.current=true
	stage.add_child(camera)
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json"))
	var manifest_path:="res://assets/vehicles/original_render_manifest.json"
	var additions:Array=[]
	for entry:Dictionary in catalog.vehicles:
		if entry.get("rig_schema","")!="recovered-original":continue
		var model:Node3D=load(entry.model).instantiate()
		stage.add_child(model)
		var diagonal:=Vector2(entry.length_m,entry.width_m).length()
		var horizontal:=maxf(diagonal,(diagonal*.5+entry.height_m*.866)*430.0/245)*1.16
		camera.size=horizontal*245/430
		var target:=Vector3(0,entry.height_m*.48,0)
		var path:String="res://assets/vehicles/sprites/"+entry.id
		DirAccess.make_dir_recursive_absolute(path)
		for angle in range(0,360,45):
			var azimuth:=deg_to_rad(angle)
			camera.position=target+Vector3(sin(azimuth)*15,15*tan(deg_to_rad(30)),cos(azimuth)*15)
			camera.look_at(target)
			for frame in range(3):await process_frame
			await RenderingServer.frame_post_draw
			var error:=stage.get_texture().get_image().save_png(path+"/%03d.png"%angle)
			if error!=OK:
				push_error("Sprite capture failed: "+entry.id)
				quit(1)
				return
		additions.append({"id":entry.id,"pixels_per_metre":430/horizontal,"angles_deg":[0,45,90,135,180,225,270,315]})
		print("ORIGINAL_SPRITES ",entry.id)
		model.queue_free()
		await process_frame
	var manifest:Dictionary={"vehicles":additions}
	var output:=FileAccess.open(manifest_path,FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest,"  ")+"\n")
	output.close()
	stage.queue_free()
	await process_frame
	print("RESULT ",additions.size()," vehicles / ",additions.size()*8," new directional frames")
	quit()
