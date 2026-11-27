extends SceneTree
const Model=preload("res://core/city_model.gd")
const Adapter=preload("res://core/city_simulation_worker.gd")
const Coordinator=preload("res://simulation/CitySimulationWorker.cs")
# These worker-only export fields are required, but do not have an independent parity oracle.
const WORKER_ONLY_EXPORT_KEYS=["checkpoint","external_infrastructure","loans","next_transit_line_id","next_transit_route_id","transit_lines","transit_routes","transit_state"]
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
func validation_difference(expected:Dictionary,exported:Dictionary)->String:
 var actual:=exported.duplicate()
 var missing:=PackedStringArray()
 for key:String in WORKER_ONLY_EXPORT_KEYS:
  if not actual.erase(key):missing.append(key)
 if missing.is_empty() and actual==expected:return ""
 var unexpected:=PackedStringArray()
 var unequal:=PackedStringArray()
 for key:Variant in expected:
  if not actual.has(key):missing.append(str(key))
  elif actual[key]!=expected[key]:unequal.append(str(key))
 for key:Variant in actual:
  if not expected.has(key):unexpected.append(str(key))
 return "missing fields: [%s]; unexpected fields: [%s]; unequal fields: [%s]"%[", ".join(missing),", ".join(unexpected),", ".join(unequal)]
func check_comparison(expected:Dictionary,exported:Dictionary):
 var changed:=exported.duplicate()
 changed.unknown_validation_field=true
 check(validation_difference(expected,changed).contains("unexpected fields: [unknown_validation_field]"),"parity rejects unknown export fields")
 changed=exported.duplicate()
 changed.erase("clock_seconds")
 check(validation_difference(expected,changed).contains("missing fields: [clock_seconds]"),"parity rejects missing canonical fields")
 changed=exported.duplicate()
 changed.erase("checkpoint")
 check(validation_difference(expected,changed).contains("missing fields: [checkpoint]"),"parity rejects missing worker-only fields")
 changed=exported.duplicate()
 changed.rng_state=int(expected.rng_state)^1
 check(validation_difference(expected,changed).contains("unequal fields: [rng_state]"),"parity rejects unequal canonical values")
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
  var difference:=validation_difference(expected,exported)
  checks+=1
  if not difference.is_empty():
   push_error("STAGE2 FAILED: exact state at logical tick %d: %s"%[i+1,difference])
   worker.Shutdown();quit(1);return
  if i==0:check_comparison(expected,exported)
  check(result.population_view.Stats()==source.population.stats(),"population stats read view")
  check(result.population_view.Demand()==source.population.demand(source.buildings),"demand read view")
  check(result.happiness_view.Inspect(-123).is_empty(),"unknown happiness ID")
  check(result.population_view.WorkplaceInfo(-123).is_empty(),"unknown workplace ID")
  if i==0:old_view=result.population_view
  if i==5399:check(old_view.GetElapsedDays()<result.population_view.GetElapsedDays(),"previous view immutable")
 check(worker.GetWorkerThread()>0,"dedicated managed thread ID")
 worker.Shutdown()
 print("STAGE2_PASS checks=",checks," exact_ticks=5400 seeded_after=90")
 quit(0)
