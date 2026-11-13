extends SceneTree
var game
func _initialize():run.call_deferred()
func click(point: Vector2):
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;root.push_input(event,true);await process_frame
func escape():
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=KEY_ESCAPE;event.physical_keycode=KEY_ESCAPE;event.pressed=down;root.push_input(event,true);await process_frame
func settle():
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
func run():
 var path:=""
 var scenario:="corner"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
  if arg.begins_with("--case="):scenario=arg.trim_prefix("--case=")
 assert(not path.is_empty())
 if scenario=="mixed-width":await capture_mixed_width(path);return
 if scenario!="corner":await capture_construction(path,scenario);return
 game=load("res://main.tscn").instantiate();game.city=preload("res://core/city_model.gd").new(100,100);game.paused=true;root.add_child(game);current_scene=game
 assert(game.city.add_road(PackedVector2Array([Vector2(20,35),Vector2(50,35)]),"local",true,3).ok)
 assert(game.city.add_road(PackedVector2Array([Vector2(50,35),Vector2(50,65)]),"local",true,3).ok)
 await settle();await click(game.categories[1].get_global_rect().get_center());await settle();await click(game.road_lane_cards[1].get_global_rect().get_center());game.road_drawer.cancel()
 game.map_zoom=1.2;game.origin=Vector2.ZERO;game.origin=Vector2(960,400)-game.screen(Vector2(41,43));game.queue_redraw();await settle()
 var basis: Dictionary=game.city.zoning_lattices[0]
 for cell in game.city.zoning_grid.parcels.values():
  for p in cell.polygon:
   var delta: Vector2=p-basis.origin
   assert(absf(delta.dot(basis.along)-roundf(delta.dot(basis.along)))<.001 and absf(delta.dot(basis.outward)-roundf(delta.dot(basis.outward)))<.001)
 var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080) and image.save_png(path)==OK)
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify({"case":"corner","grid":game.road_grid_enabled,"shared_basis":basis,"roads":game.city.roads,"cells":game.city.zoning_grid.count(),"all_cell_corners_on_shared_board":true},"  "));file.close()
 print("NATIVE_SHARED_ROAD_GRID_PASS odd-width L corner, all actual parcel corners share one board");quit()
func move_world(point: Vector2):
 var event:=InputEventMouseMotion.new();event.position=game.screen(point);root.push_input(event,true);await process_frame
func capture_construction(path: String,scenario: String):
 assert(scenario in ["crossing","overlap"])
 game=load("res://main.tscn").instantiate();game.city=preload("res://core/city_model.gd").new(100,100);game.paused=true;root.add_child(game);current_scene=game
 if scenario=="crossing":
  for y in [30,46]:assert(game.city.add_road(PackedVector2Array([Vector2(20,y),Vector2(65,y)])).ok)
 else:assert(game.city.add_road(PackedVector2Array([Vector2(20,35),Vector2(65,35)]),"local",true,4).ok)
 await settle();await click(game.categories[1].get_global_rect().get_center());await settle();await click(game.road_lane_cards[0 if scenario=="crossing" else 2].get_global_rect().get_center())
 if scenario=="overlap":await click(game.road_grid_button.get_global_rect().get_center());assert(not game.road_grid_enabled)
 game.map_zoom=1.0;game.origin=Vector2.ZERO;game.origin=Vector2(960,400)-game.screen(Vector2(43,39));game.queue_redraw();await settle()
 var first:=Vector2(44,20) if scenario=="crossing" else Vector2(20,36.5)
 var last:=Vector2(44,60) if scenario=="crossing" else Vector2(65,36.5)
 await move_world(first);await click(game.screen(first));await move_world(last);await settle()
 var result: Dictionary=game.road_drawer.preview();assert(result.ok==(scenario=="crossing"))
 var before: int=game.city.roads.size()
 var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080) and image.save_png(path)==OK)
 await click(game.screen(last))
 if scenario=="crossing":assert(game.city.roads.size()==before+1 and game.city.junctions.size()==2 and game.city.roads[-1].points==result.points)
 else:assert(game.city.roads.size()==before and "겹" in result.reason)
 var state:={"case":scenario,"preview_ok":result.ok,"reason":result.get("reason",""),"grid":game.road_grid_enabled,"points":result.points,"roads_before_click":before,"roads_after_click":game.city.roads.size(),"junctions_after_click":game.city.junctions.size(),"input":"real lane-card click and world mouse press/release; capture before final click, transaction verified afterward"}
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
 print("NATIVE_ROAD_CONSTRUCTION_PASS "+scenario+" preview and actual final click agree");quit()
func capture_mixed_width(path: String):
 game=load("res://main.tscn").instantiate();game.city=preload("res://core/city_model.gd").new(100,100);game.paused=true;root.add_child(game);current_scene=game
 assert(game.city.add_road(PackedVector2Array([Vector2(15,40),Vector2(85,40)]),"local",true,8).ok)
 await settle();await click(game.categories[1].get_global_rect().get_center());await settle();await click(game.road_lane_cards[0].get_global_rect().get_center())
 if game.road_grid_enabled:await click(game.road_grid_button.get_global_rect().get_center())
 game.map_zoom=.95;game.origin=Vector2.ZERO;game.origin=Vector2(960,400)-game.screen(Vector2(50,42));game.queue_redraw();await settle()
 for endpoints in [[Vector2(40,16),Vector2(40,70)],[Vector2(70,40),Vector2(70,70)]]:
  # Straight mode intentionally chains from its last endpoint; start a separate stroke.
  await escape();await click(game.categories[1].get_global_rect().get_center());await settle();await click(game.road_lane_cards[0].get_global_rect().get_center())
  await move_world(endpoints[0]);await click(game.screen(endpoints[0]));await move_world(endpoints[1]);await settle()
  var preview: Dictionary=game.road_drawer.preview()
  assert(preview.ok and preview.points[0].distance_to(endpoints[0])<.01 and preview.points[-1].distance_to(endpoints[1])<.01);await click(game.screen(endpoints[1]));await settle()
 assert(game.city.roads.size()==3 and game.city.junctions.size()==2)
 assert(game.city.junctions.any(func(j):return j.arms.size()==3) and game.city.junctions.any(func(j):return j.arms.size()==4))
 for junction in game.city.junctions:
  assert(is_equal_approx(junction.box_width,8.0))
  for arm in junction.arms:
   var expected:=1.25 if arm.lanes==8 else 4.25
   assert(is_equal_approx(game.city.RoadJunctions.crosswalk_distance(junction,arm),expected))
   var crossing: Vector2=game.city.RoadJunctions.sample(arm.points,expected)
   assert(game.city.road_crosswalks.any(func(p):return Geometry2D.is_point_in_polygon(crossing,p)))
   var finish: float=game.city.RoadJunctions.stop_line_distance(junction,arm)+.04+.03
   var centre_end: Vector2=game.city.RoadJunctions.sample(arm.points,finish)
   var normal:=Vector2(-arm.direction.y,arm.direction.x)
   var median_end: Vector2=centre_end+normal*game.city.RoadProfile.median_offset(arm)
   assert(game.city.road_medians.any(func(line):return minf(line[0].distance_to(median_end),line[-1].distance_to(median_end))<.005))
   for offset in game.city.RoadProfile.separators(arm):
    var lane_end: Vector2=centre_end+normal*offset
    assert(game.city.road_lane_marks.any(func(line):return Geometry2D.get_closest_point_to_segment(lane_end,line[0],line[-1]).distance_to(lane_end)<.55))
 for polygon in game.city.road_pavement+game.city.road_asphalt:
  for region in game.city.intersection_regions:assert(not game.city.Parcels.overlap(polygon,region))
 for line in game.city.road_medians+game.city.road_lane_marks:
  for junction in game.city.junctions:
   for region in game.city.RoadJunctions.lane_mark_regions(junction):assert(not Geometry2D.is_point_in_polygon((line[0]+line[-1])/2,region))
 await escape();assert(game.mode=="select")
 game.queue_redraw();await settle()
 var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080) and image.save_png(path)==OK)
 var state:={"case":"mixed-width","input":"actual lane-card/grid clicks, two world road gestures, preview and committed T/cross verified, ESC exits preview","roads":game.city.roads,"junctions":game.city.junctions,"road_bodies_outside_boxes":true,"lane_marks_end_at_actual_stop_lines":true,"crosswalks_at_actual_crossed_edges":true,"wide_arm_crossing_distance_cells":1.25,"narrow_arm_crossing_distance_cells":4.25,"stop_line_polygons":game.city.road_stop_lines.size(),"crosswalk_polygons":game.city.road_crosswalks.size(),"grid":game.road_grid_enabled}
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
 print("NATIVE_MIXED_WIDTH_JUNCTIONS_PASS 8/2-lane T and cross; medians and lane dashes reach stop lines, zebra gaps protected, real mouse commits");quit()
