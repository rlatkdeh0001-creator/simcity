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
 actual.SetParallelWorkers(2)
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
 # Public Inspect dictionaries must not let a caller poison the private target cache.
 actual.Inspect(1).factors.goods=-1000.0;reference.Inspect(1).factors.goods=-1000.0
 check(same(actual.Preview(1),reference.Preview(1)),"public factor mutation cannot alter a fresh preview")
 for tick in range(75):check(same(actual.Tick(48,PackedInt64Array()),reference.Tick(48,PackedInt64Array())),"bucket restores factors after public mutation "+str(tick))
 # Stable cached preview must not repeat native factor evaluation or source scanning.
 var before:Dictionary=actual.CacheStats()
 for b in buildings:actual.Preview(b.id)
 var after:Dictionary=actual.CacheStats()
 check(before==after,"unchanged cached target inputs perform no extra scoring/source scans")
 for seed_value in [42,20261114]:
  rng.seed=seed_value
  var left=load("res://simulation/HappinessCore.cs").new();var right=load("res://tests/reference/HappinessReferenceCore.cs").new()
  left.SetParallelWorkers(2)
  var seeded:Array=[]
  for i in range(36):
   var b:=building(i+1,Vector2(rng.randf_range(-800,800),rng.randf_range(-800,800)),"industrial" if i%5==0 else "residential");b.level=rng.randi_range(1,5);seeded.append(b)
  for core in [left,right]:core.Configure(config);core.SetWorld(seeded,facilities,roads)
  for tick in range(5400):
   var supply:=PackedInt64Array()
   if tick%100==0:supply=PackedInt64Array([1,1,0 if tick%200==0 else 1])
   check(same(left.Tick(48,supply),right.Tick(48,supply)),"three-day exact seed=%d tick=%d"%[seed_value,tick])
  check(same(left.CityHappiness(),right.CityHappiness()),"three-day weighted average seed="+str(seed_value))
 print("RESULT ",count-failed," passed ",failed," failed");quit(1 if failed else 0)
