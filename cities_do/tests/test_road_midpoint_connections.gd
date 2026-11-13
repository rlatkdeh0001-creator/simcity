extends SceneTree
const City=preload("res://core/city_model.gd")
var game
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func settle():
 for i in range(3):await process_frame
func click(point: Vector2):
 var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true);await process_frame
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
func road_tool():
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=KEY_ESCAPE;event.physical_keycode=KEY_ESCAPE;event.pressed=down;root.push_input(event,true);await process_frame
 await click(game.categories[1].get_global_rect().get_center());await settle();await click(game.road_lane_cards[0].get_global_rect().get_center());await settle()
func branch(first: Vector2,last: Vector2,label: String,arms: int) -> bool:
 await road_tool();await click(game.screen(first))
 var motion:=InputEventMouseMotion.new();motion.position=game.screen(last);root.push_input(motion,true);await process_frame
 var result: Dictionary=game.road_drawer.preview();var before: int=game.city.roads.size()
 verify(result.ok,label+" has a green preview: "+result.get("reason",""))
 if not result.ok:return false
 var expected: PackedVector2Array=result.points.duplicate();await click(game.screen(last));await settle()
 verify(game.city.roads.size()==before+1 and game.city.roads[-1].points==expected,label+" actual final mouse click commits the preview unchanged")
 verify((game.city.junctions.size()==1 and game.city.junctions[0].arms.size()==arms) if arms>=3 else game.city.junctions.is_empty(),label+" creates exactly the required T/cross or continuous end connection")
 return true
func run():
 root.size=Vector2i(1280,820);game=load("res://main.tscn").instantiate();game.city=City.new(100,100);game.paused=true;root.add_child(game);current_scene=game;await settle()
 for kind in ["angled_both_sides","cardinal_both_sides","start_extension","end_extension"]:
  game.road_drawer.cancel();game.city=City.new(100,100);game.road_grid_enabled=true;game.map_zoom=1.0;game.origin=Vector2.ZERO;game.origin=Vector2(640,260)-game.screen(Vector2(48,40.5))
  await road_tool();var first:=Vector2(40,40);var last:=Vector2(56,40) if kind=="cardinal_both_sides" else Vector2(56,41)
  await click(game.screen(first));await click(game.screen(last));await settle()
  verify(game.city.roads.size()==1,kind+" builds the roughly 64m host using the actual lane card and world mouse input")
  if game.city.roads.is_empty():continue
  var original: PackedVector2Array=game.city.roads[0].points.duplicate();var axis: Vector2=(original[-1]-original[0]).normalized();var middle: Vector2=(original[0]+original[-1])/2;var normal:=Vector2(-axis.y,axis.x)
  if kind in ["angled_both_sides","cardinal_both_sides"]:
   if await branch(middle,middle-normal*16,kind+" first midpoint 90-degree arm",3):
    var junction: Vector2=game.city.junctions[0].position
    await branch(junction,junction+normal*16,kind+" opposite midpoint 90-degree arm",4)
  else:
   var start: Vector2=original[0] if kind=="start_extension" else original[-1];var direction: Vector2=-axis if kind=="start_extension" else axis
   await branch(start,start+direction*16,kind,0)
  verify(game.city.roads[0].points==original,kind+" preserves the original host geometry")
 game.queue_free();await process_frame
 print("RESULT %d/%d midpoint connection checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
