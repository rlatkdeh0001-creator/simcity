extends SceneTree
## One real rail-tool stroke shortens two operating lines. The reset warning is per edit, not per line.
const City = preload("res://core/city_model.gd")
const Planner = preload("res://core/transit_line_planner.gd")
const WARNING := "수정사항이 있는 모든 열차가 초기화됩니다!"
const SIZE := Vector2i(1280, 820)

var game
var checks := 0
var failures := 0
var modal_opens := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		printerr("FAIL ", label)
	return ok

func run() -> void:
	Engine.max_fps = 60
	root.size = SIZE
	var city = City.new(220, 90, 42)
	city.population_enabled = false
	city.happiness_enabled = false
	city.funds = 1000000
	var fixture := build_fixture(city)
	if not fixture.is_empty():
		game = load("res://main.tscn").instantiate()
		game.city = city
		game.paused = true
		root.add_child(game)
		current_scene = game
		await regression(city, fixture)
		city.simulation.shutdown()
	print("SECOND_FIX_SHARED_RAIL_EDIT checks=%d failed=%d" % [checks, failures])
	quit(1 if failures else 0)

func build_fixture(city) -> Dictionary:
	# A--B--(detour)--C--D. A->C and D->B share the detour but start at opposite ends.
	var road: Dictionary = city.add_road(PackedVector2Array([Vector2(2, 40), Vector2(216, 40)]), "local", true, 4)
	if not check(road.ok, "fixture road supports four real stations"):
		return {}
	var ports: Array[PackedVector2Array] = []
	var stops: Array[int] = []
	for x: float in [25.0, 65.0, 155.0, 195.0]:
		var placed: Dictionary = city.public_facilities.place("train-station-01", Vector2(x, 33), 0, true)
		if not check(placed.ok, "fixture station at x=%.0f: %s" % [x, placed.get("reason", "")]):
			return {}
		var lot: Dictionary = city.public_facilities.lots[-1]
		var points: PackedVector2Array = lot.internal_points.duplicate()
		if points[0].x > points[-1].x:
			points.reverse()
		ports.append(points)
		stops.append(lot.id)
	var start := ports[1][-1] + Vector2(12, 0)
	var end := ports[2][0] - Vector2(12, 0)
	# Leave straight leads for the terminal crossovers. The shortcut joins at two interior
	# vertices of this one record, with room for both choices at each junction.
	var detour := PackedVector2Array([ports[1][-1]])
	for i in range(33):
		var t := float(i) / 32.0
		detour.append(start.lerp(end, t) - Vector2(0, 14.0 * pow(sin(PI * t), 2)))
	detour.append(ports[2][0])
	var track_ids: Array[int] = []
	for points: PackedVector2Array in [PackedVector2Array([ports[0][-1], ports[1][0]]), detour,
			PackedVector2Array([ports[2][-1], ports[3][0]])]:
		var built: Dictionary = city.add_transit_route(points)
		if not check(built.ok, "fixture track connects: " + str(built.get("reason", ""))):
			return {}
		track_ids.append(built.route.id)
	var ids: Array[int] = []
	for pair: Array in [[stops[0], stops[2]], [stops[3], stops[1]]]:
		var line: Dictionary = city.create_transit_line("rail", pair, {"dwell_seconds": 4.0, "headway_seconds": 20.0})
		if not check(line.ok, "fixture operating line %s: %s" % [pair, line.get("reason", "")]):
			return {}
		ids.append(line.line.id)
	return {"ids": ids, "start": start, "end": end, "detour_id": track_ids[1]}

func regression(city, fixture: Dictionary) -> void:
	var sim = city.simulation
	for i in range(120):
		if sim.is_ready():
			break
		await process_frame
	if not check(sim.is_ready() and sim.get_fault().is_empty(), "main's real simulation worker is ready"):
		return
	var ids: Array[int] = fixture.ids
	for i in range(20):
		if not publish_step(city):
			check(false, "worker publishes train movement: " + sim.get_fault())
			return
		if ids.all(func(id): return moving(train(city, id))):
			break
	for id in ids:
		var before: Dictionary = train(city, id)
		if not check(moving(before) and fixture.detour_id in before.plan.hosts,
				"line %d has a moving, visible consist on the old detour plan" % id):
			return

	game.map_zoom = 0.65
	game.origin = Vector2(640, 310) - game.world_renderer.iso((fixture.start + fixture.end) / 2.0) * game.map_zoom
	game.refresh()
	node_added.connect(observe_warning)
	await settle()
	await press(game.find_child("Bottom_transport", true, false))
	await press(game.transport_tabs.get_child(2))
	await press(game.find_child("Tool_rail", true, false))
	if not check(game.mode == "rail" and game.road_drawer.kind == "straight", "HUD selects straight rail construction"):
		return

	var start: Vector2 = game.screen(fixture.start)
	var end: Vector2 = game.screen(fixture.end)
	var unchanged := snapshot(city)
	await click(start)
	await move_mouse(end)
	await settle()
	var preview: Dictionary = game.transit_view.preview()
	if not check(preview.get("ok", false) and preview.points == PackedVector2Array([fixture.start, fixture.end]),
			"real map input previews the exact straight shortcut: " + str(preview.get("reason", ""))):
		return
	check(modal_opens == 0 and not game.route_warning_open() and snapshot(city) == unchanged,
			"anchor and preview neither warn nor change tracks, lines, trains or pending edits")

	await click(end)
	if not check(game.route_warning_open() and modal_opens == 1 and game.route_warning.message.text == WARNING,
			"one final map click opens exactly one train-reset modal for both lines"):
		return
	check(snapshot(city) == unchanged, "the open modal has applied or queued nothing")
	await press(game.route_warning.cancel_button)
	check(not game.route_warning_open() and modal_opens == 1 and snapshot(city) == unchanged,
			"one Cancel leaves tracks, lines and both moving consists byte-identical")

	# Cancellation preserves the anchor. Retry the same stroke and confirm only once.
	await click(end)
	if not check(game.route_warning_open() and modal_opens == 2 and snapshot(city) == unchanged,
			"retry opens one fresh modal and still applies nothing before confirmation"):
		return
	var old_routes: Array = city.transit_routes.duplicate(true)
	var old_lines: Array = city.transit_lines.duplicate(true)
	var old_trains: Dictionary = city.transit_state.trains.duplicate(true)
	var new_id: int = city.next_transit_route_id
	# Enter is the real modal confirmation path and avoids coupling this
	# scenario to a second mouse re-target immediately after reopening it.
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()
	var published := publish_step(city)
	await settle()
	check(not game.route_warning_open() and modal_opens == 2, "one Confirm closes the modal with no second warning")
	if not check(published, "worker publishes the confirmed edit and train resets: " + sim.get_fault()):
		return
	var route: Dictionary = city.get_transit_route(new_id)
	check(city.next_transit_route_id == new_id + 1 and city.transit_routes.slice(0, -1) == old_routes
			and route.get("points") == preview.points and city.transit_lines == old_lines,
			"confirmation adds exactly the previewed track and changes no existing tracks or stops")
	for id in ids:
		var line: Dictionary = city.transit_lines.filter(func(row): return row.id == id)[0]
		var plan: Dictionary = Planner.new().rail_plan(city, line)
		var before: Dictionary = old_trains[id]
		if not check(plan.ok and new_id in plan.hosts and plan.length < before.plan.length - 1.0,
				"line %d now takes the new shorter path" % id):
			continue
		var after := train(city, id)
		var station: Dictionary = city.public_facilities.lots.filter(func(lot): return lot.id == line.stops[0])[0]
		var ports: PackedVector2Array = station.internal_points
		var station_centre := (ports[0] + ports[-1]) * 2.0 # Midpoint in metres.
		check(after.get("plan") == plan and at_first_stop(after, station_centre) and city.transit_state.lines[id].status == "dwelling",
				"line %d's published consist resets to its own first stop on the new plan" % id)
		# Worker publications copy records; stable car IDs and departure history distinguish a reset from a respawn.
		check(after.get("departures") == before.departures and after.get("last_departure") == before.last_departure
				and car_ids(after) == car_ids(before), "line %d retains its consist IDs and departure history" % id)

func observe_warning(node: Node) -> void:
	if node.name == &"RouteResetWarning" and node is Control:
		var warning := node as Control
		if warning.visible:
			modal_opens += 1
		warning.visibility_changed.connect(func():
			if warning.visible:
				modal_opens += 1)

func snapshot(city) -> PackedByteArray:
	return var_to_bytes([city.transit_routes, city.next_transit_route_id, city.transit_lines,
			city.transit_state, city.simulation.queued_edit_count()])

func publish_step(city) -> bool:
	city.simulation.resume()
	city.advance_society(city.config.development_interval_seconds)
	return city.simulation.validation_publish()

func train(city, id: int) -> Dictionary:
	return city.transit_state.trains.get(id, {})

func moving(consist: Dictionary) -> bool:
	return not consist.is_empty() and consist.distance > 5.0 and consist.speed > 0.0 \
			and consist.departures > 0 and not consist.visible.is_empty()

func at_first_stop(consist: Dictionary, station_centre: Vector2) -> bool:
	if consist.get("distance") != 0.0 or consist.get("speed") != 0.0 or consist.get("next_stop") != 1:
		return false
	var cars: Array = consist.visible
	if cars.is_empty():
		return false
	var centre := Vector2.ZERO
	for pose: Dictionary in cars:
		centre += pose.position
	return (centre / cars.size()).distance_to(station_centre) < 8.0

func car_ids(consist: Dictionary) -> Array:
	return consist.get("visible", []).map(func(pose): return pose.id)

func settle() -> void:
	for i in range(4):
		await process_frame

func move_mouse(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame

func click(position: Vector2) -> void:
	await move_mouse(position)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		root.push_input(event, true)
		await process_frame
	await settle()

func press(button: Control) -> void:
	if not is_instance_valid(button) or not button.is_visible_in_tree():
		check(false, "input control unavailable: " + str(button))
		return
	await click(button.get_global_rect().get_center())
