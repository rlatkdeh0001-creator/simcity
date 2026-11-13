extends SceneTree
const City=preload("res://core/city_model.gd")
const Geometry=preload("res://core/road_geometry.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func run():
 for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2(.8,.6)]:
  for lanes in [2,3,8]:
   var city:=City.new(100,100);var first:=Vector2(40,40);var last: Vector2=first+direction*20
   city.add_road(PackedVector2Array([first,last]),"local",true,lanes)
   var visual: Dictionary=city.road_visuals[0];var perpendicular:=true;var ends:=0
   for shape in Geometry.ribbons(visual.points,visual.width,visual.flat_start,visual.flat_end):
    for p in shape:
     var progress: float=(p-first).dot(direction)
     if progress<-.001 or progress>20.001:perpendicular=false
     if absf(progress)<.001 or absf(progress-20)<.001:ends+=1
   verify(visual.flat_start and visual.flat_end,"both unconnected ends request flat pavement caps "+str([direction,lanes]))
   verify(perpendicular and ends>=4,"pavement terminates exactly on planes perpendicular to the road, without pointed or rounded protrusion")
 var city:=City.new(100,100);city.add_road(PackedVector2Array([Vector2(20,30),Vector2(40,30)]));city.add_road(PackedVector2Array([Vector2(40,30),Vector2(40,50)]))
 verify(city.road_visuals.size()==1 and city.road_visuals[0].flat_start and city.road_visuals[0].flat_end,"render-only joined chain keeps its smooth connection and flat free ends")
 print("RESULT %d/%d flat road cap checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
