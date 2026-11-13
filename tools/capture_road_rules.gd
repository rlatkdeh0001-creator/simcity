extends SceneTree
var game
func _initialize():run.call_deferred()
func click(point: Vector2):
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;root.push_input(event,true);await process_frame
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
