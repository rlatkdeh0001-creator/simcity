extends Node2D
const Model = preload("res://core/city_model.gd")
var city = Model.new()
var mode := "build"
var zone := "residential"
var selected := -1
var stroke := PackedVector2Array()
var drawing := false
var pointer := Vector2.ZERO
var message := "도로 옆 빈 땅을 클릭해 2×2 건물을 지으세요."
var hud: Label
var info: Label
var origin := Vector2(650, 130)
var tile := Vector2(14, 7)

func screen(p: Vector2) -> Vector2:
	return origin + Vector2((p.x - p.y) * tile.x, (p.x + p.y) * tile.y)

func world(p: Vector2) -> Vector2:
	var d := p - origin
	return Vector2((d.x / tile.x + d.y / tile.y) / 2.0, (d.y / tile.y - d.x / tile.x) / 2.0)

func _ready():
	city.add_road(PackedVector2Array([Vector2(1, 20), Vector2(39, 20)]))
	city.add_building(10, 17, "residential", 120)
	city.add_building(12, 17, "commercial", 10)
	city.add_building(14, 17, "industrial", 5)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(320, 0)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "CITIES_DO · 건설 실험실"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	for item in [["build", "2×2 건설"], ["road", "자유 도로 · 드래그"], ["select", "건물 선택"]]:
		var button := Button.new()
		button.text = item[1]
		var tool: String = item[0]
		button.pressed.connect(func(): mode = tool; drawing = false; stroke.clear(); refresh())
		box.add_child(button)
	var zones := OptionButton.new()
	for name_text in ["주거", "상업", "공업"]:
		zones.add_item(name_text)
	zones.item_selected.connect(func(index): zone = ["residential", "commercial", "industrial"][index])
	box.add_child(zones)
	var score_button := Button.new()
	score_button.text = "선택 건물 성장 수치 +100"
	score_button.pressed.connect(func():
		var b: Dictionary = city.find_building(selected)
		if not b.is_empty(): b.score += 100.0
		refresh())
	box.add_child(score_button)
	var upgrade := Button.new()
	upgrade.text = "선택 건물 업그레이드"
	upgrade.pressed.connect(func():
		var result: Dictionary = city.upgrade_chain(selected)
		message = "성장 %d개 · 연쇄 %d개" % [result.events.size(), max(0, result.events.size() - 1)] if result.ok else result.reason
		refresh())
	box.add_child(upgrade)
	info = Label.new()
	box.add_child(info)
	var reset := Button.new()
	reset.text = "도시 초기화"
	reset.pressed.connect(func(): city = Model.new(); selected = -1; message = "자유 도로를 먼저 그려 주세요."; refresh())
	box.add_child(reset)
	hud = Label.new()
	hud.position = Vector2(22, 730)
	hud.add_theme_font_size_override("font_size", 16)
	layer.add_child(hud)
	refresh()

func pick_rendered_building(position: Vector2) -> Dictionary:
	var ordered: Array = city.buildings.duplicate()
	ordered.sort_custom(func(a, b): return a.x + a.y > b.x + b.y)
	for b in ordered:
		var base := polygon(b.x, b.y, b.size)
		var top := polygon(b.x, b.y, b.size, 5 + b.level * 7)
		for face in [top, PackedVector2Array([base[1], base[2], top[2], top[1]]), PackedVector2Array([base[2], base[3], top[3], top[2]])]:
			if Geometry2D.is_point_in_polygon(position, face):
				return b
	return city.building_at(world(position))

func refresh():
	var b: Dictionary = city.find_building(selected)
	info.text = "선택 없음" if b.is_empty() else "#%d · %d×%d · 레벨 %d\n성장 수치 %.0f / %.0f" % [b.id, b.size, b.size, b.level, b.score, city.config.score_threshold]
	hud.text = "도구: %s · 건물 %d개 · 도로 %d개\n%s\n8×8 45%% / 4×4 30%% / 2×2 25%% · 인접 연쇄 55%% (최대 8개)" % [mode, city.buildings.size(), city.roads.size(), message]
	queue_redraw()

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		pointer = world(event.position)
		if drawing and (stroke.is_empty() or stroke[-1].distance_to(pointer) > 0.2):
			stroke.append(pointer)
		queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = world(event.position)
		if event.pressed:
			if mode == "road":
				drawing = true
				stroke = PackedVector2Array([pointer])
			elif mode == "build":
				var result: Dictionary = city.add_building(int(floor(pointer.x)), int(floor(pointer.y)), zone)
				message = "2×2 건설 완료" if result.ok else result.reason
				if result.ok: selected = result.building.id
			else:
				var b: Dictionary = pick_rendered_building(event.position)
				selected = b.get("id", -1)
			refresh()
		elif drawing:
			finish_road()

func _input(event):
	# Release above the HUD must also finish/cancel a captured map stroke.
	if event is InputEventMouseButton and not event.pressed and drawing:
		call_deferred("finish_road")

func finish_road():
	if not drawing: return
	drawing = false
	var result: Dictionary = city.add_road(stroke)
	message = "자유 도로 건설 완료" if result.ok else result.reason
	stroke.clear()
	refresh()

func polygon(x: float, y: float, size: float, lift: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in [Vector2(x, y), Vector2(x + size, y), Vector2(x + size, y + size), Vector2(x, y + size)]:
		points.append(screen(p) - Vector2(0, lift))
	return points

func _draw():
	for i in range(city.width + 1):
		draw_line(screen(Vector2(i, 0)), screen(Vector2(i, city.height)), Color("29404a"))
	for i in range(city.height + 1):
		draw_line(screen(Vector2(0, i)), screen(Vector2(city.width, i)), Color("29404a"))
	for road in city.roads:
		var points := PackedVector2Array()
		for p in road.points: points.append(screen(p))
		draw_polyline(points, Color("70818b"), 9, true)
		draw_polyline(points, Color("d5c58b"), 1, true)
	var sorted: Array = city.buildings.duplicate()
	sorted.sort_custom(func(a, b): return a.x + a.y < b.x + b.y)
	for b in sorted:
		var color: Color = {"residential": Color("65a87b"), "commercial": Color("629dce"), "industrial": Color("d8ac60")}[b.zone]
		var base := polygon(b.x, b.y, b.size)
		var top := polygon(b.x, b.y, b.size, 5 + b.level * 7)
		draw_colored_polygon(PackedVector2Array([base[1], base[2], top[2], top[1]]), color.darkened(0.35))
		draw_colored_polygon(PackedVector2Array([base[2], base[3], top[3], top[2]]), color.darkened(0.15))
		draw_colored_polygon(top, color)
		if b.id == selected:
			var outline := top.duplicate()
			outline.append(top[0])
			draw_polyline(outline, Color.WHITE, 2)
	if mode == "build" and pointer.x >= 0 and pointer.y >= 0 and pointer.x < city.width and pointer.y < city.height:
		var x := int(floor(pointer.x))
		var y := int(floor(pointer.y))
		var valid: bool = city.placement_error(x, y, 2) == ""
		draw_colored_polygon(polygon(x, y, 2), Color(0.3, 1, 0.5, 0.5) if valid else Color(1, 0.25, 0.2, 0.5))
	if stroke.size() > 1:
		var points := PackedVector2Array()
		for p in stroke: points.append(screen(p))
		var valid: bool = city.add_road(stroke, "local", false).ok
		draw_polyline(points, Color("75dc99") if valid else Color("ee706b"), 6, true)
