extends SceneTree
const Model=preload("res://core/city_model.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func fixture(exporting:bool):
 var c=Model.new(100,100);c.happiness_enabled=false
 c.buildings.append({"id":1,"x":20,"y":48,"size":2,"level":1,"zone":"residential","power_demand_kw":80.0,"water_demand_m3_day":20.0,"sewage_return_ratio":.8})
 c.next_id=2
 var port:Vector2=c.power.ports[0].position;var end:=Vector2(96,200)
 assert(c.power.add_wire(PackedVector2Array([port,end])).ok)
 assert(c.water.add_pipe(PackedVector2Array([port,end])).ok)
 if exporting:c.power.add_plant(end,200);c.water.add_facility(end,"water",100);c.water.add_facility(Vector2(64,200),"sewage",100)
 c.enable_taxation()
 return c
func run():
 var c=fixture(false)
 check(c.has_method("economic_status"),"scalar economic read facade exists")
 if not c.has_method("economic_status"):finish();return
 for exporting in [false,true]:
  c=fixture(exporting)
  check(c.economic_status().daily_net==null,"unclosed day is unavailable, not invented zero")
  var initial:float=c.utility_balance()
  # Real engine utility billing; no injected quotes or fabricated economic samples.
  for i in range(3600):c.advance_utilities(1)
  c.clock.game_seconds=86400;c._assess_tax_boundary()
  var s:Dictionary=c.economic_status()
  check(s.available and s.day==1,"complete tax and both real utility intervals close one day")
  check(is_equal_approx(s.daily_net,c.utility_balance()-initial),"realized daily net reconciles funds plus all fractional carries")
  if exporting:check(s.power_revenue>0 and s.water_revenue>0,"actual electricity and water exports count as income")
  else:check(s.power_expense>0 and s.water_expense>0,"actual electricity imports and water/sewage costs count as expense")
  check(s.interest==0,"interest remains explicitly zero until T4")
  var before:float=c.utility_balance();c.economic_status();c.tax_status();c.advance_utilities(0)
  check(c.utility_balance()==before and c.economic_status()==s,"read facade and pause do not meter or collect")
  var hud=load("res://bottom_ui.gd").new()
  hud.city=c;hud.money=Label.new();hud.balance_label=Label.new();hud.city_name_button=Button.new();hud.date_label=Label.new();hud.happiness_label=Label.new();hud.population_label=Label.new()
  hud.refresh_status()
  check(hud.monthly_balance==roundi(s.daily_net),"HUD reads actual closed economic net instead of fabricated fixture value")
  for control in [hud.money,hud.balance_label,hud.city_name_button,hud.date_label,hud.happiness_label,hud.population_label]:control.free()
  hud.free()
 # Native day-boundary upkeep is recorded once, not inferred from current inventory.
 c=Model.new();c.happiness_enabled=false;c.enable_taxation()
 var asset:String=c.public_facilities.entries.keys()[0]
 c.public_facilities.lots.append({"id":90000,"public_asset_id":asset})
 c.clock.game_seconds=86400-48;c.utilities.elapsed=86400-48
 c.enable_simulation_worker();c.simulation.worker.Suspend();var before:int=c.funds
 c.advance_society(2);check(c.simulation.validation_publish(),"native upkeep day publication")
 check(c.funds==before-c.public_facilities.monthly_upkeep(),"actual native upkeep debit exactly once")
 check(c._tax_day_economy.facility_upkeep==c.public_facilities.monthly_upkeep(),"published upkeep is actual worker debit")
 c.simulation.shutdown()
 c=fixture(false);c.utilities.elapsed=10*86400+24
 c.advance_utilities(3600-1);c.clock.game_seconds=11*86400;c._assess_tax_boundary()
 check(not c.economic_status().available,"old save partial utility day is unavailable, never invented as full history")
 c.advance_utilities(3600);c.clock.game_seconds=12*86400;c._assess_tax_boundary()
 check(c.economic_status().available and c.economic_status().day==12,"old save resumes economic reports after one complete metered day")
 c=fixture(false)
 c.population.configure_labor_policy({"enabled":false})
 var work:Dictionary={"id":2,"x":24,"y":48,"size":2,"level":1,"zone":"commercial"}
 c.buildings.append(work);c.next_id=3;c.population.record_building(work)
 c.population.import_fixture_state({"people":[{"id":1,"household_id":1,"education":0,"age_years":25.0,"origin":"fixture","workplace_id":2,"job_stage":0}],"households":[{"id":1,"home_id":1}],"next_person":2,"next_household":2,"tax_policy":c.population.core.ExportTaxCheckpoint()})
 c.population.sync(c.buildings)
 c.clock.game_seconds=86400-48;c.utilities.elapsed=86400-72;c.power.pending_doth=-.999999
 c.enable_simulation_worker();c.simulation.worker.Suspend();c.simulation.worker.SetValidationGate(true)
 c.advance_society(2);before=c.funds
 c.advance_utilities(1)
 var after_meter:int=c.funds
 check(after_meter<before,"real utility metering posts a main-thread debit during pending tax step")
 c.simulation.validation_publish()
 check(c.tax_status().collected>0 and c.funds==after_meter+int(c.tax_status().posted),"worker tax credit preserves concurrent actual utility debit exactly")
 c.simulation.shutdown()
 finish()
func finish():
 print("TAX_ECONOMIC_STATUS checks=%d failed=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
