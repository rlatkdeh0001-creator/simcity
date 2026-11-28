extends SceneTree
const City=preload("res://core/city_model.gd")
# Approved 14m chainage boundary: docs/design/ROAD_DRAWING_KO.md:39,48.
const MIN_GAP_CELLS:=3.5
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
 var points:=PackedVector2Array([Vector2(40+13.99/4,40),Vector2(40+13.99/4,60)])
 var preview:=propose(city,points)
 verify(not preview.ok and "14m" in preview.get("reason","") and var_to_bytes(city.roads)==before,"T preview rejects 13.99m across a straight authored seam without mutation")
 var committed:=propose(city,points,true)
 verify(not committed.ok and committed.reason==preview.reason and var_to_bytes(city.roads)==before,"13.99m confirmation agrees with preview and preserves every original road")
 city=City.new(100,100)
 city.add_road(PackedVector2Array([Vector2(10,40),Vector2(40,40)]))
 city.add_road(PackedVector2Array([Vector2(40,40),Vector2(40,80)]))
 points=PackedVector2Array([Vector2(40,43.49),Vector2(60,43.49)])
 preview=propose(city,points)
 verify(not preview.ok and "14m" in preview.get("reason",""),"T below 14m beside a bent two-arm corner is rejected by the same spacing rule")
 for gap in [1.0,3.0,13.99/4,3.5,4.0,5.0]:
  for reverse in [false,true]:
   city=split_host();before=var_to_bytes(city.roads)
   points=PackedVector2Array([Vector2(40+gap,40),Vector2(40+gap,60)])
   if reverse:points.reverse()
   preview=propose(city,points)
   verify(preview.ok==(gap>=MIN_GAP_CELLS) and var_to_bytes(city.roads)==before,"T start/end preview at %.2fm reverse=%s is pure and follows the 14m boundary"%[gap*4,reverse])
   committed=propose(city,points,true)
   verify((committed.ok and city.junctions.size()==2 and var_to_bytes(city.roads.slice(0,3))==before) if gap>=MIN_GAP_CELLS else (not committed.ok and var_to_bytes(city.roads)==before),"T start/end confirmation at %.2fm reverse=%s matches preview and preserves existing roads"%[gap*4,reverse])
 for gap in [3.0,13.99/4,3.5,4.0]:
  city=split_host();points=PackedVector2Array([Vector2(40+gap,20),Vector2(40+gap,60)])
  verify(propose(city,points).ok==(gap>=MIN_GAP_CELLS),"through crossing across an authored seam follows spacing at "+str(gap))
  city=City.new(100,100)
  city.add_road(PackedVector2Array([Vector2(10,40),Vector2(40+gap,40)]))
  city.add_road(PackedVector2Array([Vector2(40,40),Vector2(40,20)]))
  points=PackedVector2Array([Vector2(40+gap,40),Vector2(40+gap,60)])
  verify(propose(city,points).ok==(gap>=MIN_GAP_CELLS),"angled road-end connection follows spacing at "+str(gap))
  city=City.new(100,100)
  city.add_road(PackedVector2Array([Vector2(10,40),Vector2(40,40)]))
  city.add_road(PackedVector2Array([Vector2(40,40),Vector2(40,80)]))
  points=PackedVector2Array([Vector2(40,40+gap),Vector2(60,40+gap)])
  verify(propose(city,points).ok==(gap>=MIN_GAP_CELLS),"bent two-arm corner boundary follows spacing at "+str(gap))
 # A removed T arm must not remove the remaining L's spacing protection.
 city=City.new(100,100)
 city.add_road(PackedVector2Array([Vector2(10,40),Vector2(40,40)]))
 city.add_road(PackedVector2Array([Vector2(40,40),Vector2(40,80)]))
 city.add_road(PackedVector2Array([Vector2(40,40),Vector2(60,40)]))
 var removed:Dictionary=city.demolish_road_selection(city.road_demolition_selection(2,Vector2(50,40)))
 verify(removed.ok and city.junctions.is_empty(),"removing a T arm leaves the authored two-arm corner")
 before=var_to_bytes(city.roads)
 var below:=propose(city,PackedVector2Array([Vector2(40,40+13.99/4),Vector2(60,40+13.99/4)]),true)
 verify(not below.ok and "14m" in below.reason and var_to_bytes(city.roads)==before,"post-demolition corner rejects 13.99m without moving survivors")
 var exact:=propose(city,PackedVector2Array([Vector2(40,43.5),Vector2(60,43.5)]),true)
 verify(exact.ok and var_to_bytes(city.roads.slice(0,2))==before,"post-demolition corner permits exactly 14m and keeps existing roads")
 # Measure along the sampled centreline, not the three-cell Euclidean shortcut.
 city=City.new(100,100)
 city.add_road(PackedVector2Array([Vector2(40,40),Vector2(44,40),Vector2(44,43),Vector2(40,43)]))
 city.add_road(PackedVector2Array([Vector2(40,20),Vector2(40,40)]))
 verify(propose(city,PackedVector2Array([Vector2(40,43),Vector2(40,60)])).ok,"eleven-cell centreline gap remains allowed despite three-cell Euclidean distance")
 # Stored legacy short gaps are not retroactively deleted or used to block remote work.
 city=split_host();var legacy:Dictionary=city.add_road(PackedVector2Array([Vector2(43.25,40),Vector2(43.25,60)]))
 verify(legacy.ok and city.junctions.size()==2,"legacy fixture really has two junctions 13m apart")
 before=var_to_bytes(city.roads)
 verify(propose(city,PackedVector2Array([Vector2(10,85),Vector2(90,85)])).ok and var_to_bytes(city.roads)==before,"unrelated construction preserves legacy short-gap records")
 print("RESULT %d/%d junction spacing checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
