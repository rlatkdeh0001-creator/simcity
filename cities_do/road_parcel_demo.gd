extends "res://main.gd"
func _ready():
	showcase_view=true
	super._ready()
	city=Model.new(100,100,42)
	mode="select"
	city.add_road(PackedVector2Array([Vector2(12,22),Vector2(44,22)]),"local",true,2)
	city.add_road(PackedVector2Array([Vector2(10,53),Vector2(37,39)]),"local",true,2)
	city.add_road(PackedVector2Array([Vector2(58,19),Vector2(80,19),Vector2(87,35)]),"local",true,4)
	var curve:=PackedVector2Array()
	for angle in range(-90,46,5):curve.append(Vector2(53,66)+Vector2.from_angle(deg_to_rad(angle))*20)
	city.add_road(curve,"local",true,2)
	# Place a few valid local 2x2 lots on different road orientations.
	var used:={}
	for frame in city.zoning_grid.frames.values():
		if used.has(frame.road_index):continue
		for u in range(maxi(0,frame.columns-1)):
			if city.parcel_placement_error(frame,u,0,2)!="":continue
			var result: Dictionary=city.add_building_at(frame.origin+frame.along*(u+.5)+frame.outward*.5,"residential",100)
			if result.ok:
				used[frame.road_index]=true
				break
	selected=city.buildings[1].id if city.buildings.size()>1 else -1
	var back:=Button.new()
	back.text="건설 화면으로 돌아가기"
	back.pressed.connect(func():get_tree().change_scene_to_file("res://main.tscn"))
	controls_panel.get_child(0).add_child(back)
	var title:=Label.new()
	title.text="도로에서 직각으로 나오는 구획\n직선 · 사선 · 꺾임 · 곡선의 짧은 직선 블록"
	title.position=Vector2(360,24)
	title.add_theme_font_size_override("font_size",21)
	get_child(0).add_child(title)
	var low:=Vector2(INF,INF)
	var high:=Vector2(-INF,-INF)
	for parcel in city.zoning_grid.parcels.values():
		for point in parcel.polygon:
			var projected:=Vector2((point.x-point.y)*tile.x,(point.x+point.y)*tile.y)
			low=low.min(projected);high=high.max(projected)
	var area:=Rect2(370,120,get_viewport_rect().size.x-420,get_viewport_rect().size.y-280)
	map_zoom=minf(area.size.x/(high.x-low.x),area.size.y/(high.y-low.y))
	origin=area.position+(area.size-(high-low)*map_zoom)/2-low*map_zoom
	hud.position=Vector2(24,get_viewport_rect().size.y-140)
	message="지도 위 도로 방향 ⟂ 구획 깊이 · 블록 겹침/도로 침범 칸은 제외"
	refresh()
	var plan:=Node2D.new()
	get_child(0).add_child(plan)
	plan.draw.connect(func():draw_plan(plan))
	plan.queue_redraw()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-parcels="):capture_view.call_deferred(argument.trim_prefix("--capture-parcels="))
func capture_view(path: String):
	for frame in range(12):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	assert(not image.is_empty())
	assert(image.save_png(path)==OK)
	print("PASS actual road-local grid capture · ",city.zoning_grid.count()," cells · ",city.buildings.size()," buildings")
	get_tree().quit()

func draw_plan(canvas: Node2D):
	var origin_point:=Vector2(get_viewport_rect().size.x-350,get_viewport_rect().size.y-350)
	canvas.draw_rect(Rect2(origin_point-Vector2(15,32),Vector2(335,330)),Color("193038"))
	canvas.draw_string(ThemeDB.fallback_font,origin_point-Vector2(0,10),"같은 지도를 위에서 보기 · 직각 확인",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
	var scale_factor:=2.8
	for parcel in city.zoning_grid.parcels.values():
		var outline:=PackedVector2Array()
		for point in parcel.polygon:outline.append(origin_point+point*scale_factor)
		outline.append(outline[0]);canvas.draw_polyline(outline,Color("b1cba4"),0.4,true)
	for road in city.roads:
		var path:=PackedVector2Array()
		for point in road.points:path.append(origin_point+point*scale_factor)
		canvas.draw_polyline(path,Color("657078"),road.width*scale_factor,true)
