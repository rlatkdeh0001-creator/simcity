extends Node2D
const Model=preload("res://core/city_model.gd")
const Adapter=preload("res://core/road_generator_adapter.gd")
const Legacy=preload("res://core/legacy_road_comparison.gd")
var city=Model.new(100,100)
var adapter
var camera:Camera3D
var mode_label:Label
var perspective:=false
func label_at(text:String,p:Vector2,size:int=25)->Label:
	var label:=Label.new();label.text=text;label.position=p;label.add_theme_font_size_override("font_size",size);add_child(label);return label
func set_camera(iso:bool):
	perspective=iso
	if iso:
		camera.position=Vector3(130,230,180);camera.look_at(Vector3.ZERO);camera.size=320
	else:
		camera.position=Vector3(0,350,0);camera.rotation_degrees=Vector3(-90,0,0);camera.size=1100/4.5
	mode_label.text="오른쪽: 실제 3D 입체 보기" if iso else "양쪽: 같은 배치·축척의 평면 보기"
func viewport_at(position:Vector2)->SubViewport:
	var container:=SubViewportContainer.new();container.position=position;container.size=Vector2(1140,1100);container.stretch=true;add_child(container)
	var viewport:=SubViewport.new();viewport.size=Vector2i(1140,1100);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.own_world_3d=true;container.add_child(viewport)
	return viewport
func _ready():
	scale=Vector2.ONE*minf(get_viewport_rect().size.x/2400,get_viewport_rect().size.y/1600)
	label_at("CITIES_DO · Godot Road Generator 실제 도입 비교",Vector2(40,23),38)
	label_at("일반도로 80 km/h · 고속도로 160 km/h · 동일한 4차로 나들목 배치",Vector2(40,83),24)
	label_at("게임 내 도로 · 공통 곡선 규칙",Vector2(55,165),31)
	label_at("동일한 곡선 · 3D 미리보기",Vector2(1245,165),31)
	city.add_road(PackedVector2Array([Vector2(50,24),Vector2(50,76)]),"local",true,4)
	city.add_road(PackedVector2Array([Vector2(24,50),Vector2(76,50)]),"highway",true,4)
	city.add_interchange_at(Vector2(50,50))
	var before:=viewport_at(Vector2(40,230));before.disable_3d=true
	var legacy:=Legacy.new();legacy.city=city;before.add_child(legacy)
	var after:=viewport_at(Vector2(1220,230));after.msaa_3d=Viewport.MSAA_2X
	var world:=Node3D.new();after.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("748b6e")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.65
	world.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-65,-30,0);light.light_energy=1.0;light.shadow_enabled=true;world.add_child(light)
	var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(1000,1000);ground.mesh=plane;ground.position.y=-.1
	var grass:=StandardMaterial3D.new();grass.albedo_color=Color("748b6e");grass.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;grass.roughness=1;ground.material_override=grass;world.add_child(ground)
	adapter=Adapter.new();world.add_child(adapter);adapter.build(city)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.current=true;after.add_child(camera)
	mode_label=label_at("",Vector2(40,1390),26);set_camera(false)
	label_at("실제 건설 도구도 같은 유선형 램프를 생성",Vector2(55,1340),23)
	label_at("폭·방향·경사가 부드럽게 연결 · 기존 색감 유지",Vector2(1245,1340),23)
	label_at("Road Generator 0.9.5 / MIT · 비교 장면에 실제 연동 · 차량 합류 시뮬레이션은 후속",Vector2(40,1490),23)
	var toggle:=Button.new();toggle.position=Vector2(1740,1400);toggle.text="오른쪽 평면 / 입체 전환";toggle.pressed.connect(func():set_camera(not perspective));add_child(toggle)
	var back:=Button.new();back.position=Vector2(2120,1400);back.text="건설 화면으로";back.pressed.connect(func():get_tree().change_scene_to_file("res://main.tscn"));add_child(back)
	for arg in OS.get_cmdline_user_args():
		if arg=="--isometric":set_camera(true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-generator="):
			for i in range(12):await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var error=get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture-generator="))
			print("GENERATOR CAPTURE ",error," ",adapter.stats());get_tree().quit(error)
