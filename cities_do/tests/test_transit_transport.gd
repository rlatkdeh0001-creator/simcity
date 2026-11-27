extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label)
func _initialize():run.call_deferred()
func connected(city,edge:String,kind:String)->int:
 for town:Dictionary in city.regional_exchange().neighbors:
  if town.edge==edge:return int(town.channels[kind].connection_count)
 return -1
func run():
 var city=load("res://core/city_model.gd").new(100,100,42)
 city.population_enabled=false;city.happiness_enabled=false
 var rail:Dictionary=city.add_transit_route(PackedVector2Array([Vector2(0,10),Vector2(20,10)]),"rail")
 check(connected(city,"x_min","rail")==1,"boundary rail automatically registers independent neighbor channel")
 var metro:Dictionary=city.add_transit_route(PackedVector2Array([Vector2(80,90),Vector2(100,90)]),"metro")
 check(connected(city,"x_max","metro")==1,"boundary metro channel")
 var manual:Dictionary=city.add_external_link("rail",PackedVector2Array([Vector2(0,70),Vector2(20,70)]))
 city.enable_simulation_worker();city.simulation.worker.Suspend()
 var update:Dictionary=city.update_transit_route(rail.route.id,PackedVector2Array([Vector2(10,10),Vector2(30,10)]))
 check(update.ok and connected(city,"x_min","rail")==1,"moving route interior removes only managed link")
 var delta:Dictionary=city.simulation._make_delta(city)
 check(delta.get("world",{}).get("transit_routes",[])==city.transit_routes,"world journal contains full independent routes")
 city.advance_society(2);city.simulation.validation_publish()
 var state:Dictionary=city.simulation.export_validation_state()
 check(state.get("transit_routes",[])==city.transit_routes,"worker receives route update")
 check(state.external_infrastructure==city.external_infrastructure,"worker receives route-owned channel unlink")
 city.simulation.resume()
 var transient:Dictionary=city.add_transit_route(PackedVector2Array([Vector2(40,80),Vector2(60,80)]),"metro")
 city.remove_transit_route(transient.route.id)
 city.remove_transit_route(rail.route.id);city.remove_transit_route(metro.route.id)
 city.advance_society(2);city.simulation.validation_publish()
 state=city.simulation.export_validation_state()
 check(state.has("transit_routes") and state.transit_routes.is_empty(),"worker explicit empty replacement removes final route")
 check(state.external_infrastructure.size()==1 and state.external_infrastructure[0].id==manual.link.id,"manual external link survives all transit deletion")
 check(state.get("next_transit_route_id",-1)==city.next_transit_route_id,"create-delete in one delta preserves ID high watermark")
 city.simulation.shutdown()
 # Checkpoint restoration includes routes even when no new delta exists.
 var source=load("res://core/city_model.gd").new(100,100,19)
 source.population_enabled=false;source.happiness_enabled=false
 source.add_transit_route(PackedVector2Array([Vector2(0,10),Vector2(20,10)]),"rail")
 var Adapter=load("res://core/city_simulation_worker.gd")
 var adapter=Adapter.new()
 check(adapter.boot(Adapter.capture(source)).ok,"checkpoint boot succeeds")
 check(adapter.city.transit_routes==source.transit_routes and adapter.city.next_transit_route_id==source.next_transit_route_id,"checkpoint retains routes and allocator")
 for failure in failures:printerr("FAIL "+failure)
 print("TRANSIT_TRANSPORT checks=%d failed=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
