extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize():run.call_deferred()
func click(p:Vector2):
 var motion:=InputEventMouseMotion.new();motion.position=p;root.push_input(motion,true);await process_frame
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=p;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
func run():
 root.size=Vector2i(1280,820)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame
 if game.city.simulation!=null:game.city.simulation.shutdown()
 game.city=load("res://tests/transit_operations_fixture.gd").rail_city()
 game.map_zoom=.5;game.origin=Vector2(550,-80);game.refresh()
 game.select_category("transport");await process_frame
 var button=game.drawer_box.find_child("Tool_transit_line",true,false)
 check(button!=null,"existing chooser provides minimal line action")
 if button!=null:
  await click(button.get_global_rect().get_center())
  check(game.mode=="transit_line","native button activates line stop selection")
  await click(game.screen(game.city.public_facilities.lots[0].position))
  game.drawer.hide();await process_frame
  check(game.mode=="select" and game.transit_line_tool.stops.is_empty(),"closing chooser cancels hidden line selection")
  game.select_category("transport");await process_frame
  button=game.drawer_box.find_child("Tool_transit_line",true,false)
  await click(button.get_global_rect().get_center())
  for index:int in [0,1,0]:await click(game.screen(game.city.public_facilities.lots[index].position))
  check(game.city.transit_lines.size()==1,"native first second first stop clicks create operating loop")
  game.city.enable_simulation_worker();game.city.simulation.worker.Suspend()
  for i in range(6):game.city.simulation.resume();game.city.advance_society(2);game.city.simulation.validation_publish()
  game.world_renderer.synchronize();await process_frame
  check(game.city.transit_state.visible.size()==3,"actual worker publishes running full train")
  check(game.world_renderer.get("transit_cars")!=null,"renderer consumes immutable operational snapshots")
  if game.world_renderer.get("transit_cars")!=null:
   check(game.world_renderer.transit_cars.size()==3,"three retained original sprites")
   for sprite in game.world_renderer.transit_cars.values():check(sprite.texture!=null,"real sprite texture loads")
  check(game.traffic.has_method("sprite_path"),"sprite resolver follows approved version catalogue")
  if game.traffic.has_method("sprite_path"):check("-v3/" in game.traffic.sprite_path("train-loco-01",Vector2.RIGHT),"approved locomotive v3 not obsolete original")
  game.city.simulation.shutdown()
 for kind:String in ["metro","freight","bus"]:
  game.city=load("res://tests/test_scheduled_buses.gd").fixture(4) if kind=="bus" else load("res://tests/transit_operations_fixture.gd").rail_city("metro" if kind=="metro" else "rail")
  game.map_zoom=.5;game.origin=Vector2(550,-80);game.refresh();game.select_category("transport");await process_frame
  var action=game.drawer_box.find_child("Tool_freight_line" if kind=="freight" else "Tool_transit_line",true,false)
  await click(action.get_global_rect().get_center())
  for index:int in [0,1,0]:await click(game.screen(game.city.public_facilities.lots[index].position))
  check(game.city.transit_lines.size()==1,"native route workflow "+kind)
  game.city.enable_simulation_worker();game.city.simulation.worker.Suspend()
  for i in range(3):game.city.simulation.resume();game.city.advance_society(2);game.city.simulation.validation_publish()
  game.world_renderer.synchronize();await process_frame
  var count:int=1 if kind=="bus" else 4
  check(game.world_renderer.transit_cars.size()==count,"full native sprite count "+kind)
  for sprite in game.world_renderer.transit_cars.values():
   check(sprite.texture!=null and sprite.texture.get_image().get_used_rect().has_area(),"original nonempty sprite "+kind)
   if kind=="metro":check(not sprite.is_visible_in_tree(),"metro hidden above ground")
  if kind=="metro":
   game.activate_tool("metro");await process_frame
   for sprite in game.world_renderer.transit_cars.values():check(sprite.is_visible_in_tree(),"metro visible at actual underground depth")
  game.activate_tool("remove_line");await process_frame
  await click(game.screen(game.city.public_facilities.lots[0].position))
  check(game.city.simulation.queued_edit_count()==1,"native remove-line click respects suspended worker FIFO "+kind)
  game.city.simulation.resume();game.city.advance_society(2);game.city.simulation.validation_publish();await process_frame
  check(game.city.transit_lines.is_empty() and game.world_renderer.transit_cars.is_empty(),"publication removes line and retained sprites "+kind)
  game.city.simulation.shutdown()
 for kind:String in ["rail","metro"]:
  var fixture:Dictionary=load("res://tests/transit_operations_fixture.gd").populate(game,kind,3)
  await process_frame
  check(fixture.snapshot.visible.size()==(4 if kind=="metro" else 3),"parent capture fixture uses actual worker "+kind)
  for sprite in game.world_renderer.transit_cars.values():
   check(sprite.get_parent()==(game.transit_view.metro_layer if kind=="metro" else game.world_renderer.actors),"fixture city swap reparents retained vehicle "+kind)
  if kind=="rail":
   for i in range(100):
    await process_frame
    if not game.building_views.busy and game.building_views.queue.is_empty():break
   var id:int=game.city.public_facilities.lots[0].id
   var far=game.world_renderer.station_parts["%d:StationRear"%id]
   var near=game.world_renderer.station_parts["%d:StationFront"%id]
   check(far.texture!=null and near.texture!=null,"actual original station parts loaded around running train")
   for sprite in game.world_renderer.transit_cars.values():check(sprite.position.y>far.position.y and sprite.position.y<near.position.y,"real train depth lies between station rear and front")
 game.queue_free();await process_frame
 print("TRANSIT_OPERATIONS_VIEW checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
