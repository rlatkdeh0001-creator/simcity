extends SceneTree
const City=preload("res://core/city_model.gd")
const Parcels=preload("res://core/road_parcels.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func run():
 for kind in ["T","cross","rotated","transition","oblique"]:
  var city:=City.new(100,100);var centre:=Vector2(50,45);var axis:=Vector2(.8,.6) if kind=="rotated" else Vector2.RIGHT;var normal:=Vector2(-axis.y,axis.x)
  city.add_road(PackedVector2Array([centre,centre+axis*30]),"local",true,8)
  city.add_road(PackedVector2Array([centre-axis*30,centre]),"local",true,2)
  var branch:=Vector2.from_angle(deg_to_rad(20)) if kind=="oblique" else normal
  if kind!="transition":city.add_road(PackedVector2Array([centre-branch*25,centre+branch*25 if kind in ["cross","oblique"] else centre]),"local",true,2)
  verify(city.get("intersection_regions")!=null,kind+" derives a common intersection exclusion region")
  if city.get("intersection_regions")==null:continue
  var nodes: Array=(city.junctions+city.road_joins).filter(func(n):return n.has("box"))
  verify(nodes.size()==1 and city.intersection_regions.size()==1,kind+" has one max-width box including mixed-width uncontrolled transitions")
  if nodes.is_empty():continue
  var node: Dictionary=nodes[0];var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF)
  for p in node.box:
   var local:=Vector2((p-centre).dot(axis),(p-centre).dot(normal));low=low.min(local);high=high.max(local)
  verify(low.distance_to(Vector2(-4,-4))<.002 and high.distance_to(Vector2(4,4))<.002,kind+" box uses the widest eight-cell road, not separate arm widths")
  verify(node.box.size()>16,kind+" uses continuous rounded outer curb corners")
  var surfaces_clear:=true
  for polygon in city.road_pavement+city.road_asphalt:
   if Parcels.overlap(polygon,node.box):surfaces_clear=false
  verify(surfaces_clear,kind+" individual road pavement and sidewalks stop outside the box")
  var lines_clear:=true
  for line in city.road_medians+city.road_lane_marks:
   if Geometry2D.is_point_in_polygon((line[0]+line[-1])/2,node.box):lines_clear=false
  verify(lines_clear,kind+" lane separators and medians end at the common box boundary")
  var markings_clear:=true
  for polygon in city.road_crosswalks+city.road_stop_lines:
   if Parcels.overlap(polygon,node.box):markings_clear=false
  verify(markings_clear,kind+" crosswalks and stop lines never appear inside the box")
  if kind=="oblique":
   var no_floating_fragments:=true
   for stripe in city.road_crosswalks:
    for p in stripe:
     if p.x>centre.x+4 and absf(p.y-centre.y)<3.5:no_floating_fragments=false
   verify(no_floating_fragments,"oblique narrow-arm zebra never floats on the overlapping eight-lane carriageway beyond the box")
  var uniform:=true
  for x in [-2.5,0,2.5]:
   for y in [-2.5,0,2.5]:uniform=uniform and Geometry2D.is_point_in_polygon(centre+axis*x+normal*y,node.asphalt)
  verify(uniform,kind+" central intersection is one solid asphalt region without sidewalk islands")
  verify(Geometry2D.is_point_in_polygon(centre-axis*3.55+normal*.80,node.asphalt),kind+" narrow-arm curb entry has a rounded concave fillet rather than a sharp corner")
  if kind=="transition":verify(city.road_crosswalks.is_empty() and city.road_stop_lines.is_empty(),"two-arm lane-count transition remains uncontrolled and has no invented zebra crossings")
  else:
   verify(not city.road_crosswalks.is_empty() and not city.road_stop_lines.is_empty(),kind+" supported approach boundaries retain both crossing stripes and incoming stop lines")
   for arm in node.arms:verify(city.RoadJunctions.crosswalk_distance(node,arm)>4,kind+" approach crossing is at its box edge rather than the two-lane edge")
 print("RESULT %d/%d junction box checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
