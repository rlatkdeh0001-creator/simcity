extends Node2D
## Actual shared road renderer; plan view makes odd-lane allocations easy to inspect.
const Model=preload("res://core/city_model.gd")
const Renderer=preload("res://core/road_renderer.gd")
var cases:Array=[]
var display_scale:=1.0
func add_case(title: String,subtitle: String,area: Rect2,definitions: Array):
	var city=Model.new(60,40,42)
	for d in definitions:
		var r:Dictionary=city.add_road(PackedVector2Array([d[0],d[1]]),"local",true,d[2],d[3])
		assert(r.ok)
	cases.append({"city":city,"area":area})
	var heading:=Label.new();heading.position=area.position+Vector2(22,15);heading.text=title;heading.add_theme_font_size_override("font_size",27);add_child(heading)
	var caption:=Label.new();caption.position=area.position+Vector2(22,56);caption.text=subtitle;caption.add_theme_font_size_override("font_size",18);add_child(caption)
func project(p: Vector2,area: Rect2) -> Vector2:return area.position+Vector2(150,110)+p*16
func _ready():
	scale=Vector2.ONE*minf(get_viewport_rect().size.x/2400,get_viewport_rect().size.y/1600)
	var title:=Label.new();title.position=Vector2(40,22);title.text="CITIES_DO · 교차로 + 왕복 3·5차로";title.add_theme_font_size_override("font_size",36);add_child(title)
	var note:=Label.new();note.position=Vector2(40,78);note.text="같은 도로 모델·렌더러의 평면 확인 화면 · 1칸=4m · 3차로 폭 12m / 5차로 폭 20m (보도 포함)";note.add_theme_font_size_override("font_size",20);add_child(note)
	var back:=Button.new();back.position=Vector2(2100,30);back.text="건설 화면으로";back.pressed.connect(func():get_tree().change_scene_to_file("res://main.tscn"));add_child(back)
	add_case("십자 교차로 · 3차로 × 2차로","가로 1+1 · 세로 2+1 / 중앙선·차선은 교차로 앞에서 끊음",Rect2(40,150,1120,630),[[Vector2(5,16),Vector2(45,16),2,false],[Vector2(25,3),Vector2(25,29),3,false]])
	add_case("T자 교차로 · 5차로 × 3차로","5차로 3+2 · 3차로 2+1 / 기존 도로 중심선으로 끝점 연결",Rect2(1200,150,1160,630),[[Vector2(5,16),Vector2(45,16),5,false],[Vector2(25,3),Vector2(25,14),3,false]])
	add_case("왕복 3차로 · 방향 반전","위: 그리는 방향 2 + 반대 1 / 아래: 그리는 방향 1 + 반대 2",Rect2(40,820,1120,660),[[Vector2(5,10),Vector2(45,10),3,false],[Vector2(5,25),Vector2(45,25),3,true]])
	add_case("왕복 5차로 · 방향 반전","위: 그리는 방향 3 + 반대 2 / 아래: 그리는 방향 2 + 반대 3",Rect2(1200,820,1160,660),[[Vector2(5,10),Vector2(45,10),5,false],[Vector2(5,25),Vector2(45,25),5,true]])
	var footer:=Label.new();footer.position=Vector2(40,1515);footer.text="회색: 보도 · 노란색: 양방향 중앙선 · 흰 점선: 같은 방향 차로 구분 · 화살표: 차로 진행 방향";footer.add_theme_font_size_override("font_size",21);add_child(footer)
	queue_redraw()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-road="):
			for i in range(4):await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var error=get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture-road="))
			print("ROAD CAPTURE ",error);get_tree().quit(error)
func _draw():
	for c in cases:
		draw_rect(c.area,Color("314447"));draw_rect(c.area.grow(-2),Color("799174"))
		Renderer.draw_roads(self,c.city.roads,project.bind(c.area),1.7,c.city.road_network.junctions,c.city.road_network.get("ports",[]))
