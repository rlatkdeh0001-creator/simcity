extends SceneTree
const City=preload("res://core/city_model.gd")
const Paths=preload("res://core/road_junctions.gd")
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
 var drawing=game.road_drawer
 verify(drawing.has_method("measurements"),"road preview exposes approved length and connection-angle annotations")
 if drawing.has_method("measurements"):
  game.activate_tool("road");verify(drawing.measurements().is_empty(),"no numeric annotation before the first click")
  game.city.add_road(PackedVector2Array([Vector2(10,30),Vector2(30,30)]));drawing.click(Vector2(30,30));game.pointer=Vector2(30,18)
  var m: Dictionary=drawing.measurements()
  verify(m.length_text=="48 m" and is_equal_approx(m.length_m,48),"length label reflects the actual quantized forty-eight-metre road")
  verify(m.midpoint==Vector2(30,24),"length box anchors above the centreline arc midpoint")
  verify(m.angles.size()==1 and m.angles[0].text=="90°" and is_equal_approx(m.angles[0].degrees,90),"right-angle connection has a ninety-degree arc and numeric box")
  game.pointer=Vector2(43,42);m=drawing.measurements()
  verify(m.angles.size()==1 and not is_equal_approx(m.angles[0].degrees,90),"oblique connections always show their actual angle rather than hiding outside snap tolerance")
  drawing.cancel();drawing.set_kind("straight");drawing.click(Vector2(50,30));game.pointer=Vector2(30,30);m=drawing.measurements()
  verify(m.angles.size()==1 and m.angles[0].center==Vector2(30,30) and m.angles[0].text=="180°","arrival endpoint also displays the connected straight angle")
  drawing.cancel();drawing.set_kind("straight");drawing.click(Vector2(60,60));game.pointer=Vector2(72,60);m=drawing.measurements()
  verify(m.angles.is_empty() and m.length_text=="48 m","isolated construction keeps only its length box")
  for kind in ["curve","free"]:
   drawing.cancel();drawing.set_kind(kind);drawing.click(Vector2(30,30))
   if kind=="curve":drawing.click(Vector2(40,40))
   game.pointer=Vector2(48,43);var p: Dictionary=drawing.preview();m=drawing.measurements(p)
   verify(is_equal_approx(m.length_m,Paths.length_of(p.points)*4) and m.midpoint.distance_to(Paths.sample(p.points,Paths.length_of(p.points)/2))<.001,kind+" uses the entire sampled arc length and its true half-length point")
   verify(m.angles.size()==1,kind+" preserves its connection annotation")
  drawing.cancel();verify(drawing.measurements().is_empty(),"cancel removes all measurement annotations")
 game.queue_free();await process_frame
 print("RESULT %d/%d road measurement checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
