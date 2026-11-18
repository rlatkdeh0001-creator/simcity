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
func entry(category:String,id:String)->Dictionary:
	var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+category+"/catalog.json"));return doc[category].filter(func(e):return e.id==id)[0]
func stage(p:Vector2,dim:Vector2i,span:float,target:Vector3,offset:Vector3)->SubViewport:
	var holder:=SubViewportContainer.new();holder.position=p;root.add_child(holder)
	var v:=SubViewport.new();v.size=dim;v.own_world_3d=true;v.msaa_3d=Viewport.MSAA_4X;holder.add_child(v)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("a5b9a0");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;v.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);v.add_child(light)
	var cam:=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=span;v.add_child(cam);cam.position=target+offset;cam.look_at(target);cam.current=true;return v
func scene(v:SubViewport,verify:bool):
	var rail:=entry("facilities","rail-track-01")
	for x in [-12.,0.,12.]:
		var n:=model(v,rail.model,Vector3(x,0,0),90)
		for part in n.find_children("EndBuffer*","MeshInstance3D",true,false):part.hide()
	var freight:=entry("vehicles","train-loco-freight-01");var flat:=entry("vehicles","train-flatcar-01");var cargo:=entry("vehicles","container-20ft-01");var lead:=entry("vehicles","train-loco-01")
	var a:=model(v,freight.model,Vector3(8,0,2),90)
	var b:=model(v,flat.model,Vector3(-1,0,2),90);var c:=model(v,flat.model,Vector3(-9,0,2),90)
	var containers:Array[Node3D]=[]
	for x in [-1.,-9.]:containers.append(model(v,cargo.model,Vector3(x,1.2,2),90))
	var passenger:=model(v,lead.model,Vector3(8,0,-2),90)
	if not verify:return
	var bb:=bounds(a);assert(abs(bb.size.x-10)<.002 and abs(bb.size.z-3)<.002 and abs(bb.size.y-3.8)<.002);checks+=1
	assert(abs(bb.position.y)<.002);checks+=1
	assert(abs(bb.position.x-bounds(b).end.x)<.002 and abs(bounds(b).position.x-bounds(c).end.x)<.002);checks+=2
	assert(abs(bb.end.x-bounds(c).position.x-26)<.002);checks+=1
	for n in containers:assert(abs(bounds(n).end.y-3.8)<.002);checks+=1
	assert(abs(bounds(passenger).end.y-3.8)<.002 and lead.model.ends_with("-v3.glb"));checks+=1
	var bars:=a.find_children("PantographContactBar*","MeshInstance3D",true,false);assert(bars.size()==1)
	var pb:=bounds(bars[0]);assert(abs(pb.end.y-3.8)<.002 and abs(pb.size.z-1.24)<.002);checks+=1
	var base:Node3D=a.find_child("RecessedPantographBase",true,false);var base_b:=bounds(base)
	assert(base_b.position.x>4.8 and base_b.end.x<6.4 and base_b.position.z>1.18 and base_b.end.z<2.82 and base_b.position.y>=3.6);checks+=1
	assert(a.find_children("FrontWindscreen*","MeshInstance3D",true,false).size()==2 and a.find_children("RearWindscreen*","MeshInstance3D",true,false).size()==2);checks+=1
	var front:Node3D=a.find_child("FrontHeadlight",true,false);var rear:Node3D=a.find_child("RearTaillight",true,false)
	assert(front!=null and rear!=null and bounds(front).position.x>12.4 and bounds(rear).end.x<3.6);checks+=1
	var wheels:=a.find_children("RailWheel*","MeshInstance3D",true,false);assert(wheels.size()==8)
	for wheel in wheels:
		var w:=bounds(wheel);assert(abs(w.position.y)<.002)
		var lateral:float=absf(w.get_center().z-2);assert(lateral>.7175 and lateral<.8675)
	checks+=1
	assert(abs(bb.position.z-bounds(passenger).end.z-1)<.002);checks+=1
func run():
	root.size=Vector2i(1600,1000);var bg:=ColorRect.new();bg.size=Vector2(1600,1000);bg.color=Color("172d35");root.add_child(bg)
	label("FREIGHT V2 / large machine-room louvres / exposed running gear",Vector2(20,12),26)
	var main:=stage(Vector2(20,65),Vector2i(1560,430),14,Vector3(0,1,0),Vector3(12,17,38));scene(main,true)
	label("26m loaded v2 consist / adjacent v3 passenger lead / roof and pickup <= 3.8m",Vector2(20,505),22)
	var old:=stage(Vector2(20,580),Vector2i(760,360),7,Vector3(0,1.7,0),Vector3(8,4.5,22))
	model(old,"res://assets/vehicles/train-loco-freight-01.glb",Vector3.ZERO,90)
	var revised:=stage(Vector2(820,580),Vector2i(760,360),7,Vector3(0,1.7,0),Vector3(8,4.5,22))
	model(revised,entry("vehicles","train-loco-freight-01").model,Vector3.ZERO,90)
	label("V1 retained / same scale and light",Vector2(20,545),22)
	label("V2 / low side view: bogies, wheels, pilot and coupling",Vector2(820,545),22)
	label("Original scripted geometry / inspection only / no operation or simulation changes",Vector2(20,963),21)
	for i in range(16):await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1600,1000));assert(image.save_png(OS.get_cmdline_user_args()[0])==OK)
	print("FREIGHT_GRAPHICAL_PASS checks=",checks," LWH10x3x3.8 body9 pantograph1 top3.8 recess front twin_windows couplers2 consist26 wheels8 rail_top0");quit()
