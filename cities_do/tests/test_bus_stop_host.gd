extends SceneTree
var checks:=0
var failures:=0
var journal:Dictionary={}
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize():run.call_deferred()
func fixture():
 var city=load("res://core/city_model.gd").new(100,100,42)
 city.population_enabled=false;city.happiness_enabled=false
 city.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
 var curb:=Vector2(70,40-city.RoadProfile.asphalt_width(city.roads[0])/2)
 check(city.public_facilities.place("bus-stop-01",curb,0,true).ok,"stop fixture places")
 return city
func run():
 var city=fixture()
 var original:Dictionary=city.public_facilities.lots[0].duplicate(true)
 var price:float=city.public_facilities.price("bus-stop-01")
 var host:int=city.roads[0].parcel_id
 check(city.demolish_road_unit(host,Vector2(40,40)).ok,"middle unit removed")
 check(city.roads.size()==2 and city.roads[0].parcel_id==host,"left keeps original road ID")
 check(city.public_facilities.lots[0].front_road_id==city.roads[1].parcel_id,"surviving stop rebinds actual right fragment")
 var expected:Dictionary=original.duplicate(true);expected.front_road_id=city.roads[1].parcel_id
 check(city.public_facilities.lots[0]==expected,"only stop host changes; position front polygon identity preserved")
 check(city.demolish("road",city.roads[1].parcel_id).ok,"remove actual right host")
 expected.front_road_id=-1;expected.road_direction=0
 check(city.public_facilities.lots[0]==expected,"removed host invalidates only binding, never attaches remote left")
 check(price==city.public_facilities.price(original.public_asset_id) and city.public_facilities.lots.size()==1,"facility and original price retained")
 for span in [Vector2(69.5,70.5),Vector2(69,70.5)]:
  var short_city=fixture()
  var before:Dictionary=short_city.public_facilities.lots[0].duplicate(true)
  var road:Dictionary=short_city.roads[0]
  var selection:Dictionary={"ok":true,"cuts":[]}
  for interval:Vector2 in [Vector2(0,span.x-2),Vector2(span.y-2,88)]:
   selection.cuts.append({"id":road.parcel_id,"first":interval.x,"last":interval.y,"points":short_city.RoadJunctions.slice(road.points,interval.x,interval.y)})
  check(short_city.demolish_road_selection(selection).ok,"trim host below 8m straight support")
  before.front_road_id=-1;before.road_direction=0
  check(short_city.public_facilities.lots[0]==before,"short straight host invalid without moving facility")
 var edge=fixture()
 var edge_record:Dictionary=edge.public_facilities.lots[0].duplicate(true)
 check(edge.demolish_road_unit(edge.roads[0].parcel_id,Vector2(70.6,40)).ok,"remove adjacent stop support")
 edge_record.front_road_id=-1;edge_record.road_direction=0
 check(edge.public_facilities.lots[0]==edge_record,"nearby remaining endpoint cannot snap retained stop")
 worker_test()
 print("BUS_STOP_HOST checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)

class HostAdapter extends "res://core/city_simulation_worker.gd":
 func export_validation()->Dictionary:
  return {"roads":city.roads.duplicate(true),"lots":city.public_facilities.lots.duplicate(true),"checkpoint":capture(city)}

func worker_test():
 var city=fixture()
 var Adapter=load("res://core/city_simulation_worker.gd")
 var probe=load("res://core/city_native_mailbox.gd").new()
 probe.Initialize(HostAdapter.new(),Adapter.capture(city));probe.Suspend()
 check(probe.GetWorkerThread()!=OS.get_thread_caller_id(),"native probe runs off main thread")
 city.enable_simulation_worker();city.simulation.worker.Suspend()
 city.simulation.edit_completed.connect(func(_result):journal=city.simulation._make_delta(city))
 var original:Dictionary=city.public_facilities.lots[0].duplicate(true)
 var selection:Dictionary=city.road_demolition_selection(city.roads[0].parcel_id,Vector2(40,40),Vector2(42,40))
 city.simulation.worker.SetValidationGate(true);city.advance_society(2)
 check(city.demolish_road_selection(selection).get("queued",false),"road split queues at real native gate")
 check(city.roads.size()==1 and city.public_facilities.lots[0]==original,"queued split leaves public stop unchanged")
 city.simulation.validation_publish()
 city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 check(city.roads.size()==2,"queued split replayed")
 var expected:Dictionary=original.duplicate(true);expected.front_road_id=city.roads[1].parcel_id
 check(city.public_facilities.lots[0]==expected,"FIFO split rebinds before next submission")
 submit_probe(city,probe,expected,"split")
 city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 city.simulation.resume();city.simulation.worker.SetValidationGate(true);city.advance_society(2)
 check(city.demolish("road",int(expected.front_road_id)).get("queued",false),"host deletion queues")
 check(city.public_facilities.lots[0]==expected,"pending host deletion does not invalidate early")
 city.simulation.validation_publish()
 city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 expected.front_road_id=-1;expected.road_direction=0
 check(city.public_facilities.lots[0]==expected,"FIFO host deletion invalidates retained record")
 submit_probe(city,probe,expected,"host deletion")
 city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 check(city.simulation.get_fault().is_empty(),"primary native worker accepts refreshed journals")
 city.simulation.shutdown();probe.Shutdown()

func submit_probe(city,probe,expected:Dictionary,label:String):
 var delta:Dictionary=journal.duplicate(true)
 check(delta.get("world",{}).has("roads") and delta.get("world",{}).has("public_lots"),label+" journal marks both roads and stops dirty")
 check(delta.get("world",{}).get("public_lots",[])==city.public_facilities.lots,label+" journal carries refreshed binding")
 # Replay the actual production journal into an independently observable native worker.
 delta.base_tick=probe.GetPublishedTick();delta.base_revision=probe.GetPublishedRevision()
 check(probe.Submit(delta,2),label+" native journal submitted")
 probe.Suspend();check(not probe.PublishBoundary().is_empty(),label+" native journal published")
 var state:Dictionary=probe.ExportValidationState()
 check(state.get("lots",[])==[expected] and state.get("roads",[])==city.roads,label+" native worker has exact roads and stop")
 var restored=HostAdapter.new();restored.boot(state.checkpoint)
 check(restored.city.public_facilities.lots==[expected] and restored.city.roads==city.roads,label+" checkpoint preserves exact binding and geometry")
