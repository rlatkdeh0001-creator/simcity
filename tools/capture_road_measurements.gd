extends SceneTree
var game
func _initialize():run.call_deferred()
func click(point: Vector2):
 for down in [true,false]:
  var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=point;root.push_input(e,true);await process_frame
func position_preview(size: Vector2i):
 game.map_zoom=2.2 if size.x==1920 else 1.0
 game.origin=Vector2.ZERO;game.origin=(Vector2(900,480) if size.x==1920 else Vector2(size)*Vector2(.6,.28))-game.screen(Vector2(30,30))
 var move:=InputEventMouseMotion.new();move.position=game.screen(Vector2(30,42));root.push_input(move,true);game.queue_redraw()
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
func run():
 var path:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
 assert(not path.is_empty())
 game=load("res://main.tscn").instantiate();game.city=preload("res://core/city_model.gd").new(100,100);game.paused=true;root.add_child(game);current_scene=game
 game.city.add_road(PackedVector2Array([Vector2(10,30),Vector2(30,30)]))
 for i in range(6):await process_frame
 await click(game.categories[1].get_global_rect().get_center())
 game.map_zoom=2.2;game.origin=Vector2.ZERO;game.origin=Vector2(900,480)-game.screen(Vector2(30,30))
 await click(game.screen(Vector2(30,30)))
 var layouts:=[]
 for size in [Vector2i(1920,1080),Vector2i(1280,820),Vector2i(960,640)]:
  if size.x!=1920:root.mode=Window.MODE_WINDOWED;root.size=size
  for i in range(3):await process_frame
  await position_preview(size)
  var m: Dictionary=game.road_drawer.measurements();var boxes: Array=game.road_drawer.measurement_boxes
  assert(m.length_text=="48 m" and m.angles.size()==1 and m.angles[0].text=="90°" and boxes.size()==2)
  for box in boxes:assert(box.font_size>=18 and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(box.rect) and box.rect.end.y<game.drawer.global_position.y)
  assert(not boxes[0].rect.intersects(boxes[1].rect))
  layouts.append({"viewport":str(root.size),"boxes":boxes})
  if size.x==1920:
   var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080) and image.save_png(path)==OK)
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify({"input":"real category and first point clicks, actual map motion","length":"48 m","angle":"90°","layouts":layouts,"road_count":game.city.roads.size()},"  "));file.close()
 print("NATIVE_MEASURE_PASS 48 m / 90 degrees; 20px; three layouts fit without overlap; no automatic construction");quit()
