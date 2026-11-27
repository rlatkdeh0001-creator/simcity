extends SceneTree
func _initialize():run.call_deferred()
func text(value:String,pos:Vector2,size:int=22):
	var l:=Label.new();l.text=value;l.position=pos;l.add_theme_font_size_override("font_size",size);root.add_child(l)
func bounds(n:Node3D)->AABB:
	if n is MeshInstance3D:return n.global_transform*n.get_aabb()
	var b:=AABB();var first:=true
	for m in n.find_children("*","MeshInstance3D",true,false):
		var a:AABB=m.global_transform*m.get_aabb()
		if first:b=a;first=false
		else:b=b.merge(a)
	return b
func model(v:SubViewport,path:String,p:Vector3)->Node3D:
	var scene=load(path);assert(scene is PackedScene)
	var n:Node3D=scene.instantiate();v.add_child(n);n.position=p;return n
func run():
	root.size=Vector2i(1600,1000)
	var bg:=ColorRect.new();bg.size=Vector2(1600,1000);bg.color=Color("172d35");root.add_child(bg)
	text("LARGE PARK / 32 x 32m / 24 trees + shallow pond + loop walk + gazebo",Vector2(20,14),27)
	var holder:=SubViewportContainer.new();holder.position=Vector2(0,65);root.add_child(holder)
	var v:=SubViewport.new();v.size=Vector2i(1600,850);v.own_world_3d=true;v.msaa_3d=Viewport.MSAA_4X;holder.add_child(v)
	var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("c2cfc7");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.7;v.add_child(world)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);v.add_child(light)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=66.;v.add_child(camera);camera.position=Vector3(49,49,66);camera.look_at(Vector3(8,1,0));camera.current=true
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/facilities/catalog.json"))
	var entry:Dictionary=catalog.facilities.filter(func(e):return e.id=="park-large-8x8")[0]
	var park:=model(v,entry.model,Vector3.ZERO);var b:=bounds(park)
	assert(abs(b.size.x-32)<.002 and abs(b.size.z-32)<.002 and abs(b.position.y)<.002)
	assert(entry.width==8 and entry.depth==8 and entry.tree_count==24 and entry.pond_is_shallow_overlay_not_hole)
	var entrance:Node3D=park.find_child("FrontEntryPlaza",true,false)
	assert(entrance!=null and bounds(entrance).position.z>11.9 and entry.frame_gltf.front=="+Z")
	var small:=model(v,"res://assets/facilities/park-plaza-4x4.glb",Vector3(27,0,0));assert(abs(bounds(small).size.x-16)<.01)
	model(v,"res://assets/vehicles/taxi-sedan-01.glb",Vector3(2,0,18))
	var person:=MeshInstance3D.new();var capsule:=CapsuleMesh.new();capsule.radius=.2;capsule.height=1.75;person.mesh=capsule;v.add_child(person);person.position=Vector3(-2,.875,17.5)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("b28063");person.material_override=mat
	text("LEFT: new 8 x 8 park | RIGHT: existing 4 x 4 fountain park | FRONT: taxi + 1.75m human scale",Vector2(20,928),22)
	text("Four mid-edge walk entrances; continuous solid ground, shallow flat water; inspection only",Vector2(20,967),21)
	for frame in range(16):await process_frame
	await RenderingServer.frame_post_draw
	var output:=OS.get_cmdline_user_args()[0];var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1600,1000));assert(image.save_png(output)==OK)
	print("LARGE_PARK_GRAPHICAL_PASS load/32x32/front/continuous_ground/24trees/reference_scale; ",output)
	quit()
