extends SceneTree
func _initialize():run.call_deferred()
func click(point: Vector2):
 for down in [true,false]:
  var e:=InputEventMouseButton.new();e.position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);await process_frame
func run():
 var path:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);current_scene=game
 game.city.add_road(PackedVector2Array([Vector2(10,40),Vector2(70,40)]))
 game.map_zoom=1.3;game.origin=Vector2.ZERO;game.origin=Vector2(960,330)-game.screen(Vector2(35,45));game.queue_redraw()
 for i in range(5):await process_frame
 await click(game.categories[1].get_global_rect().get_center())
 for i in range(5):await process_frame
 await click(game.screen(Vector2(35,40)))
 var raw:=Vector2(38,60);var motion:=InputEventMouseMotion.new();motion.position=game.screen(raw);root.push_input(motion,true)
 for i in range(5):await process_frame
 var candidate: Dictionary=game.road_drawer.preview();var points: PackedVector2Array=candidate.points
 assert(candidate.ok and game.city.roads.size()==1 and points[0]==Vector2(35,40) and points[-1].is_equal_approx(Vector2(35,60)))
 await RenderingServer.frame_post_draw;assert(root.get_texture().get_image().save_png(path)==OK)
 await click(game.screen(raw))
 assert(game.city.roads.size()==2 and game.city.roads[-1].points==points and game.city.junctions.size()>0)
 var state:={"input":"actual road-category click, snapped middle start click, near-90 cursor preview and end click","capture_phase":"green preview before commit","raw_cursor":raw,"snapped_points":points,"after_click_committed_points":game.city.roads[-1].points,"junctions":game.city.junctions.size(),"angle_dot_existing_tangent":(points[-1]-points[0]).normalized().dot(Vector2.RIGHT),"viewport":str(root.get_visible_rect())}
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
 print("NATIVE_90_SNAP_PASS exact right angle; green preview equals actual committed road");quit()
