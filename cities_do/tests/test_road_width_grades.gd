extends SceneTree
const City=preload("res://core/city_model.gd")
const Net=preload("res://core/traffic_network.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func run():
 for spec in [[2,3],[3,3],[4,5],[5,5],[6,7],[7,7],[8,8]]:
  var city:=City.new(100,100);var added:=city.add_road(PackedVector2Array([Vector2(20,40),Vector2(40,40)]),"local",true,spec[0])
  verify(added.ok,"approved lane count "+str(spec[0]))
  if not added.ok:continue
  var road:Dictionary=city.roads[0]
  verify(is_equal_approx(road.width,float(spec[1])),"lane count "+str(spec[0])+" uses approved pavement width grade")
  var solid:=city.road_lane_marks.filter(func(line):return line[0].distance_to(line[-1])>2)
  verify(solid.size()==(2 if spec[0] in [2,4,6] else 0),"only even non-eight roads have two continuous shoulder edges")
  for line in solid:
   verify(absf(line[0].y-40)<city.RoadProfile.asphalt_width(road)/2,"shoulder edge stays within asphalt")
  var net:=Net.new();verify(net.build(city.roads) and net.lanes.size()==spec[0],"shoulders add no simulated traffic lanes")
  var clear:=true
  for parcel in city.zoning_grid.parcels.values():
   for point in city.Parcels.polygon(parcel.frame,parcel.u,parcel.v,1):clear=clear and absf(point.y-40)>=road.width/2-.0005
  verify(clear and city.zoning_grid.count()>0,"frontage uses new whole pavement footprint")
 var restored:=City.new(100,100);var points:=PackedVector2Array([Vector2(20,40),Vector2(40,40)])
 restored.roads.assign([{"points":points,"kind":"local","lanes":2,"width":2.0,"major_side":1,"parcel_id":17}]);restored.next_road_id=18;restored._update_zoning_for_road({})
 verify(restored.roads.size()==1 and restored.roads[0].parcel_id==17 and restored.roads[0].points==points and restored.roads[0].width==3,"legacy load recomputes width without deleting or moving road IDs/points")
 for count in [2,4]:
  var city:=City.new(100,100);verify(city.add_road(points,"highway",true,count).ok and city.roads[0].width==count,"highway footprint remains unchanged")
 print("RESULT %d/%d road width grade checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
