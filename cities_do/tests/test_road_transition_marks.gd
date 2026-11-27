extends SceneTree
const City=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func linked(lines:Array,start:Vector2,end:Vector2)->bool:
 var visited:Array[Vector2]=[start];var queue:Array[Vector2]=[start]
 while not queue.is_empty():
  var point:Vector2=queue.pop_front()
  if point.distance_to(end)<.001:return true
  for path in lines:
   for i in range(1,path.size()):
    for side in [0,1]:
     var first:Vector2=path[i-1+side];var last:Vector2=path[i-side]
     if first.distance_to(point)<.001 and not visited.any(func(p):return p.distance_to(last)<.001):visited.append(last);queue.append(last)
 return false
func run():
 for spec in [[2,3],[4,5],[6,7],[3,5],[5,7],[7,8],[3,2],[5,3],[8,7]]:
  for major in [1,-1]:
   var city:=City.new(100,100);city.add_road(PackedVector2Array([Vector2(20,40),Vector2(36,40)]),"local",true,spec[0],false,false,major);city.add_road(PackedVector2Array([Vector2(36,40),Vector2(52,40)]),"local",true,spec[1],false,true,major)
   var label:=str(spec)+" major="+str(major);var start:=Vector2(20,40+city.RoadProfile.median_offset(city.roads[0]));var end:=Vector2(52,40+city.RoadProfile.median_offset(city.roads[1]))
   verify(linked(city.road_medians,start,end),label+" actual cached yellow line is connected end to end")
   verify(city.road_crosswalks.is_empty() and city.road_stop_lines.is_empty(),label+" uncontrolled extension invents no zebra or stop lines")
   var surfaces:Array=city.road_asphalt+city.junction_asphalt;var supported:=true
   for line in city.road_lane_marks:
    for p in line:
     if not surfaces.any(func(poly):return Geometry2D.is_point_in_polygon(p,poly)):supported=false
   verify(supported,label+" lane and shoulder transitions stay on actual asphalt")
 print("RESULT %d/%d road transition marking checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
