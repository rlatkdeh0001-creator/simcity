extends SceneTree
var passed:=0
var failed:=0
func check(ok:bool,label:String):
 if ok:passed+=1;print("PASS "+label)
 else:failed+=1;push_error("FAIL "+label)
func _initialize():run.call_deferred()
func run():
 check(ResourceLoader.exists("res://simulation/HappinessCore.cs"),"managed happiness calculator exists")
 if failed:quit(1);return
 var core=load("res://simulation/HappinessCore.cs").new()
 core.Configure({"goods":10.0,"commute":0.0,"garbage":0.0,"tax":0.0,"fire_buildings_per_incident":100})
 var inputs:Dictionary={"employment":1.0,"power":true,"water":true,"health":0,"police":0,"fire":0,"education":0,"park":0,"housing":0,"pollution_noise":0}
 var value:Dictionary=core.Score(inputs)
 check(value.target==50,"base20 + actual employment20 + temporary goods10")
 check(value.factors.size()==15,"fourteen factors plus the base are explicitly represented")
 inputs.employment=0;check(core.Score(inputs).factors.money==-10,"unemployment penalty")
 inputs.employment=.5;check(core.Score(inputs).factors.money==5,"mixed employment interpolates actual group employment")
 inputs.employment=1
 for key in ["health","police","fire","education"]:
  inputs[key]=10;check(core.Score(inputs).factors[key]==10,"service factor "+key)
 inputs.park=5;inputs.housing=5;inputs.pollution_noise=-15
 check(core.Score(inputs).target==85,"park, housing and capped pollution contribute")
 inputs.power=false;check(core.Score(inputs).target==0,"electricity absence forces zero")
 inputs.power=true;inputs.water=false;check(core.Score(inputs).target==0,"water absence forces zero")
 inputs.water=true;inputs.pollution_noise=0
 check(core.Score(inputs).target==100,"happiness is capped at 100")
 for key in ["goods","commute","garbage","tax"]:check(value.factors.has(key),"replaceable temporary factor "+key)
 core.Configure({"goods":0.0,"commute":-2.0,"garbage":-3.0,"tax":-4.0,"fire_buildings_per_incident":100})
 check(core.Score(inputs).factors.tax==-4 and core.Score(inputs).factors.goods==0,"temporary values are configuration, not hardcoded fulfillment")
 world_checks()
 print("RESULT %d/%d happiness checks passed"%[passed,passed+failed]);quit(1 if failed else 0)
func fresh():
 var core=load("res://simulation/HappinessCore.cs").new()
 core.Configure({"goods":10.0,"commute":0.0,"garbage":0.0,"tax":0.0,"fire_buildings_per_incident":100})
 return core
func body(id:int,x:float,level:int=1,zone:String="residential")->Dictionary:
 return {"id":id,"position":Vector2(x,20),"polygon":PackedVector2Array([Vector2(x-4,16),Vector2(x+4,16),Vector2(x+4,24),Vector2(x-4,24)]),"road":0,"zone":zone,"level":level,"power":true,"water":true,"noise":false,"occupants":4,"eligible":4,"employed":4,"students":[1,0,0,0]}
func facility(id:int,x:float,kind:String,capacity:float=1000)->Dictionary:
 return {"id":id,"position":Vector2(x,20),"polygon":PackedVector2Array([Vector2(x-8,12),Vector2(x+8,12),Vector2(x+8,28),Vector2(x-8,28)]),"road":0,"kind":kind,"capacity":capacity,"school_stage":0}
func world_checks():
 var core=fresh()
 check(core.has_method("SetWorld"),"world, services and growth evaluator exists")
 if not core.has_method("SetWorld"):return
 var road:=PackedFloat64Array([0,0,0,2000,0])
 for pair in [[0,10],[1000,10],[1000.01,9],[2000,9],[2000.01,8],[3000.01,7],[4000.01,6],[5000.01,5],[6000,5],[6000.01,0]]:check(core.DistanceScore(pair[0])==pair[1],"road-distance service boundary "+str(pair[0]))
 core.SetWorld([body(75,100)],[facility(10,150,"health",4),facility(11,150,"police"),facility(12,150,"fire",1),facility(13,150,"education",1)],road);core.Tick(48,PackedInt64Array())
 for key in ["health","police","fire","education"]:check(core.Inspect(75).factors[key]==10,"placed capacity-backed service "+key)
 core=fresh();core.SetWorld([body(150,200),body(75,100)],[facility(10,0,"health",4)],road);core.Tick(48,PackedInt64Array())
 check(core.Inspect(75).factors.health==10 and core.Inspect(150).factors.health==0,"nearer buildings reserve resident capacity first")
 core.SetWorld([body(150,200),body(75,100)],[facility(10,0,"health",4),facility(11,300,"health",4)],road);core.Tick(48,PackedInt64Array())
 check(core.Preview(150).factors.health==0,"midday placement does not reassign daily quotas")
 core.Tick(86400,PackedInt64Array());check(core.Preview(150).factors.health==10,"next day allocates next available facility")
 core=fresh();core.SetWorld([body(150,100),body(75,100)],[facility(10,0,"health",4)],road);core.Tick(48,PackedInt64Array())
 check(core.Preview(75).factors.health==10 and core.Preview(150).factors.health==0,"equal distance breaks ties by building ID")
 var disconnected:Dictionary=facility(11,100,"park");disconnected.road=1
 core=fresh();core.SetWorld([body(75,100)],[disconnected],PackedFloat64Array([0,0,0,2000,0,1,0,40,2000,40]));core.Tick(48,PackedInt64Array())
 check(core.Preview(75).factors.park==0,"nearby but disconnected park gives no road-access bonus")
 core=fresh();core.SetWorld([body(75,100)],[facility(10,500,"park")],road);core.Tick(48,PackedInt64Array());check(core.Preview(75).factors.park==5,"park inclusive 400m road distance")
 core=fresh();core.SetWorld([body(75,100)],[facility(10,501,"park")],road);core.Tick(48,PackedInt64Array());check(core.Preview(75).factors.park==0,"park beyond 400m gives no bonus")
 core=fresh();core.SetWorld([body(75,100),body(150,200,1,"industrial")],[],road);core.Tick(48,PackedInt64Array());check(core.Preview(75).factors.pollution_noise==-10,"factory within 100m")
 var park:Dictionary=facility(10,150,"park")
 core.SetWorld([body(75,100),body(150,200,1,"industrial")],[park,facility(11,160,"park")],road)
 check(core.Preview(75).factors.pollution_noise==-5,"intervening parks halve each source once, not repeatedly")
 park.position.y=120;park.polygon=PackedVector2Array([Vector2(142,112),Vector2(158,112),Vector2(158,128),Vector2(142,128)])
 core.SetWorld([body(75,100),body(150,200,1,"industrial")],[park],road);check(core.Preview(75).factors.pollution_noise==-10,"off-path park does not buffer pollution")
 core=fresh();core.SetWorld([body(75,100),body(150,250,1,"industrial")],[],road);core.Tick(48,PackedInt64Array());check(core.Preview(75).factors.pollution_noise==-5,"factory outer 200m band")
 core=fresh();core.SetWorld([body(75,100)],[facility(10,400,"pollution")],road);core.Tick(48,PackedInt64Array());check(core.Preview(75).factors.pollution_noise==-15,"coal/oil/incinerator inner 300m band")
 core.SetWorld([body(75,100)],[facility(10,600,"pollution")],road);check(core.Preview(75).factors.pollution_noise==-8,"heavy-source outer 600m band")
 var noisy:Dictionary=body(75,100);noisy.noise=true;core.SetWorld([noisy],[facility(10,200,"pollution")],road);check(core.Preview(75).factors.pollution_noise==-15,"road noise and emissions share the -15 cap")
 core.SetWorld([noisy],[],road);check(core.Preview(75).factors.pollution_noise==-5,"immediate four-plus-lane road noise")
 core=fresh();core.SetWorld([body(75,100),body(150,199,2),body(225,201,2)],[],road);core.Tick(48,PackedInt64Array());core.Tick(86400,PackedInt64Array());check(core.Preview(75).factors.housing==1,"only higher residential neighbors within 100m; bonus moves one per day")
 core=fresh();core.SetWorld([body(1,100)],[],road);core.Tick(48,PackedInt64Array());check(not core.Inspect(1).initialized,"only ID modulo 75 bucket is evaluated")
 core.Tick(48,PackedInt64Array());check(core.Inspect(1).actual==50,"new building starts at its first target")
 check(core.Tick(86399,PackedInt64Array()).upgrades.is_empty(),"no upgrade before a full continuous day")
 var upgrades:Array=[]
 for i in range(75):upgrades.append_array(core.Tick(48,PackedInt64Array()).upgrades)
 check(upgrades==[1],"qualifying building requests one upgrade in its own bucket")
 core.Acknowledge(1,true,2);check(core.Inspect(1).held_seconds==0,"successful level change resets next-level timer")
 core.Tick(48,PackedInt64Array([1,0,1]));check(core.Inspect(1).actual==0 and core.Inspect(1).held_seconds==0,"power loss immediately zeros happiness and interrupts continuity")
 var poor:Dictionary=body(1,100);poor.employed=0
 core=fresh();core.SetWorld([body(1,100)],[],road);core.Tick(48,PackedInt64Array());core.Tick(48,PackedInt64Array());core.SetWorld([poor],[],road);core.Tick(86400,PackedInt64Array());check(core.Inspect(1).actual==45,"actual happiness declines by at most five per day")
 check(core.Inspect(1).held_seconds==0,"dropping below threshold resets continuous holding")
 var empty:Dictionary=body(75,100);empty.occupants=0;empty.eligible=0;empty.employed=0
 core=fresh();core.SetWorld([empty],[],road);core.Tick(48,PackedInt64Array());check(core.Tick(172800,PackedInt64Array()).upgrades.is_empty(),"unoccupied buildings cannot earn resident happiness growth")
 var protected_buildings:Array=[]
 for i in range(101):protected_buildings.append(body((i+1)*75,i))
 core=fresh();core.SetWorld(protected_buildings,[facility(10,0,"fire",1)],road);core.Tick(48,PackedInt64Array())
 check(core.Preview(7500).factors.fire==10 and core.Preview(7575).factors.fire==0,"fire incident capacity uses configured 100 buildings, not people")
 core=fresh();core.SetWorld([body(75,100)],[facility(10,0,"health"),facility(11,0,"police"),facility(12,0,"fire",1)],road);core.Tick(48,PackedInt64Array())
 var level:=1
 for stage in range(4):
  var grown:Array=[]
  grown.append_array(core.Tick(86400,PackedInt64Array()).upgrades)
  for i in range(74):grown.append_array(core.Tick(48,PackedInt64Array()).upgrades)
  check(grown==[75],"80 happiness qualifies full-day threshold for level "+str(level))
  level+=1;core.Acknowledge(75,true,level)
 check(core.Tick(172800,PackedInt64Array()).upgrades.is_empty(),"level five never upgrades beyond the cap")
 core=fresh();core.SetWorld([body(75,100)],[],road);core.Tick(48,PackedInt64Array());core.Tick(100,PackedInt64Array());core.SetWorld([body(75,100,2)],[],road)
 check(core.Inspect(75).held_seconds==0,"external level change cannot inherit the previous-level holding time")
