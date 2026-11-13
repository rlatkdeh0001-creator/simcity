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
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
 assert(not path.is_empty())
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
