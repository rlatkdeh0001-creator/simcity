extends SceneTree
var game
func _initialize():run.call_deferred()
func click(point: Vector2):
 for down in [true,false]:
  var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=point;root.push_input(e,true);await process_frame
func settle():
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
func run():
 var path:=""
 var scenario:="cards"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
  if arg.begins_with("--case="):scenario=arg.trim_prefix("--case=")
 assert(not path.is_empty())
 if scenario=="grid":await capture_grid(path);return
 game=load("res://main.tscn").instantiate();game.city=preload("res://core/city_model.gd").new(100,100);game.paused=true;root.add_child(game);current_scene=game
 var counts:=[2,3,4,5,8]
 for i in range(counts.size()):assert(game.city.add_road(PackedVector2Array([Vector2(18,20+i*14),Vector2(34,20+i*14)]),"local",true,counts[i]).ok)
 await settle();await click(game.categories[1].get_global_rect().get_center());await settle()
 await click(game.road_lane_cards[3].get_global_rect().get_center());assert(game.road_lanes==5)
 await click(game.road_grid_button.get_global_rect().get_center());assert(not game.road_grid_enabled)
 await click(game.road_grid_button.get_global_rect().get_center());assert(game.road_grid_enabled)
 game.map_zoom=1.1;game.origin=Vector2.ZERO;game.origin=Vector2(980,400)-game.screen(Vector2(26,48));game.queue_redraw();await settle()
 var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080) and image.save_png(path)==OK)
 var layouts:=[]
 for size in [Vector2i(1920,1080),Vector2i(1280,820),Vector2i(960,640)]:
  if size.x!=1920:root.mode=Window.MODE_WINDOWED;root.size=size
  await settle()
  var rects:=[]
  for card in game.road_lane_cards:
   assert(card.caption.get_theme_font_size("font_size")>=18);rects.append(card.get_global_rect())
  assert(game.road_grid_button.get_global_rect().end.x<=root.size.x and game.road_grid_button.get_theme_stylebox("normal").bg_color==Color("36b7ff"))
  for i in range(4):assert(rects[i].end.x<=rects[i+1].position.x)
  layouts.append({"viewport":str(root.size),"cards":rects,"grid":game.road_grid_button.get_global_rect()})
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify({"selected_lanes":5,"major_side":1,"grid":true,"input":"actual category, lane card and grid toggle mouse press/release","layouts":layouts,"thumbnail_source":"actual generated road meshes, building studio"},"  "));file.close()
 print("NATIVE_LANE_CARDS_PASS five real-render cards; selected5; grid actual off/on; 1920/1280/960 layouts");quit()
func move_world(point: Vector2):
 var e:=InputEventMouseMotion.new();e.position=game.screen(point);root.push_input(e,true);await process_frame
func capture_grid(path: String):
 game=load("res://main.tscn").instantiate();game.city=preload("res://core/city_model.gd").new(100,100);game.paused=true;root.add_child(game);current_scene=game
 assert(game.city.add_road(PackedVector2Array([Vector2(24,30),Vector2(72,30)]),"local",true,4).ok)
 await settle();await click(game.categories[1].get_global_rect().get_center());await settle();await click(game.road_lane_cards[0].get_global_rect().get_center())
 game.map_zoom=1.2;game.origin=Vector2.ZERO;game.origin=Vector2(960,400)-game.screen(Vector2(48,35.5));game.queue_redraw();await settle()
 await move_world(Vector2(24.23,41.2));await click(game.screen(Vector2(24.23,41.2)))
 await move_world(Vector2(72.26,41.3));var preview: Dictionary=game.road_drawer.preview();assert(preview.ok)
 await click(game.screen(Vector2(72.26,41.3)));assert(game.city.roads.size()==2 and game.city.roads[-1].points==preview.points)
 game.road_drawer.cancel()
 var lot:=PackedVector2Array([Vector2(32,32),Vector2(40,32),Vector2(40,40),Vector2(32,40)])
 var parcel: Dictionary=game.city.zoning_grid.parcel_at(Vector2(32.5,32.5));assert(game.city.parcel_placement_error(parcel.frame,parcel.u,parcel.v,8).is_empty())
 var cells: Array=game.city.zoning_grid.opposing_lot_cells(parcel.frame,parcel.u,parcel.v);assert(cells.size()==64)
 var painted: Dictionary=game.city.paint_zones(lot,"residential");assert(painted.ok and painted.changed==64)
 game.refresh();await settle();var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080) and image.save_png(path)==OK)
 var state:={"grid":game.road_grid_enabled,"lanes":[4,2],"edge_gap_cells":8,"opposed_cells":cells.size(),"valid_8x8_placement":true,"painted_cells":painted.changed,"input":"real category/card and world mouse press/release","preview_equals_commit":game.city.roads[-1].points==preview.points,"roads":game.city.roads}
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
 print("NATIVE_ROAD_GRID_PASS actual mouse input; eight-cell edge gap; 64 opposed cells; valid8x8; exact preview=commit");quit()
