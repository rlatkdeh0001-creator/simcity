extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize():run.call_deferred()
func mutate_park(city,id:int):
 if city._defer_simulation_edit(mutate_park.bind(city,id)):return
 for lot:Dictionary in city.public_facilities.lots:
  if lot.id==id:lot.effect_enabled=not lot.effect_enabled;lot.capacity["test_metadata"]=17
 city._simulation_world_changed()
func test_bus_facility_fifo():
 var city=load("res://tests/test_scheduled_buses.gd").fixture(4)
 city.create_transit_line("bus",city.public_facilities.lots.map(func(lot):return lot.id),{"dwell_seconds":1.0})
 city.enable_simulation_worker()
 for i in range(3):city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 check(city.transit_state.bus.vehicles.size()==1 and city.transit_state.bus.vehicles[0].distance>0,"native worker bus already moving before park edits")
 var park_id:int=city.next_id
 var key:int=city.transit_state.bus.topology_key
 var route:Array=city.transit_state.bus.vehicles[0].route.duplicate()
 for edit:String in ["add","mutation","remove"]:
  city.simulation.worker.Suspend();city.simulation.worker.SetValidationGate(true);city.advance_society(2)
  var before:Dictionary=city.transit_state.duplicate(true)
  if edit=="add":check(city.public_facilities.place("park-plaza-4x4",Vector2(50,26),0,true).get("queued",false),"park placement queued at native gate")
  elif edit=="mutation":mutate_park(city,park_id)
  else:city.public_facilities.remove(park_id)
  check(city.transit_state==before,"queued park "+edit+" does not speculatively advance bus")
  city.simulation.validation_publish()
  for i in range(2):city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
  var parks:Array=city.public_facilities.lots.filter(func(lot):return lot.id==park_id)
  check(parks.is_empty() if edit=="remove" else parks.size()==1,"FIFO park "+edit+" applied")
  if edit=="mutation":check(parks.size()==1 and parks[0].capacity.get("test_metadata",0)==17,"queued metadata mutation applied")
  var bus:Dictionary=city.transit_state.bus.vehicles[0]
  check(city.transit_state.lines[1].status!="blocked" and bus.distance>before.bus.vehicles[0].distance and bus.route==route and city.transit_state.bus.topology_key==key,"native publication continues same bus route after park "+edit)
 var Adapter=load("res://core/city_simulation_worker.gd")
 var restored=Adapter.new();restored.boot(Adapter.capture(city))
 var expected:Dictionary=restored.run_step({"base_tick":0,"base_revision":0},2.0,1)
 city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 check(city.transit_state==expected.transit_state,"native park-edited bus checkpoint continuation deterministic")
 city.simulation.shutdown()
func run():
 test_bus_facility_fifo()
 var city=load("res://tests/transit_operations_fixture.gd").rail_city()
 city.enable_simulation_worker();city.simulation.worker.Suspend()
 city.simulation.worker.SetValidationGate(true);city.advance_society(2)
 var stops:Array=city.public_facilities.lots.map(func(lot):return lot.id)
 check(city.create_transit_line("rail",stops).get("queued",false),"line creation queues at native worker gate")
 check(city.transit_lines.is_empty() and city.transit_state.visible.is_empty(),"no speculative line allocation or cars")
 var clock:float=city.clock.game_seconds
 city.advance_society(100)
 check(city.transit_state.seconds==0 and city.clock.game_seconds==clock,"busy worker freezes accepted transit time")
 city.simulation.validation_publish()
 for i in range(4):city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 check(city.transit_lines.size()==1,"FIFO replay creates one line")
 check(city.transit_state.visible.size()==3,"native publication delivers full train")
 var before:Dictionary=city.transit_snapshot()
 before.visible.clear()
 check(city.transit_state.visible.size()==3,"read snapshot cannot mutate published state")
 var frozen:=var_to_bytes(city.transit_state)
 city.advance_society(0)
 check(var_to_bytes(city.transit_state)==frozen,"pause does not advance operational state")
 city.simulation.shutdown()
 print("TRANSIT_OPERATIONS_FIFO checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
