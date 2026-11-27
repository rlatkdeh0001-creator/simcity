extends SceneTree
const City=preload("res://core/city_model.gd")
const Junctions=preload("res://core/road_junctions.gd")
const Profile=preload("res://core/road_profile.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func hits_polygon(line: PackedVector2Array,polygon: PackedVector2Array) -> bool:
 if Geometry2D.is_point_in_polygon((line[0]+line[-1])/2,polygon):return true
 for i in range(polygon.size()):
  if Geometry2D.segment_intersects_segment(line[0],line[-1],polygon[i],polygon[(i+1)%polygon.size()])!=null:return true
 return false
func near_endpoint(lines: Array,point: Vector2) -> bool:
 for line in lines:
  if line[0].distance_to(point)<.005 or line[-1].distance_to(point)<.005:return true
 return false
func nearby_dash(lines: Array,point: Vector2) -> bool:
 for line in lines:
  if Geometry2D.get_closest_point_to_segment(point,line[0],line[-1]).distance_to(point)<.55:return true
 return false
func run():
 for kind in ["cross","T","rotated","odd"]:
  var city:=City.new(100,100);var centre:=Vector2(50,45);var axis:=Vector2(.8,.6) if kind=="rotated" else Vector2.RIGHT;var normal:=Vector2(-axis.y,axis.x);var lanes:=3 if kind=="odd" else 8
  city.add_road(PackedVector2Array([centre-axis*30,centre+axis*30]),"local",true,lanes)
  city.add_road(PackedVector2Array([centre-normal*25,centre if kind=="T" else centre+normal*25]),"local",true,2)
  verify(city.junctions.size()==1,kind+" fixture has an actual mixed-width intersection")
  var node: Dictionary=city.junctions[0]
  var protected:=true
  for line in city.road_medians+city.road_lane_marks:
   for polygon in city.road_crosswalks+city.road_stop_lines:
    if hits_polygon(line,polygon):protected=false
  verify(protected,kind+" median and lane dashes never cross painted zebra stripes or stop lines")
  for arm in node.arms:
   # Existing zebra geometry: .22 half length, .18 stop gap, .04 stop half width.
   # Leave only .03 cells before its outer edge; never use the max-width render box.
   var end_distance:=Junctions.crosswalk_distance(node,arm)+.22+.18+.04+.03
   var median_end: Vector2=Junctions.sample(arm.points,end_distance)+Vector2(-arm.direction.y,arm.direction.x)*Profile.median_offset(arm)
   verify(near_endpoint(city.road_medians,median_end),kind+" "+str(arm.lanes)+"-lane median reaches the actual stop-line approach edge")
   for offset in Profile.separators(arm):
    var lane_end: Vector2=Junctions.sample(arm.points,end_distance)+Vector2(-arm.direction.y,arm.direction.x)*offset
    verify(nearby_dash(city.road_lane_marks,lane_end),kind+" lane separator continues to the stop line within its existing dash spacing")
  var state_before:=var_to_str(city.roads)
  city._update_zoning_for_road({})
  verify(var_to_str(city.roads)==state_before,kind+" derived approach paint never changes authored road geometry")
 print("RESULT %d/%d approach marking checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
