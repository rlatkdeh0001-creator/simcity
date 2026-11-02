extends Node2D
const RoadGeometry = preload("res://core/road_geometry.gd")
const Traffic = preload("res://core/traffic_controller.gd")
const PowerOverlay = preload("res://core/power_overlay.gd")
var power_overlay
var power_snapshot := {}
const WaterOverlay = preload("res://core/water_overlay.gd")
var water_overlay
var water_snapshot := {}
var traffic
var traffic_button: Button
var map_settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://maps/example_100.json"))
const Model = preload("res://core/city_model.gd")
var city = Model.new(int(map_settings.width_cells), int(map_settings.height_cells), int(map_settings.seed))
var road_lanes := 2
var map_zoom := 0.65
var panning := false
var showcase_view := false
var controls_panel: PanelContainer
var building_textures := {}
var building_images := {}
var mode := "build"
var zone := "residential"
var selected := -1
var stroke := PackedVector2Array()
var drawing := false
var pointer := Vector2.ZERO
var message := "빈 지도입니다. 도로를 그리면 주변 건설 격자가 표시됩니다."
var hud: Label
var info: Label
var treasury_label: Label
var origin := Vector2(650, 130)
var tile := Vector2(14, 7)

func screen(p: Vector2) -> Vector2:
	return origin + Vector2((p.x - p.y) * tile.x, (p.x + p.y) * tile.y) * map_zoom

func world(p: Vector2) -> Vector2:
	var d := (p - origin) / map_zoom
	return Vector2((d.x / tile.x + d.y / tile.y) / 2.0, (d.y / tile.y - d.x / tile.x) / 2.0)

func _ready():
	if not showcase_view and get_tree().has_meta("construction_session"):
		var session: Dictionary = get_tree().get_meta("construction_session")
		city = session.city
		map_zoom = session.map_zoom
		origin = session.origin
		get_tree().remove_meta("construction_session")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for asset in city.catalog.entries:
		var texture: Texture2D = load(asset.texture)
		if texture != null:
			building_textures[asset.id] = texture
			building_images[asset.id] = texture.get_image()

	var layer := CanvasLayer.new()
	add_child(layer)
	traffic = Traffic.new()
	add_child(traffic)
	var panel := PanelContainer.new()
	controls_panel = panel
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
	treasury_label = Label.new()
	treasury_label.name = "TreasuryLabel"
	treasury_label.add_theme_font_size_override("font_size", 18)
	box.add_child(treasury_label)
	for item in [["build", "2×2 건설"], ["road", "자유 도로 · 드래그"], ["select", "건물 선택"]]:
		var button := Button.new()
		button.text = item[1]
		var tool: String = item[0]
		button.pressed.connect(func(): mode = tool; drawing = false; stroke.clear(); refresh())
		box.add_child(button)
	var lanes_choice := OptionButton.new()
	lanes_choice.add_item("왕복 2차로 · 1+1 · 폭 2칸")
	lanes_choice.add_item("왕복 4차로 · 2+2 · 폭 4칸")
	lanes_choice.item_selected.connect(func(index): road_lanes = 2 if index == 0 else 4; queue_redraw())
	box.add_child(lanes_choice)
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
	var showcase_button := Button.new()
	showcase_button.visible = not showcase_view
	showcase_button.text = "주거 건물 10종 전시"
	showcase_button.pressed.connect(func():
		get_tree().set_meta("construction_session",{"city":city,"map_zoom":map_zoom,"origin":origin})
		get_tree().change_scene_to_file("res://residential_showcase.tscn"))
	box.add_child(showcase_button)
	var vehicle_button := Button.new()
	vehicle_button.name = "VehicleShowcaseButton"
	vehicle_button.text = "차량 20종 전시"
	vehicle_button.visible = not showcase_view
	vehicle_button.pressed.connect(func():
		get_tree().set_meta("construction_session",{"city":city,"map_zoom":map_zoom,"origin":origin})
		get_tree().change_scene_to_file("res://vehicle_showcase.tscn"))
	box.add_child(vehicle_button)
	var facility_button := Button.new()
	facility_button.name = "FacilitiesShowcaseButton"
	facility_button.text = "공원·주차 시설 전시"
	facility_button.visible = not showcase_view
	facility_button.pressed.connect(func():
		get_tree().set_meta("construction_session",{"city":city,"map_zoom":map_zoom,"origin":origin})
		get_tree().change_scene_to_file("res://facilities_showcase.tscn"))
	box.add_child(facility_button)
	var traffic_row := HBoxContainer.new()
	traffic_row.visible = not showcase_view
	box.add_child(traffic_row)
	traffic_button = Button.new()
	traffic_button.name = "TrafficToggleButton"
	traffic_button.text = "도로 주행 시작"
	traffic_button.pressed.connect(toggle_traffic)
	traffic_row.add_child(traffic_button)
	var traffic_demo := Button.new()
	traffic_demo.name = "TrafficDemoButton"
	traffic_demo.text = "주행 AI 시험장"
	traffic_demo.pressed.connect(func():
		get_tree().set_meta("construction_session",{"city":city,"map_zoom":map_zoom,"origin":origin})
		get_tree().change_scene_to_file("res://traffic_demo.tscn"))
	traffic_row.add_child(traffic_demo)
	var power_button := Button.new()
	power_button.name = "PowerTabButton"
	power_button.text = "전력"
	power_button.visible = not showcase_view
	power_button.pressed.connect(func():
		if water_overlay.tab_open: water_overlay.toggle()
		power_overlay.toggle())
	var power_row := HBoxContainer.new()
	power_row.visible = not showcase_view
	box.add_child(power_row)
	power_row.add_child(power_button)
	var power_demo := Button.new()
	power_demo.name = "PowerDemoButton"
	power_demo.text = "전력 실습 도시"
	power_demo.pressed.connect(func():
		get_tree().set_meta("construction_session",{"city":city,"map_zoom":map_zoom,"origin":origin})
		get_tree().change_scene_to_file("res://power_demo.tscn"))
	power_row.add_child(power_demo)
	var water_row := HBoxContainer.new()
	water_row.visible = not showcase_view
	box.add_child(water_row)
	var water_button := Button.new()
	water_button.name = "WaterTabButton"
	water_button.text = "상하수도"
	water_button.pressed.connect(func(): water_overlay.toggle())
	water_row.add_child(water_button)
	var water_demo := Button.new()
	water_demo.name = "WaterDemoButton"
	water_demo.text = "상하수도 실습 도시"
	water_demo.pressed.connect(func():
		get_tree().set_meta("construction_session",{"city":city,"map_zoom":map_zoom,"origin":origin})
		get_tree().change_scene_to_file("res://water_demo.tscn"))
	water_row.add_child(water_demo)
	var parcel_demo := Button.new()
	parcel_demo.text = "도로 직각 구획 예시"
	parcel_demo.visible = not showcase_view
	parcel_demo.pressed.connect(func():
		get_tree().set_meta("construction_session",{"city":city,"map_zoom":map_zoom,"origin":origin})
		get_tree().change_scene_to_file("res://road_parcel_demo.tscn"))
	box.add_child(parcel_demo)
	var reset := Button.new()
	reset.text = "도시 초기화"
	reset.pressed.connect(func(): stop_traffic(); city = Model.new(int(map_settings.width_cells), int(map_settings.height_cells), int(map_settings.seed)); selected = -1; message = "자유 도로를 먼저 그려 주세요."; refresh())
	box.add_child(reset)
	hud = Label.new()
	hud.position = Vector2(360, get_viewport_rect().size.y-100)
	hud.add_theme_font_size_override("font_size", 16)
	layer.add_child(hud)
	power_snapshot = city.power_state()
	power_overlay = PowerOverlay.new()
	add_child(power_overlay)
	power_overlay.setup(self,layer)
	water_snapshot = city.water_state()
	water_overlay = WaterOverlay.new()
	add_child(water_overlay)
	water_overlay.setup(self,layer)
	refresh()

func toggle_traffic():
	if traffic.running:
		stop_traffic()
		message = "도로 주행을 종료했습니다"
	else:
		if traffic.rebuild(city.roads):
			traffic.seed_traffic()
			traffic_button.text = "도로 주행 종료"
		message = traffic.status
	refresh()

func stop_traffic():
	if traffic != null: traffic.stop()
	if traffic_button != null: traffic_button.text = "도로 주행 시작"

func _process(delta: float):
	# Simulation/billing runs regardless of the power tab or visual pause.
	power_snapshot = city.advance_power(delta/3600.0)
	water_snapshot = city.advance_water(delta/86400.0)
	if water_overlay != null: water_overlay.update_state(delta)
	if treasury_label != null: treasury_label.text = "자금: %s" % city.Economy.format_amount(city.funds)
	if power_overlay != null: power_overlay.update_state(delta)
	if traffic != null and traffic.running:
		traffic.update(delta)
		queue_redraw()

func draw_traffic():
	if traffic == null or not traffic.running: return
	var ordered: Array = traffic.simulation.vehicles.duplicate()
	ordered.sort_custom(func(a,b):
		var pa: Vector2 = traffic.simulation.position(a)
		var pb: Vector2 = traffic.simulation.position(b)
		return pa.x+pa.y < pb.x+pb.y)
	for vehicle in ordered:
		var position_m: Vector2 = traffic.simulation.position(vehicle)
		var heading: Vector2 = traffic.simulation.heading(vehicle)
		var texture: Texture2D = traffic.texture_for(vehicle.asset_id, heading)
		var rect: Rect2 = traffic.sprite_rect(vehicle.asset_id, screen(position_m/4.0), tile.x/4.0*sqrt(2.0)*map_zoom)
		draw_texture_rect(texture, rect, false)

func pick_rendered_building(position: Vector2) -> Dictionary:
	var ordered: Array = city.buildings.duplicate()
	ordered.sort_custom(func(a, b): return building_depth(a) > building_depth(b))
	for b in ordered:
		var asset: Dictionary = city.catalog.get_asset(b.get("asset_id", ""))
		if not asset.is_empty() and building_images.has(asset.id) and city.supports_static_sprite(b):
			var rect: Rect2 = city.catalog.sprite_rect(asset, screen(Vector2(b.x + b.size, b.y + b.size)), tile.x * 2 * map_zoom)
			if rect.has_point(position):
				var uv := (position - rect.position) / rect.size
				var image: Image = building_images[asset.id]
				var pixel := Vector2i(uv * Vector2(image.get_size()))
				if image.get_pixelv(pixel).a > 0.1:
					return b
			continue
		var base := projected_footprint(b)
		var top := lifted_footprint(b,visual_lift(b))
		var faces: Array[PackedVector2Array]=[top]
		for edge in range(4):
			var next: int=(edge+1)%4
			faces.append(PackedVector2Array([base[edge],base[next],top[next],top[edge]]))
		for face in faces:
			if Geometry2D.is_point_in_polygon(position, face):
				return b
	return city.building_at(world(position))

func refresh():
	if treasury_label != null:
		treasury_label.text = "자금: %s" % city.Economy.format_amount(city.funds)
	var b: Dictionary = city.find_building(selected)
	info.text = "선택 없음" if b.is_empty() else "#%d · %d×%d · 레벨 %d\n성장 수치 %.0f / %.0f" % [b.id, b.size, b.size, b.level, b.score, city.config.score_threshold]
	if not b.is_empty():
		var asset: Dictionary = city.catalog.get_asset(b.get("asset_id", ""))
		if not asset.is_empty():
			info.text += "\n%s · %s · 지상 %d층" % [asset.category_name, asset.name, asset.storeys]
		if b.has("frame"):
			info.text += "\n도로 직각 구획 · 방향 %.1f°" % rad_to_deg(Vector2(b.frame.along).angle())
			if not city.supports_static_sprite(b):info.text += "\n방향에 맞춘 임시 입체 건물"
	hud.text = "도구: %s · 건물 %d개 · 도로 %d개\n%s\n8×8 45%% / 4×4 30%% / 2×2 25%% · 인접 연쇄 55%% (최대 8개)" % [mode, city.buildings.size(), city.roads.size(), message]
	hud.text += "\n%d×%d · 1칸=4m · 휠 확대/축소 · 가운데 버튼 드래그 이동" % [city.width, city.height]
	queue_redraw()

func _unhandled_input(event):
	if water_overlay != null and water_overlay.handle_input(event): return
	if power_overlay != null and power_overlay.handle_input(event): return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var anchor := world(event.position)
			map_zoom = clampf(map_zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.15),0.15,3.0)
			origin = event.position - Vector2((anchor.x-anchor.y)*tile.x,(anchor.x+anchor.y)*tile.y)*map_zoom
			queue_redraw()
			return
	if event is InputEventMouseMotion and panning:
		origin += event.relative
		queue_redraw()
		return
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
				var result: Dictionary = city.add_building_at(pointer, zone)
				message = "2×2 건설 완료" if result.ok else result.reason
				if result.ok: selected = result.building.id
			else:
				var b: Dictionary = pick_rendered_building(event.position)
				selected = b.get("id", -1)
			refresh()
		elif drawing:
			finish_road()

func _input(event):
	if water_overlay != null: water_overlay.finish_capture(event)
	if power_overlay != null: power_overlay.finish_capture(event)
	# Release above the HUD must also finish/cancel a captured map stroke.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		panning = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and drawing:
		call_deferred("finish_road")

func finish_road():
	if not drawing: return
	drawing = false
	var result: Dictionary = city.add_road(stroke, "local", true, road_lanes)
	if result.ok: stop_traffic()
	message = "자유 도로 건설 완료" if result.ok else result.reason
	stroke.clear()
	refresh()

func polygon(x: float, y: float, size: float, lift: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in [Vector2(x, y), Vector2(x + size, y), Vector2(x + size, y + size), Vector2(x, y + size)]:
		points.append(screen(p) - Vector2(0, lift * map_zoom))
	return points

func building_depth(building: Dictionary) -> float:
	var depth: float=-INF
	for point in city.footprint(building):depth=maxf(depth,point.x+point.y)
	return depth

func visual_lift(building: Dictionary) -> float:
	var asset: Dictionary=city.catalog.get_asset(building.get("asset_id",""))
	if not asset.is_empty():return asset.storeys*3.05*tile.x*sqrt(3.0)/sqrt(2.0)/4.0
	return 5+building.level*7

func projected_footprint(building: Dictionary) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for point in city.footprint(building):result.append(screen(point))
	return result

func lifted_footprint(building: Dictionary,lift: float) -> PackedVector2Array:
	var result:=projected_footprint(building)
	for i in range(result.size()):result[i]-=Vector2(0,lift*map_zoom)
	return result

func visible_world_bounds() -> Rect2i:
	var viewport_size := get_viewport_rect().size
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for p in [Vector2.ZERO,Vector2(viewport_size.x,0),viewport_size,Vector2(0,viewport_size.y)]:
		low = low.min(world(p))
		high = high.max(world(p))
	var first := Vector2i(maxi(0,floori(low.x)-1),maxi(0,floori(low.y)-1))
	var last := Vector2i(mini(city.width,ceili(high.x)+1),mini(city.height,ceili(high.y)+1))
	return Rect2i(first,Vector2i(maxi(0,last.x-first.x),maxi(0,last.y-first.y)))

func draw_ribbon(points: PackedVector2Array, width: float, color: Color):
	for shape in RoadGeometry.ribbons(points,width):
		var projected := PackedVector2Array()
		for point in shape: projected.append(screen(point))
		draw_colored_polygon(projected,color)

func _draw():
	# One terrain polygon, no full-map cell array or always-on grid.
	var terrain := PackedVector2Array([screen(Vector2.ZERO),screen(Vector2(city.width,0)),screen(Vector2(city.width,city.height)),screen(Vector2(0,city.height))])
	draw_colored_polygon(terrain,Color("7e9275"))
	for parcel in city.zoning_grid.parcels_in(visible_world_bounds()):
		var outline := PackedVector2Array()
		for point in parcel.polygon:outline.append(screen(point))
		draw_colored_polygon(outline,Color(0.82,0.89,0.72,0.22))
		outline.append(outline[0])
		draw_polyline(outline,Color(0.87,0.94,0.8,0.5),0.7,true)
	for road in city.roads:
		draw_ribbon(road.points,road.width,Color("c8cbc3"))
		draw_ribbon(road.points,road.width*(0.75 if road.lanes == 2 else 0.8125),Color("4c5659"))
		var points := PackedVector2Array()
		for p in road.points: points.append(screen(p))
		draw_polyline(points,Color("e4bd5f"),maxf(0.6,map_zoom),true)
		for dash in RoadGeometry.lane_marks(road):
			draw_line(screen(dash[0]),screen(dash[1]),Color("e8e7dc"),maxf(0.6,map_zoom),true)
	draw_traffic()
	var sorted: Array = city.buildings.duplicate()
	sorted.sort_custom(func(a, b): return building_depth(a) < building_depth(b))
	for b in sorted:
		var asset: Dictionary = city.catalog.get_asset(b.get("asset_id", ""))
		if not asset.is_empty() and building_textures.has(asset.id) and city.supports_static_sprite(b):
			var rect: Rect2 = city.catalog.sprite_rect(asset, screen(Vector2(b.x + b.size, b.y + b.size)), tile.x * 2 * map_zoom)
			draw_texture_rect(building_textures[asset.id], rect, false)
			if b.id == selected:
				var outline := polygon(b.x, b.y, b.size)
				draw_polyline(PackedVector2Array([outline[1],outline[2],outline[3]]), Color.WHITE, 2)
			continue
		var color: Color = {"residential": Color("65a87b"), "commercial": Color("629dce"), "industrial": Color("d8ac60")}[b.zone]
		var base := projected_footprint(b)
		var top := lifted_footprint(b,visual_lift(b))
		var faces: Array[Dictionary]=[]
		for edge in range(4):
			var next: int=(edge+1)%4
			faces.append({"depth":(base[edge].y+base[next].y)/2,"points":PackedVector2Array([base[edge],base[next],top[next],top[edge]]),"shade":0.15 if edge%2 else 0.35})
		faces.sort_custom(func(a,c):return a.depth<c.depth)
		for face in faces:draw_colored_polygon(face.points,color.darkened(face.shade))
		draw_colored_polygon(top, color)
		if b.id == selected:
			var outline := top.duplicate()
			outline.append(top[0])
			draw_polyline(outline, Color.WHITE, 2)
	if mode == "build":
		var parcel: Dictionary=city.zoning_grid.parcel_at(pointer)
		if not parcel.is_empty():
			var valid: bool=city.parcel_placement_error(parcel.frame,parcel.u,parcel.v,2)==""
			var preview:=PackedVector2Array()
			for point in city.Parcels.polygon(parcel.frame,parcel.u,parcel.v,2):preview.append(screen(point))
			draw_colored_polygon(preview,Color(0.3,1,0.5,0.5) if valid else Color(1,0.25,0.2,0.5))
	if stroke.size() > 1:
		var points := PackedVector2Array()
		for p in stroke: points.append(screen(p))
		var valid: bool = city.add_road(stroke, "local", false, road_lanes).ok
		draw_ribbon(stroke, road_lanes, Color(0.3,0.9,0.5,0.7) if valid else Color(0.95,0.3,0.25,0.7))
