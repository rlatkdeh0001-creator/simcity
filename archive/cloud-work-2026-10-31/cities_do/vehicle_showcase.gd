extends Node2D
const CATALOG="res://assets/vehicles/catalog.json"
var entries:Array=[]
var previews:Array=[]
var spinning:=false
var animate_wheels:=false
var same_scale:=false
var selected:=-1
var info:Label
func label_at(value:String,position:Vector2,size:int=24)->Label:
	var label:=Label.new();label.text=value;label.position=position;label.add_theme_font_size_override("font_size",size);add_child(label);return label
static func model_bounds(node:Node3D)->AABB:
	var result:=AABB();var first:=true
	var pending:Array=[node]
	while not pending.is_empty():
		var child:Node=pending.pop_back();pending.append_array(child.get_children())
		if child is MeshInstance3D:
			var bounds:AABB=child.global_transform*child.get_aabb()
			if first:result=bounds;first=false
			else:result=result.merge(bounds)
	return result
static func spin_nodes(node:Node)->Array:
	var result:Array=[]
	for child in node.get_children():
		if child.name.begins_with("Wheel_") and child.name.ends_with("_Spin"):result.append(child)
		result.append_array(spin_nodes(child))
	return result
func fit_camera(preview:Dictionary):
	var bounds:AABB=preview.bounds
	var length:float=maxf(16.34 if same_scale else bounds.size.z,3.2)
	var target:Vector3=Vector3(0,bounds.size.y*.45,0)
	preview.camera.position=target+Vector3(-length*.95,length*.95*sqrt(2.0)*tan(PI/6),length*.95)
	preview.camera.look_at(target)
	preview.camera.size=maxf(length*.82,bounds.size.y*1.65)
func choose(index:int):
	selected=index;var entry:Dictionary=entries[index]
	info.text="%s · 길이 %.2fm / 폭 %.2fm / 높이 %.2fm · 바퀴 %d개 · %s"%[entry.label,entry.length_m,entry.width_m,entry.height_m,entry.wheel_count,"우측 승하차" if entry.category=="bus" else "좌측 운전석 / 우측통행"]
	queue_redraw()
func create_preview(index:int,entry:Dictionary):
	var area:=Rect2(40+(index%5)*468,190+floori(index/5.0)*350,448,332)
	var container:=SubViewportContainer.new();container.position=area.position+Vector2(9,7);container.size=Vector2(430,245);container.stretch=true;add_child(container)
	var viewport:=SubViewport.new();viewport.size=Vector2i(430,245);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_2X;container.add_child(viewport)
	var world:=Node3D.new();viewport.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_CLEAR_COLOR;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;world.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);light.light_energy=.95;world.add_child(light)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-25,140,0);fill.light_energy=.35;world.add_child(fill)
	var model:Node3D=load(entry.model).instantiate();world.add_child(model)
	var bounds:=model_bounds(model)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.current=true;viewport.add_child(camera)
	var preview:Dictionary={"area":area,"model":model,"viewport":viewport,"camera":camera,"bounds":bounds,"wheels":spin_nodes(model)}
	previews.append(preview);fit_camera(preview)
	var accent:Color={"bus":Color("6fadc5"),"taxi":Color("e0b959"),"citizen":Color("92baa1"),"industrial":Color("cd9a70")}[entry.category]
	var heading:=label_at("%02d  %s"%[index+1,entry.label],area.position+Vector2(16,253),24);heading.modulate=accent
	label_at("%.2fm × %.2fm · %d개 바퀴"%[entry.length_m,entry.width_m,entry.wheel_count],area.position+Vector2(16,290),19)
	container.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:choose(index))
func _ready():
	scale=Vector2.ONE*minf(get_viewport_rect().size.x/2400,get_viewport_rect().size.y/1800)
	entries=JSON.parse_string(FileAccess.get_file_as_string(CATALOG)).entries
	label_at("CITIES_DO · 차량 20종",Vector2(40,25),40)
	label_at("버스 1 · 택시 1 · 시민용 10 · 산업용 8  |  실제 게임 GLB 모델",Vector2(40,87),25)
	label_at("종류별 자동 확대 · 아래 길이/폭은 실제 설계 단위(m) · 우측통행",Vector2(40,128),21)
	var back:=Button.new();back.position=Vector2(2180,35);back.text="건설 화면으로";back.pressed.connect(func():get_tree().change_scene_to_file("res://main.tscn"));add_child(back)
	var rotate:=CheckBox.new();rotate.position=Vector2(1660,90);rotate.text="전체 회전";rotate.toggled.connect(func(value):spinning=value);add_child(rotate)
	var wheels:=CheckBox.new();wheels.position=Vector2(1830,90);wheels.text="바퀴 회전";wheels.toggled.connect(func(value):animate_wheels=value);add_child(wheels)
	var scale_choice:=CheckBox.new();scale_choice.position=Vector2(2000,90);scale_choice.text="같은 축척으로 비교";scale_choice.toggled.connect(func(value):same_scale=value;reset_cameras());add_child(scale_choice)
	for index in range(entries.size()):create_preview(index,entries[index])
	info=label_at("차량을 누르면 제원을 확인할 수 있습니다.",Vector2(40,1625),23)
	label_at("차량 전용 zstack/vehicle 스킬 적용 · Blender 원본 + 바퀴 축/트레일러 관절 포함 · 차량 운행은 후속",Vector2(40,1700),22)
	choose(0);queue_redraw()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-fleet="):
			for i in range(12):await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var error=get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture-fleet="))
			for index in range(previews.size()):
				var path:String="res://assets/vehicles/"+entries[index].id+".png"
				previews[index].viewport.get_texture().get_image().save_png(path)
			var manifest:Dictionary={"units":"metres","sprite_size_px":[430,245],"camera_elevation_degrees":30,"camera_position_xz_ratio":[-1,1],"forward_axis_gltf":"+Z","model_yaw_degrees":[0,45,90,135,180,225,270,315],"entries":{}}
			for index in range(previews.size()):
				var id:String=entries[index].id
				var directory:String="res://assets/vehicles/sprites/"+id
				DirAccess.make_dir_recursive_absolute(directory)
				manifest.entries[id]={"pixels_per_metre":245.0/previews[index].camera.size,"ortho_height_m":previews[index].camera.size,"frames":[]}
			for frame in range(8):
				for preview in previews:preview.model.rotation.y=frame*PI/4
				for step in range(3):await get_tree().process_frame
				await RenderingServer.frame_post_draw
				for index in range(previews.size()):
					var id:String=entries[index].id
					var path:String="res://assets/vehicles/sprites/"+id+"/%03d.png"%(frame*45)
					previews[index].viewport.get_texture().get_image().save_png(path)
					manifest.entries[id].frames.append(path)
			var output:=FileAccess.open("res://assets/vehicles/render_manifest.json",FileAccess.WRITE);output.store_string(JSON.stringify(manifest,"  "));output.close()
			print("FLEET CAPTURE ",error," models ",entries.size()," directional frames 160");get_tree().quit(error)
func reset_cameras():
	for preview in previews:fit_camera(preview)
func _process(delta:float):
	for preview in previews:
		if spinning:preview.model.rotate_y(delta*.35)
		if animate_wheels:
			for wheel in preview.wheels:wheel.rotate_x(delta*1.5)
func _draw():
	for index in range(previews.size()):
		var area:Rect2=previews[index].area
		draw_rect(area,Color("263942"));draw_rect(Rect2(area.position+Vector2(8,6),Vector2(432,247)),Color("b9c5b3"))
		if index==selected:draw_rect(area.grow(2),Color("d1b76e"),false,2)
