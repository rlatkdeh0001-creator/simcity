extends SceneTree
var checks:=0
var failed:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failed+=1;printerr("FAIL "+label)
func _initialize():run.call_deferred()
func run():
 var city=load("res://core/city_model.gd").new(100,100,42)
 check(city.population.has_method("configure_labor_policy"),"production model exposes configured labor policy")
 if not city.population.has_method("configure_labor_policy"):finish();return
 check(city.population.demand(city.buildings).residential==4,"production bootstrap eight household units requests four 2x2 buildings")
 city.enable_simulation_worker();city.simulation.worker.Suspend()
 city.advance_society(2);city.simulation.validation_publish()
 var state:Dictionary=city.simulation.export_validation_state()
 check(state.population.has("labor_policy") and state.population.labor_policy.enabled,"worker checkpoint preserves production labor opt-in")
 check(city.population.demand(city.buildings).residential==4,"immutable native demand publishes new labor units")
 city.simulation.shutdown()
 finish()
func finish():
 print("LABOR_MODEL_INTEGRATION checks=%d failed=%d"%[checks,failed]);quit(1 if failed else 0)
