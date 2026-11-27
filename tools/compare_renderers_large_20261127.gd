extends SceneTree
## Fixture recipe: 727a9e1:tools/validate_population_live.gd::live_city(), plus
## the first legal commercial lot and camera from validate_csharp_population_live.gd.
## Use plain production CityModel/main.tscn, not the historical timing subclasses.
const City = preload("res://core/city_model.gd")
const SEED := 20261114
const POPULATION_SEED := SEED ^ 0x71294 # PopulationState.Initialize's production stream.
const SIZE := Vector2i(1920, 1080)
const ANCHOR := Vector2(960, 410)
const ZOOM := 0.9
const WARM_US := 1_000_000
const SAMPLE_US := 8_000_000
const MAX_SAMPLES := 100_000
const DRIVERS := {"gl_compatibility": "opengl3", "forward_plus": "vulkan", "mobile": "vulkan"}
var game

func _initialize():
 run.call_deferred()

func fail(message: String):
 printerr("FAIL P11 ", message)
 await finish(1)

func finish(code: int):
 if is_instance_valid(game):
  game.queue_free() # main.gd::_exit_tree joins the production worker.
  await process_frame
 if code == 0:
  print("P11_PASS")
 quit(code)

func fixture() -> Dictionary:
 var city = City.new(100, 100, SEED)
 for y in [28, 48, 68]:
  if not city.add_road(PackedVector2Array([Vector2(24, y), Vector2(72, y)])).ok:
   return {}
 for x in [28, 48, 68]:
  if not city.add_road(PackedVector2Array([Vector2(x, 24), Vector2(x, 72)])).ok:
   return {}
 for parcel in city.zoning_grid.parcels.values():
  if parcel.v != 0 or parcel.u % 2 != 0:
   continue
  var placed: Dictionary = city.add_building_at(parcel.center)
  if placed.ok and city.buildings.size() == 60:
   break
 if city.buildings.size() != 60:
  return {}
 for i in range(120):
  var home: Dictionary = city.buildings[i >> 1]
  var household := {"id": i + 1, "home_id": home.id}
  city.population.households.append(household)
  for j in range(2):
   city.population.add_person(household, (i * 2 + j) % 5, 30, "native-validation")
 city.population.next_household = 121
 city.population.sync(city.buildings)
 for id in city.zoning_grid.parcels.keys().slice(0, 32):
  city.zone_designations[id] = "residential"
 var workplace: Dictionary = {}
 for parcel in city.zoning_grid.parcels.values():
  var placed: Dictionary = city.add_building_at(parcel.center, "commercial")
  if placed.ok:
   workplace = placed.building
   break
 if workplace.is_empty():
  return {}
 city.population.sync(city.buildings)
 city.population.release_compatibility_views()
 return {"city": city, "workplace": workplace}

func fingerprint(value: Variant) -> String:
 var digest := HashingContext.new()
 digest.start(HashingContext.HASH_SHA256)
 digest.update(var_to_bytes(value))
 return digest.finish().hex_encode()

func city_state(city) -> Dictionary:
 var stats: Dictionary = city.population.stats()
 return {"clock_seconds": city.clock.game_seconds, "published_tick": city.simulation.get_published_tick(),
  "frozen_cycles": city.society_frozen_cycles, "population": stats.population,
  "households": stats.households, "buildings": city.buildings.size(), "funds": city.funds}

func run():
 var args := OS.get_cmdline_user_args()
 if args.size() != 4 or args[0] != "--p11-measure":
  await fail("use the serial Python driver, with explicit authorization to measure"); return
 var requested := args[1]
 var workload := args[2]
 var out := args[3]
 var method := RenderingServer.get_current_rendering_method()
 var driver := RenderingServer.get_current_rendering_driver_name()
 print("P11_ACTIVE method=", method, " driver=", driver, " workload=", workload)
 if method != requested or not DRIVERS.has(method) or driver != DRIVERS[method]:
  await fail("renderer or graphics driver fallback"); return
 if workload not in ["paused", "live_1x"] or not out.is_absolute_path() or FileAccess.file_exists(out):
  await fail("invalid workload or output path already exists"); return
 if DisplayServer.get_name() == "headless" or DisplayServer.window_get_mode() not in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
  await fail("expected a native fullscreen window"); return
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Engine.max_fps = 0
 if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED or Engine.max_fps != 0:
  await fail("VSync or FPS cap still enabled"); return
 var built := fixture()
 if built.is_empty():
  await fail("historical road/lot recipe did not build"); return
 var city = built.city
 var workplace: Dictionary = built.workplace
 var houses: Array = city.buildings.filter(func(b): return b.zone == "residential" and b.size == 2 and b.level == 1)
 var stats: Dictionary = city.population.stats()
 if [city.width, city.height, city.rng.seed, city.population.rng_seed()] != [100, 100, SEED, POPULATION_SEED]:
  await fail("fixture map or seed has drifted"); return
 if [city.roads.size(), city.buildings.size(), houses.size(), city.zone_designations.size()] != [6, 61, 60, 32]:
  await fail("fixture roads, lots or designations have drifted"); return
 if [stats.population, stats.households, workplace.zone, city.population.backend_name()] != [240, 120, "commercial", "CSharp"]:
  await fail("fixture population, workplace or backend has drifted"); return
 var recipe_sha := fingerprint([city.width, city.height, city.rng.seed, city.rng.state,
  city.appearance_rng.state, city.population.rng_state(), city.roads, city.buildings,
  city.zone_designations, city.population.core.ExportState()])
 game = load("res://main.tscn").instantiate()
 game.city = city
 game.paused = true
 game.simulation_speed = 1.0
 root.add_child(game)
 current_scene = game
 game.mode = "select"
 game.drawer.hide()
 # This is the historical formula, not the centre of the oriented polygon.
 var cell := Vector2(workplace.x + workplace.size * 0.5, workplace.y + workplace.size * 0.5)
 game.map_zoom = ZOOM
 game.origin = Vector2.ZERO
 game.origin = ANCHOR - game.screen(cell)
 var origin: Vector2 = game.origin
 game.selected = workplace.id
 game.refresh()
 for _i in range(8):
  await process_frame
 var sim = city.simulation
 if sim == null:
  await fail("main scene did not attach the production simulation worker"); return
 var deadline := Time.get_ticks_msec() + 30_000
 while not sim.is_ready() or game.building_views.busy or not game.building_views.queue.is_empty():
  if Time.get_ticks_msec() >= deadline or not sim.get_fault().is_empty():
   await fail("production worker or building views did not settle: " + sim.get_fault()); return
  await process_frame
 await RenderingServer.frame_post_draw
 if root.size != SIZE or DisplayServer.window_get_size() != SIZE or root.get_texture().get_size() != Vector2(SIZE):
  await fail("expected a 1920x1080 window and actual viewport texture"); return
 if not game.labor_panel.visible or game.traffic.running or game.traffic.simulation != null:
  await fail("expected the selected commercial workplace panel and no seeded traffic"); return
 var warm_until := Time.get_ticks_usec() + WARM_US
 while Time.get_ticks_usec() < warm_until:
  await RenderingServer.frame_post_draw
 var initial := city_state(city)
 if initial.clock_seconds != 0.0 or initial.published_tick != 0 or initial.population != 240:
  await fail("city advanced before the common sample boundary"); return
 var initial_sha := fingerprint([recipe_sha, initial, city.roads, city.buildings,
  game.selected, cell, origin, game.map_zoom, game.mode, game.drawer.visible, game.simulation_speed])
 print("P11_FIXTURE recipe=", recipe_sha, " initial=", initial_sha, " camera_cell=", cell, " workplace=", workplace.id)
 var durations := PackedInt64Array()
 game.paused = workload == "paused"
 var start := Time.get_ticks_usec()
 var previous := start
 while previous - start < SAMPLE_US and durations.size() < MAX_SAMPLES:
  await RenderingServer.frame_post_draw
  var now := Time.get_ticks_usec()
  durations.append(now - previous)
  previous = now
 var final := city_state(city)
 var playback_changed: bool = game.paused != (workload == "paused") or game.simulation_speed != 1.0
 game.paused = true
 if previous - start < SAMPLE_US or playback_changed or not sim.get_fault().is_empty():
  await fail("sample limit, playback change or worker fault"); return
 if game.origin != origin or game.map_zoom != ZOOM or game.selected != workplace.id or root.size != SIZE:
  await fail("camera, selection or window changed"); return
 if workload == "paused" and final != initial:
  await fail("paused city state changed"); return
 if workload == "live_1x" and (final.published_tick <= initial.published_tick or final.clock_seconds <= initial.clock_seconds):
  await fail("live scene did not publish a production tick and advance the clock"); return
 var sorted := durations.duplicate()
 sorted.sort()
 var result := {"method": method, "driver": driver, "workload": workload,
  "seed": SEED, "population_seed": POPULATION_SEED, "map_cells": [100, 100], "roads": city.roads.size(), "homes": 60,
  "commercial": 1, "zoned_cells": 32, "vehicles": 0,
  "recipe_sha256": recipe_sha, "initial_sha256": initial_sha, "initial": initial, "final": final,
  "camera_cell": [cell.x, cell.y], "camera_origin": [origin.x, origin.y], "camera_anchor": [ANCHOR.x, ANCHOR.y],
  "zoom": ZOOM, "workplace_id": workplace.id, "workplace_asset": workplace.asset_id,
  "width": SIZE.x, "height": SIZE.y, "fullscreen": true, "vsync": false, "max_fps": Engine.max_fps,
  "simulation_speed": game.simulation_speed, "warmup_usec": WARM_US, "target_sample_usec": SAMPLE_US,
  "frames": durations.size(), "elapsed_usec": previous - start, "frame_usec": Array(durations),
  "average_ms": float(previous - start) / durations.size() / 1000.0,
  "p95_ms": float(sorted[ceili(durations.size() * 0.95) - 1]) / 1000.0}
 var file := FileAccess.open(out, FileAccess.WRITE)
 if file == null:
  await fail("could not open frames.json"); return
 file.store_string(JSON.stringify(result, "  ", true, true))
 var write_failed := file.get_error() != OK
 file.close()
 if write_failed:
  await fail("could not write frames.json"); return
 await finish(0)
