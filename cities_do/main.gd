extends Node2D
const RoadGeometry = preload("res://core/road_geometry.gd")
const BoundaryLinks = preload("res://core/boundary_links.gd")
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
const BuildingViews = preload("res://core/building_views.gd")
var painter_order=preload("res://core/isometric_order.gd").new()
var building_views
var public_controller
var road_drawer
var mode := "select"
var demolition_hover := {}
var zone := "residential"
var selected := -1
var stroke := PackedVector2Array()
var drawing := false
var zoning_drag := false
var zoning_start := Vector2.ZERO
var zoning_end := Vector2.ZERO
var zoning_brush := "residential"
var zoning_anchor: Dictionary={}
const ZONE_COLORS := {"residential":Color("65b77a"),"commercial":Color("629dce"),"industrial":Color("dfb552")}
var pointer := Vector2.ZERO
var message := ""
var hud: Label
var labor_panel: PanelContainer
var labor_rings
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

	building_views = BuildingViews.new()
	add_child(building_views)
	building_views.changed.connect(queue_redraw)
	public_controller=preload("res://core/public_placement_controller.gd").new()
	public_controller.view=self
	add_child(public_controller)
	road_drawer=preload("res://core/road_drawing.gd").new(self)

	var layer := CanvasLayer.new()
	add_child(layer)
	traffic = Traffic.new()
	add_child(traffic)
	_build_controls(layer)
	power_snapshot = city.power_state()
	power_overlay = PowerOverlay.new()
	add_child(power_overlay)
	power_overlay.setup(self,layer)
	water_snapshot = city.water_state()
	water_overlay = WaterOverlay.new()
	add_child(water_overlay)
	water_overlay.setup(self,layer)
	labor_panel=PanelContainer.new()
	labor_panel.name="LaborPanel"
	labor_panel.position=Vector2(get_viewport_rect().size.x-490,20)
	layer.add_child(labor_panel)
	labor_rings=preload("res://labor_rings.gd").new()
	labor_panel.add_child(labor_rings)
	refresh()

func _build_controls(layer: CanvasLayer):
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
	treasury_label = preload("res://core/currency_label.gd").new()
	treasury_label.name = "TreasuryLabel"
	treasury_label.add_theme_font_size_override("font_size", 18)
	box.add_child(treasury_label)
	for item in [["build", "구획"], ["road", "자유 도로 · 드래그"], ["select", "건물 선택"], ["demolish", "철거"]]:
		var button := Button.new()
		button.text = item[1]
		var tool: String = item[0]
		button.pressed.connect(func(): cancel_zoning_drag(); mode = tool; drawing = false; stroke.clear(); refresh())
		box.add_child(button)
	var lanes_choice := OptionButton.new()
	lanes_choice.add_item("왕복 2차로 · 1+1 · 폭 2칸")
	lanes_choice.add_item("왕복 4차로 · 2+2 · 폭 4칸")
	lanes_choice.item_selected.connect(func(index): road_lanes = 2 if index == 0 else 4; queue_redraw())
	box.add_child(lanes_choice)
	var zones := OptionButton.new()
	for name_text in ["주거", "상업", "공업", "구획 해제"]:
		zones.add_item(name_text)
	zones.item_selected.connect(func(index): cancel_zoning_drag(); zone = ["residential", "commercial", "industrial", ""][index])
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
	vehicle_button.text = "차량 41종 전시"
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
	var services_button := Button.new()
	services_button.name="EducationMedicalShowcaseButton"
	services_button.text="교육·의료 7종 전시"
	services_button.visible=not showcase_view
	services_button.pressed.connect(func():
		get_tree().set_meta("construction_session",{"city":city,"map_zoom":map_zoom,"origin":origin})
		get_tree().change_scene_to_file("res://education_medical_showcase.tscn"))
	box.add_child(services_button)
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
	reset.pressed.connect(func(): cancel_zoning_drag(); stop_traffic(); city = Model.new(int(map_settings.width_cells), int(map_settings.height_cells), int(map_settings.seed)); selected = -1; message = ""; refresh())
	box.add_child(reset)
	hud = Label.new()
	hud.position = Vector2(360, get_viewport_rect().size.y-100)
	hud.add_theme_font_size_override("font_size", 16)
	layer.add_child(hud)

func toggle_traffic():
	if traffic.running:
		stop_traffic()
		message = "도로 주행을 종료했습니다"
	else:
		if traffic.rebuild(city.roads):
			traffic.seed_traffic()
			if traffic_button != null: traffic_button.text = "도로 주행 종료"
		message = traffic.status
	refresh()

func stop_traffic():
	if traffic != null: traffic.stop()
	if traffic_button != null: traffic_button.text = "도로 주행 시작"

func _process(delta: float):
	var before_buildings: int=city.buildings.size()
	city.advance_society(delta)
	if labor_panel!=null:labor_panel.position.x=maxf(8,get_viewport_rect().size.x-490)
	if city.buildings.size()!=before_buildings or (labor_panel!=null and labor_panel.visible): refresh()
	# Simulation/billing runs regardless of the power tab or visual pause.
	power_snapshot = city.advance_power(delta*city.Clock.SCALE/3600.0)
	water_snapshot = city.advance_water(delta*city.Clock.SCALE/86400.0)
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

func building_visual(b: Dictionary) -> Dictionary:
	var asset: Dictionary=city.catalog.get_asset(b.get("asset_id",""))
	if asset.is_empty():return {}
	if city.supports_static_sprite(b) and building_textures.has(asset.id):
		var bounds: Rect2=city.Parcels.bounds(city.footprint(b))
		return {"texture":building_textures[asset.id],"image":building_images[asset.id],
			"rect":city.catalog.sprite_rect(asset,screen(bounds.end),tile.x*2*map_zoom)}
	var view: Dictionary=building_views.view(asset,city.front_direction(b))
	if view.is_empty():return {}
	var center:=Vector2.ZERO
	for point in city.footprint(b):center+=point
	center/=4
	var scale_factor: float=tile.x/4*sqrt(2.0)*map_zoom/view.ppm
	return {"texture":view.texture,"image":view.image,
		"rect":Rect2(screen(center)-view.anchor*scale_factor,Vector2(view.image.get_size())*scale_factor)}

func pick_rendered_building(position: Vector2) -> Dictionary:
	var ordered: Array = building_draw_order().filter(func(record):return not record.has("public_asset_id"))
	ordered.reverse()
	for b in ordered:
		var visual:=building_visual(b)
		if not visual.is_empty():
			var rect: Rect2=visual.rect
			if rect.has_point(position):
				var uv := (position-rect.position)/rect.size
				var image: Image=visual.image
				var pixel:=Vector2i(uv*Vector2(image.get_size()))
				if image.get_pixelv(pixel).a>.1:return b
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
	if road_drawer!=null and mode!="road":road_drawer.cancel()
	if labor_panel!=null:
		labor_panel.visible=city.population.workplaces.has(selected)
		labor_rings.work=city.population.workplaces.get(selected,{})
		labor_rings.queue_redraw()
	if treasury_label != null:
		treasury_label.text = "자금: %s" % city.Economy.format_amount(city.funds)
	var b: Dictionary = city.find_building(selected)
	info.text = "선택 없음" if b.is_empty() else "#%d · %d×%d · 레벨 %d\n성장 수치 %.0f / %.0f" % [b.id, b.size, b.size, b.level, b.score, city.config.score_threshold]
	if not b.is_empty():
		var asset: Dictionary = city.catalog.get_asset(b.get("asset_id", ""))
		if not asset.is_empty():
			info.text += "\n%s · %s · 지상 %d층" % [asset.category_name, asset.name, asset.storeys]
	hud.text = message
	queue_redraw()

func cancel_zoning_drag() -> void:
	zoning_drag=false
	zoning_anchor.clear()
	queue_redraw()

func zoning_selection() -> PackedVector2Array:
	if zoning_anchor.is_empty():return PackedVector2Array()
	var frame: Dictionary=zoning_anchor.frame
	var offset: Vector2=world(zoning_end)-Vector2(frame.origin)
	var u:=floori(offset.dot(frame.along)+.00001);var v:=floori(offset.dot(frame.outward)+.00001)
	var first_u:=mini(int(zoning_anchor.u),u);var first_v:=mini(int(zoning_anchor.v),v)
	var width:=absi(u-int(zoning_anchor.u))+1;var depth:=absi(v-int(zoning_anchor.v))+1
	var first: Vector2=frame.origin+frame.along*first_u+frame.outward*first_v
	return PackedVector2Array([first,first+frame.along*width,first+frame.along*width+frame.outward*depth,first+frame.outward*depth])

func finish_zoning(position: Vector2,over_hud: bool=false) -> void:
	if not zoning_drag:return
	zoning_end=position
	if mode!="build" or over_hud:
		cancel_zoning_drag()
		return
	var result: Dictionary=city.paint_zones(zoning_selection(),zoning_brush)
	message=result.reason
	cancel_zoning_drag()
	refresh()

func _unhandled_key_input(event):
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:cancel_zoning_drag()

func _unhandled_input(event):
	if road_drawer!=null and road_drawer.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if zoning_drag and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_zoning_drag()
		return
	if mode=="demolish":
		if event is InputEventMouseMotion:
			demolition_hover=demolition_target(event.position)
			queue_redraw()
		elif event is InputEventMouseButton:
			if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
				mode="select"
				demolition_hover.clear()
				refresh()
				return
			if event.button_index==MOUSE_BUTTON_LEFT:
				if event.pressed:
					var target := demolition_target(event.position)
					if not target.is_empty():
						var result: Dictionary=city.demolish(target.kind,target.id)
						message=result.reason
						if result.ok:
							if target.kind=="road": stop_traffic()
							if target.kind=="building" and selected==target.id: selected=-1
							demolition_hover.clear()
						refresh()
				return
	if water_overlay != null and water_overlay.handle_input(event): return
	if power_overlay != null and power_overlay.handle_input(event): return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			cancel_zoning_drag()
			panning = event.pressed
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			cancel_zoning_drag()
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
				stroke = PackedVector2Array([city.RoadJunctions.snap_point(pointer,city.roads)])
			elif mode == "build":
				var parcel: Dictionary=city.zoning_grid.parcel_at(pointer)
				if parcel.is_empty():return
				zoning_anchor=parcel.duplicate(true)
				zoning_start=event.position
				zoning_end=event.position
				zoning_brush=zone
				zoning_drag=true
			else:
				var b: Dictionary = pick_rendered_building(event.position)
				selected = b.get("id", -1)
			refresh()
		elif zoning_drag:
			finish_zoning(event.position)
		elif drawing:
			finish_road()

func _input(event):
	if zoning_drag:
		if event is InputEventMouseMotion:
			zoning_end=event.position
			queue_redraw()
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
			finish_zoning(event.position,get_viewport().gui_get_hovered_control()!=null)
	if water_overlay != null: water_overlay.finish_capture(event)
	if power_overlay != null: power_overlay.finish_capture(event)
	# Release above the HUD must also finish/cancel a captured map stroke.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		panning = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and drawing:
		if get_viewport().gui_get_hovered_control()==null:
			pointer=world(event.position)
			if stroke.is_empty() or stroke[-1].distance_to(pointer)>.00001:stroke.append(pointer)
		call_deferred("finish_road")

func finish_road():
	if not drawing: return
	drawing = false
	var result: Dictionary = city.add_road(stroke, "local", true, road_lanes, true)
	if result.ok: stop_traffic()
	message = "자유 도로 건설 완료" if result.ok else result.reason
	stroke.clear()
	refresh()

func polygon(x: float, y: float, size: float, lift: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in [Vector2(x, y), Vector2(x + size, y), Vector2(x + size, y + size), Vector2(x, y + size)]:
		points.append(screen(p) - Vector2(0, lift * map_zoom))
	return points

func building_draw_order() -> Array:
	var records: Array=city.buildings.duplicate()
	records.append_array(city.public_facilities.lots)
	var polygons: Array=[]
	for record: Dictionary in records:polygons.append(city.footprint(record))
	return painter_order.sorted(records,polygons)

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
	for shape in RoadGeometry.clipped_ribbons(points,width,Vector2(city.width,city.height)):
		var projected := PackedVector2Array()
		for point in shape: projected.append(screen(point))
		draw_colored_polygon(projected,color)

func show_zoning_tiles() -> bool:
	return mode in ["build","road"]

func visible_zoning_parcels() -> Array[Dictionary]:
	if show_zoning_tiles(): return city.zoning_grid.parcels_in(visible_world_bounds())
	var empty: Array[Dictionary]=[]
	return empty

func demolition_target(position: Vector2) -> Dictionary:
	var public_record: Dictionary=public_controller.target(position)
	if not public_record.is_empty():return {"kind":"public_facility","id":public_record.id,"polygon":projected_footprint(public_record)}
	# Visible utility layer wins over an overlapping road; hidden pipes are never hit.
	for kind in ["power_plant","water_facility"]:
		var facilities: Array=city.power.plants if kind=="power_plant" else city.water.facilities
		for facility in facilities:
			if facility.has("public_lot_id"):continue
			var point: Vector2=facility.position/4-Vector2.ONE
			var top := polygon(point.x,point.y,2,22)
			var base := polygon(point.x,point.y,2)
			if Geometry2D.is_point_in_polygon(position,top) or Geometry2D.is_point_in_polygon(position,base):
				return {"kind":kind,"id":facility.id,"polygon":top}
	for kind in ["power_wire","water_pipe"]:
		var visible_layer: bool=power_overlay.tab_open if kind=="power_wire" else water_overlay.tab_open
		if not visible_layer: continue
		var wires: Array=city.power.wires if kind=="power_wire" else city.water.geometry.wires
		var nearest := 8.0
		var result := {}
		for wire in wires:
			for i in range(wire.points.size()-1):
				var a := screen(wire.points[i]/4)
				var b := screen(wire.points[i+1]/4)
				var distance: float=position.distance_to(Geometry2D.get_closest_point_to_segment(position,a,b))
				if distance<nearest:
					nearest=distance
					var points := PackedVector2Array()
					for point in wire.points: points.append(screen(point/4))
					result={"kind":kind,"id":wire.id,"line":points}
		if not result.is_empty(): return result
	var building: Dictionary=pick_rendered_building(position)
	if not building.is_empty(): return {"kind":"building","id":building.id,"polygon":projected_footprint(building)}
	var point := world(position)
	for i in range(city.roads.size()):
		var road: Dictionary=city.roads[i]
		for j in range(road.points.size()-1):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,road.points[j],road.points[j+1]))<=road.width/2:
				return {"kind":"road","id":int(road.get("parcel_id",i)),"road":road}
	return {}

func draw_front_door(b: Dictionary):
	var footprint: PackedVector2Array=city.footprint(b)
	var center:=Vector2.ZERO
	for point in footprint:center+=point
	center/=4
	var front: Vector2=city.front_direction(b)
	var middle:=center+front*float(b.size)/2
	var side:=Vector2(-front.y,front.x)*.15
	var lift:=Vector2(0,minf(visual_lift(b)*map_zoom*.8,2.2*tile.x/4*sqrt(1.5)*map_zoom))
	var left:=screen(middle-side)
	var right:=screen(middle+side)
	# A back-facing door is hidden by the roof/body, as on the 3D asset.
	if screen(middle).y<screen(center).y-.001:return
	draw_colored_polygon(PackedVector2Array([left,right,right-lift,left-lift]),Color("293c46"))

func _draw():
	# One terrain polygon, no full-map cell array or always-on grid.
	var terrain := PackedVector2Array([screen(Vector2.ZERO),screen(Vector2(city.width,0)),screen(Vector2(city.width,city.height)),screen(Vector2(0,city.height))])
	draw_colored_polygon(terrain,Color("7e9275"))
	for parcel in visible_zoning_parcels():
		var outline := PackedVector2Array()
		for point in parcel.polygon:outline.append(screen(point))
		var designated: String=city.zone_designations.get(parcel.id,"")
		var tint: Color=ZONE_COLORS.get(designated,Color(0.82,0.89,0.72))
		tint.a=.50 if not designated.is_empty() else .22
		draw_colored_polygon(outline,tint)
		outline.append(outline[0])
		draw_polyline(outline,Color(0.87,0.94,0.8,0.5),0.7,true)
	# Paint all sidewalks before any asphalt: a later stroke's round end cap
	# must not cut a pale curb across the already-connected carriageway.
	for road in city.road_visuals:
		draw_ribbon(road.points,road.width,Color("c8cbc3"))
	for road in city.road_visuals:
		draw_ribbon(road.points,road.width*(0.75 if road.lanes == 2 else 0.8125),Color("4c5659"))
	for road in city.road_visuals:
		var points := PackedVector2Array()
		for p in road.points: points.append(screen(p))
		draw_polyline(points,Color("e4bd5f"),maxf(0.6,map_zoom),true)
		for dash in RoadGeometry.lane_marks(road):
			var clipped: PackedVector2Array=RoadGeometry.clipped_segment(dash[0],dash[1],Vector2(city.width,city.height))
			if clipped.size()==2:draw_line(screen(clipped[0]),screen(clipped[1]),Color("e8e7dc"),maxf(0.6,map_zoom),true)
	for junction in city.junctions:
		for asphalt in [false,true]:
			var outline := PackedVector2Array()
			for point in city.RoadJunctions.patch(junction,asphalt): outline.append(screen(point))
			if outline.size()>=3: draw_colored_polygon(outline,Color("4c5659") if asphalt else Color("c8cbc3"))
		# Gentle endpoint/lane transitions connect traffic without new zebra crossings.
		if junction.get("transition",false):continue
		for arm in junction.arms:
			var direction: Vector2=arm.direction
			var normal := Vector2(-direction.y,direction.x)
			var half: float=arm.width*(.75 if arm.lanes==2 else .8125)/2
			var centre: Vector2=junction.position+direction*city.RoadJunctions.crosswalk_distance(junction,arm)
			var stripe_half: float=city.RoadJunctions.CROSSWALK_HALF_LENGTH
			var offset := -half+.12
			while offset<half-.12:
				var p: Vector2=centre+normal*offset
				var corners := PackedVector2Array([p-direction*stripe_half,p+direction*stripe_half,p+direction*stripe_half+normal*.14,p-direction*stripe_half+normal*.14])
				var projected := PackedVector2Array()
				for corner in corners:projected.append(screen(corner))
				draw_colored_polygon(projected,Color("e8e7dc"))
				offset+=.28
	BoundaryLinks.draw_links(self,self,BoundaryLinks.road_links(city))
	draw_traffic()
	var sorted: Array = building_draw_order()
	for b in sorted:
		if b.has("public_asset_id"):
			var public_visual: Dictionary=public_controller.visual(b)
			if not public_visual.is_empty():draw_texture_rect(public_visual.texture,public_visual.rect,false)
			continue
		var visual:=building_visual(b)
		if not visual.is_empty():
			draw_texture_rect(visual.texture,visual.rect,false)
			if b.id==selected:
				var outline:=projected_footprint(b)
				outline.append(outline[0])
				draw_polyline(outline,Color.WHITE,2)
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
		draw_front_door(b)
		if b.id == selected:
			var outline := top.duplicate()
			outline.append(top[0])
			draw_polyline(outline, Color.WHITE, 2)
	if zoning_drag:
		var selection := zoning_selection()
		if selection.size()>=3:
			var preview := PackedVector2Array()
			for point in selection:preview.append(screen(point))
			var tint: Color=ZONE_COLORS.get(zoning_brush,Color("e4eef1"))
			tint.a=.3
			draw_colored_polygon(preview,tint)
	if stroke.size() > 1:
		var snapped: PackedVector2Array=city.RoadJunctions.snap_path(stroke,city.roads)
		var points := PackedVector2Array()
		for p in snapped: points.append(screen(p))
		var valid: bool = city.add_road(snapped, "local", false, road_lanes).ok
		draw_ribbon(snapped, road_lanes, Color(0.3,0.9,0.5,0.7) if valid else Color(0.95,0.3,0.25,0.7))

	if road_drawer!=null:road_drawer.draw_preview()
	if mode=="demolish" and not demolition_hover.is_empty():
		var tint := Color(1,.35,.20,.65)
		if demolition_hover.has("polygon"):
			draw_colored_polygon(demolition_hover.polygon,tint)
		elif demolition_hover.has("line"):
			draw_polyline(demolition_hover.line,tint,10,true)
		elif demolition_hover.has("road"):
			draw_ribbon(demolition_hover.road.points,demolition_hover.road.width,tint)
