extends SceneTree
const City=preload("res://core/city_model.gd")
var game
var checks:=0
var failures:=0
var capture_path:=""
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func settle():
 for i in range(8):await process_frame
func motion(point: Vector2):
 var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;root.push_input(event,true);await settle()
func button(point: Vector2,down: bool,which: int=MOUSE_BUTTON_LEFT):
 var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=which;event.pressed=down;root.push_input(event,true);await settle()
func click(point: Vector2):
 await motion(point);await button(point,true);await button(point,false)
func key(code: int):
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;root.push_input(event,true);await settle()
func fixture():
 game.cancel_zoning_drag();game.city=City.new(100,100)
 game.city.add_road(PackedVector2Array([Vector2(10,40),Vector2(80,40)]))
 game.city.add_road(PackedVector2Array([Vector2(50,20),Vector2(50,65)]))
 game.map_zoom=.6;game.origin=Vector2.ZERO;game.origin=Vector2(600,300)-game.screen(Vector2(40,40))
 game.mode="select";game.refresh()
 await settle() # Wait for HUD relayout before resolving native button coordinates.
 await click(game.bulldozer.get_global_rect().get_center())
 verify(game.mode=="demolish","native viewport bulldozer click activates actual tool")
func interval(first: float,last: float) -> bool:
 var cuts: Array=game.demolition_hover.get("selection",{}).get("cuts",[])
 return cuts.size()==1 and cuts[0].id==0 and is_equal_approx(cuts[0].first,first) and is_equal_approx(cuts[0].last,last)
func run():
 root.size=Vector2i(1280,820)
 game=load("res://main.tscn").instantiate();game.city=City.new(100,100);game.paused=true;root.add_child(game);current_scene=game;await settle()
 await fixture()
 await motion(game.screen(Vector2(25.3,40)))
 verify(interval(0,40),"hover previews full free-end to true-junction interval, not legacy one-cell cut")
 var original:=var_to_bytes(game.city.roads)
 await button(game.screen(Vector2(25.3,40)),true)
 verify(var_to_bytes(game.city.roads)==original,"actual road mouse press does not mutate before release")
 if var_to_bytes(game.city.roads)!=original:
  game.queue_free();await process_frame;print("RESULT %d/%d road demolition input checks passed"%[checks-failures,checks]);quit(1);return
 game.message="old failure"
 await button(game.screen(Vector2(25.3,40)),false)
 verify(game.city.roads.size()==2 and game.city.roads[0].points[0]==Vector2(50,40),"actual click release deletes whole preview and keeps junction's opposite arm")
 verify(game.message.is_empty() and game.money.tooltip_text.is_empty(),"successful player demolition clears prior error and has no completion notice")
 await fixture()
 original=var_to_bytes(game.city.roads)
 await motion(game.screen(Vector2(25.3,40)));await button(game.screen(Vector2(25.3,40)),true)
 await motion(game.screen(Vector2(26.1,40)))
 verify(interval(15.3,17.3),"forward native drag begins at exact projected press and advances eight metres")
 await motion(game.screen(Vector2(29.8,40)))
 verify(interval(15.3,21.3),"native drag grows in two-world-cell ceiling increments")
 await motion(game.screen(Vector2(70,40)))
 verify(interval(15.3,40),"distant native drag red interval stops at actual cross junction")
 verify(var_to_bytes(game.city.roads)==original,"multiple real motion frames and clamped preview do not mutate road data")
 if not capture_path.is_empty() and failures==0:
  verify(DisplayServer.get_name()!="headless" and RenderingServer.get_current_rendering_method()=="gl_compatibility" and DisplayServer.window_get_size()==root.size,"capture runs in real native GL Compatibility window with matching client viewport")
  game.queue_redraw();await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image()
  verify(image.get_size()==root.size and image.get_width()==1280,"raw rendered viewport has actual requested dimensions")
  var selected_pixel:=image.get_pixelv(Vector2i(game.screen(Vector2(35,40))))
  var outside_pixel:=image.get_pixelv(Vector2i(game.screen(Vector2(65,40))))
  verify(selected_pixel.r>selected_pixel.g*1.35 and outside_pixel.r<outside_pixel.g*1.25,"actual framebuffer is red inside selected interval and not red beyond junction")
  if failures==0:verify(image.save_png(capture_path)==OK,"exactly one raw Godot drag framebuffer saved before release")
 var expected: Dictionary=game.demolition_hover.get("selection",{}).duplicate(true)
 await button(game.screen(Vector2(70,40)),false)
 verify(game.city.roads.size()==3 and game.city.roads[0].points[-1].is_equal_approx(Vector2(25.3,40)) and game.city.roads[1].points[0]==Vector2(50,40),"release deletes precisely red preview, leaving start fragment and junction onward untouched")
 verify(expected.get("cuts",[]).size()==1 and game.demolition_hover.is_empty(),"committed preview is cleared rather than left showing a removed span")
 for cancellation in ["escape","right","tab","hud_release"]:
  await fixture();original=var_to_bytes(game.city.roads)
  await motion(game.screen(Vector2(25.3,40)));await button(game.screen(Vector2(25.3,40)),true);await motion(game.screen(Vector2(35,40)))
  match cancellation:
   "escape":await key(KEY_ESCAPE)
   "right":await button(game.screen(Vector2(35,40)),true,MOUSE_BUTTON_RIGHT);await button(game.screen(Vector2(35,40)),false,MOUSE_BUTTON_RIGHT)
   "tab":await click(game.categories[1].get_global_rect().get_center())
   "hud_release":await button(game.bulldozer.get_global_rect().get_center(),false)
  await button(game.screen(Vector2(35,40)),false)
  verify(var_to_bytes(game.city.roads)==original and game.demolition_hover.is_empty(),cancellation+" cancels captured selection without later release deletion")
 await fixture();await motion(game.screen(Vector2(35.3,40)));await button(game.screen(Vector2(35.3,40)),true);await motion(game.screen(Vector2(31.1,40)))
 verify(interval(19.3,25.3),"reverse native drag grows backwards from exact press")
 await button(game.screen(Vector2(31.1,40)),false)
 verify(game.city.roads[0].points[-1].is_equal_approx(Vector2(29.3,40)) and game.city.roads[1].points[0].is_equal_approx(Vector2(35.3,40)),"reverse release removes the exact quantized preview interval")
 game.queue_free();await process_frame
 print("RESULT %d/%d road demolition input checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
