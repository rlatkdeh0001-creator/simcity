extends "res://tests/test_road_midpoint_connections.gd"
func settle():
 for i in range(8):await process_frame
func select_lanes(count: int):
 await road_tool()
 if count!=2:
  for card in game.road_lane_cards:
   if int(card.get_meta("lanes"))==count:await click(card.get_global_rect().get_center());break
 await settle()
 verify(game.mode=="road" and game.road_lanes==count,"actual lane card selects "+str(count)+" lanes and drawing mode before world input")
func run():
 root.size=Vector2i(1280,820);game=load("res://main.tscn").instantiate();game.city=City.new(100,100);game.paused=true;root.add_child(game);current_scene=game;await settle()
 var cases:=[
  ["2 to 8 end",2,8,Vector2(36,40),Vector2(52,40),false,0],
  ["2 to 8 start",2,8,Vector2(20,40),Vector2(4,40),false,0],
  ["2 to 8 midpoint overdraw",2,8,Vector2(28,40),Vector2(52,40),false,0],
  ["8 to 2 end",8,2,Vector2(36,40),Vector2(52,40),false,0],
  ["2 to 2 end",2,2,Vector2(36,40),Vector2(52,40),true,0],
  ["8 to 8 end",8,8,Vector2(36,40),Vector2(52,40),true,0],
  ["8 to 2 right-angle T",2,8,Vector2(28,40),Vector2(28,56),true,3],
  ["8 across 2 cross",2,8,Vector2(28,24),Vector2(28,56),true,4],
  ["8 to 2 angled endpoint",2,8,Vector2(36,40),Vector2(36,56),true,0]
 ]
 for spec in cases:
  game.road_drawer.cancel();game.city=City.new(100,100);game.road_grid_enabled=true;game.map_zoom=1;game.origin=Vector2.ZERO;game.origin=Vector2(640,260)-game.screen(Vector2(28,40))
  await select_lanes(spec[1]);await click(game.screen(Vector2(20,40)));await click(game.screen(Vector2(36,40)));await settle()
  verify(game.city.roads.size()==1,spec[0]+" builds its host through the actual lane card")
  if game.city.roads.is_empty():continue
  var before:=var_to_str(game.city.roads);var count: int=game.city.roads.size()
  await select_lanes(spec[2]);await click(game.screen(spec[3]));var motion:=InputEventMouseMotion.new();motion.position=game.screen(spec[4]);root.push_input(motion,true);await process_frame
  var result: Dictionary=game.road_drawer.preview()

  verify(result.ok==spec[5],spec[0]+" preview follows the same-profile extension / mixed-width crossing rule")
  await click(game.screen(spec[4]));await settle()
  if spec[5]:
   verify(game.city.roads.size()==count+1,spec[0]+" final mouse click constructs the permitted road")
   verify((game.city.junctions.size()==1 and game.city.junctions[0].arms.size()==spec[6]) if spec[6]>=3 else game.city.junctions.is_empty(),spec[0]+" retains the intended T/cross or uncontrolled angled/end connection")
  else:verify(var_to_str(game.city.roads)==before,spec[0]+" rejected final mouse click cannot mutate the roads")
 game.queue_free();await process_frame
 print("RESULT %d/%d road profile connection checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
