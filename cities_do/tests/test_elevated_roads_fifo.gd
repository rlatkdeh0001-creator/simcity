extends SceneTree
## Bounded correctness only: actual worker gate, FIFO replay, checkpoint, no timings.
const City=preload("res://core/city_model.gd")
const Adapter=preload("res://core/city_simulation_worker.gd")
var checks:=0
var failures:=0
var journal:Dictionary={}
class InspectAdapter extends "res://core/city_simulation_worker.gd":
 func export_validation()->Dictionary:return {"roads":city.roads.duplicate(true),"next_road_id":city.next_road_id,"checkpoint":capture(city)}
func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;printerr("FAIL ",label)
func _initialize():run.call_deferred()
func run():
 var city=City.new(160,160)
 city.population_enabled=false;city.happiness_enabled=false
 var initial:Dictionary=Adapter.capture(city)
 var probe=load("res://core/city_native_mailbox.gd").new()
 probe.Initialize(InspectAdapter.new(),initial);probe.Suspend()
 city.enable_simulation_worker();city.simulation.worker.Suspend()
 city.simulation.edit_completed.connect(func(_result):journal=city.simulation._make_delta(city))
 city.simulation.worker.SetValidationGate(true);city.advance_society(2)
 var a:=PackedVector2Array([Vector2(10,40),Vector2(42,40)])
 var b:=PackedVector2Array([Vector2(42,40),Vector2(82,40)])
 check(city.add_elevated_road(a,PackedFloat64Array([0,10])).get("queued",false),"ramp queues behind actual worker gate")
 check(city.add_elevated_road(b,PackedFloat64Array([10,10])).get("queued",false),"flat continuation queues FIFO")
 check(city.roads.is_empty(),"pending roads never mutate authoritative world early")
 city.simulation.validation_publish();city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 check(city.roads.size()==2 and city.roads[0].points==a and city.roads[1].points==b,"actual replay preserves request order and road geometry")
 check(journal.get("world",{}).get("roads",[])==city.roads,"production world journal includes exact height profiles")
 var delta:Dictionary=journal.duplicate(true);delta.base_tick=probe.GetPublishedTick();delta.base_revision=probe.GetPublishedRevision()
 check(probe.Submit(delta,2),"native observer accepts production road journal")
 probe.Suspend();check(not probe.PublishBoundary().is_empty(),"native observer publishes accepted road journal")
 var state:Dictionary=probe.ExportValidationState()
 check(state.get("roads",[])==city.roads,"worker-owned roads retain all heights and support coordinates")
 var restored=InspectAdapter.new();check(restored.boot(state.checkpoint).ok,"height road checkpoint boots")
 check(restored.city.roads==city.roads,"checkpoint restores exact elevated geometry")
 check(state.next_road_id==city.next_road_id,"worker preserves next road ID watermark")
 check(city.simulation.get_fault().is_empty(),"production worker reports no fault")
 city.simulation.shutdown();probe.Shutdown()
 print("E1_FIFO checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
