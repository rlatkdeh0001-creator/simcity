extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize():run.call_deferred()
func run():
 var city=load("res://core/city_model.gd").new(100,100,42)
 city.population_enabled=false;city.happiness_enabled=false
 city.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
 city.enable_simulation_worker();city.simulation.worker.Suspend()
 city.simulation.worker.SetValidationGate(true);city.advance_society(2)
 var id:int=city.next_id;var route_id:int=city.next_transit_route_id
 check(city.public_facilities.place("train-station-01",Vector2(30,33),0,true).get("queued",false),"station queues at real worker gate")
 check(city.public_facilities.lots.is_empty() and city.transit_routes.is_empty(),"queued placement mutates neither inventory")
 city.public_facilities.remove(id)
 city.public_facilities.place("train-station-01",Vector2(50,33),0,true)
 city.simulation.validation_publish()
 for i in range(3):
  city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 check(city.public_facilities.lots.size()==1 and city.transit_routes.size()==1,"FIFO place remove place atomic pair")
 check(city.next_transit_route_id==route_id+2,"consumed internal route IDs preserved")
 var state:Dictionary=city.simulation.export_validation_state()
 check(state.transit_routes==city.transit_routes,"worker receives owned internal rail")
 city.simulation.shutdown()
 var Adapter=load("res://core/city_simulation_worker.gd")
 var restored=Adapter.new();restored.boot(Adapter.capture(city))
 check(restored.city.public_facilities.lots==city.public_facilities.lots,"checkpoint restores station and ports")
 check(restored.city.transit_routes==city.transit_routes,"checkpoint restores rail owner")
 print("TRANSIT_FACILITIES_FIFO checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
