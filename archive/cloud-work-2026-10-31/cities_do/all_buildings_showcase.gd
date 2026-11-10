extends Node2D
## Authored 100x100 asset review city. Does not enable pending growth/service systems.
const RoadGeometry = preload("res://core/road_geometry.gd")
const RoadRenderer=preload("res://core/road_renderer.gd")
const RoadNetwork=preload("res://core/road_network.gd")
var render_roads:Array=[]
var network:Dictionary={}
var data: Dictionary
var assets := {}
var textures := {}
var images := {}
var instances: Array = []
var zoom := 1.0
var origin := Vector2(1800,250)
var dragging := false
var selected := -1
var panel: Label
var last_rects: Array = []
func screen(p: Vector2) -> Vector2:
	return origin+Vector2((p.x-p.y)*14,(p.x+p.y)*7)*zoom
func projected(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:result.append(screen(Vector2(p[0],p[1])))
	return result
func sprite_rect(b: Dictionary) -> Rect2:
	var a: Dictionary=assets[b.asset_id]
	var sf: float=(a.footprint[0]+a.footprint[1])*14*zoom/a.width_px
	var pivot := screen(Vector2(b.x+a.footprint[0],b.y+a.footprint[1]))
	return Rect2(pivot-Vector2(a.anchor[0],a.anchor[1])*sf,Vector2(a.image_size[0],a.image_size[1])*sf)
func overview():
	zoom=minf(get_viewport_rect().size.x/3200.0,get_viewport_rect().size.y/2050.0)
	origin=Vector2(get_viewport_rect().size.x/2,300*zoom)
	queue_redraw()
func focus(group: String):
	zoom=1;origin=Vector2.ZERO
	var bounds := Rect2();var found := false
	for b in instances:
		if assets[b.asset_id].group!=group:continue
		var rect := sprite_rect(b)
		bounds=rect if not found else bounds.merge(rect);found=true
	if not found:overview();return
	var size:=get_viewport_rect().size-Vector2(120,250)
	zoom=clampf(minf(size.x/bounds.size.x,size.y/bounds.size.y),.6,3.2)
	origin=Vector2(get_viewport_rect().size.x/2,get_viewport_rect().size.y/2+95)-bounds.get_center()*zoom
	queue_redraw()
func _ready():
	data=JSON.parse_string(FileAccess.get_file_as_string("res://maps/all_buildings_100.json"))
	for road in data.roads:
		var copy:Dictionary=road.duplicate(true);var points:=PackedVector2Array()
		for p in road.points:points.append(Vector2(p[0],p[1]))
		copy.points=points;render_roads.append(copy)
	network=RoadNetwork.build(render_roads)
	for a in data.entries:
		assets[a.id]=a;textures[a.id]=load(a.texture);images[a.id]=textures[a.id].get_image()
	instances=data.placements.duplicate(true)
	instances.sort_custom(func(a,b):
		var aa: Dictionary=assets[a.asset_id];var bb: Dictionary=assets[b.asset_id]
		return a.x+a.y+(aa.footprint[0]+aa.footprint[1])/2 < b.x+b.y+(bb.footprint[0]+bb.footprint[1])/2)
	var layer := CanvasLayer.new();add_child(layer)
	var bg := ColorRect.new();bg.color=Color("243235");bg.size=Vector2(get_viewport_rect().size.x,106);layer.add_child(bg)
	var title := Label.new();title.position=Vector2(22,9);title.text="CITIES_DO  |  100 × 100  |  54종 · 59동 · 도로 연결 전시";title.add_theme_font_size_override("font_size",25);bg.add_child(title)
	var bar := HBoxContainer.new();bar.position=Vector2(22,51);bg.add_child(bar)
	for item in [["전체",""],["주거","residential"],["상업","commercial"],["공업","industrial"],["전력","power"],["수도","water"],["교육","education"],["소방","fire"],["경찰","police"],["병원","medical"],["환경","waste"]]:
		var button := Button.new();button.text=item[0];button.pressed.connect(func():
			if item[1]=="":overview()
			else:focus(item[1]));bar.add_child(button)
	var back := Button.new();back.text="건설 화면으로";back.pressed.connect(func():get_tree().change_scene_to_file("res://main.tscn"));bar.add_child(back)
	panel=Label.new();panel.position=Vector2(22,112);panel.text="휠 확대 · 가운데 드래그 · 건물 클릭 | 건물 배치 전시, 시설 운영 시뮬레이션은 별도";panel.add_theme_color_override("font_outline_color",Color("182225"));panel.add_theme_constant_override("outline_size",5);layer.add_child(panel)
	overview()
	await get_tree().process_frame
	var args=OS.get_cmdline_user_args()
	var capture="";var requested_group=""
	for arg in args:
		if arg.begins_with("--capture="):capture=arg.trim_prefix("--capture=")
		if arg.begins_with("--group="):requested_group=arg.trim_prefix("--group=")
	if not requested_group.is_empty():focus(requested_group)
	if not capture.is_empty():
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error=get_viewport().get_texture().get_image().save_png(capture)
		print("CAPTURE ",capture," result=",error," types=",assets.size()," buildings=",instances.size())
		get_tree().quit(error)
func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_MIDDLE:dragging=event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var old := zoom;zoom=clampf(zoom*(1.15 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.15),.35,5)
			origin=event.position-(event.position-origin)*zoom/old;queue_redraw()
		if event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			var index := pick_building(event.position)
			if index>=0:
				selected=index
				var a: Dictionary=assets[instances[index].asset_id]
				panel.text="%s | %s | %s칸 × %s칸" % [a.name,a.group,a.footprint[0],a.footprint[1]];queue_redraw()

	elif event is InputEventMouseMotion and dragging:origin+=event.relative;queue_redraw()
func pick_building(point: Vector2) -> int:
	for i in range(instances.size()-1,-1,-1):
		var b: Dictionary=instances[i];var r:=sprite_rect(b)
		if not r.has_point(point):continue
		var uv=(point-r.position)/r.size
		var im: Image=images[b.asset_id]
		if im.get_pixel(clampi(int(uv.x*im.get_width()),0,im.get_width()-1),clampi(int(uv.y*im.get_height()),0,im.get_height()-1)).a>=.15:return i
	return -1
func _draw():
	if data.is_empty():return
	draw_colored_polygon(projected([[0,0],[100,0],[100,100],[0,100]]),Color("82977a"))
	for water in data.water_polygons:draw_colored_polygon(projected(water),Color("57949c"))
	# Faint water lines communicate the river and reservoir without revealing a terrain grid.
	for y in range(86,100,3):draw_line(screen(Vector2(1,y)),screen(Vector2(98,y)),Color(0.7,.85,.85,.2),1)
	RoadRenderer.draw_roads(self,render_roads,screen,zoom,network.junctions,network.get("ports",[]))
	for i in range(instances.size()):
		var b: Dictionary=instances[i];var a: Dictionary=assets[b.asset_id]
		draw_texture_rect(textures[b.asset_id],sprite_rect(b),false)
		if i==selected:
			var outline=projected([[b.x,b.y],[b.x+a.footprint[0],b.y],[b.x+a.footprint[0],b.y+a.footprint[1]],[b.x,b.y+a.footprint[1]],[b.x,b.y]])
			draw_polyline(outline,Color.WHITE,2,true)
