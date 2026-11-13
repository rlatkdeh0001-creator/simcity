extends "res://tests/test_road_profile_connections.gd"
func click(point:Vector2):
 var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true);await process_frame
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
func select_lanes(count:int):
 game.road_drawer.cancel()
 if not game.drawer.visible or game.chosen!="road":await click(game.categories[1].get_global_rect().get_center());await settle()
 for card in game.road_lane_cards:
  if int(card.get_meta("lanes"))==count:await click(card.get_global_rect().get_center());break
 await settle();verify(game.mode=="road" and game.road_lanes==count,"actual lane card selects "+str(count)+" lanes and drawing mode before world input")
func run():
 root.size=Vector2i(1280,820);game=load("res://main.tscn").instantiate();game.city=City.new(100,100);game.paused=true;root.add_child(game);current_scene=game;await settle()
 for spec in [[2,3,true,false],[4,5,true,false],[6,7,true,false],[2,4,true,false],[5,7,true,false],[7,8,true,false],[8,7,true,false],[5,3,true,true],[2,6,false,false],[4,8,false,false],[8,2,false,false]]:
  game.road_drawer.cancel();game.city=City.new(100,100);game.road_grid_enabled=true;game.map_zoom=.5;game.origin=Vector2.ZERO;game.origin=Vector2(640,220)-game.screen(Vector2(28,40))
  await select_lanes(spec[0]);await click(game.screen(Vector2(20,40)));await click(game.screen(Vector2(36,40)));await settle();verify(game.city.roads.size()==1,"native grade host "+str(spec))
  var before:=var_to_str(game.city.roads)
  await select_lanes(spec[1]);var start:=Vector2(20,40) if spec[3] else Vector2(36,40);var end:=Vector2(4,40) if spec[3] else Vector2(52,40);await click(game.screen(start));var motion:=InputEventMouseMotion.new();motion.position=game.screen(end);root.push_input(motion,true);await process_frame
  var result:Dictionary=game.road_drawer.preview()

  verify(result.ok==spec[2],"native grade green/red preview "+str(spec));await click(game.screen(end));await settle()
  verify((game.city.roads.size()==2 and game.city.junctions.is_empty()) if spec[2] else var_to_str(game.city.roads)==before,"native confirmation preserves junction-free transition or rejected original roads "+str(spec))
  for polygon in game.city.road_pavement+game.city.junction_pavement:
   var projected:=PackedVector2Array()
   for p in polygon:projected.append(game.screen(p))
   verify(not Geometry2D.triangulate_polygon(projected).is_empty(),"projected transition pavement has valid triangles "+str(spec))
 game.queue_free();await process_frame
 print("RESULT %d/%d native road grade flow checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
