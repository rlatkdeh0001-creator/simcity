extends SceneTree
var checks:=0
var failures:Array=[]
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label)
func _initialize():run.call_deferred()
func run():
 var city=load("res://core/city_model.gd").new(100,100,42)
 city.enable_simulation_worker();city.simulation.worker.Suspend()
 var result:Dictionary=city.add_external_link("rail",PackedVector2Array([Vector2(0,10),Vector2(20,10)]))
 check(result.ok,"real regional rail link is valid")
 var delta:Dictionary=city.simulation._make_delta(city)
 check(delta.get("world",{}).get("external_infrastructure",[])==city.external_infrastructure,"external links enter owned worker delta")
 city.advance_society(2);city.simulation.validation_publish()
 var state:Dictionary=city.simulation.export_validation_state()
 check(state.get("external_infrastructure",[])==city.external_infrastructure,"worker receives regional connection data before commuting")
 city.simulation.resume()
 check(city.remove_external_link(result.link.id),"regional unlink succeeds")
 delta=city.simulation._make_delta(city)
 check(delta.get("world",{}).has("external_infrastructure"),"last-link removal sends explicit empty replacement")
 city.advance_society(2);city.simulation.validation_publish()
 state=city.simulation.export_validation_state()
 check(state.has("external_infrastructure") and state.external_infrastructure.is_empty(),"worker removes disconnected commuting channel")
 city.simulation.shutdown()
 for failure in failures:printerr("FAIL "+str(failure))
 print("COMMUTING_TRANSPORT checks=%d failed=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
