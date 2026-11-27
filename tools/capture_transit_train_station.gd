extends SceneTree
## Two actual GLB views in one raw framebuffer. Rails/cars/train are fixture-only.
var checks:=0
func _initialize():run.call_deferred()

func label(text: String,pos: Vector2,size: int=22):
	var item:=Label.new();item.text=text;item.position=pos;item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",Color("f2f5ed"));root.add_child(item)

func stage(pos: Vector2,dimensions: Vector2i,span: float,offset: Vector3) -> SubViewport:
	var holder:=SubViewportContainer.new();holder.position=pos;holder.size=dimensions;root.add_child(holder)
	var viewport:=SubViewport.new();viewport.size=dimensions;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;holder.add_child(viewport)
	var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color("c2cfc7");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.7;viewport.add_child(world)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);light.light_energy=1.;viewport.add_child(light)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=span;viewport.add_child(camera)
	var target:=Vector3(0,3,-1.5);camera.position=target+offset;camera.look_at(target);camera.current=true
	return viewport

func bounds(item: Node3D) -> AABB:
	if item is MeshInstance3D:return item.global_transform*item.get_aabb()
	var result:=AABB();var first:=true
	for child in item.find_children("*","MeshInstance3D",true,false):
		var b:AABB=child.global_transform*child.get_aabb()
		if first:result=b;first=false
		else:result=result.merge(b)
	return result

func model(viewport: SubViewport,path: String,pos: Vector3=Vector3.ZERO,yaw: float=0.) -> Node3D:
	var packed=load(path);assert(packed is PackedScene)
	var node:Node3D=packed.instantiate();viewport.add_child(node);node.position=pos;node.rotation_degrees.y=yaw
	return node

func fixture_box(viewport: SubViewport,name: String,size: Vector3,pos: Vector3,color: Color):
	var node:=MeshInstance3D.new();node.name=name;var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;node.material_override=mat;viewport.add_child(node);node.position=pos

func person(viewport: SubViewport,pos: Vector3):
	var node:=MeshInstance3D.new();var mesh:=CapsuleMesh.new();mesh.radius=.20;mesh.height=1.75;node.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("b28063");node.material_override=mat;viewport.add_child(node);node.position=pos+Vector3(0,.875,0)

func scene(viewport: SubViewport):
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/facilities/catalog.json"))
	var entry:Dictionary=catalog.facilities.filter(func(e):return e.id=="train-station-01")[0]
	var station:=model(viewport,entry.model);var b:=bounds(station)
	assert(abs(b.size.x-32.)<.002 and abs(b.size.z-24.)<.002)
	assert(entry.storeys==2 and entry.platform_length_m==32 and entry.track_included==false)
	var platform:Node3D=station.find_child("RearPlatform32m",true,false)
	assert(platform!=null and abs(bounds(platform).end.y-1.1)<.002)
	var vehicles:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json"))
	var lead:Dictionary=vehicles.vehicles.filter(func(e):return e.id=="train-loco-01")[0]
	var coach:Dictionary=vehicles.vehicles.filter(func(e):return e.id=="train-passenger-01")[0]
	assert(lead.model.ends_with("train-loco-01-v3.glb") and coach.model.ends_with("train-passenger-01-v3.glb"))
	var a:=model(viewport,lead.model,Vector3(11,0,-13.8),90)
	var c:=model(viewport,coach.model,Vector3(.5,0,-13.8),90)
	var d:=model(viewport,coach.model,Vector3(-10.5,0,-13.8),90)
	var aa:=bounds(a);var cc:=bounds(c);var dd:=bounds(d)
	assert(abs(aa.position.x-cc.end.x)<.002)
	assert(abs(cc.position.x-dd.end.x)<.002)
	assert(abs(aa.end.x-dd.position.x-32.)<.002)
	var gap:=b.position.z-aa.end.z
	assert(gap>.20 and gap<.40,"Train overlaps or sits too far from platform")
	checks+=8
	# Display-only rails: top y=0 matches the vehicle's authored rail datum.
	fixture_box(viewport,"FixtureBallastOnly",Vector3(34,.10,3.8),Vector3(0,-.12,-13.8),Color("8b9690"))
	for dz in [-.7175,.7175]:fixture_box(viewport,"FixtureRailOnly",Vector3(34,.06,.07),Vector3(0,-.03,-13.8+dz),Color("667779"))
	model(viewport,"res://assets/vehicles/taxi-sedan-01.glb",Vector3(-6.5,.14,7.3),-90)
	model(viewport,"res://assets/vehicles/car-sedan-03.glb",Vector3(1.0,.14,7.3),-90)
	person(viewport,Vector3(12,.22,5.4));person(viewport,Vector3(-10,1.1,-10.5))

func run():
	root.size=Vector2i(1600,1000)
	var bg:=ColorRect.new();bg.size=Vector2(1600,1000);bg.color=Color("172d35");root.add_child(bg)
	label("TRAIN STATION / 32 x 24m / tall glass atrium + 32m covered rear platform",Vector2(20,12),26)
	label("FRONT / drop-off plaza, taxi + car, 1.75m scale",Vector2(20,66),21)
	label("REAR / v3 lead car + two coaches = 32m",Vector2(860,66),21)
	var front:=stage(Vector2(20,105),Vector2i(820,800),46.,Vector3(26,31,36));scene(front)
	var rear:=stage(Vector2(860,105),Vector2i(720,800),52.,Vector3(-26,27,-36));scene(rear)
	label("Station source contains no tracks or vehicles; all rail/vehicle context is inspection-only",Vector2(20,935),20)
	label("Static fit and orientation verified; no passenger boarding, drop-off traffic or train operation implemented",Vector2(20,970),19)
	for frame in range(16):await process_frame
	await RenderingServer.frame_post_draw
	var output:=ProjectSettings.globalize_path("res://../docs/transit-validation/train-station-1600.png")
	var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1600,1000));assert(image.save_png(output)==OK)
	print("TRAIN_STATION_GRAPHICAL_PASS ",checks," checks; 32x24m, platform1.1m, 32m v3 consist, platform gap0.3m; ",output)
	quit()
