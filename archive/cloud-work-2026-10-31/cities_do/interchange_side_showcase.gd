extends Node2D
const Model=preload("res://core/city_model.gd")
const Renderer=preload("res://core/road_renderer.gd")
var city=Model.new(100,100)
func project(point:Vector2)->Vector2:return Vector2(800,850)+(point-Vector2(50,50))*25
func label_at(text:String,position:Vector2,size:int=26):
	var label:=Label.new();label.text=text;label.position=position;label.add_theme_font_size_override("font_size",size);add_child(label)
func _ready():
	scale=Vector2.ONE*minf(get_viewport_rect().size.x/2400,get_viewport_rect().size.y/1600)
	label_at("CITIES_DO · 도로 바깥쪽으로 진출 / 바깥쪽에서 진입",Vector2(40,25),38)
	label_at("램프가 본선 중앙까지 들어가지 않도록 수정 · 실제 공용 도로 렌더러",Vector2(40,88),25)
	assert(city.add_road(PackedVector2Array([Vector2(50,24),Vector2(50,76)]),"local",true,4).ok)
	assert(city.add_road(PackedVector2Array([Vector2(24,50),Vector2(76,50)]),"highway",true,4).ok)
	assert(city.add_interchange_at(Vector2(50,50)).ok)
	label_at("사이드 인",Vector2(230,700),29)
	label_at("사이드 아웃",Vector2(1150,700),29)
	label_at("사이드 아웃",Vector2(230,960),29)
	label_at("사이드 인",Vector2(1150,960),29)
	label_at("고속도로 160 km/h",Vector2(90,830),22)
	label_at("일반도로 80 km/h",Vector2(880,270),22)
	label_at("1. 양쪽 모두 측면 접속",Vector2(1650,240),30)
	label_at("각 방향의 바깥 차도 가장자리에서
램프가 갈라지고 합류합니다.",Vector2(1650,305),24)
	label_at("2. 본선은 계속 이어짐",Vector2(1650,485),30)
	label_at("중앙분리대와 중앙선은 유지합니다.
연결되는 쪽 방호벽만 엽니다.",Vector2(1650,550),24)
	label_at("3. 도로망 연결도 유지",Vector2(1650,730),30)
	label_at("램프 끝의 측면 접속점을
도로망에 별도로 연결합니다.
중앙에 교차로를 만들지 않습니다.",Vector2(1650,795),24)
	label_at("차량 합류 시뮬레이션은 후속",Vector2(1650,1080),23)
	var back:=Button.new();back.position=Vector2(1780,1350);back.text="고속도로 비교 화면으로";back.pressed.connect(func():get_tree().change_scene_to_file("res://highway_showcase.tscn"));add_child(back)
	queue_redraw()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-side="):
			for i in range(4):await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var error=get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture-side="))
			print("SIDE CAPTURE ",error);get_tree().quit(error)
func _draw():
	draw_rect(Rect2(40,170,1520,1370),Color("748b6e"))
	draw_rect(Rect2(1600,170,760,1370),Color("243b40"))
	Renderer.draw_roads(self,city.roads,project,2.1,city.road_network.junctions,city.road_network.ports)
	for port in city.road_network.ports:
		if city.roads[port.road].kind=="highway":draw_arc(project(port.position),12,0,TAU,32,Color("e6d381"),2,true)
