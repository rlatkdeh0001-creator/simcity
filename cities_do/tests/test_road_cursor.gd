extends SceneTree
const City=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.city=City.new(100,100);game.paused=true;root.add_child(game);await process_frame
 game.road_grid_enabled=false # Free-position cursor/ring contract; quantized contacts are tested separately.
 var drawing=game.road_drawer
 verify(drawing.has_method("cursor_preview"),"road tool exposes its pre-click ground cursor state")
 if drawing.has_method("cursor_preview"):
  game.activate_tool("road");game.pointer=Vector2(50,50)
  var before:=var_to_str(game.city.roads);var disc: Dictionary=drawing.cursor_preview()
  verify(not disc.is_empty() and disc.ok and not disc.snapped and disc.center==game.pointer,"empty ground has a valid green disc at the pending first point")
  verify(is_equal_approx(disc.radius*2,game.city.config.road_width*game.road_lanes/2.0),"ground disc diameter equals the selected road world width")
  game.road_lanes=4;var wider: Dictionary=drawing.cursor_preview()
  verify(is_equal_approx(wider.radius,disc.radius*2),"four-lane selection doubles the cursor footprint")
  game.road_lanes=2
  verify(var_to_str(game.city.roads)==before,"hover cursor never creates a road")
  game.city.add_road(PackedVector2Array([Vector2(10,30),Vector2(30,30)]));game.pointer=Vector2(30.4,30.1)
  var snap: Dictionary=drawing.cursor_preview()
  verify(snap.ok and snap.snapped and snap.center==Vector2(30,30),"blue ring follows the exact existing endpoint snap")
  game.pointer=Vector2(20.4,30.3);snap=drawing.cursor_preview()
  verify(snap.snapped and snap.center.distance_to(Vector2(20.4,30))<.001,"existing road interior contact also has a blue snap ring")
  game.pointer=Vector2(-3,20);verify(not drawing.cursor_preview().ok,"outside-map start is red")
  game.city.add_road(PackedVector2Array([Vector2(40,60),Vector2(70,60)]));verify(game.city.add_building(50,57).ok,"collision fixture uses a genuinely placed building")
  game.pointer=Vector2(51,58);verify(not drawing.cursor_preview().ok,"occupied ground is red")
  game.pointer=Vector2(50,50);drawing.click(game.pointer);verify(drawing.cursor_preview().is_empty(),"first click replaces start disc with the existing road preview")
  var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;drawing.handle_input(escape)
  verify(drawing.cursor_preview().is_empty(),"ESC removes the cursor along with pending construction")
  game.activate_tool("road");verify(not drawing.cursor_preview().is_empty(),"selecting the road card re-arms the start cursor")
  var right:=InputEventMouseButton.new();right.button_index=MOUSE_BUTTON_RIGHT;right.pressed=true;drawing.handle_input(right)
  verify(drawing.cursor_preview().is_empty(),"right-click cancellation removes the cursor")
  for kind in ["straight","curve","free"]:
   drawing.set_kind(kind);verify(not drawing.cursor_preview().is_empty(),kind+" uses the same approved pre-click cursor")
  game.activate_tool("select");verify(drawing.cursor_preview().is_empty(),"other tools never retain the road cursor")
 game.queue_free();await process_frame
 print("RESULT %d/%d road cursor checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
