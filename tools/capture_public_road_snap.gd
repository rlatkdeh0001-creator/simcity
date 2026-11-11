extends SceneTree
var game
func _initialize():run.call_deferred()
func mouse(point: Vector2,down: bool):
 var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
 await process_frame
func move(point: Vector2):
 var event:=InputEventMouseMotion.new();event.position=point;root.push_input(event,true)
 await process_frame
func card(category: String,id: String):
 game.select_category(category)
 for frame in range(5):await process_frame
 for button in game.drawer_box.get_children():
  if button is Button and button.get_meta("thumbnail_asset_id","")==id:
   game.drawer_scroll.ensure_control_visible(button)
   for frame in range(5):await process_frame
   await mouse(button.get_global_rect().get_center(),true);await mouse(button.get_global_rect().get_center(),false)
   return game.public_controller.asset_id==id
 return false
func run():
 var path:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
 if path.is_empty():quit(1);return
 game=load("res://main.tscn").instantiate();game.paused=true;game.city.population_enabled=false
 game.city.add_road(PackedVector2Array([Vector2(2,40),Vector2(46,40)]),"local",true,4)
 root.add_child(game);current_scene=game
 for frame in range(5):await process_frame
 if not await card("fire","fire-station"):quit(1);return
 var raw:=Vector2(12,33.4);await move(game.screen(raw));await mouse(game.screen(raw),true);await mouse(game.screen(raw),false)
 if not game.public_controller.last_result.get("ok",false):quit(1);return
 if not await card("police","police-station"):quit(1);return
 game.map_zoom=1.6;game.origin=Vector2(1100,10);raw=Vector2(28,33.4);await move(game.screen(raw))
 for frame in range(120):
  await process_frame
  if frame>20 and not game.building_views.busy and game.building_views.queue.is_empty():break
 var ghost: Dictionary=game.public_controller.preview()
 if not ghost.ok or ghost.record.position.distance_to(Vector2(28,35))>.001:quit(1);return
 await RenderingServer.frame_post_draw
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"input":"real C-card and mouse events","cursor":raw,"ghost":ghost,"placed":game.city.public_facilities.lots,"funds":game.city.funds,"viewport":str(root.get_visible_rect())},"  ")+"\n");file.close()
 quit(0 if root.get_texture().get_image().save_png(path)==OK else 1)
