extends SceneTree
var checks:=0
var ident:String
var spec:Dictionary
var crossing:bool
var canvas:SubViewport
func _initialize():run.call_deferred()
func run():
	ident=OS.get_cmdline_user_args()[1];crossing=ident=="rail-crossing-signal-01"
	spec=JSON.parse_string(FileAccess.get_file_as_string("res://spec.json"))
	canvas=SubViewport.new();canvas.size=Vector2i(1600,1000);canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(canvas)
	var display:=TextureRect.new();display.texture=canvas.get_texture();display.size=Vector2(1600,1000);root.add_child(display)
	var bg:=ColorRect.new();bg.size=Vector2(1600,1000);bg.color=Color("172d35");canvas.add_child(bg)
	label(ident+" / inspection only / metre-scale original geometry",Vector2(20,12),25)
	var states:Array=["off","left","right"] if crossing else ["off","red","green"]
	for i in range(3):
		label(states[i]+(" / arm raised" if crossing and i==2 else " / arm lowered" if crossing else ""),Vector2(20+i*530,52),22)
		var span:float=11.0 if crossing and i==2 else 8.5 if crossing else 5.5
		var target:=Vector3(-.3,3.1,0) if crossing and i==2 else Vector3(-1.9,2,0) if crossing else Vector3(0,1.65,0)
		var v:=stage(Vector2(20+i*530,82),Vector2i(510,340),span,target,Vector3(7,8,15))
		var n:=prop(v,Vector3.ZERO,0,states[i])
		if i==0:
			var bb:=bounds(n)
			assert(abs(bb.size.y-float(spec.height_m))<.002);checks+=1
			assert(abs(bb.position.y)<.002);checks+=1
			for key in spec.lamp_materials:
				var lamp:MeshInstance3D=n.find_child(key,true,false);assert(lamp!=null)
				assert(bounds(lamp).get_center().z>0);checks+=1
				assert(lamp.get_active_material(0).resource_name=="mat_"+key+"_off");checks+=1
			if crossing:
				var arm:Node3D=n.find_child("arm",true,false)
				assert(arm.position.distance_to(Vector3(-.3,1,.05))<.002);checks+=1
				assert(abs(bounds(arm).size.x-5.25)<.002);checks+=1
			else:
				var head:Node3D=n.find_child("HeadHousing",true,false);assert(abs(bounds(head).position.y-2.3)<.002);checks+=1
		if crossing and i==2:n.find_child("arm",true,false).rotation_degrees.z=-90
	label("2-lane road / double-track crossing" if crossing else "Crosswalk corner / 1.76 m wide markings",Vector2(20,435),22)
	var context:=stage(Vector2(20,465),Vector2i(780,370),35,Vector3(0,.5,0),Vector3(16,24,29))
	box(context,Vector3(0,-.10,0),Vector3(12,.18,25),Color("a5a6a1"))
	box(context,Vector3(0,.001,0),Vector3(10.5,.025,25),Color("4c5659"))
	if crossing:
		for z in [-2.,2.]:
			for offset in [-.7175,.7175]:box(context,Vector3(0,.025,z+offset),Vector3(27,.03,.075),Color("b5c1c2"))
		prop(context,Vector3(5.75,0,5.3),0,"left");prop(context,Vector3(-5.75,0,-5.3),180,"right")
		for z in [-9.,9.]:box(context,Vector3(0,.03,z),Vector3(.12,.01,5),Color("efbd32"))
	else:
		box(context,Vector3(0,-.10,-2.5),Vector3(25,.18,12),Color("a5a6a1"))
		box(context,Vector3(0,.001,-2.5),Vector3(25,.025,10.5),Color("4c5659"))
		for x in range(-5,6):box(context,Vector3(x,.03,4.5),Vector3(.5,.01,1.76),Color("e6e7df"))
		prop(context,Vector3(5.75,0,4.5),90,"green");prop(context,Vector3(-5.75,0,4.5),-90,"red")
	model(context,"res://car.glb",Vector3(2.3,0,9),0)
	label("Same scale / car-sedan-03 + vehicle post (edda3f3)",Vector2(830,435),22)
	var compare:=stage(Vector2(830,465),Vector2i(750,370),15,Vector3(0,3,0),Vector3(5,6,19))
	var example:=prop(compare,Vector3(-4,0,0),0,states[1])
	if crossing:example.find_child("arm",true,false).rotation_degrees.z=-90
	model(compare,"res://car.glb",Vector3(0,0,0),0);model(compare,"res://vehicle-signal.glb",Vector3(4,0,0),0)
	label("Actual sprite reductions"+(" (arm excluded)" if crossing else "")+" / 11.7 px/m",Vector2(20,850),21)
	label("2.5 px/m / native pixels (not magnified)",Vector2(830,850),21)
	for i in range(3):
		label(states[i],Vector2(35+i*200,882),18);sprite(states[i],Vector2(100+i*200,883),11.7)
		label(states[i],Vector2(850+i*220,882),18);sprite(states[i],Vector2(960+i*220,900),2.5)
	label("Front: Blender -Y / glTF +Z. Source all lamps OFF. No placement or timing simulation.",Vector2(20,965),18)
	for i in range(24):await process_frame
	await RenderingServer.frame_post_draw
	var image:=canvas.get_texture().get_image();assert(image.get_size()==Vector2i(1600,1000));assert(image.save_png(OS.get_cmdline_user_args()[0])==OK)
	print("STREET_PROP_GRAPHICAL_PASS ",ident," checks=",checks," actual framebuffer1600x1000; loaded source GLB, dimensions, base, front, independent off lamps, pivot/head; reduced sprites11.7/2.5px/m");quit()
func label(t:String,p:Vector2,s:int):
	var l:=Label.new();l.text=t;l.position=p;l.add_theme_font_size_override("font_size",s);canvas.add_child(l)
func sprite(state:String,p:Vector2,ppm:float):
	var s:=Sprite2D.new();s.texture=load("res://sprites/"+state+"_000.png");s.centered=false;s.position=p;s.scale=Vector2.ONE*ppm/48.;canvas.add_child(s)
func prop(v:SubViewport,p:Vector3,yaw:float,state:String)->Node3D:
	var n:=model(v,"res://prop.glb",p,yaw)
	for key in spec.lamp_materials:
		var on:bool=(state=="left" and key=="lamp_left") or (state=="right" and key=="lamp_right") or (state=="red" and key=="lamp_ped_red") or (state=="green" and key=="lamp_ped_green")
		if on:
			var o:MeshInstance3D=n.find_child(key,true,false);var mat:=StandardMaterial3D.new()
			var c:Array=spec.material_definitions["mat_"+key+"_on"].base_color_linear
			mat.albedo_color=Color(c[0],c[1],c[2],1).linear_to_srgb();mat.emission_enabled=true;mat.emission=mat.albedo_color;mat.emission_energy_multiplier=2;o.material_override=mat
			if not crossing:
				var lens:MeshInstance3D=n.find_child(key+"_lens",true,false);var lm:=StandardMaterial3D.new();var lc:Array=spec.material_definitions["mat_"+key+"_lens_on"].base_color_linear
				lm.albedo_color=Color(lc[0],lc[1],lc[2],1).linear_to_srgb();lm.emission_enabled=true;lm.emission=lm.albedo_color;lm.emission_energy_multiplier=.5;lens.material_override=lm
	return n
func bounds(n:Node3D)->AABB:
	if n is MeshInstance3D:return n.global_transform*n.get_aabb()
	var b:=AABB();var first:=true
	for m in n.find_children("*","MeshInstance3D",true,false):
		var a:AABB=m.global_transform*m.get_aabb()
		if first:b=a;first=false
		else:b=b.merge(a)
	return b
func model(v:SubViewport,path:String,p:Vector3,yaw:float)->Node3D:
	var packed=load(path);assert(packed is PackedScene);var n:Node3D=packed.instantiate();v.add_child(n);n.position=p;n.rotation_degrees.y=yaw;return n
func box(v:SubViewport,p:Vector3,d:Vector3,c:Color):
	var n:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=d;n.mesh=mesh;var m:=StandardMaterial3D.new();m.albedo_color=c;n.material_override=m;v.add_child(n);n.position=p
func stage(p:Vector2,dim:Vector2i,span:float,target:Vector3,offset:Vector3)->SubViewport:
	var holder:=SubViewportContainer.new();holder.position=p;canvas.add_child(holder)
	var v:=SubViewport.new();v.size=dim;v.own_world_3d=true;v.msaa_3d=Viewport.MSAA_4X;holder.add_child(v)
	var e:=WorldEnvironment.new();e.environment=Environment.new();e.environment.background_mode=Environment.BG_COLOR;e.environment.background_color=Color("a5b9a0");e.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.environment.ambient_light_color=Color.WHITE;e.environment.ambient_light_energy=.75;v.add_child(e)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);v.add_child(light)
	var cam:=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.keep_aspect=Camera3D.KEEP_WIDTH;cam.size=span;v.add_child(cam);cam.position=target+offset;cam.look_at(target);cam.current=true;return v
