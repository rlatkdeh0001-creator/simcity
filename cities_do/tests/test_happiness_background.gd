extends "res://tests/test_happiness_spatial.gd"
func raw(value:Dictionary)->Dictionary:
 var result:Dictionary=value.duplicate(true);result.erase("logical_tick");return result
func run():
 var actual=load("res://simulation/HappinessCore.cs").new()
 if not actual.has_method("EnableBackground"):
  check(false,"nonblocking snapshot job API is required");quit(1);return
 var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://core/happiness_config.json"))
 var rows:Array=[building(75,Vector2.ZERO)]
 var roads:=PackedFloat64Array([0,-100,0,100,0])
 var expected=load("res://tests/reference/HappinessReferenceCore.cs").new()
 for core in [actual,expected]:core.Configure(config);core.SetWorld(rows,[],roads)
 actual.EnableBackground();actual.SetBackgroundGateForValidation(true);actual.SetWorld(rows,[],roads)
 check(actual.SubmitBackgroundTick(48,PackedInt64Array([75,1,1])),"accept one frozen input")
 rows[0].power=false
 check(not actual.SubmitBackgroundTick(48,PackedInt64Array()),"busy input is rejected, not queued")
 check(actual.PublishBackgroundTick().is_empty(),"incomplete work cannot publish")
 check(actual.BackgroundStatus().submitted==1 and actual.BackgroundStatus().published==0 and actual.BackgroundStatus().skipped==1,"accepted logical IDs and skip count")
 check(actual.CityHappiness()==null,"renderer retains the previous buffer while gated")
 actual.SetBackgroundGateForValidation(false);actual.SuspendBackground()
 check(actual.BackgroundStatus().worker_thread!=actual.BackgroundStatus().main_thread,"calculation ran on a real background thread")
 check(actual.CityHappiness()==null,"completion alone does not publish")
 var committed:Dictionary=actual.PublishBackgroundTick()
 check(committed.logical_tick==1 and same(raw(committed),expected.Tick(48,PackedInt64Array([75,1,1]))),"submitted world snapshot and output exactly match the serial oracle")
 check(actual.PublishBackgroundTick().is_empty(),"completion publishes once")
 var exposed:Dictionary=actual.Inspect(75);exposed.factors.goods=-1000
 check(actual.Inspect(75).factors.goods==10.0,"public inspection cannot mutate the published buffer")
 check(actual.BackgroundStatus().submitted==actual.BackgroundStatus().published,"no backlog remains")
 # A live population may change after submission: frozen managed groups must not.
 var pop=load("res://simulation/PopulationCore.cs").new();pop.Initialize(11)
 pop.Configure(JSON.parse_string(FileAccess.get_file_as_string("res://core/population_config.json")))
 var people:Array=[]
 for i in range(4):people.append({"id":i+1,"household_id":1+i/2,"education":0,"age_years":30.0,"origin":"snapshot","workplace_id":-1,"job_stage":-1})
 pop.ImportState(people,[{"id":1,"home_id":75},{"id":2,"home_id":75}],{});pop.SetNextPerson(5);pop.SetNextHousehold(3)
 pop.SyncPacked(PackedInt64Array([75,0,2,1,150,1,2,1]));pop.MatchJobs()
 actual.BindPopulation(pop);actual.SetWorld([building(75,Vector2.ZERO),building(150,Vector2(100,0),"commercial")],[],roads)
 actual.SetBackgroundGateForValidation(true)
 check(actual.SubmitBackgroundTick(86400,PackedInt64Array()),"capture an immutable managed population snapshot")
 pop.AddPerson(1,0,30,"after-submission")
 actual.SetBackgroundGateForValidation(false);actual.SuspendBackground();actual.PublishBackgroundTick()
 check(actual.Inspect(75).target==expected.Score({"employment":1.0,"power":true,"water":true}).target,"an in-flight tick does not observe a later population mutation")
 check(actual.SubmitBackgroundTick(86400,PackedInt64Array()),"next logical input captures changed aggregate groups")
 actual.SuspendBackground();actual.PublishBackgroundTick()
 check(actual.Inspect(75).target==expected.Score({"employment":4.0/5.0,"power":true,"water":true}).target,"next snapshot includes the changed employment ratio")
 for seed_value in [42,20261114]:
  var rng:=RandomNumberGenerator.new();rng.seed=seed_value
  var left=load("res://simulation/HappinessCore.cs").new();var right=load("res://tests/reference/HappinessReferenceCore.cs").new();var seeded:Array=[]
  for i in range(30):seeded.append(building(i+1,Vector2(rng.randf_range(-400,400),rng.randf_range(-400,400)),"industrial" if i%5==0 else "residential"))
  for core in [left,right]:core.Configure(config);core.SetWorld(seeded,[],roads)
  left.EnableBackground()
  for tick in range(5400):
   var supplies:=PackedInt64Array()
   if tick%100==0:supplies=PackedInt64Array([1,1,0 if tick%200==0 else 1])
   check(left.SubmitBackgroundTick(48,supplies),"logical submit seed=%d tick=%d"%[seed_value,tick])
   left.SuspendBackground()
   var value:Dictionary=left.PublishBackgroundTick()
   check(value.logical_tick==tick+1 and same(raw(value),right.Tick(48,supplies)),"three-day result exact seed=%d tick=%d"%[seed_value,tick])
  check(left.CityHappiness()==right.CityHappiness(),"three-day published average seed="+str(seed_value))
  left.SuspendBackground()
 print("RESULT %d/%d background snapshot checks passed"%[count-failed,count]);quit(0 if failed==0 else 1)
