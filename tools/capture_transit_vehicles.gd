extends SceneTree
## Read-only graphical asset fixture; no product code or source model changes.
var output := ""
var verified := 0

func _initialize():
	output = ProjectSettings.globalize_path("res://../docs/transit-validation/vehicles-v2-1600.png")
	run.call_deferred()

func stage_at(pos: Vector2, dimensions: Vector2i, span: float, target: Vector3) -> SubViewport:
	var holder := SubViewportContainer.new()
	holder.position = pos
	holder.size = dimensions
	root.add_child(holder)
	var stage := SubViewport.new()
	stage.size = dimensions
	stage.own_world_3d = true
	stage.msaa_3d = Viewport.MSAA_4X
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("c7d4d1")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .7
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-35,0)
	light.light_energy = 1.0
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = span
	stage.add_child(camera)
	camera.position = target + Vector3(10,30,50)
	camera.look_at(target)
	camera.current = true
	return stage

func label(text: String, pos: Vector2, font_size: int = 22):
	var node := Label.new()
	node.text = text
	node.position = pos
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color("f2f5ed"))
	root.add_child(node)

func model(stage: SubViewport, id: String, pos: Vector3, yaw: float = 90.0) -> Node3D:
	var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json"))
	var entries:Array=doc.vehicles.filter(func(e):return e.id==id)
	assert(entries.size()==1,"Missing or duplicate catalog ID: "+id)
	var packed = load(entries[0].model)
	assert(packed is PackedScene, "GLB not loaded: "+id)
	var instance: Node3D = packed.instantiate()
	stage.add_child(instance)
	instance.position = pos
	instance.rotation_degrees.y = yaw
	return instance

func bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = child.global_transform * child.get_aabb()
		if first: result=box; first=false
		else: result=result.merge(box)
	return result

func tint(node: Node3D, color: Color):
	for child in node.find_children("*", "MeshInstance3D", true, false):
		for surface in range(child.mesh.get_surface_count()):
			var mat: StandardMaterial3D = child.mesh.surface_get_material(surface).duplicate()
			mat.albedo_color=color
			child.set_surface_override_material(surface,mat)

func person(stage: SubViewport, pos: Vector3):
	# Explicit 1.75m scale mannequin, not a production citizen asset.
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius=.20; mesh.height=1.75
	body.mesh=mesh
	var mat := StandardMaterial3D.new(); mat.albedo_color=Color("8c6550")
	body.material_override=mat
	stage.add_child(body); body.position=pos+Vector3(0,.875,0)

func run():
	root.size=Vector2i(1600,1000)
	var bg:=ColorRect.new(); bg.color=Color("172d35"); bg.size=Vector2(1600,1000); root.add_child(bg)
	label("TRANSIT / original geometry / Godot GLB inspection",Vector2(20,12),28)
	label("32m consist: locomotive + two coaches | bus 10.8m / taxi 4.65m / person 1.75m",Vector2(20,52))
	var top:=stage_at(Vector2(20,90),Vector2i(1560,340),12.0,Vector3(0,1,0))
	var loco:=model(top,"train-loco-01",Vector3(11,0,-3))
	var coach:=model(top,"train-passenger-01",Vector3(.5,0,-3))
	var coach2:=model(top,"train-passenger-01",Vector3(-10.5,0,-3))
	model(top,"bus-city-01",Vector3(-8,0,4))
	model(top,"taxi-sedan-01",Vector3(2,0,4))
	person(top,Vector3(6,0,4))
	var lb:=bounds(loco); var cb:=bounds(coach); var cb2:=bounds(coach2)
	assert(abs(lb.position.x-cb.end.x)<.001,"First coupler heads do not meet")
	assert(abs(cb.position.x-cb2.end.x)<.001,"Second coupler heads do not meet")
	assert(abs(lb.end.x-cb2.position.x-32.0)<.001,"Consist is not 32m")
	verified+=3
	label("7m flatcar + independent 6.06m container / deck z=1.20m",Vector2(20,449),21)
	var cargo:=stage_at(Vector2(20,484),Vector2i(760,460),10.5,Vector3(0,1.6,0))
	var flat:=model(cargo,"train-flatcar-01",Vector3.ZERO,35)
	var load_model:=model(cargo,"container-20ft-01",Vector3(0,1.2,0),35)
	# Verify contact plane and unrotated local envelope from registered metadata.
	var flat_spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../assets/vehicle-fleet/train-flatcar-01/spec.json"))
	assert(is_equal_approx(float(flat_spec.container_load_origin_blender[2]),1.2))
	assert(abs(bounds(load_model).position.y-1.2)<.001)
	verified+=2
	label("ContainerPaint / one tintable material / red, blue, green, grey",Vector2(820,449),21)
	var colors:=stage_at(Vector2(820,484),Vector2i(760,460),15.0,Vector3(0,1.2,0))
	var palette:=[Color("a35f50"),Color("527b9b"),Color("668274"),Color("929b9d")]
	for i in range(4):
		var item:=model(colors,"container-20ft-01",Vector3(-3.5+7*(i%2),0,-2.2+4.4*floori(i/2.0)),90)
		tint(item,palette[i])
	label("Viewing fixture only - no map placement, railway operation or transport simulation",Vector2(20,960),20)
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var image:=root.get_texture().get_image()
	assert(image.get_size()==Vector2i(1600,1000))
	var error:=image.save_png(output)
	assert(error==OK)
	print("TRANSIT_GRAPHICAL_PASS ",verified," connection/load checks; 4 new GLBs loaded; 32m consist; capture ",output)
	quit()
