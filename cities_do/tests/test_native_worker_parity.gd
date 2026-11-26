extends SceneTree
const Model=preload("res://core/city_model.gd")
const Adapter=preload("res://core/city_simulation_worker.gd")
const Coordinator=preload("res://core/city_native_mailbox.gd")
var checks:=0
func check(value:bool,message:String):
 checks+=1
 if not value:push_error("STAGE2 FAILED: "+message);quit(1);assert(false,message)
func town():
 var source=Model.new(100,100,42)
 check(source.add_road(PackedVector2Array([Vector2(10,40),Vector2(42,40)])).ok,"road fixture")
 var i:=0
 for frame:Dictionary in source.zoning_grid.frames.values():
  if i==8:break
  source.paint_zones(source.Parcels.polygon(frame,0,0,2),"residential" if i%4<2 else ("commercial" if i%4==2 else "industrial"));i+=1
 # Oracle intentionally stays on the unchanged legacy full-pack synchronous path.
 return source
func canonical(source)->Dictionary:
 return {"buildings":source.buildings.duplicate(true),"population":source.population.core.ExportCityCheckpoint(),"happiness":source.happiness.core.ExportCityCheckpoint(),
 "rng_state":source.rng.state,"appearance_state":source.appearance_rng.state,"clock_seconds":source.clock.game_seconds,
 "funds":source.funds,"next_id":source.next_id,"development_elapsed":source.development_elapsed,"development_cursor":source.development_cursor,"society_elapsed":source.society_elapsed}
func _initialize():run.call_deferred()
func run():
 var source=town()
 # Non-empty mid-run initialization catches lost elapsed, IDs, RNG and held growth.
 for i in range(90):source.advance_society(2)
 var checkpoint:Dictionary=Adapter.capture(source)
 var worker=Coordinator.new();worker.Initialize(Adapter.new(),checkpoint)
 while not worker.IsReady():await process_frame
 var old_view
 for i in range(5400):
  if i==0:worker.SetValidationGate(true)
  var delta:Dictionary={"base_tick":i,"base_revision":0,"revision":0}
  check(worker.Submit(delta,2),"submit")
  check(not worker.Submit(delta,2),"single pending slot")
  if i==0:
   check(worker.IsBusy(),"busy while held")
   check(worker.PublishBoundary().is_empty(),"cannot publish incomplete")
   check(worker.GetPublishedTick()==0,"busy freezes logical ID")
   worker.SetValidationGate(false)
  while not worker.IsComplete():await process_frame
  check(not worker.Submit(delta,2),"completed unpublished still owns slot")
  check(worker.GetPublishedTick()==i,"completion is not publication")
  var result:Dictionary=worker.PublishBoundary()
  check(result.logical_tick==i+1,"boundary publication")
  source.advance_society(2)
  var expected:Dictionary=canonical(source)
  var exported:Dictionary=worker.ExportValidationState()
  # The export also carries save/transport data outside this parity fixture.
  var actual:Dictionary={}
  for key:Variant in expected:
   if exported.has(key):actual[key]=exported[key]
  checks+=1
  if actual!=expected:
   var mismatches:=PackedStringArray()
   for key:Variant in expected:
    if not actual.has(key) or actual[key]!=expected[key]:mismatches.append(str(key))
   push_error("STAGE2 FAILED: exact state at logical tick %d (missing/unequal fields: %s)"%[i+1,", ".join(mismatches)])
   worker.Shutdown();quit(1);return
  check(result.population_view.Stats()==source.population.stats(),"population stats read view")
  check(result.scalars.stats==source.population.stats(),"scalar stats")
  check(result.scalars.demand==source.population.demand(source.buildings),"scalar demand")
  check(result.scalars.rng_seed==source.population.rng_seed() and result.scalars.rng_state==source.population.rng_state(),"scalar population RNG")
  check(result.scalars.elapsed_days==source.population.elapsed_days and result.scalars.birth_day==source.population.birth_day,"scalar elapsed metadata")
  check(result.scalars.next_person==source.population.next_person and result.scalars.next_household==source.population.next_household,"scalar population IDs")
  check(result.scalars.happiness_average==source.happiness.core.CityHappiness(),"scalar happiness")
  check(result.population_view.Demand()==source.population.demand(source.buildings),"demand read view")
  check(result.happiness_view.Inspect(-123).is_empty(),"unknown happiness ID")
  check(result.population_view.WorkplaceInfo(-123).is_empty(),"unknown workplace ID")
  if i==0:old_view=result.population_view
  if i==5399:check(old_view.GetElapsedDays()<result.population_view.GetElapsedDays(),"previous view immutable")
 check(worker.GetWorkerThread()>0,"dedicated managed thread ID")
 worker.Shutdown()
 print("STAGE2_PASS checks=",checks," exact_ticks=5400 seeded_after=90")
 quit(0)
