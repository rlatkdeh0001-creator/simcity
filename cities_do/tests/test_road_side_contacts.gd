extends "res://tests/test_road_profile_connections.gd"
func run():
 root.size=Vector2i(1280,820);game=load("res://main.tscn").instantiate();game.city=City.new(100,100);game.paused=true;root.add_child(game);current_scene=game;await settle()
 var cases:=[
  ["parallel side boundary",false,Vector2(30,45),Vector2(46,45),false,0],
  ["perpendicular curb-only end",false,Vector2(38,20),Vector2(38,36),false,0],
  ["legacy widened box boundary",true,Vector2(33,20),Vector2(33,36),false,0],
  ["legacy widened box overlap",true,Vector2(33,21),Vector2(33,37),false,0],
  ["real mixed-width T",false,Vector2(38,40),Vector2(38,56),true,3],
  ["real mixed-width cross",false,Vector2(38,24),Vector2(38,56),true,4],
  ["three-lane parallel side boundary",false,Vector2(30,45.5),Vector2(46,45.5),false,0,3],
  ["three-lane legacy widened box overlap",true,Vector2(33.5,21),Vector2(33.5,37),false,0,3],
  ["five-lane legacy widened box overlap",true,Vector2(32.5,21),Vector2(32.5,37),false,0,5],
  ["real three-lane mixed-width T",false,Vector2(38.5,40),Vector2(38.5,56),true,3,3]
 ]
 for spec in cases:
  game.road_drawer.cancel()
  # Release the worker owned by this fixture before replacing its model.
  if game.city.simulation!=null:game.city.simulation.shutdown()
  game.city=City.new(100,100);game.road_grid_enabled=true;game.map_zoom=1;game.origin=Vector2.ZERO;game.origin=Vector2(640,260)-game.screen(Vector2(38,40))
  if spec[1]:
   # Old authored/saved data stays loadable; do not route restoration through new-build guards.
   game.city.add_road(PackedVector2Array([Vector2(20,40),Vector2(36,40)]))
   game.city.add_road(PackedVector2Array([Vector2(36,40),Vector2(52,40)]),"local",true,8)
   var saved: Array=game.city.roads.duplicate(true);var next_id: int=game.city.next_road_id;var restored:=City.new(100,100);restored.roads.assign(saved);restored.next_road_id=next_id;restored._update_zoning_for_road({});game.city=restored
   verify(var_to_str(game.city.roads)==var_to_str(saved),spec[0]+" rebuilds legacy records without deleting or moving them")
  else:
   await select_lanes(8);await click(game.screen(Vector2(30,40)));await click(game.screen(Vector2(46,40)));await settle()
   verify(game.city.roads.size()==1 and game.city.roads[0].lanes==8,spec[0]+" builds its eight-lane host through real mouse input")
  var before:=var_to_str(game.city.roads);var count: int=game.city.roads.size()
  await select_lanes(spec[6] if spec.size()>6 else 2)
  # New odd-width lattice can leave a half-cell gap here; pin the literal curb contact.
  if spec[0]=="legacy widened box boundary":game.road_grid_enabled=false
  await click(game.screen(spec[2]));var result:Dictionary=profile_preview(spec[3])
  if spec[0]=="perpendicular curb-only end":
   var literal:=PackedVector2Array([spec[2],spec[3]])
   # The existing width lattice moves the requested stroke without moving the curb contact off y=36.
   var snapped:=PackedVector2Array([Vector2(38.5,21),Vector2(37.5,36)])
   var literal_plan:Dictionary=game.city.add_elevated_road(literal,PackedFloat64Array([0.0,0.0]),"local",false,2)
   var snapped_plan:Dictionary=game.city.add_elevated_road(result.points,result.heights_m,"local",false,2,false,result.major_side,result.grid_frame)
   verify(result.points==snapped and not literal_plan.ok and not snapped_plan.ok and var_to_str(game.city.roads)==before,"model rejects both literal and resolved 0m curb-only strokes without writing roads: %s"%[str(result.points)])
  verify(result.fixture_aimed and result.ok==spec[4],spec[0]+" preview rejects surface-only contact but permits actual crossings: "+str(result.get("reason","")))
  game.road_drawer.last_result={}
  await click(game.screen(spec[3]));await settle()
  if spec[4]:
   verify(game.city.roads.size()==count+1 and game.city.junctions.size()==1 and game.city.junctions[0].arms.size()==spec[5],spec[0]+" actual final click creates its real junction")
  else:verify(not game.road_drawer.last_result.is_empty() and not game.road_drawer.last_result.ok and var_to_str(game.city.roads)==before,spec[0]+" actual rejection leaves every existing road intact")
 game.queue_free();await process_frame
 print("RESULT %d/%d road side-contact checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
