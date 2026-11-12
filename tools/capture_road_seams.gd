extends SceneTree
func _initialize():run.call_deferred()
func run():
 var path:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);current_scene=game
 var segments:=[PackedVector2Array([Vector2(10,40),Vector2(30,40)]),PackedVector2Array([Vector2(30,40),Vector2(48,46)]),PackedVector2Array([Vector2(48,46),Vector2(48,63)])]
 for points in segments:assert(game.city.add_road(points,"local",true,4).ok)
 assert(game.city.junctions.is_empty() and game.city.road_joins.size()==2 and game.city.road_visuals.size()==1)
 game.map_zoom=1.6;game.origin=Vector2.ZERO;game.origin=Vector2(960,430)-game.screen(Vector2(32,45));game.queue_redraw()
 for i in range(5):await process_frame
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080));assert(image.save_png(path)==OK)
 var state:={"viewport":str(image.get_size()),"original_roads":game.city.roads.size(),"true_intersections":game.city.junctions.size(),"uncontrolled_joins":game.city.road_joins.size(),"continuous_render_strokes":game.city.road_visuals.size(),"smooth_centerline":game.city.road_visuals[0].points,"seams":[]}
 for p in [Vector2(30,40),Vector2(48,46)]:state.seams.append({"world":p,"screen":game.screen(p)})
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
 print("NATIVE_SEAMS_PASS two bent seams, one continuous road, zero crosswalk/intersection controls");quit()
