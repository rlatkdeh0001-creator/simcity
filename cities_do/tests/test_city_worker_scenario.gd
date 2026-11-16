extends "res://tests/reference/city_worker_scenario_fixture.gd"
const Adapter=preload("res://core/city_simulation_worker.gd")
const Coordinator=preload("res://simulation/CitySimulationWorker.cs")
func run():
 setup();city.population.enable_geometry_transport(city.buildings)
 var worker=Coordinator.new();worker.Initialize(Adapter.new(),Adapter.capture(city))
 while not worker.IsReady():await process_frame
 var revision:=0;var checks:=0;var previous_supply:Dictionary={}
 for b:Dictionary in city.buildings:previous_supply[b.id]=supply(b)
 for i in range(7350):
  city.advance_utilities(2)
  var ops:Array=[]
  for b:Dictionary in city.buildings:
   var now:Array=supply(b)
   if previous_supply.get(b.id)!=now:ops.append({"kind":"update","id":b.id,"record":b.duplicate(true)})
  var next_revision:int=revision+int(not ops.is_empty())
  assert(worker.Submit({"base_tick":i,"base_revision":revision,"revision":next_revision,"building_ops":ops,"meta":{"funds":city.funds}},2))
  city.advance_society(2)
  while not worker.IsComplete():await process_frame
  var result:Dictionary=worker.PublishBoundary();revision=next_revision
  previous_supply.clear()
  for b:Dictionary in city.buildings:previous_supply[b.id]=supply(b)
  if i%300==0 or i==7349:
   var actual:Dictionary=worker.ExportValidationState();checks+=1
   assert(actual.buildings==city.buildings,"scenario full buildings tick "+str(i))
   assert(actual.population==city.population.core.ExportCityCheckpoint(),"scenario people/jobs/RNG tick "+str(i))
   assert(actual.happiness==city.happiness.core.ExportCityCheckpoint(),"scenario happiness state tick "+str(i))
   for home:Dictionary in homes:
    assert(result.happiness_view.Inspect(home.id)==city.happiness.core.Inspect(home.id),"immutable happiness inspection")
 var levels:Array=[];var targets:Array=[]
 for home:Dictionary in homes:levels.append(home.level);targets.append(home.happiness_target)
 assert(levels==[1,4,5] and targets==[40.0,70.0,80.0])
 worker.Shutdown();print("STAGE2_SCENARIO_PASS checkpoints=",checks," ticks=7350 levels=",levels," targets=",targets);quit(0)
func supply(b:Dictionary)->Array:
 return [b.get("has_power"),b.get("has_water"),b.get("has_sewage"),b.get("power_ratio"),b.get("water_ratio"),b.get("sewage_ratio")]
