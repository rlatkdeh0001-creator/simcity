extends SceneTree
const Mailbox=preload("res://core/city_native_mailbox.gd")
var checks:=0
var failures:Array=[]
class Adapter:
 extends RefCounted
 var mode:=""
 func boot(_checkpoint:Dictionary)->Dictionary:
  return {"ok":false,"error":"boot-probe-fault"} if mode=="boot_fault" else {"ok":true}
 func run_step(delta:Dictionary,_seconds:float,tick:int)->Dictionary:
  if mode=="step_fault":return {"ok":false,"error":"step-probe-fault"}
  return {"ok":true,"logical_tick":tick+(1 if mode=="stale" else 0),"revision":delta.revision,"payload":{"array":[1,2,3]}}
 func export_validation()->Dictionary:return {"ok":true,"exported":true}
class RetireProbe:
 extends RefCounted
 var log:Dictionary
 func _init(target:Dictionary):log=target
 func _notification(what:int):
  if what==NOTIFICATION_PREDELETE:log.thread=OS.get_thread_caller_id()
class NoManaged:
 extends RefCounted
 # Intentionally has NO coordinator or view methods. Any accidental dispatch errors.
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label);printerr("FAIL ",label)
func _initialize():run.call_deferred()
func run():
 var w=Mailbox.new();w.Initialize(Adapter.new(),{});w.Suspend()
 check(w.IsReady() and w.GetFault().is_empty(),"boot native status")
 var actual_coordinator=w._coordinator
 w._coordinator=NoManaged.new()
 var retire_log:Dictionary={}
 var probe=RetireProbe.new(retire_log)
 w.AdoptBootViews(probe,null);probe=null
 var delta:Dictionary={"base_tick":0,"base_revision":0,"revision":5,"meta":{"funds":7}}
 check(not w.Submit({"base_tick":99,"base_revision":0},2) and not w.GetContractError().is_empty(),"stale base rejected natively")
 check(not w.Submit(delta,INF) and not w.Submit(delta,0),"invalid seconds rejected natively")
 check(not w.Submit({"base_tick":0,"base_revision":0,"revision":0,"financing_flush":true},0),"empty financing flush cannot manufacture an extra publication")
 w.SetValidationGate(true)
 check(w.Submit(delta,2),"accepted owned input")
 check(delta.is_read_only() and delta.meta.is_read_only(),"input recursively frozen")
 check(w.IsBusy() and w.HasPending() and not w.IsComplete(),"held worker busy")
 check(not w.Submit(delta,2) and w.PublishBoundary().is_empty(),"no queue or incomplete publication")
 w.Suspend()
 check(w.IsComplete() and w.HasPending() and w.GetPublishedTick()==0,"completion not publication")
 check(not w.Submit(delta,2) and w.ExportValidationState().is_empty(),"completed-unpublished still owns slot")
 var r:Dictionary=w.PublishBoundary()
 check(r.logical_tick==1 and w.GetPublishedRevision()==5,"publish native boundary")
 check(r.is_read_only() and r.payload.is_read_only() and r.payload.array.is_read_only(),"result recursively frozen")
 check(retire_log.is_empty(),"boot read root held across first publication on main")
 check(w.PublishBoundary().is_empty(),"publication exactly once")
 check(w.ExportValidationState().exported,"explicit native export command")
 check(retire_log.get("thread",0)==w.GetWorkerThread() and int(retire_log.thread)!=OS.get_thread_caller_id(),"old root retired on worker during next command")
 check(w.Submit({"base_tick":1,"base_revision":5,"revision":5},2),"next job accepted without managed coordinator dispatch")
 w.Suspend();w.PublishBoundary()
 check(w.GetPublishedTick()==2 and w.GetFault().is_empty(),"no-managed coordinator status/submit/publish contract")
 w._coordinator=actual_coordinator;w.Shutdown()
 for mode:String in ["boot_fault","step_fault","stale"]:
  var a=Adapter.new();a.mode=mode
  var broken=Mailbox.new();broken.Initialize(a,{})
  broken.Suspend()
  if mode!="boot_fault":
   check(broken.Submit({"base_tick":0,"base_revision":0,"revision":0},2),"fault fixture submit "+mode)
   broken.Suspend()
   if mode=="stale":check(broken.PublishBoundary().is_empty(),"stale result never visible")
  check(not broken.GetFault().is_empty(),"fault propagated "+mode)
  check(broken.IsBusy() and not broken.Submit({"base_tick":0,"base_revision":0},2),"fault prevents new work "+mode)
  broken.Shutdown()
 await scalar_contract()
 print("NATIVE_MAILBOX_CONTRACT checks=",checks," failed=",failures.size())
 quit(0 if failures.is_empty() else 1)
func scalar_contract():
 var fixture=load("res://tests/test_city_simulation_facade.gd").new()
 var city=fixture.town()
 var sim=load("res://core/city_simulation.gd").new(city)
 sim.worker.Suspend()
 check(city.population.published_read_view().get_script()!=null and city.happiness.published_read_view().get_script()!=null,"T0 native cached read roots")
 var old_stats:Dictionary=city.population.stats()
 var actual_coordinator=sim.worker._coordinator
 sim.worker._coordinator=NoManaged.new()
 var clock_events:=0
 city.clock.minute_changed.connect(func():
  city.population.stats();city.population.demand([]);city.population.rng_seed();city.population.rng_state()
  var unused=[city.population.elapsed_days,city.population.birth_day,city.population.next_person,city.population.next_household,city.happiness.average_value()]
  check(unused.size()==5,"clock signal scalar HUD uses native cache")
 )
 for i in range(4):
  # Poison the retained managed views: all scalar methods MUST continue to work.
  var pv=city.population.published_read_view();var hv=city.happiness.published_read_view()
  var real_p=pv.managed_view;var real_h=hv.managed_view
  pv.managed_view=NoManaged.new();hv.managed_view=NoManaged.new()
  sim.advance(2);sim.worker.Suspend();check(sim._publish(),"real native publication with poisoned old views")
  pv.managed_view=real_p;hv.managed_view=real_h
  var stats:Dictionary=city.population.stats();var d:Dictionary=city.population.demand([])
  var p=city.population.published_read_view();var h=city.happiness.published_read_view()
  var reference:Dictionary=p.managed_view.Stats()
  var expected_h:Variant=h.managed_view.CityHappiness()
  p.managed_view=NoManaged.new();h.managed_view=NoManaged.new()
  check(city.population.stats()==reference and city.population.demand([])==d,"HUD stats/demand detached native scalars")
  check(city.happiness.average_value()==(null if expected_h==null else roundi(float(expected_h))),"HUD happiness native scalar")
  check(city.population.rng_state()==p.scalars.rng_state and city.population.elapsed_days==p.scalars.elapsed_days,"RNG/elapsed native metadata")
  # Subsequent publication is also safe with these poisoned current roots.
 check(old_stats.population>=0 and city.population.stats().population>=0,"old stats root intact")
 sim.worker._coordinator=actual_coordinator;sim.shutdown()
 fixture.free()
