extends SceneTree
## One unmodified framebuffer: matched v3 lead + two coaches, side and 3/4.
var checks:=0
func _initialize():run.call_deferred()

func label(text: String,pos: Vector2,size: int=23):
	var node:=Label.new();node.text=text;node.position=pos;node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",Color("f2f5ed"));root.add_child(node)

func stage(pos: Vector2,dimensions: Vector2i,span: float,offset: Vector3) -> SubViewport:
	var holder:=SubViewportContainer.new();holder.position=pos;holder.size=dimensions;root.add_child(holder)
	var viewport:=SubViewport.new();viewport.size=dimensions;viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;holder.add_child(viewport)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("c7d4d1")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7;viewport.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);light.light_energy=1.;viewport.add_child(light)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=span;viewport.add_child(camera)
	var target:=Vector3(0,1.9,0);camera.position=target+offset;camera.look_at(target);camera.current=true
	return viewport

func model(viewport: SubViewport,entry: Dictionary,x: float) -> Node3D:
	var packed=load(entry.model);assert(packed is PackedScene)
	var instance:Node3D=packed.instantiate();viewport.add_child(instance)
	instance.position.x=x;instance.rotation_degrees.y=90
	return instance

func bounds(node: Node3D) -> AABB:
	var result:=AABB();var first:=true
	for child in node.find_children("*","MeshInstance3D",true,false):
		var box:AABB=child.global_transform*child.get_aabb()
		if first:result=box;first=false
		else:result=result.merge(box)
	return result

func consist(viewport: SubViewport):
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json"))
	var lead:Dictionary=catalog.vehicles.filter(func(e):return e.id=="train-loco-01")[0]
	var coach:Dictionary=catalog.vehicles.filter(func(e):return e.id=="train-passenger-01")[0]
	assert(lead.model.ends_with("train-loco-01-v3.glb"))
	assert(coach.model.ends_with("train-passenger-01-v3.glb"))
	var a:=model(viewport,lead,11.);var b:=model(viewport,coach,.5);var c:=model(viewport,coach,-10.5)
	var aa:=bounds(a);var bb:=bounds(b);var cc:=bounds(c)
	assert(abs(aa.position.x-bb.end.x)<.001)
	assert(abs(bb.position.x-cc.end.x)<.001)
	assert(abs(aa.end.x-cc.position.x-32.)<.001)
	assert(abs(aa.size.y-3.8)<.001 and abs(aa.size.z-3.)<.001)
	assert((a.global_basis*Vector3(0,0,1)).distance_to(Vector3.RIGHT)<.001)
	assert(abs(bb.size.y-3.8)<.001 and abs(cc.size.y-3.8)<.001)
	checks+=8

func run():
	root.size=Vector2i(1600,1000)
	var bg:=ColorRect.new();bg.size=Vector2(1600,1000);bg.color=Color("172d35");root.add_child(bg)
	label("HIGH-SPEED TRAIN v3 / long thin wedge + matched ribbon-window coaches",Vector2(20,12),27)
	label("SIDE / 4.5m nose taper / 1.2m tip width / lead and coaches share 3.8m height + end profile",Vector2(20,60),22)
	var side:=stage(Vector2(20,100),Vector2i(1560,300),7.5,Vector3(0,0,45));consist(side)
	label("FRONT THREE-QUARTER / 32m consist / continuous stripe and lower skirts / one recessed pantograph",Vector2(20,425),21)
	var three_quarter:=stage(Vector2(20,465),Vector2i(1560,475),14.5,Vector3(30,18,35));consist(three_quarter)
	label("New v3 originals and GLBs only | v1/v2 preserved | asset inspection, not transport operation",Vector2(20,960),20)
	for frame in range(14):await process_frame
	await RenderingServer.frame_post_draw
	var output:=ProjectSettings.globalize_path("res://../docs/transit-validation/train-v3-consist-1600.png")
	var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1600,1000));assert(image.save_png(output)==OK)
	print("TRAIN_V3_GRAPHICAL_PASS ",checks," checks; v3 lead + 2 coaches, equal height, 32m, side/3-4; ",output)
	quit()
