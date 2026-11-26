extends SceneTree
## Untimed equality by default. --baseline=<UTF-8 pinned road_height.gd> compares
## every support decision/result; --support-benchmark additionally times supports().
const Height=preload("res://core/road_height.gd")
const SEED:=20261126
const LOOPS:=2
const SAMPLES:=9
class Corridors:
 var roads:Array=[]
 var transit_routes:Array=[]
var checks:=0
var failures:=0

func _initialize():
 run.call_deferred()

func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;printerr("FAIL ",label)

func fixture()->Dictionary:
 var rng:=RandomNumberGenerator.new();rng.seed=SEED
 var city:=Corridors.new()
 for i in range(320):
  var start:=Vector2(rng.randf_range(3,360),rng.randf_range(110,380))
  var points:=PackedVector2Array([start])
  for j in range(5):points.append(points[-1]+Vector2(rng.randf_range(3,11),rng.randf_range(-1,1)))
  var r:={"points":points,"width":float(3+i%6),"id":i+1,"kind":"rail" if i%4==0 else "metro" if i%4==1 else "local"}
  if i%3==0:r.heights_m=PackedFloat64Array([0,5,10,15,20,20])
  if r.kind=="local":city.roads.append(r)
  else:city.transit_routes.append(r)
 for i in range(9):
  var x:=26.0+i*20.0+rng.randf_range(-1,1)
  var path:=PackedVector2Array([Vector2(x,38),Vector2(x+1,62),Vector2(x,82)])
  city.roads.append({"points":path,"width":3.0,"heights_m":PackedFloat64Array([0,5,10])})
  city.transit_routes.append({"id":400+i,"kind":"rail","points":PackedVector2Array([Vector2(x+6,30),Vector2(x+6,50)]),"width":1.9})
 var simple:={"points":PackedVector2Array([Vector2(10,45),Vector2(50,45.25),Vector2(100,45.5),Vector2(190,45)]),"width":3.0,"heights_m":PackedFloat64Array([5,10,15,15])}
 var wide:={"points":PackedVector2Array([Vector2(10,74),Vector2(64,76),Vector2(110,72),Vector2(156,70),Vector2(194,74)]),"width":7.0,"heights_m":PackedFloat64Array([15,15,10,5,5])}
 var obstructed:={"points":PackedVector2Array([Vector2(10,92),Vector2(170,92)]),"width":3.0,"heights_m":PackedFloat64Array([10,10])}
 city.roads.append({"points":PackedVector2Array([Vector2(8,92),Vector2(80,92)]),"width":3.0})
 return {"city":city,"candidates":[simple,wide,obstructed]}

func plans(method:Callable,data:Dictionary)->Array:
 var result:Array=[]
 for candidate:Dictionary in data.candidates:result.append(method.call(data.city,candidate))
 return result

func timed(method:Callable,data:Dictionary)->int:
 var start:=Time.get_ticks_usec()
 for i in range(LOOPS):plans(method,data)
 return Time.get_ticks_usec()-start

func run():
 var baseline_file:=""
 var bench:=false
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--baseline="):baseline_file=arg.trim_prefix("--baseline=")
  if arg=="--support-benchmark":bench=true
 var data:=fixture()
 var actual:=plans(Height.supports,data)
 check(actual[0].ok and actual[0].piers.size()>12,"narrow road: support runs span the crossing field")
 check(actual[1].ok and actual[1].piers.size()>12 and actual[1].piers.all(func(p):return p.positions.size()==2),"wide road: both shaft positions survive")
 check(not actual[2].ok and actual[2].piers.is_empty(),"long interior obstruction still refuses a support run")
 var mutable:=Corridors.new()
 var candidate:Dictionary=data.candidates[0]
 var first:Dictionary=Height.supports(mutable,candidate)
 mutable.roads.append({"points":candidate.points,"width":3.0})
 check(first.ok and not Height.supports(mutable,candidate).ok,"a newly added road invalidates the next invocation")
 mutable.roads.clear()
 check(first==Height.supports(mutable,candidate),"removal restores the exact original pier plan")
 if not baseline_file.is_empty():
  var source:=FileAccess.get_file_as_string(baseline_file)
  var original:=GDScript.new();original.source_code=source
  var loaded:=not source.is_empty() and original.reload()==OK
  check(loaded,"the frozen baseline compiles")
  if loaded:
   check(plans(original.supports,data)==actual,"all three pier plans match the frozen baseline exactly")
   var compared:=0;var mismatch:=0
   for item:Dictionary in data.candidates:
    var length:=Height.length_cells(item.points)
    var candidates:=Height.support_candidates(data.city,item)
    for i in range(0,floori(length*4)+1):
     var d:=i*.25
     if Height.support_clear(data.city,item,d,candidates)!=original.support_clear(data.city,item,d):mismatch+=1
     compared+=1
   check(mismatch==0,"all %d individual quarter-cell support queries match the frozen baseline"%compared)
   if bench and failures==0:
    plans(original.supports,data);plans(Height.supports,data)
    var before:Array[int]=[];var after:Array[int]=[]
    for i in range(SAMPLES):
     if i%2==0:before.append(timed(original.supports,data));after.append(timed(Height.supports,data))
     else:after.append(timed(Height.supports,data));before.append(timed(original.supports,data))
    print("SUPPORT_BENCHMARK ",JSON.stringify({"seed":SEED,"roads":data.city.roads.size(),"rail_metro":data.city.transit_routes.size(),"plans_per_sample":LOOPS*data.candidates.size(),"before_usec":before,"after_usec":after}))
 elif bench:check(false,"benchmark requires a pinned baseline")
 print("SECOND_FIX_SUPPORTS checks=%d failed=%d"%[checks,failures])
 quit(1 if failures else 0)
