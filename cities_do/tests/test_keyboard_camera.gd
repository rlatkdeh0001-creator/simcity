extends SceneTree
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(value: bool,label: String):
 checks+=1
 if value:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func key(code: int,down: bool):
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
 if code>=KEY_A and code<=KEY_Z:e.unicode=code
 root.push_input(e,true);await process_frame
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame
 var camera=game.get_node_or_null("KeyboardCamera")
 verify(camera!=null,"playable scene installs real-time keyboard camera")
 if camera==null:game.queue_free();await process_frame;print("RESULT %d/%d keyboard camera checks passed" % [checks-failures,checks]);quit(1);return
 camera.set_process(false);root.gui_release_focus()
 game.map_zoom=1.0;game.origin=Vector2(960,540)-Vector2(0,100*game.tile.y)
 var start: Vector2=game.origin
 var cardinal:=0.0
 for entry in [[KEY_W,Vector2.UP],[KEY_UP,Vector2.UP],[KEY_S,Vector2.DOWN],[KEY_DOWN,Vector2.DOWN],[KEY_A,Vector2.LEFT],[KEY_LEFT,Vector2.LEFT],[KEY_D,Vector2.RIGHT],[KEY_RIGHT,Vector2.RIGHT]]:
  game.origin=start;await key(entry[0],true);camera.step(.1);await key(entry[0],false)
  var movement: Vector2=game.origin-start
  verify(movement.dot(-entry[1])>0 and absf(movement.cross(entry[1]))<.001,"screen-space camera direction "+str(entry[0]))
  if cardinal==0:cardinal=movement.length()
  verify(is_equal_approx(movement.length(),60.0),"all movement aliases use 600 screen pixels/sec at zoom 1")
 game.origin=start;await key(KEY_W,true);await key(KEY_D,true);camera.step(.1);await key(KEY_W,false);await key(KEY_D,false)
 verify(is_equal_approx((game.origin-start).length(),cardinal),"diagonal input is normalized")
 game.origin=start;await key(KEY_W,true);await key(KEY_UP,true);camera.step(.1);await key(KEY_W,false);await key(KEY_UP,false)
 verify(is_equal_approx((game.origin-start).length(),cardinal),"W plus Up never doubles axis speed")
 game.origin=start;await key(KEY_A,true);await key(KEY_D,true);camera.step(.1);await key(KEY_A,false);await key(KEY_D,false)
 verify(game.origin.is_equal_approx(start),"opposite movement keys cancel")
 game.origin=start;await key(KEY_SHIFT,true);await key(KEY_W,true);camera.step(.1);await key(KEY_W,false);await key(KEY_SHIFT,false)
 verify(is_equal_approx((game.origin-start).length(),cardinal*2),"Shift doubles speed")
 game.origin=start
 var modified:=InputEventKey.new();modified.keycode=KEY_W;modified.pressed=true;modified.shift_pressed=true;root.push_input(modified,true)
 camera.step(.1);await key(KEY_W,false);await key(KEY_SHIFT,false)
 verify(is_equal_approx((game.origin-start).length(),cardinal*2),"held Shift modifier works even after entering/leaving text input cleared old key state")
 game.map_zoom=.5;game.origin=Vector2(960,540)-Vector2(0,100*game.tile.y)*game.map_zoom;var far_start: Vector2=game.origin
 await key(KEY_D,true);camera.step(.1);await key(KEY_D,false)
 verify(is_equal_approx((game.origin-far_start).length(),cardinal*2),"zooming out speeds screen travel according to inverse zoom")
 game.map_zoom=1;game.origin=start
 game.begin_city_name_edit();await key(KEY_W,true);camera.step(.1);await key(KEY_W,false)
 verify(game.origin.is_equal_approx(start),"actual city-name LineEdit keeps typing without camera movement")
 verify(game.city_name_edit.text=="W","movement key reaches actual text editor instead of being swallowed")
 root.gui_release_focus();await key(KEY_D,true);game.begin_city_name_edit();camera.step(.1);root.gui_release_focus();camera.step(.1);await key(KEY_D,false)
 verify(game.origin.is_equal_approx(start),"entering text input clears previously held movement")
 var edit:=TextEdit.new();game.add_child(edit);edit.grab_focus();await key(KEY_UP,true);camera.step(.1);await key(KEY_UP,false)
 verify(game.origin.is_equal_approx(start),"TextEdit retains cursor arrows without camera movement")
 edit.queue_free();await process_frame;root.gui_release_focus()
 await key(KEY_D,true);game.panning=true;camera.step(.1);await key(KEY_D,false);game.panning=false
 verify(game.origin.is_equal_approx(start),"middle-mouse panning takes precedence over keyboard movement")
 await key(KEY_D,true);root.focus_exited.emit();camera.step(.1);await key(KEY_D,false)
 verify(game.origin.is_equal_approx(start),"focus-loss clear cannot leave a stuck movement key")
 game.city_name_button.grab_focus();await key(KEY_RIGHT,true);camera.step(.1);await key(KEY_RIGHT,false)
 verify(root.gui_get_focus_owner()==game.city_name_button and game.origin.x<start.x,"outside text entry arrow pans without also moving HUD focus")
 root.gui_release_focus();game.origin=start
 game.origin=start;await key(KEY_D,true);camera.step(100);await key(KEY_D,false)
 var center: Vector2=game.world(Vector2(960,540))
 verify(center.x>=-.001 and center.y>=-.001 and center.x<=game.city.width+.001 and center.y<=game.city.height+.001,"large keyboard movement keeps viewport center within map bounds")
 game.origin=start;await key(KEY_D,true);game._process(0);camera.step(.1);await key(KEY_D,false)
 verify(is_equal_approx((game.origin-start).length(),cardinal),"camera remains usable while simulation is paused")
 game.origin=start;camera.set_process(true);await key(KEY_D,true)
 for i in range(5):await process_frame
 await key(KEY_D,false);camera.set_process(false)
 verify(game.paused and game.origin.x<start.x,"actual independent process moves camera during paused simulation")
 game.origin=start;game.city.funds=1000000;verify(game.public_controller.begin("park-garden-2x2"),"facility placement begins for shortcut regression")
 await key(KEY_R,true);await key(KEY_R,false)
 verify(game.public_controller.turns==1 and game.origin.is_equal_approx(start),"R still rotates facility without panning")
 await key(KEY_ESCAPE,true);await key(KEY_ESCAPE,false)
 verify(game.public_controller.asset_id.is_empty() and game.origin.is_equal_approx(start),"ESC still cancels placement without panning")
 game.queue_free();await process_frame
 print("RESULT %d/%d keyboard camera checks passed" % [checks-failures,checks]);quit(1 if failures else 0)
