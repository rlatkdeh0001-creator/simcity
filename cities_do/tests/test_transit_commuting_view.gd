extends SceneTree
# One final normal native viewport, no FPS reads or timing measurements.
var checks:=0
var failed:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failed+=1;printerr("FAIL "+label)
func _initialize():run.call_deferred()
func click(point:Vector2):
 var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true);await process_frame
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
func run():
 if FileAccess.file_exists("res://../docs/transit-commuting-validation/p4-native-1920.png"):
  printerr("FAIL capture already exists; refusing a second frame");quit(1);return
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame
 if game.city.simulation!=null:game.city.simulation.shutdown()
 game.city=load("res://tests/test_transit_commuting.gd").fixture()
 game.city.population_enabled=true;game.map_zoom=.65;game.origin=Vector2(780,80);game.refresh()
 game.select_category("transport");await process_frame
 var action=game.drawer_box.find_child("Tool_transit_line",true,false)
 check(action!=null,"existing transport chooser action")
 if action!=null:
  await click(action.get_global_rect().get_center())
  for index:int in [0,1,0]:await click(game.screen(game.city.public_facilities.lots[index].position))
 check(game.city.transit_lines.size()==1,"existing stop-click UI creates physical passenger loop")
 game.drawer.hide();game.city.enable_simulation_worker();game.city.simulation.worker.Suspend()
 for i in range(6):game.city.simulation.resume();game.city.advance_society(2);game.city.simulation.validation_publish()
 check(game.city.commuting_status().inbound>0,"production native worker publishes rail inbound workers")
 check(game.city.commuting.last_plan.flows.any(func(flow):return flow.mode=="rail"),"published authoritative commuting choices use rail")
 game.refresh();game.world_renderer.synchronize()
 for i in range(120):
  await process_frame
  if not game.building_views.busy and game.building_views.queue.is_empty():break
 check(game.world_renderer.transit_cars.size()==3,"normal renderer displays full existing train consist")
 for sprite in game.world_renderer.transit_cars.values():check(sprite.texture!=null,"original train sprite present")
 check(DisplayServer.get_name()!="headless","real normal viewport backend")
 if failed==0:
  await RenderingServer.frame_post_draw
  var image:Image=root.get_texture().get_image()
  check(image.get_size()==Vector2i(1920,1080),"native 1920x1080 framebuffer")
  if failed==0:
   check(image.save_png("res://../docs/transit-commuting-validation/p4-native-1920.png")==OK,"single final frame saved")
   var file:=FileAccess.open("res://../docs/transit-commuting-validation/p4-native-state.json",FileAccess.WRITE)
   file.store_string(JSON.stringify({"viewport":[root.size.x,root.size.y],"mode":game.mode,"drawer_visible":game.drawer.visible,"commuting":game.city.commuting_status(),"flows":game.city.commuting.last_plan.flows,"transit_state":game.city.transit_state,"native_tick":game.city.simulation._published_tick},"  "));file.close()
 game.city.simulation.shutdown();game.queue_free();await process_frame
 print("TRANSIT_COMMUTING_VIEW checks=%d failed=%d"%[checks,failed]);quit(1 if failed else 0)
