extends "res://tests/test_road_grade_flow.gd"
func run():
 var output:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):output=arg.trim_prefix("--evidence=")
 assert(not output.is_empty());root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();game.city=City.new(100,100);game.paused=true;root.add_child(game);current_scene=game;await settle();game.map_zoom=.7;game.origin=Vector2.ZERO;game.origin=Vector2(960,340)-game.screen(Vector2(40,54))
 var strokes:=[ [2,Vector2(28,40.5),Vector2(40,40.5)],[3,Vector2(40,40.5),Vector2(52,40.5)],[3,Vector2(24,68.5),Vector2(32,68.5)],[5,Vector2(32,68.5),Vector2(40,68.5)],[7,Vector2(40,68.5),Vector2(48,68.5)],[8,Vector2(48,68.5),Vector2(56,68.5)] ]
 for spec in strokes:
  var count:int=game.city.roads.size();await select_lanes(spec[0]);await click(game.screen(spec[1]));var e:=InputEventMouseMotion.new();e.position=game.screen(spec[2]);e.global_position=e.position;root.push_input(e,true);await process_frame;assert(game.road_drawer.preview().ok);await click(game.screen(spec[2]));await settle();assert(game.city.roads.size()==count+1)
 game.road_drawer.cancel();game.queue_redraw();await settle();await RenderingServer.frame_post_draw
 assert(game.city.roads.size()==6 and game.city.junctions.is_empty() and game.city.road_joins.filter(func(j):return j.get("taper",false)).size()==3 and failures==0)
 var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080) and image.save_png(output)==OK)
 var file:=FileAccess.open(output.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify({"input":"actual lane-card and world press/release","same_grade":[2,3],"adjacent_grades":[3,5,7,8],"roads":game.city.roads,"tapers":3,"controlled_junctions":0,"viewport":str(image.get_size())},"  "));file.close();print("NATIVE_GRADE_TRANSITIONS_PASS six actual strokes; continuous medians; three tapers; no controlled junctions");quit()
