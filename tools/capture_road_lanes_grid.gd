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
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
 assert(not path.is_empty())
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
