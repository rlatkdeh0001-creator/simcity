extends SceneTree
var checks:=0
const DIR="res://assets/rail/rail-track-01/"
func _initialize():run.call_deferred()
func label(t:String,p:Vector2,s:int=20):
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
func entry(file:String,id:String,key:String)->Dictionary:
	var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file));return doc[key].filter(func(e):return e.id==id)[0]
func stage()->SubViewport:
	var holder:=SubViewportContainer.new();holder.position=Vector2(20,65);root.add_child(holder)
	var v:=SubViewport.new();v.size=Vector2i(940,500);v.own_world_3d=true;v.msaa_3d=Viewport.MSAA_4X;holder.add_child(v)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("a5b9a0");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;v.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);v.add_child(light)
	var cam:=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=34;v.add_child(cam);var target:=Vector3(0,2,-5);cam.position=target+Vector3(26,35,-45);cam.look_at(target);cam.current=true
	return v
func texture(name:String,pos:Vector2,size:Vector2):
	var n:=Sprite2D.new();n.texture=load(DIR+name+".png");n.centered=false;n.position=pos;n.scale=size/Vector2(n.texture.get_size());root.add_child(n)
func ribbon(radius:float,origin:Vector2,scale_px:float):
	var tex:Texture2D=load(DIR+"strip.png")
	for i in range(100):
		var a:=deg_to_rad(float(i));var b:=deg_to_rad(float(i+1));var points:=PackedVector2Array();var uv:=PackedVector2Array()
		for pair in [Vector2(a,-1.8),Vector2(b,-1.8),Vector2(b,1.8),Vector2(a,1.8)]:
			points.append(origin+Vector2(sin(pair.x)*(radius+pair.y),34-cos(pair.x)*(radius+pair.y))*scale_px)
			uv.append(Vector2(pair.x*radius*80,(pair.y+1.8)*80))
		var poly:=Polygon2D.new();poly.polygon=points;poly.uv=uv;poly.texture=tex;poly.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED;root.add_child(poly)
func run():
	root.size=Vector2i(1600,1000);var bg:=ColorRect.new();bg.size=Vector2(1600,1000);bg.color=Color("172d35");root.add_child(bg)
	label("RAIL / double-track sample 12 x 7.6m / gauge 1.435m / track centres 4m",Vector2(20,12),25)
	var v:=stage();var station:=model(v,entry("res://assets/facilities/catalog.json","train-station-01","facilities").model,Vector3.ZERO)
	assert(abs(bounds(station).size.z-24)<.002);checks+=1
	var rail_entry:=entry("res://assets/facilities/catalog.json","rail-track-01","facilities")
	for x in [-12.,0.,12.]:
		var n:=model(v,rail_entry.model,Vector3(x,0,-15.8),90);var b:=bounds(n)
		assert(abs(b.size.x-12)<.002 and abs(b.size.z-7.6)<.002 and abs(b.position.y+.35)<.002);checks+=1
		for part in n.find_children("EndBuffer*","MeshInstance3D",true,false):part.hide()
		var r:Node3D=n.find_child("Rail_0_0_-1",true,false);assert(r!=null and abs(bounds(r).end.y)<.002);checks+=1
	var lead:=entry("res://assets/vehicles/catalog.json","train-loco-01","vehicles")
	var coach:=entry("res://assets/vehicles/catalog.json","train-passenger-01","vehicles")
	assert(lead.model.ends_with("-v3.glb") and coach.model.ends_with("-v3.glb"))
	var a:=model(v,lead.model,Vector3(5.5,0,-13.8),90);var c:=model(v,coach.model,Vector3(-5,0,-13.8),90);var d:=model(v,coach.model,Vector3(0,0,-17.8),90)
	assert(abs(bounds(a).position.x-bounds(c).end.x)<.002);assert(abs(bounds(station).position.z-bounds(a).end.z-.3)<.002);assert(abs(bounds(a).position.z-bounds(d).end.z-1)<.002);checks+=3
	label("1 / v1 station + v3 lead/coach; far coach / fixture-only 36m extension",Vector2(20,575),19)
	# Curved 2D ribbon: actual delivered strip UVs, not curve artwork.
	var origin:=Vector2(1000,105)
	# Plain ballast beneath both ribbons fills their 0.4m middle gap.
	for i in range(100):
		var p:=Polygon2D.new();var pts:=PackedVector2Array()
		for q in [Vector2(i,30.2),Vector2(i+1,30.2),Vector2(i+1,37.8),Vector2(i,37.8)]:pts.append(origin+Vector2(sin(deg_to_rad(q.x))*q.y,34-cos(deg_to_rad(q.x))*q.y)*8)
		p.polygon=pts;p.color=Color("a59c8e");root.add_child(p)
	ribbon(32,origin,8);ribbon(36,origin,8)
	label("3 / curved double ribbon / radii 32 + 36m",Vector2(980,575),19)
	for i in range(3):texture("strip",Vector2(20+i*200,640),Vector2(200,180))
	label("2 / three repeats / 4m each",Vector2(20,610))
	texture("strip_end",Vector2(660,640),Vector2(240,216));label("4 / end + buffer",Vector2(660,610))
	var asphalt:=ColorRect.new();asphalt.position=Vector2(960,640);asphalt.size=Vector2(600,190);asphalt.color=Color("4c5659");root.add_child(asphalt)
	for lane in range(2):
		for i in range(3):texture("strip_rails",Vector2(960+i*200,640+lane*100),Vector2(200,90))
	label("5 / rails only over asphalt 4c5659",Vector2(960,610))
	var mini:=ColorRect.new();mini.position=Vector2(20,880);mini.size=Vector2(144,91.2);mini.color=Color("a59c8e");root.add_child(mini)
	for lane in range(2):
		for i in range(3):texture("strip",Vector2(20+i*48,880+lane*48),Vector2(48,43.2))
	label("6 / 12px per metre\n12 x 7.6m double track",Vector2(185,883),19)
	for name in ["strip","strip_end","strip_rails"]:
		var t:Texture2D=load(DIR+name+".png");assert(t.get_size()==Vector2(320,288));checks+=1
	label("3D source: straight 8m + end 4m. Strip images: ONE track, emission/no shadows, 80px/m.",Vector2(530,888),20)
	label("Static inspection only / drawing, routing, crossings and operation remain code-side work.",Vector2(530,927),20)
	for i in range(16):await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1600,1000));assert(image.save_png(OS.get_cmdline_user_args()[0])==OK)
	print("RAIL_TRACK_GRAPHICAL_PASS checks=",checks," sample12x7.6m gauge1.435 centres4 platform_gap0.3 bodies_gap1 rail_top0; six views");quit()
