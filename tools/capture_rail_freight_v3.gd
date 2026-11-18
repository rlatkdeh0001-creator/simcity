extends SceneTree
var checks:=0
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1600,1000)
	var bg:=ColorRect.new();bg.size=Vector2(1600,1000);bg.color=Color("172d35");root.add_child(bg)
	label("FREIGHT V3 / wheels and bogie frames only / existing train black 30383b",Vector2(20,25),26)
	label("V2 retained",Vector2(20,170),26)
	label("V3 / same geometry, scale, camera and light",Vector2(820,170),26)
	var old:=stage(Vector2(20,220),Vector2i(760,600),10,Vector3(0,1.7,0),Vector3(8,4.5,22))
	model(old,"res://assets/vehicles/train-loco-freight-01-v2.glb",Vector3.ZERO,90)
	var revised:=stage(Vector2(820,220),Vector2i(760,600),10,Vector3(0,1.7,0),Vector3(8,4.5,22))
	var path:String=entry("vehicles","train-loco-freight-01").model
	assert(path.ends_with("-v3.glb"));checks+=1
	var n:=model(revised,path,Vector3.ZERO,90)
	var bb:=bounds(n)
	assert(abs(bb.size.x-10)<.002 and abs(bb.size.y-3.8)<.002 and abs(bb.size.z-3)<.002);checks+=1
	assert(abs(bb.position.y)<.002);checks+=1
	var front:Node3D=n.find_child("FrontHeadlight",true,false)
	var rear:Node3D=n.find_child("RearTaillight",true,false)
	assert(bounds(front).position.x>4.4 and bounds(rear).end.x< -4.4);checks+=1
	var wheels:=n.find_children("RailWheel*","MeshInstance3D",true,false)
	assert(wheels.size()==8);checks+=1
	for wheel in wheels:assert(abs(bounds(wheel).position.y)<.002)
	checks+=1
	label("10 x 3 x 3.8 m / 4536 triangles / front +X in this view / low side angle",Vector2(20,870),24)
	label("Only wheel + bogie frame material slots changed; cabinets, pilots, hubs and couplers retained.",Vector2(20,920),23)
	for i in range(16):await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1600,1000));assert(image.save_png(OS.get_cmdline_user_args()[0])==OK)
	print("FREIGHT_GRAPHICAL_PASS checks=",checks," catalog_v3 LWH10x3x3.8 front rail_top wheels8");quit()
func label(t:String,p:Vector2,s:int=22):
	var l:=Label.new();l.text=t;l.position=p;l.add_theme_font_size_override("font_size",s);root.add_child(l)
func bounds(n:Node3D)->AABB:
	if n is MeshInstance3D:return n.global_transform*n.get_aabb()
	var b:=AABB();var first:=true
	for m in n.find_children("*","MeshInstance3D",true,false):
		var v:AABB=m.global_transform*m.get_aabb()
		if first:b=v;first=false
		else:b=b.merge(v)
	return b
func model(v:SubViewport,path:String,p:Vector3,yaw:float=0.)->Node3D:
	var packed=load(path);assert(packed is PackedScene);var n:Node3D=packed.instantiate();v.add_child(n);n.position=p;n.rotation_degrees.y=yaw;return n
func entry(category:String,id:String)->Dictionary:
	var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+category+"/catalog.json"));return doc[category].filter(func(e):return e.id==id)[0]
func stage(p:Vector2,dim:Vector2i,span:float,target:Vector3,offset:Vector3)->SubViewport:
	var holder:=SubViewportContainer.new();holder.position=p;root.add_child(holder)
	var v:=SubViewport.new();v.size=dim;v.own_world_3d=true;v.msaa_3d=Viewport.MSAA_4X;holder.add_child(v)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("a5b9a0");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;v.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);v.add_child(light)
	var cam:=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=span;v.add_child(cam);cam.position=target+offset;cam.look_at(target);cam.current=true;return v
