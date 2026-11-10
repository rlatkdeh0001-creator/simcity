extends SceneTree
const Network = preload("res://core/traffic_network.gd")
const Simulation = preload("res://core/traffic_simulation.gd")
const Bridge = preload("res://core/road_generator_traffic.gd")
var checks := 0
var failed := 0
var asset := {"id":"car-hatch-01","length_m":4.0,"max_speed":18.0}

func _initialize():
	run.call_deferred()

func verify(value: bool, detail: String):
	checks += 1
	if value: print("PASS " + detail)
	else:
		failed += 1
		push_error("FAIL " + detail)

func road(points: Array, lanes: int = 2, kind: String = "local") -> Dictionary:
	return {"points":PackedVector2Array(points),"lanes":lanes,"width":float(lanes),"kind":kind}

func ring_network() -> RefCounted:
	var points := []
	for i in range(97):
		var a := i*TAU/96.0
		points.append(Vector2(50,50)+Vector2(cos(a),sin(a))*33)
	var network := Network.new()
	verify(network.build([road(points)]), "closed curved road produces valid lanes")
	return network

func advance(sim, seconds: float, rate: int = 30):
	for i in range(int(seconds*rate)): sim.update(1.0/rate)

func run():
	for method in ["test_network", "test_following", "test_loop", "test_timing", "test_fleet"]:
		if call(method) != true: verify(false, method + " finished without runtime errors")
	if await test_bridge_and_ui() != true: verify(false, "bridge/UI test finished")
	print("RESULT %d/%d traffic checks passed" % [checks-failed,checks])
	quit(1 if failed else 0)

func test_network() -> bool:
	var network := Network.new()
	verify(network.build([road([Vector2(10,20),Vector2(90,20)])]), "straight city road imports")
	verify(network.lanes.size() == 2, "two lanes represent opposite directions")
	verify(network.sample(0,0).is_equal_approx(Vector2(40,81.5)), "city cells convert to metres; forward lane stays right")
	verify(network.sample(1,0).is_equal_approx(Vector2(360,78.5)), "reverse lane stays on its own right side")
	verify(network.tangent(0,20).dot(network.tangent(1,20)) < -0.999, "opposite lane tangents")
	verify(is_equal_approx(network.lanes[0].speed_limit*3.6,80.0), "local speed ceiling 80 km/h")
	network.build([road([Vector2(10,20),Vector2(50,20)]),road([Vector2(90,20),Vector2(50,20)])])
	verify(network.route(0,3) == [0,3], "AStar lane route follows connected road endpoint despite reversed input")
	verify(network.route(0,1).is_empty(), "routing cannot turn into oncoming lane")
	network.build([road([Vector2(10,20),Vector2(40,20)]),road([Vector2(50,20),Vector2(90,20)])])
	verify(network.route(0,2).is_empty(), "disconnected roads have no fabricated route")
	verify(network.build([road([Vector2(10,50),Vector2(90,50)]),road([Vector2(50,10),Vector2(50,90)])]) and network.junctions.size()==1, "crossing roads form a controlled junction")
	verify(not network.build([road([Vector2(10,20),Vector2(90,20)]),road([Vector2(20,20),Vector2(50,20)])]), "overlapping duplicate roads rejected")
	network.build([road([Vector2(10,20),Vector2(90,20)],4,"highway")])
	verify(network.lanes.size() == 4, "four lanes generated")
	verify(is_equal_approx(network.lanes[0].speed_limit*3.6,160.0), "highway speed ceiling 160 km/h")
	return true

func test_following() -> bool:
	var network := Network.new()
	network.build([road([Vector2(0,20),Vector2(100,20)])])
	var sim := Simulation.new(network)
	var leader_asset := asset.duplicate()
	leader_asset.max_speed = 5.0
	var leader: Dictionary = sim.spawn(leader_asset,[0],55)
	var follower: Dictionary = sim.spawn(asset,[0],15)
	verify(sim.spawn(asset,[0],16).is_empty(), "overlapping spawn refused")
	var min_gap := INF
	var matched := false
	for i in range(30*50):
		sim.update(1.0/30.0)
		min_gap = minf(min_gap,leader.progress-follower.progress-(leader.length+follower.length)/2)
		if i > 900 and follower.speed < 5.1: matched = true
	verify(min_gap >= 1.9999, "fast car never enters slow leader's protected gap")
	verify(matched and follower.progress < leader.progress, "fast follower matches slow leader without overtaking")
	var stopped := Simulation.new(network)
	var car: Dictionary = stopped.spawn(asset,[0],15)
	stopped.signals[0] = {"progress":100.0,"red":true}
	advance(stopped,30)
	verify(car.speed < 0.05 and car.progress+car.length/2 <= 98.001, "red stop line respected with bumper clearance")
	var progress: float = car.progress
	stopped.signals[0].red = false
	advance(stopped,5)
	verify(car.speed > 1 and car.progress > progress+5, "green releases stopped car with acceleration")
	advance(stopped,70)
	verify(car.arrived and car.speed < 0.05 and car.progress < 400-car.length/2, "open route stops at destination instead of wrapping")
	return true

func test_loop() -> bool:
	var network = ring_network()
	var sim := Simulation.new(network)
	var length: float = network.lanes[0].length
	var seam_check := Simulation.new(network)
	seam_check.spawn(asset,[0],2,true)
	verify(seam_check.spawn(asset,[0],length-2,true).is_empty(), "spawn checks protected spacing across loop seam")
	var lead: Dictionary = sim.spawn(asset,[0],10,true)
	lead.max_speed = 3.0
	var follow: Dictionary = sim.spawn(asset,[0],length-15,true)
	var min_gap := INF
	var valid := true
	for i in range(30*180):
		sim.update(1.0/30)
		var gap := fposmod(lead.progress-follow.progress,length)-4.0
		min_gap = minf(min_gap,gap)
		for vehicle in sim.vehicles:
			var p: Vector2 = sim.position(vehicle)
			valid = valid and p.is_finite() and absf(p.distance_to(Vector2(200,200))-130.5) < 0.25
	verify(min_gap >= 1.999, "following distance is maintained across closed-lane seam")
	verify(valid, "vehicles stay on offset curved lane for three minutes")
	verify(follow.distance > 300 and not follow.arrived, "closed route keeps moving through seam")
	return true

func test_fleet() -> bool:
	var network = ring_network()
	var sim := Simulation.new(network)
	for lane in network.lanes:
		for i in range(50): sim.spawn(asset,[lane.id],8+i*(lane.length-16)/50,true)
	verify(sim.vehicles.size() == 100, "100 vehicle fixture spawns with valid spacing")
	var started := Time.get_ticks_usec()
	advance(sim,10)
	var duration := (Time.get_ticks_usec()-started)/1000.0
	print("BENCHMARK 100 vehicles / 300 fixed ticks: %.2f ms total, %.3f ms per tick" % [duration,duration/300.0])
	var valid := true
	for lane in network.lanes:
		var ordered: Array = sim.vehicles.filter(func(v): return v.lane == lane.id)
		ordered.sort_custom(func(a,b):return a.progress < b.progress)
		for i in range(ordered.size()):
			var next: Dictionary = ordered[(i+1)%ordered.size()]
			var gap := fposmod(next.progress-ordered[i].progress,lane.length)-4.0
			valid = valid and gap >= 1.999 and is_finite(ordered[i].speed)
	verify(valid, "100 vehicle fixture preserves gaps and finite states")
	return true

func test_timing() -> bool:
	var network = ring_network()
	var a := Simulation.new(network)
	var b := Simulation.new(network)
	a.spawn(asset,[0],20,true)
	b.spawn(asset,[0],20,true)
	advance(a,20,30)
	advance(b,20,60)
	verify(is_equal_approx(a.vehicles[0].progress,b.vehicles[0].progress) and is_equal_approx(a.vehicles[0].speed,b.vehicles[0].speed), "30/60 Hz frames produce identical fixed-step state")
	a.paused = true
	var before: float = a.vehicles[0].progress
	a.update(2.0)
	verify(a.vehicles[0].progress == before, "pause does not accumulate hidden movement")
	a.paused = false
	a.update(0.5)
	verify(a.vehicles[0].progress > before and is_equal_approx(a.elapsed,20.5), "long frame advances deterministic substeps")
	return true

func test_bridge_and_ui() -> bool:
	var network = ring_network()
	var sim := Simulation.new(network)
	var car: Dictionary = sim.spawn(asset,[0],network.lanes[0].length-5,true)
	var bridge := Bridge.new()
	root.add_child(bridge)
	bridge.setup(network)
	bridge.sync(sim.vehicles)
	verify(bridge.agents[car.id] is RoadLaneAgent and bridge.road_lanes[0] is RoadLane, "actual upstream RoadLaneAgent and RoadLane instantiated")
	var agrees := true
	for i in range(600):
		sim.update(1.0/30)
		bridge.sync(sim.vehicles)
		var p: Vector3 = bridge.actors[car.id].global_position
		agrees = agrees and Vector2(p.x,p.z).distance_to(sim.position(car)) < 0.03
	verify(agrees and bridge.agent_moves >= 600, "upstream agent agrees with metre-based simulation including loop wrap")
	bridge.free()
	network = Network.new()
	network.build([road([Vector2(0,20),Vector2(10,20)]),road([Vector2(10,20),Vector2(30,20)])])
	sim = Simulation.new(network)
	car = sim.spawn(asset,network.route(0,2),8)
	bridge = Bridge.new()
	root.add_child(bridge)
	bridge.setup(network)
	agrees = true
	for i in range(300):
		sim.update(1.0/30)
		bridge.sync(sim.vehicles)
		var p: Vector3 = bridge.actors[car.id].global_position
		agrees = agrees and Vector2(p.x,p.z).distance_to(sim.position(car)) < 0.03
	verify(car.lane == 2 and agrees, "upstream agent follows routed transition into next road")
	bridge.free()
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main.city.add_road(PackedVector2Array([Vector2(10,20),Vector2(90,20)]))
	main.toggle_traffic()
	verify(main.traffic.running and not main.traffic.simulation.vehicles.is_empty(), "construction screen starts traffic on player's road")
	main.traffic.update(1)
	verify(main.traffic.simulation.vehicles[0].speed > 0, "player road traffic advances")
	verify(main.traffic.texture_for("car-hatch-01",Vector2.RIGHT).resource_path.ends_with("315.png"), "eastbound sprite faces down/right in isometric projection")
	verify(main.traffic.texture_for("car-hatch-01",Vector2.DOWN).resource_path.ends_with("045.png"), "southbound sprite faces down/left in isometric projection")
	var city = main.city
	main.map_zoom = 1.14
	main.origin = Vector2(412,230)
	main.select_category("transport")
	main.find_children("Tool_traffic_demo","Button",true,false)[0].pressed.emit()
	await process_frame
	await process_frame
	var demo = current_scene
	verify(demo.scene_file_path == "res://traffic_demo.tscn" and demo.traffic.simulation.vehicles.size() >= 20, "demo button opens live fleet on curved road")
	demo.find_children("PauseTraffic","Button",true,false)[0].pressed.emit()
	verify(demo.traffic.simulation.paused, "demo pause control works")
	var old: bool = demo.manual_red
	demo.find_children("ToggleStopLine","Button",true,false)[0].pressed.emit()
	verify(demo.manual_red != old, "demo controlled stop-line button works")
	demo.find_children("TrafficDemoReturn","Button",true,false)[0].pressed.emit()
	await process_frame
	await process_frame
	verify(current_scene.city == city and is_equal_approx(current_scene.map_zoom,1.14) and current_scene.origin == Vector2(412,230), "return preserves player's city and camera")
	current_scene.queue_free()
	await process_frame
	return true
