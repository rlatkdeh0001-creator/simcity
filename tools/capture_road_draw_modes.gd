extends SceneTree
var game
func _initialize():run.call_deferred()
func mouse(point: Vector2,down: bool):
 var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
func click(point: Vector2):
 await mouse(point,true);await mouse(point,false)
func world_click(point: Vector2):await click(game.screen(point))
func move(point: Vector2):
 var event:=InputEventMouseMotion.new();event.position=game.screen(point);root.push_input(event,true);await process_frame
func run():
 var path:="";var scenario:="curve"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
  if arg.begins_with("--case="):scenario=arg.trim_prefix("--case=")
 if path.is_empty() or scenario not in ["curve","buttons"]:quit(1);return
 game=load("res://main.tscn").instantiate();game.paused=true;game.city.population_enabled=false;root.add_child(game);current_scene=game
 for frame in range(5):await process_frame
 await click(game.categories[1].get_global_rect().get_center())
 game.map_zoom=1.1;game.origin=Vector2(1000,-80);game.queue_redraw()
 await world_click(Vector2(12,40));await world_click(Vector2(32,40))
 if game.city.roads.size()!=1:push_error("Actual two-click road did not commit");quit(1);return
 await click(game.road_mode_buttons[1].get_global_rect().get_center())
 await world_click(Vector2(32.4,40.1));await world_click(Vector2(40,15));await move(Vector2(65,25))
 var preview: Dictionary=game.road_drawer.preview()
 if not preview.ok or preview.points.size()<8 or game.city.roads.size()!=1:push_error("Actual quadratic preview not green");quit(1);return
 if scenario=="buttons":
  await world_click(Vector2(65,25))
  if game.city.roads.size()!=2:quit(1);return
  await click(game.road_mode_buttons[2].get_global_rect().get_center())
  if game.road_drawer.kind!="free":quit(1);return
  await move(Vector2(70,30))
 for frame in range(15):await process_frame
 await RenderingServer.frame_post_draw
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"scenario":scenario,"input":"real category/mode buttons and world clicks","mode":game.road_drawer.kind,"pending":game.road_drawer.anchors,"preview":preview if scenario=="curve" else {},"road_count":game.city.roads.size(),"palette":str(game.road_modes.get_global_rect()),"buttons":game.road_mode_buttons.map(func(b):return {"name":b.name,"selected":b.button_pressed,"rect":str(b.get_global_rect())}),"viewport":str(root.get_visible_rect()),"funds":game.city.funds},"  ")+"\n");file.close()
 quit(0 if root.get_texture().get_image().save_png(path)==OK else 1)
