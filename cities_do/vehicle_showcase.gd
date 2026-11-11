extends Control

@export var service_only := false
@export var facility_group := ""
var entries: Array = []
var rigs: Array[Node3D] = []
var cameras: Array[Camera3D] = []
var rotating := false
var spinning := false
var same_scale := false
var grid: GridContainer

func _ready():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--asset-group="):
			var requested:=argument.trim_prefix("--asset-group=")
			if requested not in ["education_medical","commercial_industrial"]:
				push_error("Unknown exhibition asset group: "+requested)
				get_tree().quit(2)
				return
			facility_group=requested
	var doc = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json"))
	entries = doc.vehicles
	if facility_group=="commercial_industrial":
		entries=JSON.parse_string(FileAccess.get_file_as_string("res://assets/buildings/catalog.json")).buildings.filter(func(e):return e.get("recovered_batch","")=="remaining_30" and e.zone in ["commercial","industrial"] and not e.growth_enabled)
		var exhibition_theme:=Theme.new()
		exhibition_theme.default_font_size=18
		theme=exhibition_theme
	elif not facility_group.is_empty():
		entries = JSON.parse_string(FileAccess.get_file_as_string("res://assets/services/catalog.json")).facilities.filter(func(e):return e.get("group","") in ["education","medical"])
	elif service_only:
		entries=entries.filter(func(e):return e.category=="service")
		var facility: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/services/catalog.json")).facilities[0].duplicate()
		facility.merge({"length_m":16,"width_m":16,"triangles":0})
		entries.append(facility)
	var background := ColorRect.new()
	background.color = Color("142830")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var title := Label.new()
	title.text = "CITIES_DO   /   공공차량 · 화장터" if service_only else "CITIES_DO   /   차량 %d종" % entries.size()
	if not facility_group.is_empty(): title.text="CITIES_DO   /   교육 · 의료 7종"
	if facility_group=="commercial_industrial": title.text="CITIES_DO   /   상업 10 · 공업 8종"
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "시내버스 1 · 택시 1 · 시민차 20 · 산업차 16 · 공공차 3    |    실제 GLB · 미터 단위 · 우측통행"
	if service_only: subtitle.text="소방차 · 경찰차 · 운구차 · 화장터    |    애셋"
	if not facility_group.is_empty(): subtitle.text="초등학교 · 고등학교 · 전문대 · 대학교 / 진료소 · 병원 · 대형병원"
	if facility_group=="commercial_industrial": subtitle.text="업종 메타데이터 · 실제 GLB · 미터 단위 · 보기 전용"
	subtitle.add_theme_color_override("font_color", Color("b3c8c8"))
	subtitle.add_theme_font_size_override("font_size", 18)
	column.add_child(subtitle)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 14)
	column.add_child(toolbar)
	var back := Button.new()
	back.name = "ReturnToConstruction"
	back.text = "건설 화면으로 돌아가기"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
	toolbar.add_child(back)
	for item in [["같은 축척 비교", "scale"], ["차체 회전", "rotate"], ["바퀴 회전", "wheels"]]:
		var toggle := CheckButton.new()
		toggle.text = item[0]
		var action: String = item[1]
		toggle.toggled.connect(func(value):
			if action == "scale":
				same_scale = value
				update_scale()
			elif action == "rotate": rotating = value
			else: spinning = value)
		toolbar.add_child(toggle)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	for index in range(entries.size()):
		add_vehicle(entries[index], index)
	resized.connect(update_columns)
	update_columns()
	update_scale()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-vehicles="):
			capture.call_deferred(argument.trim_prefix("--capture-vehicles="))

func update_columns():
	if grid == null: return
	grid.columns = clampi(int((size.x - 48.0) / 350.0), 1, 4 if service_only else 5)

func add_vehicle(entry: Dictionary, index: int):
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = 310
	var style := StyleBoxFlat.new()
	style.bg_color = Color("203943")
	for side in ["left", "right", "top", "bottom"]:
		style.set_content_margin(side_to_margin(side), 12)
	panel.add_theme_stylebox_override("panel", style)
	grid.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var heading := Label.new()
	heading.text = "%02d   %s" % [index + 1, entry.name]
	heading.add_theme_font_size_override("font_size", 21)
	if facility_group=="commercial_industrial":
		heading.clip_text=true
		heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		heading.tooltip_text=entry.name
	box.add_child(heading)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(280, 245)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(430, 245)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("c6d7d2")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e5efea")
	environment.environment.ambient_light_energy = 0.7
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_energy = 1.1
	viewport.add_child(light)
	var rig := Node3D.new()
	rig.name = entry.id
	viewport.add_child(rig)
	var model: Node3D = load(entry.model).instantiate()
	rig.add_child(model)
	rigs.append(rig)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	var target := Vector3(0, float(entry.height_m) * 0.48, 0)
	camera.position = target + Vector3(12, 9.8, 12)
	if facility_group=="commercial_industrial":
		var distance:=maxf(24.0,maxf(float(entry.width_m),float(entry.length_m))*1.6+float(entry.height_m)*.5)
		camera.position=target+Vector3(distance,distance*9.8/12.0,distance)
	camera.look_at(target)
	camera.current = true
	cameras.append(camera)
	var specs := Label.new()
	specs.text = "%.2f × %.2f × %.2f m   ·   %d tris" % [entry.length_m, entry.width_m, entry.height_m, entry.triangles]
	if entry.get("status","")=="asset_preview_only": specs.text="%d × %dm · %d×%d칸" % [entry.width*4,entry.depth*4,entry.width,entry.depth]
	if facility_group=="commercial_industrial":
		specs.text="%s · %.2f × %.2f × %.2fm" % [entry.industry,entry.width_m,entry.length_m,entry.height_m]
		specs.clip_text=true
		specs.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		specs.tooltip_text=specs.text
	box.add_child(specs)
	var id_label := Label.new()
	id_label.text = entry.id
	id_label.add_theme_font_size_override("font_size", 14)
	if facility_group=="commercial_industrial":
		id_label.add_theme_font_size_override("font_size",18)
		id_label.clip_text=true
		id_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		id_label.tooltip_text=entry.id
	id_label.add_theme_color_override("font_color", Color("b1c8c4"))
	box.add_child(id_label)

func side_to_margin(side: String) -> int:
	return {"left": SIDE_LEFT, "right": SIDE_RIGHT, "top": SIDE_TOP, "bottom": SIDE_BOTTOM}[side]

func update_scale():
	var common_size:=48.0
	if facility_group=="commercial_industrial":
		for entry: Dictionary in entries:
			common_size=maxf(common_size,(Vector2(entry.length_m,entry.width_m).length()*.5+float(entry.height_m)*.87)*1.2)
	for index in range(cameras.size()):
		var entry: Dictionary = entries[index]
		# Camera3D size is vertical when KEEP_HEIGHT; accommodate any yaw.
		var diagonal := Vector2(float(entry.length_m), float(entry.width_m)).length()
		cameras[index].size = (common_size if not facility_group.is_empty() else (30.0 if service_only else 12.0)) if same_scale else (diagonal * 0.5 + float(entry.height_m) * 0.87) * 1.2

func _process(delta: float):
	for rig in rigs:
		if rotating: rig.rotate_y(delta * 0.3)
		if spinning:
			for node in rig.find_children("Wheel_*_Spin", "Node3D", true, false):
				node.rotate_x(delta * 2.0)

func capture(path: String):
	for frame in range(12): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Vehicle capture failed: %s" % error)
	get_tree().quit(0 if error == OK else 1)
