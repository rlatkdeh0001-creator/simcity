extends Node2D
const Model=preload("res://core/city_model.gd")
const Renderer=preload("res://core/road_renderer.gd")
var samples:Array=[]
var interchange=Model.new(100,100)
func label_at(text:String,position:Vector2,size:int=24):
	var label:=Label.new();label.text=text;label.position=position;label.add_theme_font_size_override("font_size",size);add_child(label)
func project_sample(point:Vector2,offset:Vector2)->Vector2:return offset+point*13
func project_interchange(point:Vector2)->Vector2:return Vector2(1200,240)+point*11
func _ready():
	scale=Vector2.ONE*minf(get_viewport_rect().size.x/2400,get_viewport_rect().size.y/1600)
	label_at("CITIES_DO · 8차로 / 고속도로 / 나들목",Vector2(42,25),38)
	label_at("일반도로 80 km/h · 고속도로 160 km/h · 1칸=4m · 왕복 차로 수 기준",Vector2(42,86),23)
	var back:=Button.new();back.position=Vector2(2150,35);back.text="건설 화면으로";back.pressed.connect(func():get_tree().change_scene_to_file("res://main.tscn"));add_child(back)
	for i in range(5):
		var lanes:int=[8,2,3,4,5][i]
		var kind:String="local" if i==0 else "highway"
		var city=Model.new(80,30)
		assert(city.add_road(PackedVector2Array([Vector2(2,7),Vector2(70,7)]),kind,true,lanes).ok)
		var area:=Rect2(40,160+i*260,1120,240)
		samples.append({"city":city,"area":area})
		label_at(("일반 8차로 · 4+4 · 80 km/h" if i==0 else "고속도로 %d차로 · %d+%d · 160 km/h"%[lanes,ceili(lanes/2.0),floori(lanes/2.0)]),area.position+Vector2(22,14),26)
		label_at("폭 %d칸 / %dm · %s"%[lanes,lanes*4,"보도 포함" if i==0 else "길어깨·방호벽 / 건물 진입 불가"],area.position+Vector2(22,55),19)
	assert(interchange.add_road(PackedVector2Array([Vector2(50,6),Vector2(50,94)]),"local",true,4).ok)
	assert(interchange.add_road(PackedVector2Array([Vector2(5,50),Vector2(95,50)]),"highway",true,4).ok)
	assert(interchange.add_interchange_at(Vector2(50,50)).ok)
	label_at("다이아몬드형 나들목",Vector2(1230,170),30)
	label_at("고속도로 상부 통과 · 일반도로 하부 통과",Vector2(1230,218),23)
	label_at("진입 램프 2개 + 진출 램프 2개 · 램프 80 km/h (임시값)",Vector2(1230,258),21)
	label_at("80",Vector2(1785,410),28)
	label_at("←  160",Vector2(2100,725),27)
	label_at("160  →",Vector2(1260,825),27)
	label_at("80",Vector2(1785,1200),28)
	label_at("입체교차만으로는 연결되지 않음",Vector2(1250,1295),26)
	label_at("나들목 설치 시 네 램프로 도로망 연결 · 고속도로에 건설 구획 없음",Vector2(1250,1340),20)
	label_at("현재 구현: 도로 표시·높이별 연결·제한속도 데이터 / 차량 주행과 신호 제어는 후속",Vector2(42,1510),23)
	var detail:=Button.new();detail.position=Vector2(1940,1390);detail.text="측면 진출입 확대";detail.pressed.connect(func():get_tree().change_scene_to_file("res://interchange_side_showcase.tscn"));add_child(detail)
	queue_redraw()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-highway="):
			for i in range(4):await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var error=get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture-highway="))
			print("HIGHWAY CAPTURE ",error);get_tree().quit(error)
func _draw():
	for c in samples:
		draw_rect(c.area,Color("344a48"));draw_rect(c.area.grow(-2),Color("748b6e"))
		Renderer.draw_roads(self,c.city.roads,project_sample.bind(c.area.position+Vector2(75,85)),1.6,c.city.road_network.junctions)
	draw_rect(Rect2(1200,160,1160,1280),Color("344a48"));draw_rect(Rect2(1202,162,1156,1276),Color("748b6e"))
	Renderer.draw_roads(self,interchange.roads,project_interchange,1.8,interchange.road_network.junctions,interchange.road_network.get("ports",[]))
