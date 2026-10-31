extends "res://main.gd"
const Showcase = preload("res://core/residential_showcase.gd")
var details: Label
var title_label: Label
var focus_group := ""
var legend_rows: Array[Label] = []

func _ready():
	showcase_view = true
	super._ready()
	controls_panel.hide()
	hud.hide()
	city = Showcase.create_city()
	mode = "select"
	selected = city.buildings[4].id
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20,20)
	panel.custom_minimum_size = Vector2(286,0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("162b31")
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel",style)
	layer.add_child(panel)
	panel.size = Vector2(286,maxf(300,get_viewport_rect().size.y-40))
	get_viewport().size_changed.connect(func(): panel.size.y = maxf(300,get_viewport_rect().size.y-40))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(250,0)
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",11)
	scroll.add_child(box)
	var heading := Label.new()
	heading.text = "CITIES_DO\n주거 건물 10종 전시"
	heading.add_theme_font_size_override("font_size",23)
	box.add_child(heading)
	var summary := Label.new()
	summary.text = "실제 게임 지도 · 같은 축척\n소형 4 / 중형 2 / 대형 4"
	box.add_child(summary)
	var fit := Button.new()
	fit.text = "전체 건물 한눈에 보기"
	fit.pressed.connect(func(): show_group(""))
	box.add_child(fit)
	for item in [["small","소형·중형 확대"],["large","대형 주거 확대"]]:
		var zoom_button := Button.new()
		zoom_button.text = item[1]
		var group: String = item[0]
		zoom_button.pressed.connect(func(): show_group(group))
		box.add_child(zoom_button)
	var back := Button.new()
	back.text = "건설 화면으로 돌아가기"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
	box.add_child(back)
	box.add_child(HSeparator.new())
	for index in range(city.buildings.size()):
		var building: Dictionary = city.buildings[index]
		var asset: Dictionary = city.catalog.get_asset(building.asset_id)
		var row := Label.new()
		row.text = "%02d  %s" % [index+1,asset.name]
		row.add_theme_font_size_override("font_size",15)
		box.add_child(row)
		legend_rows.append(row)
	box.add_child(HSeparator.new())
	details = Label.new()
	details.add_theme_font_size_override("font_size",16)
	box.add_child(details)
	var help := Label.new()
	help.text = "건물 클릭: 정보 확인\n휠: 확대/축소\n가운데 버튼 드래그: 화면 이동"
	help.add_theme_font_size_override("font_size",14)
	box.add_child(help)
	title_label = Label.new()
	title_label.position = Vector2(340,26)
	title_label.text = "주거 전시 거리   |   1칸 = 4m   |   왕복 4차로\n작은 주택부터 대형 타워까지 동일한 지도 축척으로 표시합니다."
	title_label.add_theme_font_size_override("font_size",19)
	layer.add_child(title_label)
	get_viewport().size_changed.connect(fit_camera)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--showcase-focus="):
			focus_group = argument.trim_prefix("--showcase-focus=")
	if focus_group == "large": selected = city.buildings[6].id
	fit_camera()
	refresh()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-showcase="):
			capture_view.call_deferred(argument.trim_prefix("--capture-showcase="))

func show_group(group: String):
	focus_group = group
	if group != "":
		for building in city.buildings:
			var asset: Dictionary = city.catalog.get_asset(building.asset_id)
			if (group == "large") == (asset.category == "large_residential"):
				selected = building.id
				break
	fit_camera()
	refresh()

func fit_camera():
	var size := get_viewport_rect().size
	var available := Rect2(340,130,maxf(400,size.x-380),maxf(350,size.y-270))
	var bounds := Rect2()
	var first := true
	for building in city.buildings:
		var asset: Dictionary = city.catalog.get_asset(building.asset_id)
		if focus_group == "small" and asset.category == "large_residential": continue
		if focus_group == "large" and asset.category != "large_residential": continue
		var front := Vector2(building.x+building.size,building.y+building.size)
		var anchor := Vector2((front.x-front.y)*tile.x,(front.x+front.y)*tile.y)
		var rect: Rect2 = city.catalog.sprite_rect(asset,anchor,tile.x*2)
		bounds = rect if first else bounds.merge(rect)
		first = false
	map_zoom = clampf(minf(available.size.x/bounds.size.x,available.size.y/bounds.size.y),0.2,2.8)
	origin = available.position+(available.size-bounds.size*map_zoom)/2.0-bounds.position*map_zoom
	queue_redraw()

func refresh():
	super.refresh()
	if details == null: return
	var building: Dictionary = city.find_building(selected)
	if building.is_empty():
		details.text = "건물을 선택해 주세요."
	else:
		var asset: Dictionary = city.catalog.get_asset(building.asset_id)
		details.text = "%s\n%s · %d×%d · 지상 %d층\n부지 %dm × %dm" % [asset.name,asset.category_name,building.size,building.size,asset.storeys,building.size*4,building.size*4]
	for index in range(legend_rows.size()):
		legend_rows[index].modulate = Color("efcc7c") if city.buildings[index].id == selected else Color("d4e0da")

func _draw():
	super._draw()
	if not showcase_view: return
	var font := ThemeDB.fallback_font
	for index in range(city.buildings.size()):
		var building: Dictionary = city.buildings[index]
		var anchor := screen(Vector2(building.x+building.size,building.y+building.size))+Vector2(0,64*map_zoom)
		draw_circle(anchor,11,Color("203a3b"))
		draw_string(font,anchor+Vector2(-8,5),"%02d" % [index+1],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("edf0df"))

func capture_view(path: String):
	for frame in range(12): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(not image.is_empty(),"A real renderer is required for capture")
	var result := image.save_png(path)
	assert(result == OK)
	var manifest := {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"viewport_px":[image.get_width(),image.get_height()],"focus_group":focus_group,"building_count":city.buildings.size(),"asset_ids":Showcase.ORDER,"pixels_per_cell_width":tile.x*2*map_zoom,"source":"Actual Godot viewport including terrain, road, zoning, buildings and interface; no compositing"}
	var file := FileAccess.open(path+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"  "))
	print("PASS actual game capture ",path," · ",image.get_width(),"x",image.get_height()," · ",city.buildings.size()," buildings")
	get_tree().quit()
