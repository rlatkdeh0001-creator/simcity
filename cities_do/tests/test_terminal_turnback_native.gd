extends SceneTree

const Fixture = preload("res://tests/transit_operations_fixture.gd")
var checks := 0
var failures := 0

func _initialize():
 run.call_deferred()

func check(ok: bool, label: String):
 checks += 1
 if not ok:failures += 1;printerr("FAIL "+label)

func click(p: Vector2):
 var motion := InputEventMouseMotion.new()
 motion.position=p;root.push_input(motion,true);await process_frame
 for down: bool in [true,false]:
  var event := InputEventMouseButton.new()
  event.position=p;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
  root.push_input(event,true);await process_frame

func run():
 root.size = Vector2i(1280,820)
 for script: String in ["rail_catenary","transit_view"]:
  var source = load("res://core/"+script+".gd")
  if source==null or not source.can_instantiate():quit(1);return
 var game = load("res://main.tscn").instantiate()
 if not "paused" in game:game.free();quit(1);return
 game.paused=true;root.add_child(game);await process_frame
 if game.city.simulation!=null:game.city.simulation.shutdown()
 game.city = Fixture.rail_city()
 game.city.remove_transit_route(game.city.transit_routes[-1].id)
 var lots: Array = game.city.public_facilities.lots
 var ports: Array = lots[0].station_ports
 var port: Dictionary = ports[0] if ports[0].outward.x>0 else ports[1]
 var center: Vector2 = port.point + Vector2(port.outward)*4.0
 game.map_zoom=0.70
 game.origin += Vector2(580,245) - game.screen(center)
 game.refresh();game.select_category("transport");await process_frame
 var action = game.drawer_box.find_child("Tool_transit_line",true,false)
 check(action!=null,"existing transit chooser reused")
 if action!=null:
  var scroll = action.get_parent()
  while scroll!=null and not scroll is ScrollContainer:scroll=scroll.get_parent()
  if scroll!=null:scroll.ensure_control_visible(action);await process_frame
  await click(action.get_global_rect().get_center())
  check(game.mode=="transit_line","visible chooser button activates transit line tool")
  for index: int in [0,1,0]:
   var point: Vector2 = game.screen(lots[index].position)
   check(Rect2(Vector2.ZERO,Vector2(root.size)).has_point(point) and not game.drawer.get_global_rect().has_point(point),"station click clear of chooser: %s" % point)
   await click(point)
 check(game.city.transit_lines.size()==1,"real viewport clicks create out/back service")
 game.city.enable_simulation_worker()
 var train_in_crossing := false
 for i in range(28):
  game.city.simulation.resume();game.city.advance_society(2.0);game.city.simulation.validation_publish()
  for pose: Dictionary in game.city.transit_state.visible:
   if pose.kind=="rail" and Vector2(pose.position).distance_to(center*4.0)<4.0:
    train_in_crossing=true;break
  if train_in_crossing:break
 check(train_in_crossing,"published train car center within 4m of the departing X center")
 # Capture composition only: zoom onto the departing X so its rails, wires and the
 # crossing car are legible; the X center stays at the same viewport point.
 game.map_zoom=2.0
 game.origin += Vector2(580,245) - game.screen(center)
 game.select_category("transport");game.mode="select";game.refresh()
 game.world_renderer.synchronize();await process_frame
 var geometry: Dictionary = game.transit_view.geometry
 check(geometry.get("crossovers",{}).size()==2,"two retained surface crossover meshes")
 check(geometry.catenary.any(func(c):return c.has("crossover_key")),"ground display emits X wires")
 check(game.world_renderer.transit_cars.size()==3,"same crossing composition contains three retained train sprites")
 for i in range(100):
  await process_frame
  if not game.building_views.busy and game.building_views.queue.is_empty():break
 var station_key := "%d:StationRear" % lots[0].id
 check(game.world_renderer.station_parts.has(station_key) and game.world_renderer.station_parts[station_key].texture!=null,"original station asset in live crossing composition")
 print("P5 coordinate world_m=%s viewport=%s client=%s" % [center*4.0,game.screen(center),root.size])
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--p5-capture=") and failures==0:
   await RenderingServer.frame_post_draw
   var path := arg.trim_prefix("--p5-capture=")
   check(root.get_texture().get_image().save_png(path)==OK,"saved explicitly requested framebuffer")
   break
 game.city.simulation.shutdown();game.queue_free();await process_frame
 print("TERMINAL_TURNBACK_NATIVE checks=%d failed=%d" % [checks,failures])
 quit(1 if failures else 0)
