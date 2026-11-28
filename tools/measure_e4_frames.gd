extends "capture_perf_cadence.gd"
## D27 A is the historical paused city. B adds four one-way profiles and
## moving vehicles without moving A's original actors. No screenshots.
const FRAMEBUFFER := Vector2i(1920, 1080)
const WARM_US := 1000000
const SAMPLE_US := 4000000

func finish(code: int):
 if is_instance_valid(game):
  game.queue_free()
  await process_frame
 quit(code)

func require(ok: bool, message: String) -> bool:
 if not ok: printerr("FAIL D27 ", message)
 return ok

func layout_fingerprint(include_progress: bool = true) -> String:
 var cars: Array = game.traffic.simulation.vehicles
 var state := [game.city.roads, game.city.buildings, cars.map(func(car): return [car.id, car.get("asset"), car.get("route"), car.get("progress") if include_progress else null]), game.map_zoom, game.origin]
 var digest := HashingContext.new()
 digest.start(HashingContext.HASH_SHA256)
 digest.update(var_to_bytes(state))
 return digest.finish().hex_encode()

func sample_frames(animate_b: bool) -> Dictionary:
 var warm_until := Time.get_ticks_usec() + WARM_US
 while Time.get_ticks_usec() < warm_until:
  await RenderingServer.frame_post_draw
  if animate_b:game.traffic.update(root.get_process_delta_time())
 var start := Time.get_ticks_usec()
 var previous := start
 var durations: Array[int] = []
 while previous - start < SAMPLE_US:
  await RenderingServer.frame_post_draw
  var now := Time.get_ticks_usec()
  durations.append(now - previous)
  previous = now
  if animate_b:game.traffic.update(root.get_process_delta_time())
 var ranked := durations.duplicate()
 ranked.sort()
 return {"frames": durations.size(), "elapsed_usec": previous - start, "frame_usec": durations,
  "average_ms": float(previous - start) / durations.size() / 1000.0,
  "p95_ms": float(ranked[ceili(ranked.size() * .95) - 1]) / 1000.0}

func add_scene_b_roads(city) -> bool:
 # Both y bands are outside the original six roads and all four fit the A camera.
 for i in range(4):
  var y:float=[12,18,77,85][i]
  var points:=PackedVector2Array([Vector2(45,y),Vector2(61,y)])
  if not city.add_road(points,"local",true,i+1,false,false,1,{},1).get("ok",false):return false
 return true

func scene_b_fleet() -> Array[Dictionary]:
 var moving:Array[Dictionary]=[]
 for car:Dictionary in game.traffic.simulation.vehicles:
  var lane:Dictionary=game.traffic.network.lanes[car.lane]
  var directed:bool=lane.road>=6 and lane.direction==1
  car.max_speed=5.0 if directed else 0.0
  if directed:moving.append(car)
 return moving

func run():
 var destination := ""
 var scene := "A"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--frames-json="): destination = arg.trim_prefix("--frames-json=")
  if arg.begins_with("--scene="): scene = arg.trim_prefix("--scene=")
 var method := RenderingServer.get_current_rendering_method()
 var driver := RenderingServer.get_current_rendering_driver_name()
 if not require(method == "gl_compatibility" and driver == "opengl3", "expected Compatibility/OpenGL3"):
  await finish(1); return
 if not require(DisplayServer.get_name() != "headless" and root.size == FRAMEBUFFER and DisplayServer.window_get_size() == FRAMEBUFFER and root.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN], "expected native 1920x1080 fullscreen"):
  await finish(1); return
 if not require(scene in ["A","B"] and not destination.is_empty() and not FileAccess.file_exists(destination), "expected scene A or B and an unused JSON destination"):
  await finish(1); return
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Engine.max_fps = 0
 if not require(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "VSync was not disabled"):
  await finish(1); return
 game = load("res://main.tscn").instantiate()
 game.city = fixture()
 if scene=="B" and not require(add_scene_b_roads(game.city), "could not add the four independent directed roads"):
  await finish(1); return
 game.paused = true; root.add_child(game); current_scene = game
 await settle()
 if not require(game.traffic.rebuild(game.city.roads), "historical fixture traffic cannot build"):
  await finish(1); return
 game.traffic.seed_traffic(); game.traffic.simulation.paused = true
 var moving:Array[Dictionary]=[]
 if scene=="B":moving=scene_b_fleet()
 game.mode = "select"; game.drawer.hide()
 game.map_zoom = .9
 game.origin = Vector2(960, 410) - game.world_renderer.iso(Vector2(48, 48)) * game.map_zoom
 game.refresh()
 await settle()
 var city = game.city
 var cars: Array = game.traffic.simulation.vehicles
 if not require(city.roads.size()==(6 if scene=="A" else 10) and city.buildings.size()==24 and cars.size()==24+moving.size(), "fixture geometry or seeded fleet count differed"):
  await finish(1); return
 if scene=="B" and not require(moving.size()==10 and city.roads.slice(6).map(func(road):return int(road.lanes))==[1,2,3,4], "scene B must have four directed profiles and ten added cars"):
  await finish(1); return
 var deadline := Time.get_ticks_msec() + 30000
 while game.building_views.busy or not game.building_views.queue.is_empty():
  if not require(Time.get_ticks_msec() < deadline, "building SubViewports did not settle"):
   await finish(1); return
  await process_frame
 var layout := layout_fingerprint(scene=="A")
 # The paused BottomUI forwards zero delta to main._process. Scene B only
 # advances the independent traffic controller once per actual rendered frame.
 if scene=="B":game.traffic.simulation.paused=false
 var result := await sample_frames(scene=="B")
 if not require(game.paused and game.traffic.simulation.paused==(scene=="A") and layout==layout_fingerprint(scene=="A"), "fixture geometry, fleet or pause state changed"):
  await finish(1); return
 if scene=="B" and not require(moving.all(func(car):return car.distance>1.0 and car.speed>0 and not car.arrived), "all ten scene B cars must actually travel and remain active"):
  await finish(1); return
 if scene=="B" and not require(cars.filter(func(car):return car not in moving).all(func(car):return car.distance==0.0 and car.speed==0.0), "the original 24 scene B vehicles remain stationary"):
  await finish(1); return
 result.merge({"scene": scene, "method": method, "driver": driver, "layout_sha256": layout,
  "seed": 20261114, "roads": city.roads.size(), "buildings": city.buildings.size(), "vehicles": cars.size(),
  "width": root.size.x, "height": root.size.y, "fullscreen": true, "vsync": false,
  "max_fps": Engine.max_fps, "paused": true, "warmup_usec": WARM_US,
  "zoom": game.map_zoom, "camera_world_cell": [48, 48], "camera_screen_point": [960, 410]})
 if scene=="B":result.moving_vehicles=moving.size()
 var file := FileAccess.open(destination, FileAccess.WRITE)
 if not require(file != null, "cannot open frames JSON"):
  await finish(1); return
 var stored := file.store_string(JSON.stringify(result, "  "))
 file.close()
 if not require(stored, "cannot write frames JSON"):
  await finish(1); return
 print("D27_PASS method=", method, " driver=", driver)
 await finish(0)
