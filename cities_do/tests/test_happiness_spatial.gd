extends SceneTree
var count:=0
var failed:=0
func check(value:bool,message:String):
 count+=1
 if not value:failed+=1;push_error(message)
func _initialize():run.call_deferred()
func building(id:int,point:Vector2,zone:String="residential")->Dictionary:
 return {"id":id,"road":0,"position":point,"polygon":PackedVector2Array(),"zone":zone,"level":1,"power":true,"water":true,"occupants":4,"eligible":4,"employed":4}
func facility(id:int,point:Vector2,kind:String)->Dictionary:
 return {"id":id,"road":0,"position":point,"polygon":PackedVector2Array([point+Vector2(-8,-8),point+Vector2(8,-8),point+Vector2(8,8),point+Vector2(-8,8)]),"kind":kind,"capacity":15000}
func same(a:Variant,b:Variant)->bool:
 if typeof(a)!=typeof(b):return false
 if a is Dictionary:
  if a.size()!=b.size():return false
  for k in a:
   if not b.has(k) or not same(a[k],b[k]):return false
  return true
 if a is Array:
  if a.size()!=b.size():return false
  for i in range(a.size()):
   if not same(a[i],b[i]):return false
  return true
 return a==b
func run():
 var source:=FileAccess.get_file_as_string("res://simulation/HappinessCore.World.cs")
 check(source.contains("IndexSpatial()"),"production world must build spatial candidate indices")
 var actual=load("res://simulation/HappinessCore.cs").new();var reference=load("res://tests/reference/HappinessReferenceCore.cs").new()
 var buildings:Array=[];var facilities:Array=[]
 var rng:=RandomNumberGenerator.new();rng.seed=20261116
 for i in range(120):
  var p:=Vector2(rng.randf_range(-1400,1400),rng.randf_range(-1400,1400))
  var b:=building(i+1,p,"industrial" if i%4==0 else "residential");b.level=i%5+1;buildings.append(b)
 for i in range(12):facilities.append(facility(1000+i,Vector2(rng.randf_range(-1200,1200),rng.randf_range(-1200,1200)),["park","health","police","fire","education","pollution"][i%6]))
 # Centres are deliberately distant while their road anchors coincide. Do not cull by lot centres.
 buildings.append(building(751,Vector2(0,12000)));facilities.append(facility(2000,Vector2(0,-12000),"park"))
 var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://core/happiness_config.json"))
 var roads:=PackedFloat64Array([0,-2000,0,2000,0])
 for core in [actual,reference]:core.Configure(config);core.SetWorld(buildings,facilities,roads)
 for tick in range(160):
  var seconds:float=86400 if tick in [76,153] else 48
  check(same(actual.Tick(seconds,PackedInt64Array()),reference.Tick(seconds,PackedInt64Array())),"reference tick/update/bucket output exact at %d"%tick)
 for b in buildings:check(same(actual.Preview(b.id),reference.Preview(b.id)),"spatial result exact for building "+str(b.id))
 # Edit topology, source, park polygon, population fixture, level, power, removal and insertion.
 buildings[1].position+=Vector2(600,-900);buildings[2].employed=0;buildings[3].level=5;buildings[4].power=false;buildings.remove_at(6)
 facilities[0].polygon=PackedVector2Array([Vector2(-1500,-1500),Vector2(1500,-1500),Vector2(1500,1500),Vector2(-1500,1500)])
 facilities.remove_at(5);buildings.append(building(9999,Vector2(-601,-601)))
 roads=PackedFloat64Array([0,-2000,0,0,0,0,0,0,2000,0,1,0,-1000,0,1000])
 for core in [actual,reference]:core.SetWorld(buildings,facilities,roads)
 for tick in range(80):check(same(actual.Tick(48,PackedInt64Array()),reference.Tick(48,PackedInt64Array())),"changed world exact at "+str(tick))
 print("RESULT ",count-failed," passed ",failed," failed");quit(1 if failed else 0)
