extends "res://tests/test_road_grade_flow.gd"
func fixture(corner:bool):
 var city=City.new(100,100)
 if corner:
  city.add_road(PackedVector2Array([Vector2(10,40),Vector2(40,40)]))
  city.add_road(PackedVector2Array([Vector2(40,40),Vector2(40,80)]))
  city.add_road(PackedVector2Array([Vector2(40,48),Vector2(60,48)]))
 else:
  city.add_road(PackedVector2Array([Vector2(10,40),Vector2(41,40)]))
  city.add_road(PackedVector2Array([Vector2(41,40),Vector2(80,40)]))
  city.add_road(PackedVector2Array([Vector2(40,40),Vector2(40,20)]))
 return city
func run():
 var output:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):output=arg.trim_prefix("--evidence=")
 root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();game.city=City.new(100,100);game.paused=true;root.add_child(game);current_scene=game;await settle()
 var cases:=[
  ["split-record T 3.5",false,Vector2(43.5,40),Vector2(43.5,60),false,false],
  ["split-record T exact four",false,Vector2(44,40),Vector2(44,60),true,false],
  ["T endpoint attachment 3.5",false,Vector2(43.5,60),Vector2(43.5,40),false,false],
  ["corner T 3.5",true,Vector2(40,43.5),Vector2(60,43.5),false,false],
  ["grid corner exact four",true,Vector2(40,44),Vector2(60,44),true,true],
  ["grid corner three",true,Vector2(40,43),Vector2(60,43),false,true]
 ]
 for spec in cases:
  game.road_drawer.cancel()
  if game.city.simulation!=null:game.city.simulation.shutdown()
  game.city=fixture(spec[1]);game.road_grid_enabled=spec[5];game.map_zoom=1;game.origin=Vector2.ZERO;game.origin=Vector2(960,400)-game.screen(Vector2(44,43))
  await select_lanes(2)
  var before:=var_to_bytes(game.city.roads);var count:int=game.city.roads.size()
  await click(game.screen(spec[2]))
  var motion:=InputEventMouseMotion.new();motion.position=game.screen(spec[3]);motion.global_position=motion.position;root.push_input(motion,true);await settle()
  var result:Dictionary=game.road_drawer.preview()
  verify(result.ok==spec[4] and (spec[4] or "4칸" in result.get("reason","")),spec[0]+" real preview uses the common four-cell policy")
  var colors:Dictionary=game.road_drawer.preview_colors(result.ok)
  verify(colors.outline==Color("3ddc84" if spec[4] else "ef5350"),spec[0]+" production preview chooses green/red")
  await click(game.screen(spec[3]));await settle()
  verify((game.city.roads.size()==count+1) if spec[4] else (var_to_bytes(game.city.roads)==before and not game.road_drawer.last_result.ok),spec[0]+" actual confirmation agrees without mutating a rejected city")
  if spec==cases[-1] and not output.is_empty() and failures==0:
   game.queue_redraw();await settle();await RenderingServer.frame_post_draw
   var image:=root.get_texture().get_image()
   assert(image.get_size()==Vector2i(1920,1080) and image.save_png(output)==OK)
   var state:={"input":"actual lane-card and viewport mouse press/release","grid_enabled":game.road_grid_enabled,"fixture":"bent two-arm corner and existing T eight cells away","gap_cells":3,"minimum_cells":4,"preview_ok":result.ok,"reason":result.reason,"outline":colors.outline.to_html(),"rejected_commit_preserved_roads":var_to_bytes(game.city.roads)==before,"preview_points":result.points,"viewport":str(image.get_size())}
   var file:=FileAccess.open(output.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
   print("NATIVE_SPACING_CAPTURE_PASS red preview; three-cell corner gap; click rejected; original roads preserved")
 game.queue_free();await process_frame
 print("RESULT %d/%d native junction spacing checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
