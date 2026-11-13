extends SceneTree
const City=preload("res://core/city_model.gd")
const Geometry=preload("res://core/road_geometry.gd")
const Profile=preload("res://core/road_profile.gd")
const Junctions=preload("res://core/road_junctions.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func asphalt(city) -> Array[PackedVector2Array]:
 var result: Array[PackedVector2Array]=[]
 for road in city.road_visuals:result.append_array(Geometry.clipped_ribbons(road.points,Profile.asphalt_width(road),Vector2(city.width,city.height),road.flat_start,road.flat_end))
 for junction in city.junctions:result.append(Junctions.patch(junction,true))
 return result
func on_surface(point: Vector2,surfaces: Array) -> bool:
 for shape in surfaces:
  if Geometry2D.is_point_in_polygon(point,shape):return true
 return false
func supported(city) -> bool:
 var surfaces:=asphalt(city)
 for stripe in city.road_crosswalks:
  for p in stripe:
   if not on_surface(p,surfaces):return false
 return true
func run():
 var city:=City.new(100,100);city.add_road(PackedVector2Array([Vector2(10,40),Vector2(90,40)]))
 city.add_road(PackedVector2Array([Vector2(50,40),Vector2(50,40)+Vector2.from_angle(deg_to_rad(20))*4]))
 var outside:=0;var surfaces:=asphalt(city)
 # Reproduce the former main.gd projection, independently of the new bounded renderer.
 for junction in city.junctions:
  for arm in junction.arms:
   var centre: Vector2=junction.position+arm.direction*Junctions.crosswalk_distance(junction,arm)
   if not on_surface(centre,surfaces):outside+=1
 verify(outside>0,"root-cause fixture reproduces a projected zebra centre on grass despite fresh junction topology")
 print("ROOT_CAUSE unbounded tangent projection, not an unrefreshed junction cache; unsupported arms=",outside)
 verify(city.get("road_crosswalks")!=null,"model derives bounded crosswalk paint from current pavement and arm lengths")
 if city.get("road_crosswalks")!=null:
  verify(not city.road_crosswalks.is_empty() and supported(city),"short oblique arm omits unsupported crossings while valid stripes remain on real pavement")
  var branch_id: int=city.roads[-1].parcel_id;city.demolish("road",branch_id)
  verify(city.junctions.is_empty() and city.road_crosswalks.is_empty(),"removing a junction arm clears all crossing paint when the junction disappears")
  city=City.new(100,100);city.add_road(PackedVector2Array([Vector2(10,40),Vector2(90,40)]));city.add_road(PackedVector2Array([Vector2(50,40),Vector2(50,60)]))
  verify(not city.road_crosswalks.is_empty() and supported(city),"normal T junction retains supported crosswalks")
  var cut: Dictionary=city.demolish_road_unit(city.roads[-1].parcel_id,Vector2(50,41.3))
  verify(cut.ok and city.junctions.size()==1 and supported(city),"partial demolition rebuilds stripe support for the surviving short junction stub")
  var absent:=true
  for stripe in city.road_crosswalks:
   for p in stripe:
    if p.x>49 and p.x<51 and p.y>41.001 and p.y<41.999:absent=false
  verify(absent,"no crossing stripe remains in the newly demolished four-metre gap")
  city.demolish("road",1)
  verify(city.junctions.is_empty() and city.road_crosswalks.is_empty(),"removing the final stub also clears derived markings after a split")
 print("RESULT %d/%d crosswalk support checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
