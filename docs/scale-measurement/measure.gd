extends SceneTree
var population_count:=10000
var scenario:="steady"
func _initialize():run.call_deferred()
func metric(values:Array)->Dictionary:
 var ordered:Array=values.duplicate();ordered.sort()
 return {"median_ms":ordered[ordered.size()/2],"max_ms":ordered[-1],"samples_ms":values}
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--population="):population_count=int(arg.trim_prefix("--population="))
  if arg.begins_with("--scenario="):scenario=arg.trim_prefix("--scenario=")
 var started:=Time.get_ticks_usec()
 var pop=load("res://PopulationCore.cs").new();pop.Initialize(20261116)
 pop.Configure(JSON.parse_string(FileAccess.get_file_as_string("res://population_config.json")))
 var people:Array=[];var households:Array=[];var buildings:=PackedInt64Array();var happiness_buildings:Array=[]
 var homes:=ceili(float(population_count)/4);var works:=ceili(float(population_count)/8)
 for i in range(homes+works):
  var residential:bool=i<homes
  var id:int=i+1;var x:float=(i%250)*12;var y:float=(i/250)*12
  buildings.append_array(PackedInt64Array([id,0 if residential else 2,2,1]))
  happiness_buildings.append({"id":id,"road":0,"position":Vector2(x,y),"polygon":PackedVector2Array([Vector2(x-4,y-4),Vector2(x+4,y-4),Vector2(x+4,y+4),Vector2(x-4,y+4)]),"zone":"residential" if residential else "industrial","level":1,"power":true,"water":true,"noise":false})
 for i in range(ceili(float(population_count)/2)):households.append({"id":i+1,"home_id":i/2+1})
 for i in range(population_count):people.append({"id":i+1,"household_id":i/2+1,"education":i%5,"age_years":30.0,"origin":"synthetic-scale","workplace_id":-1,"job_stage":-1})
 pop.ImportState(people,households,{})
 pop.SetNextPerson(population_count+1);pop.SetNextHousehold(ceili(float(population_count)/2)+1);pop.SyncPacked(buildings)
 people.clear();households.clear()
 var happy=load("res://HappinessCore.cs").new()
 happy.Configure({"goods":10.0,"commute":0.0,"garbage":0.0,"tax":0.0,"fire_buildings_per_incident":100});happy.BindPopulation(pop)
 # Registered largest facilities, not infinite fictional capacity. One connected local service cluster.
 var facilities:Array=[]
 for entry in [["health",400],["police",15000],["fire",8],["education",2400],["park",0]]:
  facilities.append({"id":homes+works+facilities.size()+1,"road":0,"position":Vector2(100,0),"polygon":PackedVector2Array([Vector2(96,-4),Vector2(104,-4),Vector2(104,4),Vector2(96,4)]),"kind":entry[0],"capacity":entry[1],"school_stage":0})
 happy.SetWorld(happiness_buildings,facilities,PackedFloat64Array([0,0,0,3000,0]))
 var generation_ms:float=(Time.get_ticks_usec()-started)/1000.0
 print("SCALE_CREATED population=",population_count," buildings=",homes+works," generation_ms=",generation_ms)
 assert(pop.Stats().population==population_count)
 if scenario=="daily":
  happy.Tick(48,PackedInt64Array())
  print("SCALE_DAILY_BEGIN population=",population_count)
  var before:=Time.get_ticks_usec();happy.Tick(86400,PackedInt64Array());var total:float=(Time.get_ticks_usec()-before)/1000.0
  var daily:Dictionary=happy.Diagnostics();daily.total_tick_ms=total
  print("SCALE_DAILY_RESULT ",JSON.stringify({"population":population_count,"daily":daily}));quit();return
 var pop_samples:Array=[];var jobs_samples:Array=[];var happy_samples:Array=[];var bucket_samples:Array=[];var groups_samples:Array=[];var mean_samples:Array=[];var initial:Dictionary={}
 # Priming first tick includes initial service allocation and JIT; retain separately, not in steady medians.
 happy.Tick(48,PackedInt64Array());initial=happy.Diagnostics()
 if scenario=="warm":
  pop.MatchJobs()
  for i in range(74):happy.Tick(48,PackedInt64Array())
 for sample in range(8):
  pop.BeginTick();var t:=Time.get_ticks_usec();pop.AdvancePacked(48,buildings);pop.MatchJobs();var population_ms:float=(Time.get_ticks_usec()-t)/1000.0;pop.EndTick()
  t=Time.get_ticks_usec();pop.MatchJobs();var jobs_ms:float=(Time.get_ticks_usec()-t)/1000.0
  t=Time.get_ticks_usec();var result:Dictionary=happy.Tick(48,PackedInt64Array());var happiness_ms:float=(Time.get_ticks_usec()-t)/1000.0
  var diagnostic:Dictionary=happy.Diagnostics()
  assert(result.upgrades.is_empty() and pop.Stats().population==population_count)
  if sample==0:continue
  pop_samples.append(population_ms);jobs_samples.append(jobs_ms);happy_samples.append(happiness_ms);bucket_samples.append(diagnostic.bucket_ms);groups_samples.append(diagnostic.groups_ms);mean_samples.append(diagnostic.average_ms)
 var row:={"warmup_happiness_buckets":75 if scenario=="warm" else 1,"population":population_count,"homes":homes,"workplaces":works,"buildings":homes+works,"generation_ms":generation_ms,"population_tick_including_matching":metric(pop_samples),"employment_replay":metric(jobs_samples),"happiness_tick_including_bucket":metric(happy_samples),"growth_bucket_including_target":metric(bucket_samples),"population_grouping":metric(groups_samples),"city_average":metric(mean_samples),"initial_happiness_sections":initial,"stats":pop.Stats()}
 print("SCALE_RESULT ",JSON.stringify(row));quit()
