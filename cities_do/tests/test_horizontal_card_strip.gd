extends SceneTree
var checks:=0
var failures:=0
var game
func _initialize():run.call_deferred()
func verify(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func settle():
 for i in range(8):await process_frame
func button(point:Vector2,code:int,down:bool):
 var e:=InputEventMouseButton.new();e.button_index=code;e.pressed=down;e.position=point;e.global_position=point;root.push_input(e,true);await process_frame
func wheel(point:Vector2,code:int):
 await button(point,code,true);await button(point,code,false);await settle()
func run():
 root.size=Vector2i(880,820);game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);current_scene=game;await settle();game.select_category("road");await settle()
 var strip=game.find_child("RoadCardStrip",true,false)
 verify(strip!=null,"road cards use reusable horizontally scrollable strip")
 if strip!=null:
  var bar:HScrollBar=strip.get_h_scroll_bar()
  verify(game.road_lane_cards.size()==7 and bar.visible and bar.max_value>bar.page,"seven cards overflow into an automatic horizontal bar at 880")
  verify(strip.get_global_rect().end.x<=880 and game.road_grid_button.get_global_rect().end.x<=880,"card strip and fixed grid toggle stay inside small viewport")
  verify(bar.get_theme_stylebox("scroll").bg_color==Color("38515e") and bar.get_theme_stylebox("grabber").bg_color==Color("36b7ff"),"approved palette track and handle")
  var zoom:float=game.map_zoom;var point:Vector2=strip.get_global_rect().get_center()
  await wheel(point,MOUSE_BUTTON_WHEEL_DOWN);verify(strip.scroll_horizontal>0 and game.map_zoom==zoom,"wheel down over cards moves right without map zoom")
  await wheel(point,MOUSE_BUTTON_WHEEL_UP);verify(strip.scroll_horizontal==0 and game.map_zoom==zoom,"wheel up over cards moves left without map zoom")
  var rect:=bar.get_global_rect();var decrement:float=bar.get_theme_icon("decrement").get_width();var increment:float=bar.get_theme_icon("increment").get_width();var area:float=rect.size.x-decrement-increment;var start:=Vector2(rect.position.x+decrement+area*bar.page/bar.max_value/2,rect.get_center().y);var finish:=start+Vector2(minf(80,area/4),0)
  await button(start,MOUSE_BUTTON_LEFT,true)
  var motion:=InputEventMouseMotion.new();motion.position=finish;motion.global_position=finish;motion.relative=finish-start;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true);await settle();await button(finish,MOUSE_BUTTON_LEFT,false);await settle()
  verify(strip.scroll_horizontal>0 and game.map_zoom==zoom and game.city.roads.is_empty(),"real handle drag scrolls cards without world construction or zoom")
  await wheel(Vector2(800,240),MOUSE_BUTTON_WHEEL_UP);verify(game.map_zoom!=zoom,"wheel over map retains existing zoom")
  game.road_lane_cards[-1].grab_focus();await settle();verify(strip.scroll_horizontal>0,"focus can reveal the rightmost lane card")
  root.size=Vector2i(1920,1080);await settle();verify(not bar.visible,"horizontal bar hides when all seven cards fit")
  root.size=Vector2i(1280,820);await settle();verify(strip.get_global_rect().end.x<=1280 and game.road_grid_button.get_global_rect().end.x<=1280,"1280 keeps fixed controls and strip inside viewport")
  root.size=Vector2i(960,640);await settle();verify(strip.get_global_rect().end.x<=960 and game.road_grid_button.get_global_rect().end.x<=960 and bar.visible==(bar.max_value>bar.page),"960 keeps controls inside viewport and shows bar only on actual overflow")
  for card in game.road_lane_cards:verify(card.caption.get_theme_font_size("font_size")>=18,"card captions retain 18px readability")
 game.queue_free();await process_frame
 print("RESULT %d/%d horizontal card strip checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
