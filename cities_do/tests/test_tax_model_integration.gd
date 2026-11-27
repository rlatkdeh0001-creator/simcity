extends SceneTree
const Model=preload("res://core/city_model.gd")
const Adapter=preload("res://core/city_simulation_worker.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func town():
 var c=Model.new(100,100)
 c.happiness_enabled=false
 c.population.configure_labor_policy({"enabled":false})
 c.buildings.assign([{"id":1,"zone":"residential","size":2,"level":1,"x":10,"y":10},{"id":2,"zone":"commercial","size":2,"level":1,"x":15,"y":10}])
 c.next_id=3
 c.population.import_fixture_state({"people":[{"id":1,"household_id":1,"education":0,"age_years":25.0,"origin":"fixture","workplace_id":2,"job_stage":0}],"households":[{"id":1,"home_id":1}],"next_person":2,"next_household":2})

 c.population.enable_geometry_transport(c.buildings);c.population.sync(c.buildings)
 return c
func step(c):
 c.simulation.resume();c.advance_society(2);check(c.simulation.validation_publish(),"native step publication")
func run():
 var c=town()
 check(c.has_method("enable_taxation"),"production taxation opt-in API exists")
 if not c.has_method("enable_taxation"):finish();return
 c.enable_taxation()
 check(not c.configure_tax_policy({"rates":[9.5,9,9,9,9,9,9,9,9]}).ok,"invalid config rejected before worker mutation")
 check(c.tax_status().enabled,"explicit production opt-in")
 c.clock.game_seconds=86400-48
 var opening:int=c.funds
 c.enable_simulation_worker();c.simulation.worker.Suspend()
 c.advance_society(0)
 check(c.clock.game_seconds==86400-48 and c.funds==opening,"paused time cannot assess")
 c.simulation.worker.SetValidationGate(true)
 c.advance_society(2)
 c.advance_society(3600)
 check(c.clock.game_seconds==86400-48 and c.funds==opening,"gated native busy cycles freeze clock and cannot credit tax")
 check(c.configure_tax_policy({"rates":[10,9,9,11,9,9,9,9,9]}).queued,"busy tax edit queued")
 check(c.configure_tax_policy({"rates":[12,9,9,13,9,9,9,9,9]}).queued,"second busy edit queued FIFO")
 c.funds-=7 # Real concurrent main transaction must survive publication.
 check(c.simulation.validation_publish(),"first day published")
 var status:Dictionary=c.tax_status()
 check(status.is_read_only() and status.cells.is_read_only() and status.cells[0].is_read_only(),"native tax scalar publication is deeply immutable")
 check(status.last_day==1 and status.collected>0,"actual worker boundary assesses employed income")
 check(c.funds==opening-7+int(status.posted),"worker-only tax credit preserves concurrent transaction")
 check(is_equal_approx(c.utility_balance(),float(c.funds)+float(status.carry)),"tax carry included in effective funds")
 var after:int=c.funds
 check(not c.simulation.validation_publish() and c.funds==after,"repeated publication cannot credit twice")
 c.advance_society(3600)
 check(c.funds==after and c.clock.day()==1,"suspended/frozen time cannot tax")
 step(c)
 check(c.tax_status().policy.rates[0]==12 and c.tax_status().policy.rates[3]==13,"FIFO policy commands reach worker")
 check(c.tax_status().collected_total==status.collected_total,"policy edit never reassesses same day")
 var state:Dictionary=c.simulation.export_validation_state()
 var cp:Dictionary=Adapter.capture(town())
 cp.population=state.population
 cp.model.values.clock.values.game_seconds=state.clock_seconds
 var restored=Adapter.new();restored.boot(cp)
 check(restored.city.tax_status().policy==c.tax_status().policy,"restore exact tax policy")
 check(restored.city.population.core.ExportTaxCheckpoint()==state.population.tax_policy,"restore exact carry/day ledger")
 var money:int=restored.city.funds;restored.city.advance_society(2)
 check(restored.city.funds==money,"restore same day does not rebill")
 restored.city.clock.game_seconds=2*86400-48;restored.city.advance_society(2)
 check(restored.city.tax_status().last_day==2 and restored.city.tax_status().collected_total>status.collected_total,"restored enabled checkpoint remains active next day")
 cp.population.erase("tax_policy");cp.model.values.clock.values.game_seconds=10*86400.0
 var old=Adapter.new();old.boot(cp)
 check(old.city.tax_status().last_day==10 and old.city.tax_status().collected_total==0,"old-save watermark established without retrobilling")
 check(old.city.tax_status().enabled,"old production save enables taxation only after establishing watermark")
 old.city.advance_society(2)
 check(old.city.tax_status().collected_total==0,"old save enable cannot charge historical days")
 c.simulation.shutdown()
 c=Model.new(100,100);c.happiness_enabled=false
 assert(c.add_road(PackedVector2Array([Vector2(10,40),Vector2(70,40)])).ok)
 var home:Dictionary={};var work:Dictionary={}
 for parcel in c.zoning_grid.parcels.values():
  var built:Dictionary=c.add_building_at(parcel.center,"residential" if home.is_empty() else "commercial")
  if not built.ok:continue
  if home.is_empty():home=built.building
  else:work=built.building;break
 c.population.import_fixture_state({"people":[{"id":1,"household_id":1,"education":0,"age_years":25.0,"origin":"fixture","workplace_id":-1,"job_stage":-1}],"households":[{"id":1,"home_id":home.id}],"next_person":2,"next_household":2})
 c.population.sync(c.buildings);c.enable_taxation();c.clock.game_seconds=86400-48
 c.enable_simulation_worker();c.simulation.worker.Suspend();c.advance_society(2);c.simulation.validation_publish()
 check(c.tax_status().zones.residential.collected>0 and c.tax_status().zones.commercial.collected>0,"real legal road/local employment feeds both worker tax bases")
 check(c.simulation.export_validation_state().population.labor_policy.enabled,"tax integration preserves production labor opt-in")
 c.simulation.shutdown()
 root.size=Vector2i(1280,820)
 var household_city=town();household_city.happiness_enabled=true
 household_city.enable_taxation();household_city.configure_tax_policy({"wages":[0,0,0,0,0]})
 household_city.advance_happiness(3600)
 var happiness_checkpoint:Dictionary=household_city.happiness.core.ExportCityCheckpoint()
 happiness_checkpoint.elapsed=86400.0-48.0;happiness_checkpoint.next_day=86400.0
 household_city.happiness.core.ImportCityCheckpoint(happiness_checkpoint)
 household_city.clock.game_seconds=86400.0-48.0
 household_city.enable_simulation_worker();household_city.simulation.worker.Suspend()
 step(household_city)
 check(household_city.happiness.inspect(1).factors.goods==-15,"native same-day happiness consumes settled necessities, not yesterday fulfillment")
 var finance_summary:Dictionary=household_city.tax_status().household_finances
 check(finance_summary.is_read_only() and finance_summary.goods_cost>0 and finance_summary.goods_paid==0,"native immutable small household summary publishes actual shortages")
 household_city.simulation.shutdown()
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);game.set_process(false)
 await process_frame
 check(game.city.tax_status().enabled,"actual production scene explicitly opts in")
 var frozen:int=game.city.funds;var seconds:float=game.city.clock.game_seconds
 game._process(3600)
 check(game.city.funds==frozen and game.city.clock.game_seconds==seconds and game.city.tax_status().collected_total==0,"actual production pause cannot tax or advance clock")
 game.queue_free();await process_frame
 finish()
func finish():
 print("TAX_MODEL_INTEGRATION checks=%d failed=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
