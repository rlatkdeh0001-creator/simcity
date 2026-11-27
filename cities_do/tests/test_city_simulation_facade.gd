extends SceneTree
## Standalone: --headless --path cities_do --script res://tests/test_city_simulation_facade.gd
var checks:=0
var failed:=0
func check(value:bool,message:String):
 checks+=1
 if not value:failed+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func run():
 check(FileAccess.file_exists("res://core/city_simulation.gd"),"full-city main facade exists")
 if failed==0:await exercise()
 print("CITY_SIMULATION_FACADE checks=%d failed=%d"%[checks,failed])
 quit(0 if failed==0 else 1)
func town():
 var city=load("res://core/city_model.gd").new(100,100,42)
 assert(city.add_road(PackedVector2Array([Vector2(10,40),Vector2(42,40)])).ok)
 var n:=0
 for frame:Dictionary in city.zoning_grid.frames.values():
  if n==8:break
  city.paint_zones(city.Parcels.polygon(frame,0,0,2),"residential" if n%4<2 else ("commercial" if n%4==2 else "industrial"));n+=1
 for i in range(90):city.advance_society(2)
 return city
var events:Array=[]
var allocated:=-1
var skip_resume:=false
class PollCounter:
 extends RefCounted
 var calls:=0
 func GetFault()->String:calls+=1;return ""
 func IsReady()->bool:calls+=1;return true
func continue_worker(sim):
 if sim.worker.has_method("Resume"):sim.resume()
 elif "--legacy-stage2-dll" in OS.get_cmdline_user_args():
  skip_resume=true;sim.suspended=false
 else:check(false,"native Resume required");sim.suspended=false
func intent(city,sim,label:String):
 if sim.defer_edit(intent.bind(city,sim,label)):return
 events.append([label,sim.get_published_tick(),city.next_id])
 if label=="create":
  allocated=city.next_id;city.next_id+=1
  var b:Dictionary=city.buildings[0].duplicate(true)
  b.id=allocated;b.x=80;b.y=80;b.test_marker="created"
  city.buildings.append(b);sim.note_building(b)
 else:
  for b:Dictionary in city.buildings:
   if b.id==allocated:b.test_marker=label;sim.note_building(b)
 return {"ok":label=="create","label":label}
func exercise():
 var city=town();var oracle=town()
 check(not city.population.has_read_view(),"legacy model remains default-off until explicitly enabled")
 var starting_stats:Dictionary=city.population.stats()
 var sim=load("res://core/city_simulation.gd").new(city)
 var completions:Array=[]
 sim.edit_completed.connect(func(result):completions.append(result))
 check(sim.enabled and city.population.has_read_view(),"constructing facade starts worker for Model.enable_simulation_worker")
 var starting_clock:float=city.clock.game_seconds
 var original:Dictionary=city.buildings[0]
 check(sim.initialize(),"initial owned checkpoint accepted")
 check(city.population.has_read_view() and city.happiness.has_read_view(),"boot attaches published T0 immutable views")
 city.population.sync([{}])
 check(city.population._depth==0 and city.population.stats()==starting_stats,"legacy editor sync is a read-only no-op while attached, never repacks geometry")
 while not sim.is_ready():await process_frame
 var native_worker=sim.worker
 var poll_counter=PollCounter.new()
 sim.worker=poll_counter;sim.advance(0.001);sim.worker=native_worker;sim._elapsed=0.0
 check(poll_counter.calls==0,"after boot, non-boundary frames never enter managed coordinator polling")
 var old_population=city.population.published_read_view()
 var old_happiness=city.happiness.published_read_view()
 var initial_inspect:Dictionary=old_happiness.Inspect(original.id)
 var initial_elapsed:float=old_population.GetElapsedDays()
 original.test_worker_geometry="worker";sim.note_building(original)
 sim.worker.SetValidationGate(true)
 sim.advance(2)
 check(sim.has_pending() and sim.worker.IsBusy(),"first boundary submits one worker job")
 check(city.clock.game_seconds==starting_clock and sim.get_published_tick()==0,"submission is not clock publication")
 sim.advance(12)
 check(sim.get_published_tick()==0 and city.society_frozen_cycles==6,"busy attempts freeze logical time without tick debt")
 check(city.population.stats()==starting_stats and city.population.demand([{}])==old_population.Demand(),"production reads use immutable views without geometry packing")
 check(sim.export_validation_state().is_empty(),"pending validation export cannot leak private state")
 intent(city,sim,"create");intent(city,sim,"updated")
 check(events.is_empty() and sim.queued_edit_count()==2,"editor FIFO holds unallocated intents while pending")
 var next_before:int=city.next_id
 city.funds-=37
 original.has_power=not original.get("has_power",false);sim.note_building(original)
 var supply_after:bool=original.has_power
 sim.worker.SetValidationGate(false);sim.suspend()
 check(sim.worker.IsComplete() and city.clock.game_seconds==starting_clock,"explicit join does not publish")
 check(city.population.stats()==starting_stats and sim.export_validation_state().is_empty(),"completed-unpublished state remains private")
 oracle.advance_society(2)
 check(sim.validation_publish(),"validation boundary explicitly publishes once")
 check(sim.get_published_tick()==1 and city.clock.game_seconds==oracle.clock.game_seconds,"clock publishes one logical interval")
 check(city.funds==oracle.funds-37,"funds delta preserves an intervening main debit")
 check(city.population.stats()==oracle.population.stats(),"published population exact against synchronous oracle")
 check(city.rng.state==oracle.rng.state and city.appearance_rng.state==oracle.appearance_rng.state and city.next_id==oracle.next_id,"RNG and next IDs publish before editor replay")
 check(bool(original.get("has_power",false))==supply_after,"pending supply journal survives geometry publication")
 check(old_population.Stats()==starting_stats and old_population.GetElapsedDays()==initial_elapsed and old_happiness.Inspect(original.id)==initial_inspect,"old read roots remain immutable")
 var exposed:Dictionary=city.population.stats();exposed.population=-999
 check(city.population.stats().population>=0,"returned stats cannot mutate published root")
 var h:Dictionary=city.happiness.inspect(original.id)
 if h.has("factors"):
  h.factors.goods=-999
  check(city.happiness.inspect(original.id).factors.goods!=-999,"inspection results are detached from happiness root")
 check(city.happiness.preview(-1).is_empty() and city.population.workplace_info(-1).is_empty(),"unknown IDs never query stale main cores")
 check(events.is_empty() and sim.queued_edit_count()==2,"validation publish does not replay UI intents")
 var exported:Dictionary=sim.export_validation_state()
 check(not exported.is_empty() and exported.clock_seconds==city.clock.game_seconds,"idle compatibility export matches published boundary")
 continue_worker(sim);sim.advance(2)
 check(events.size()==2 and events[0][0]=="create" and events[1][0]=="updated" and events[0][1]==1,"editor FIFO replays before next Submit")
 check(allocated>=next_before and allocated>=oracle.next_id,"deferred IDs allocate against newly published next_id")
 check(sim.has_pending() and sim.queued_edit_count()==0,"editor queue drains then one tick submits")
 check(completions.size()==2 and completions[0].ok and not completions[1].ok,"replay emits original results including failures for main UI feedback")
 sim.validation_publish();exported=sim.export_validation_state()
 var edited:Dictionary={}
 for b:Dictionary in exported.buildings:
  if b.id==allocated:edited=b
 check(edited.get("test_marker","")=="updated","repeated updates coalesce into one worker operation")
 check(is_same(original,city.buildings[0]),"geometry preserves Dictionary identity and stable order")
 continue_worker(sim)
 var created:Dictionary={}
 for b:Dictionary in city.buildings:
  if b.id==allocated:created=b
 city.buildings.erase(created);sim.remove_building(allocated)
 sim.note_zones();sim.note_world();sim.advance(2);sim.validation_publish()
 exported=sim.export_validation_state()
 var found:=false
 for b:Dictionary in exported.buildings:
  if b.id==allocated:found=true
 check(not found,"remove journal reconciles worker geometry")
 var empty_delta:Dictionary=sim._make_delta(city)
 check(not empty_delta.has("building_ops") and not empty_delta.has("world") and not empty_delta.has("zones"),"unchanged tick has no geometry/world snapshots")
 var frozen:float=city.clock.game_seconds
 sim.advance(100)
 check(city.clock.game_seconds==frozen,"suspended façade accrues no clock or tick debt")
 sim._publishing=true
 check(sim.defer_edit(func():events.append("clock observer edit")),"clock/funds signal observers queue edits until atomic publication completes")
 sim._publishing=false
 if sim.worker.has_method("Resume"):
  sim.shutdown();check(sim.is_busy(),"shutdown freezes facade without publication")
  sim.resume();sim.worker.SetValidationGate(true);sim.advance(2)
  check(sim.has_pending(),"resume accepts next step without recapture")
  sim.shutdown()
  check(city.clock.game_seconds==frozen and sim.get_published_tick()==3,"shutdown joins pending work without publication")
  sim.resume();sim.advance(2)
  check(sim.get_published_tick()==4,"resume preserves completed-unpublished result")
 else:skip_resume=true
 sim.shutdown()
 print("FACADE_RESUME_SKIPPED=",skip_resume)
