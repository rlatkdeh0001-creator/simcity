extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label)
func _initialize():run.call_deferred()
func run():
 var Model=load("res://core/city_model.gd")
 var city=Model.new(100,100,42)
 city.population_enabled=false;city.happiness_enabled=false
 var first:Dictionary=city.add_transit_route(PackedVector2Array([Vector2(0,10),Vector2(20,10)]),"rail")
 var link_id:int=city.external_infrastructure[0].id
 check(not city.remove_external_link(link_id),"managed boundary link can only be removed with its route")
 city.enable_simulation_worker();city.simulation.worker.Suspend()
 city.simulation.worker.SetValidationGate(true);city.advance_society(2)
 var frozen:float=city.clock.game_seconds
 var next_id:int=city.next_transit_route_id
 var queued:Dictionary=city.add_transit_route(PackedVector2Array([Vector2(40,40),Vector2(60,40)]),"metro")
 check(queued.get("queued",false),"create queues behind real worker gate")
 check(city.update_transit_route(first.route.id,PackedVector2Array([Vector2(0,12),Vector2(20,12)])).get("queued",false),"update queues")
 check(city.remove_transit_route(first.route.id).get("queued",false),"delete queues")
 check(city.transit_routes.size()==1 and city.next_transit_route_id==next_id,"busy intents allocate nothing")
 city.advance_society(2)
 check(city.clock.game_seconds==frozen,"busy native worker does not advance logical time")
 city.simulation.validation_publish()
 city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 # Publication/replay may leave a second transport prefix; drain without wall-clock timers.
 city.simulation.resume();city.advance_society(2);city.simulation.validation_publish()
 check(city.transit_routes.size()==1 and city.transit_routes[0].kind=="metro","FIFO create update delete leaves metro")
 var state:Dictionary=city.simulation.export_validation_state()
 check(state.transit_routes==city.transit_routes and state.external_infrastructure.is_empty(),"worker sees FIFO routes and disconnection")
 check(city.funds==50000,"route transport does not invent construction charges")
 city.simulation.shutdown()
 var Adapter=load("res://core/city_simulation_worker.gd")
 var source=Model.new(100,100,19);source.population_enabled=false;source.happiness_enabled=false
 var adapter=Adapter.new();adapter.boot(Adapter.capture(source))
 var delta:Dictionary={"base_tick":0,"base_revision":0,"revision":1,"world":{"transit_routes":[{"id":1,"kind":"rail","points":PackedVector2Array([Vector2(2,2),Vector2(4,2)]),"width":99}]}}
 var rejected:Dictionary=adapter.run_step(delta,2,1)
 check(not rejected.ok and adapter.city.transit_routes.is_empty(),"worker rejects malformed transit snapshot atomically")
 for failure in failures:printerr("FAIL "+failure)
 print("TRANSIT_FIFO checks=%d failed=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
