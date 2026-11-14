extends SceneTree
const City=preload("res://core/city_model.gd")
const Construction=preload("res://core/road_construction.gd")
const Paths=preload("res://core/road_junctions.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func split_host():
 var city=City.new(100,100)
 city.add_road(PackedVector2Array([Vector2(10,40),Vector2(41,40)]))
 city.add_road(PackedVector2Array([Vector2(41,40),Vector2(80,40)]))
 city.add_road(PackedVector2Array([Vector2(40,40),Vector2(40,20)]))
 return city
func propose(city,points:PackedVector2Array,commit:bool=false)->Dictionary:
 return city.add_road(points,"local",commit,2,false,true)
func run():
 var city=split_host();var before:=var_to_bytes(city.roads)
 var points:=PackedVector2Array([Vector2(43.5,40),Vector2(43.5,60)])
 var preview:=propose(city,points)
 verify(not preview.ok and "4칸" in preview.get("reason",""),"T preview rejects a 3.5-cell gap across a straight authored record boundary")
 var committed:=propose(city,points,true)
 verify(not committed.ok and var_to_bytes(city.roads)==before,"rejected T commit preserves every original road")
 city=City.new(100,100)
 city.add_road(PackedVector2Array([Vector2(10,40),Vector2(40,40)]))
 city.add_road(PackedVector2Array([Vector2(40,40),Vector2(40,80)]))
 points=PackedVector2Array([Vector2(40,43.5),Vector2(60,43.5)])
 preview=propose(city,points)
 verify(not preview.ok and "4칸" in preview.get("reason",""),"T beside a bent two-arm corner is rejected by the same spacing rule")
 for gap in [1.0,3.0,3.5,4.0,5.0]:
  for reverse in [false,true]:
   city=split_host();before=var_to_bytes(city.roads)
   points=PackedVector2Array([Vector2(40+gap,40),Vector2(40+gap,60)])
   if reverse:points.reverse()
   preview=propose(city,points)
   verify(preview.ok==(gap>=4) and var_to_bytes(city.roads)==before,"T start/end preview at %s cells reverse=%s is pure and follows four-cell boundary"%[gap,reverse])
   committed=propose(city,points,true)
   verify((committed.ok and city.junctions.size()==2) if gap>=4 else (not committed.ok and var_to_bytes(city.roads)==before),"T start/end confirmation at %s cells reverse=%s matches preview"%[gap,reverse])
 for gap in [3.0,3.5,4.0]:
  city=split_host();points=PackedVector2Array([Vector2(40+gap,20),Vector2(40+gap,60)])
  verify(propose(city,points).ok==(gap>=4),"through crossing across an authored seam follows spacing at "+str(gap))
  city=City.new(100,100)
  city.add_road(PackedVector2Array([Vector2(10,40),Vector2(40+gap,40)]))
  city.add_road(PackedVector2Array([Vector2(40,40),Vector2(40,20)]))
  points=PackedVector2Array([Vector2(40+gap,40),Vector2(40+gap,60)])
  verify(propose(city,points).ok==(gap>=4),"angled road-end connection follows spacing at "+str(gap))
  city=City.new(100,100)
  city.add_road(PackedVector2Array([Vector2(10,40),Vector2(40,40)]))
  city.add_road(PackedVector2Array([Vector2(40,40),Vector2(40,80)]))
  points=PackedVector2Array([Vector2(40,40+gap),Vector2(60,40+gap)])
  verify(propose(city,points).ok==(gap>=4),"bent two-arm corner boundary follows spacing at "+str(gap))
 # A removed T arm must not remove the remaining L's spacing protection.
 city=City.new(100,100)
 city.add_road(PackedVector2Array([Vector2(10,40),Vector2(40,40)]))
 city.add_road(PackedVector2Array([Vector2(40,40),Vector2(40,80)]))
 city.add_road(PackedVector2Array([Vector2(40,40),Vector2(60,40)]))
 var removed:Dictionary=city.demolish_road_selection(city.road_demolition_selection(2,Vector2(50,40)))
 verify(removed.ok and city.junctions.is_empty(),"removing a T arm leaves the authored two-arm corner")
 verify(not propose(city,PackedVector2Array([Vector2(40,43.5),Vector2(60,43.5)])).ok,"post-demolition corner retains the same four-cell guard")
 # Measure along the sampled centreline, not the three-cell Euclidean shortcut.
 city=City.new(100,100)
 city.add_road(PackedVector2Array([Vector2(40,40),Vector2(44,40),Vector2(44,43),Vector2(40,43)]))
 city.add_road(PackedVector2Array([Vector2(40,20),Vector2(40,40)]))
 verify(propose(city,PackedVector2Array([Vector2(40,43),Vector2(40,60)])).ok,"eleven-cell centreline gap remains allowed despite three-cell Euclidean distance")
 # Stored legacy short gaps are not retroactively deleted or used to block remote work.
 city=split_host();city.add_road(PackedVector2Array([Vector2(43.5,40),Vector2(43.5,60)]))
 before=var_to_bytes(city.roads)
 verify(propose(city,PackedVector2Array([Vector2(10,85),Vector2(90,85)])).ok and var_to_bytes(city.roads)==before,"unrelated construction preserves legacy short-gap records")
 print("RESULT %d/%d junction spacing checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
