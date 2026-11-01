extends "res://main.gd"
var stats: Label
var manual_red := true
var demo_time := 0.0
var capture_path := ""
var capture_done := false
var recording_dir := ""
var recording_index := -1
var recording_busy := false

func _ready():
	showcase_view = true
	super._ready()
	controls_panel.hide()
	hud.hide()
	mode = "select"
	city = Model.new(100,100,42)
	var ring := PackedVector2Array()
	for i in range(97):
		var angle := float(i)/96.0*TAU
		ring.append(Vector2(50,50)+Vector2(cos(angle),sin(angle))*18.0)
	city.add_road(ring, "local", true, 4)
	city.add_road(PackedVector2Array([Vector2(38,50),Vector2(62,50)]), "local", true, 2)
	traffic.rebuild(city.roads)
	for lane in traffic.network.lanes:
		var loop: bool = lane.closed
		var count := 5 if loop else 3
		for i in range(count):
			var asset: Dictionary = traffic.catalog[(lane.id*5+i)%20].duplicate()
			asset.max_speed = 7.5 if i == count-1 else 12.5
			var progress: float = 12+i*(lane.length-28)/count
			traffic.simulation.spawn(asset,[lane.id],progress,loop)
		traffic.simulation.signals[lane.id] = {"progress":lane.length*0.65,"red":true}
	traffic.bridge.sync(traffic.simulation.vehicles)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20,20)
	panel.custom_minimum_size.x = 320
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "CITIES_DO\n도로 주행 AI 시험장"
	title.add_theme_font_size_override("font_size",25)
	box.add_child(title)
	var help := Label.new()
	help.text = "우측통행 · 곡선 추종 · 앞차 간격 유지\n바깥: 4차로 순환 · 안쪽: 2차로 종점\n제어 정지선은 12초마다 정지/통과 전환"
	box.add_child(help)
	var pause := Button.new()
	pause.name = "PauseTraffic"
	pause.text = "일시정지 / 계속"
	pause.pressed.connect(func(): traffic.simulation.paused = not traffic.simulation.paused)
	box.add_child(pause)
	var signal_button := Button.new()
	signal_button.name = "ToggleStopLine"
	signal_button.text = "정지선 수동 전환"
	signal_button.pressed.connect(func():
		manual_red = not manual_red
		for signal_data in traffic.simulation.signals.values(): signal_data.red = manual_red)
	box.add_child(signal_button)
	var back := Button.new()
	back.name = "TrafficDemoReturn"
	back.text = "건설 화면으로 돌아가기"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
	box.add_child(back)
	stats = Label.new()
	box.add_child(stats)
	fit_demo()
	get_viewport().size_changed.connect(fit_demo)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-traffic="): capture_path = arg.trim_prefix("--capture-traffic=")
		if arg.begins_with("--record-traffic="):
			recording_dir = arg.trim_prefix("--record-traffic=")
			DirAccess.make_dir_recursive_absolute(recording_dir)

func fit_demo():
	var available := get_viewport_rect().size-Vector2(410,140)
	map_zoom = minf(available.x/850.0,available.y/490.0)
	origin = Vector2(360+available.x/2,(get_viewport_rect().size.y+100)/2-700*map_zoom)

func _process(delta: float):
	super._process(delta)
	if traffic == null or traffic.simulation == null: return
	if not traffic.simulation.paused:
		var previous := int(demo_time/12.0)
		demo_time += delta
		if int(demo_time/12.0) != previous:
			manual_red = not manual_red
			for data in traffic.simulation.signals.values(): data.red = manual_red
	var stopped := 0
	var speed := 0.0
	for vehicle in traffic.simulation.vehicles:
		if vehicle.speed < 0.05: stopped += 1
		speed += vehicle.speed*3.6
	stats.text = "%d대 · 정지 %d대\n평균 %.1f km/h · %.1f초\n정지선: %s" % [traffic.simulation.vehicles.size(),stopped,speed/maxi(1,traffic.simulation.vehicles.size()),traffic.simulation.elapsed,"정지" if manual_red else "통과"]
	if capture_path != "" and demo_time > 9 and not capture_done:
		capture_done = true
		capture.call_deferred()
	if recording_dir != "" and not recording_busy and int(demo_time*2) > recording_index:
		recording_index = int(demo_time*2)
		recording_busy = true
		record_frame.call_deferred()

func _draw():
	super._draw()
	if traffic == null or not traffic.running: return
	for lane_id in traffic.simulation.signals:
		var data: Dictionary = traffic.simulation.signals[lane_id]
		var p: Vector2 = screen(traffic.network.sample(lane_id,data.progress)/4.0)
		draw_circle(p,5.0,Color("e77864") if data.red else Color("6dcda0"))

func capture():
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(capture_path)
	get_tree().quit(0 if error == OK else 1)

func record_frame():
	await RenderingServer.frame_post_draw
	var path := recording_dir.path_join("%03d.png" % recording_index)
	var error := get_viewport().get_texture().get_image().save_png(path)
	recording_busy = false
	if error != OK or demo_time >= 24:
		get_tree().quit(0 if error == OK else 1)
