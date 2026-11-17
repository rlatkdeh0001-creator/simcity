extends SceneTree
var checks:=0
func _initialize():run.call_deferred()
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
func stage(p:Vector2,dim:Vector2i,span:float,offset:Vector3,target_z:float=0.)->SubViewport:
	var holder:=SubViewportContainer.new();holder.position=p;root.add_child(holder)
	var v:=SubViewport.new();v.size=dim;v.own_world_3d=true;v.msaa_3d=Viewport.MSAA_4X;holder.add_child(v)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("a5b9b7");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;v.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);v.add_child(light)
	var cam:=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=span;v.add_child(cam);var target:=Vector3(0,-11,target_z);cam.position=target+offset;cam.look_at(target);cam.current=true
	return v
func fixture_strip(v:SubViewport):
	var n:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(24,.04,12);n.mesh=mesh;n.position=Vector3(0,-12.74,0);var mat:=StandardMaterial3D.new();mat.albedo_color=Color("15181a");n.material_override=mat;v.add_child(n)
func run():
	root.size=Vector2i(1600,1000);var bg:=ColorRect.new();bg.size=Vector2(1600,1000);bg.color=Color("172d35");root.add_child(bg)
	label("SUBWAY / plain white symmetric car / 15m body + couplers = 16m / 2.8m wide / 3.6m high",Vector2(20,12),25)
	label("4 cars = 64m / original underground silhouette",Vector2(20,67));label("Black 12m tunnel strip / fixture only",Vector2(1090,67),20)
	var left:=stage(Vector2(20,105),Vector2i(1050,800),52,Vector3(25,55,45))
	var right:=stage(Vector2(1090,105),Vector2i(490,800),28,Vector3(18,24,26),4.15)
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json"));var e:Dictionary=catalog.vehicles.filter(func(x):return x.id=="subway-car-01")[0]
	var silhouette:=model(left,"res://assets/facilities/subway-platform-silhouette-01.glb",Vector3.ZERO)
	assert(abs(bounds(silhouette).position.y+13)<.002)
	var cars:Array[Node3D]=[]
	for x in [-24.,-8.,8.,24.]:cars.append(model(left,e.model,Vector3(x,-12.7,4.15),90))
	for i in range(4):
		var b:=bounds(cars[i]);assert(abs(b.size.x-16)<.002 and abs(b.size.y-3.6)<.002 and abs(b.size.z-2.8)<.002)
		assert(abs(b.position.y+12.7)<.002 and abs(b.position.z-2.75)<.002 and abs(b.end.z-5.55)<.002)
		checks+=2
		if i<3:assert(abs(b.end.x-bounds(cars[i+1]).position.x)<.002);checks+=1
	assert(abs(bounds(cars[3]).end.x-bounds(cars[0]).position.x-64)<.002);checks+=1
	assert(e.frame_gltf.forward=="+Z" and e.material_count<=3 and e.gauge_m==1.435 and e.coupler_height_m==1);checks+=1
	fixture_strip(right);model(right,e.model,Vector3(0,-12.7,4.15),90)
	label("Rail top remains at authored world y=-12.7m; body fits 3.3m groove with 0.25m platform clearance",Vector2(20,933),22)
	label("No doors, lights or markings. Black tunnel is fixture geometry, not a delivered tunnel asset.",Vector2(20,969),21)
	for frame in range(16):await process_frame
	await RenderingServer.frame_post_draw
	var output:=OS.get_cmdline_user_args()[0];var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1600,1000));assert(image.save_png(output)==OK)
	print("SUBWAY_CAR_GRAPHICAL_PASS checks=",checks," consist64m width2.8m groove3.3m coupler_contacts3 rail_top=-12.7; ",output);quit()
