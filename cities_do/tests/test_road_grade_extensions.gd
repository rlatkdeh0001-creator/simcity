extends SceneTree
const City=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func grade(count:int)->int:return 0 if count in [2,3] else (1 if count in [4,5] else (2 if count in [6,7] else 3))
func run():
 for from in [2,3,4,5,6,7,8]:
  for to in [2,3,4,5,6,7,8]:
   var city:=City.new(100,100);city.add_road(PackedVector2Array([Vector2(20,40),Vector2(36,40)]),"local",true,from)
   var old:=var_to_str(city.roads);var points:=PackedVector2Array([Vector2(36,40),Vector2(52,40)]);var allowed:=absi(grade(from)-grade(to))<=1;var label:="%d to %d"%[from,to]
   var preview:=city.add_road(points,"local",false,to,false,true)
   verify(preview.ok==allowed and var_to_str(city.roads)==old,label+" shared grade policy preview is nonmutating")
   var commit:=city.add_road(points,"local",true,to,false,true)
   verify(commit.ok==allowed and (city.roads.size()==2 if allowed else var_to_str(city.roads)==old),label+" commits only equal or adjacent grades")
   if allowed and grade(from)!=grade(to) and commit.ok:
    var join:Dictionary=city.road_joins[0];var slope:=false
    for i in range(join.footprint.size()):
     var delta:Vector2=join.footprint[(i+1)%join.footprint.size()]-join.footprint[i];slope=slope or (absf(delta.x)>.01 and absf(delta.y)>.01)
    verify(join.get("taper",false) and join.footprint.size()==4 and slope and city.junctions.is_empty(),label+" pavement uses a short sloped uncontrolled trapezoid, not a step or box")
 for pair in [[2,8],[4,8],[8,2],[8,4]]:
  var city:=City.new(100,100);city.add_road(PackedVector2Array([Vector2(20,40),Vector2(52,40)]),"local",true,pair[0])
  verify(city.add_road(PackedVector2Array([Vector2(36,40),Vector2(36,56)]),"local",true,pair[1],false,true).ok and city.junctions.size()==1,"nonadjacent grades still allow actual T crossings "+str(pair))
 for to in [6,8]:
  var city:=City.new(100,100);city.add_road(PackedVector2Array([Vector2(20,40),Vector2(36,40)]),"local",true,2);city.add_road(PackedVector2Array([Vector2(36,40),Vector2(36,24)]),"local",true,2)
  verify(city.add_road(PackedVector2Array([Vector2(36,40),Vector2(52,40)]),"local",true,to,false,true).ok and city.junctions.size()==1,"real three-arm junction is not misclassified as a forbidden straight grade jump to "+str(to))
 print("RESULT %d/%d road grade extension checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
