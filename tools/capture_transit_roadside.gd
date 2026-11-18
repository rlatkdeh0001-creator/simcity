extends SceneTree
## Read-only road-edge GLB inspection: one real framebuffer for all three facilities.
var capture_path := "res://../docs/transit-validation/roadside-1600.png"
var checks := 0

func _initialize():
	run.call_deferred()

func label(text: String, pos: Vector2, font_size: int=22):
	var node:=Label.new();node.text=text;node.position=pos
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",Color("f2f5ed"));root.add_child(node)

func stage_at(pos: Vector2, dimensions: Vector2i, span: float, target: Vector3) -> SubViewport:
	var holder:=SubViewportContainer.new();holder.position=pos;holder.size=dimensions;root.add_child(holder)
	var stage:=SubViewport.new();stage.size=dimensions;stage.own_world_3d=true
	stage.msaa_3d=Viewport.MSAA_4X;stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS;holder.add_child(stage)
	var world:=WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("b9cac3")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.70;stage.add_child(world)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);light.light_energy=1.;stage.add_child(light)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=span;stage.add_child(camera)
	camera.position=target+Vector3(18,30,45);camera.look_at(target);camera.current=true
	return stage

func model(stage: SubViewport, path: String, pos: Vector3=Vector3.ZERO, yaw: float=0.) -> Node3D:
	var packed=load(path);assert(packed is PackedScene,"Model load failed: "+path)
	var item:Node3D=packed.instantiate();stage.add_child(item);item.position=pos;item.rotation_degrees.y=yaw
	return item

func bounds(item: Node3D) -> AABB:
	var result:=AABB();var first:=true
	for child in item.find_children("*","MeshInstance3D",true,false):
		var box:AABB=child.global_transform*child.get_aabb()
		if first:result=box;first=false
		else:result=result.merge(box)
	return result

func road(stage: SubViewport, width: float):
	var slab:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(width,.08,4.8);slab.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("4c5659");mat.roughness=.9;slab.material_override=mat
	stage.add_child(slab);slab.position=Vector3(0,-.04,2.4)

func person(stage: SubViewport, pos: Vector3):
	var body:=MeshInstance3D.new();var mesh:=CapsuleMesh.new();mesh.height=1.75;mesh.radius=.20;body.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("ad7860");body.material_override=mat
	stage.add_child(body);body.position=pos+Vector3(0,.875,0)

func facility(stage: SubViewport,id: String,w: float,d: float) -> Node3D:
	var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/facilities/catalog.json"))
	var entries:Array=doc.facilities.filter(func(e):return e.id==id);assert(entries.size()==1)
	var entry:Dictionary=entries[0];assert(entry.placement=="road_edge")
	var item:=model(stage,entry.model);var box:=bounds(item)
	assert(abs(box.position.x+w/2)<.002 and abs(box.end.x-w/2)<.002)
	assert(abs(box.position.z+d)<.002 and abs(box.end.z)<.002)
	assert(item.position==Vector3.ZERO)
	checks+=4
	return item

func run():
	root.size=Vector2i(1600,1000)
	var bg:=ColorRect.new();bg.size=Vector2(1600,1000);bg.color=Color("172d35");root.add_child(bg)
	label("ROAD EDGE / three original facilities / loaded GLBs + existing vehicles",Vector2(20,12),28)
	label("bus-stop-01  /  8 x 3m",Vector2(20,65),23)
	var stop:=stage_at(Vector2(20,105),Vector2i(500,825),23.5,Vector3(1.8,1,-.2))
	var shelter:=facility(stop,"bus-stop-01",8.,3.)
	road(stop,18.)
	model(stop,"res://assets/vehicles/bus-city-01.glb",Vector3(2.5,0,1.65),-90)
	person(stop,Vector3(2.8,.1,-1.2))
	assert(not shelter.find_children("StopZoneYellowDecal*","MeshInstance3D",true,false).is_empty())
	checks+=1
	label("bus-station-01  /  32 x 12m  /  3 buses in 12 x 2.8m bays",Vector2(540,65),23)
	var station:=stage_at(Vector2(540,105),Vector2i(1040,410),18.5,Vector3(0,1,-4.3))
	facility(station,"bus-station-01",32.,12.);road(station,36.)
	for y in [2.,5.5,9.]:
		var bus:=model(station,"res://assets/vehicles/bus-city-01.glb",Vector3(0,.1,-y),-90)
		var b:=bounds(bus);assert(b.size.x<12. and b.size.z<2.8)
		checks+=1
	person(station,Vector3(-3,.22,-11.1))
	label("taxi-stand-01  /  24 x 8m  /  4 taxis in 2.6 x 5.2m bays",Vector2(540,540),23)
	var taxi_stage:=stage_at(Vector2(540,580),Vector2i(1040,350),14.5,Vector3(0,.8,-2.7))
	facility(taxi_stage,"taxi-stand-01",24.,8.);road(taxi_stage,28.)
	for x in [-4.5,-1.5,1.5,4.5]:
		var taxi:=model(taxi_stage,"res://assets/vehicles/taxi-sedan-01.glb",Vector3(x,.1,-3.35))
		var b:=bounds(taxi);assert(b.size.x<2.6 and b.size.z<5.2)
		checks+=1
	person(taxi_stage,Vector3(4,.22,-7.0))
	label("Origin = road-contact edge centre | glass shelter + separate yellow mesh | 1.75m mannequins",Vector2(20,945),20)
	label("Inspection only - live attachment, vehicle turning paths and passenger operations are not implemented",Vector2(20,973),18)
	for frame in range(14):await process_frame
	await RenderingServer.frame_post_draw
	var output:=ProjectSettings.globalize_path(capture_path);DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1600,1000));assert(image.save_png(output)==OK)
	print("ROADSIDE_GRAPHICAL_PASS ",checks," checks; 3 facility GLBs; 4 buses / 4 taxis in fixture; ",output)
	quit()
