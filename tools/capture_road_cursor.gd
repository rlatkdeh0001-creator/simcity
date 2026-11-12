extends SceneTree
var game
func _initialize():run.call_deferred()
func click(point: Vector2):
 for down in [true,false]:
  var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=point;root.push_input(e,true);await process_frame
func run():
 var folder:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence-dir="):folder=arg.trim_prefix("--evidence-dir=")
 assert(not folder.is_empty())
 root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();game.city=preload("res://core/city_model.gd").new(100,100);game.paused=true;root.add_child(game);current_scene=game
 assert(game.city.add_road(PackedVector2Array([Vector2(10,30),Vector2(30,30)])).ok)
 for i in range(6):await process_frame
 await click(game.categories[1].get_global_rect().get_center())
 for scenario in ["empty","snap"]:
  await click(game.road_mode_buttons[0].get_global_rect().get_center())
  var target:=Vector2(40,40) if scenario=="empty" else Vector2(30.4,30.1)
  game.map_zoom=2.5;game.origin=Vector2.ZERO;game.origin=Vector2(1050,440)-game.screen(Vector2(40,40) if scenario=="empty" else Vector2(30,30))
  var event:=InputEventMouseMotion.new();event.position=game.screen(target);root.push_input(event,true);game.queue_redraw()
  for i in range(8):await process_frame
  await RenderingServer.frame_post_draw
  var state: Dictionary=game.road_drawer.cursor_preview()
  assert(state.ok and state.snapped==(scenario=="snap") and game.road_drawer.anchors.is_empty())
  var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080))
  var center: Vector2=game.screen(state.center);var green:=0;var blue:=0
  for x in range(int(center.x)-90,int(center.x)+91):
   for y in range(int(center.y)-50,int(center.y)+51):
    var c:=image.get_pixel(x,y)
    if c.g>.7 and c.r<.4 and c.b<.7:green+=1
    if c.b>.85 and c.g>.5 and c.r<.4:blue+=1
  assert(green>10 and (blue>10 if scenario=="snap" else blue==0))
  var path: String=folder+"/"+str(scenario)+"-1920.png";assert(image.save_png(path)==OK)
  state.viewport=str(image.get_size());state.green_pixels=green;state.blue_pixels=blue;state.input="real category/mode button and map motion";state.roads_unchanged=game.city.roads.size()==1
  var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
  print("NATIVE_CURSOR_PASS ",scenario," green=",green," blue=",blue)
 quit()
