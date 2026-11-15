extends SceneTree
const City=preload("res://core/city_model.gd")
class CountedCity extends "res://core/city_model.gd":
 var power_calls:=0
 var water_calls:=0
 func power_consumers()->Array:power_calls+=1;return super.power_consumers()
 func water_consumers()->Array:water_calls+=1;return super.water_consumers()
var checks:=0
var failures:=0
func verify(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error("FAIL "+label)
 else:print("PASS "+label)
func _initialize():run.call_deferred()
func fixture(exporting:bool=false):
 var c=CountedCity.new(100,100)
 c.buildings.append({"id":1,"asset_id":"","score":0,"x":20,"y":48,"size":2,"level":1,"zone":"residential","power_demand_kw":80.0,"water_demand_m3_day":20.0,"sewage_return_ratio":.8})
 var port:Vector2=c.power.ports[0].position
 var end:=Vector2(96,200)
 assert(c.power.add_wire(PackedVector2Array([port,end])).ok)
 assert(c.water.add_pipe(PackedVector2Array([port,end])).ok)
 if exporting:c.power.add_plant(end,200);c.water.add_facility(end,"water",100);c.water.add_facility(Vector2(64,200),"sewage",100)
 return c
func run():
 var c=fixture()
 verify(c.get("utilities")!=null,"production city owns a staggered utility scheduler")
 if failures:quit(1);return
 c.advance_utilities(0)
 verify(c.power_calls==1 and c.water_calls==1,"startup primes both snapshots once without billing")
 for i in range(9):c.advance_utilities(.1)
 verify(c.power_calls==1 and c.water_calls==1,"ordinary frames do not rebuild consumers or solve networks")
 c.advance_utilities(.1)
 verify(c.power_calls==1 and c.water_calls==2,"water updates at game second 24, one real second before power")
 c.advance_utilities(1)
 verify(c.power_calls==2 and c.water_calls==2,"power updates at game second 48 and keeps its independent phase")
 var generation:int=c.utilities.power_generation;c.power.set_output(c.power.add_plant(Vector2(96,200),200),0)
 verify(c.utilities.power_dirty and c.utilities.power_generation==generation,"generation changes mark dirty without applying a solve")
 c.advance_utilities(1.99)
 verify(c.utilities.power_generation==generation,"dirty changes never force an early calculation")
 c.advance_utilities(.01)
 verify(not c.utilities.power_dirty and c.utilities.power_generation==generation+1,"dirty state applies at the next fixed deadline within two seconds")
 var funds:float=c.utility_balance();c.advance_utilities(0);c.advance_utilities(-1)
 verify(c.utility_balance()==funds,"paused or invalid deltas do not accrue utility charges")
 for exporting in [false,true]:
  var cached=fixture(exporting);var legacy=fixture(exporting)
  for i in range(3600):
   cached.advance_utilities(1)
   legacy.advance_power(legacy.Clock.SCALE/3600);legacy.advance_water(legacy.Clock.SCALE/86400)
  verify(absf(cached.utility_balance()-legacy.utility_balance())<.0000001,"one game day of frame-by-frame charges equals cached metering; exporting="+str(exporting))
  verify(absf(cached.power.imported_kwh-legacy.power.imported_kwh)<.0000001 and absf(cached.power.exported_kwh-legacy.power.exported_kwh)<.0000001,"all kWh are retained between staggered calculations")
  verify(absf(cached.water.supplied_m3-legacy.water.supplied_m3)<.0000001 and absf(cached.water.exported_sewage_m3-legacy.water.exported_sewage_m3)<.0000001,"all water and sewage volumes are retained")
 for fps in [30,60]:
  var cached=fixture();var legacy=fixture()
  for city in [cached,legacy]:city.funds=0;city.power.pending_doth=.003;city.water.pending_doth=.002
  for i in range(fps*20):
   cached.advance_utilities(1.0/fps);legacy.advance_power(legacy.Clock.SCALE/(3600*fps));legacy.advance_water(legacy.Clock.SCALE/(86400*fps))
  verify(absf(cached.utility_balance()-legacy.utility_balance())<.000000001,"shared fractional funds exhaust identically at "+str(fps)+" FPS")
  verify(absf(cached.power.imported_kwh-legacy.power.imported_kwh)<.0000001 and absf(cached.water.imported_water_m3-legacy.water.imported_water_m3)<.0000001 and absf(cached.water.exported_sewage_m3-legacy.water.exported_sewage_m3)<.0000001,"budget-limited power/water priority preserves every traded volume")
 root.size=Vector2i(1280,820)
 var game=load("res://main.tscn").instantiate();game.city=fixture();game.city.population_enabled=false;game.paused=true;root.add_child(game);game.set_process(false);await process_frame
 game._process(5)
 verify(game.city.utilities.elapsed==0,"the production pause control freezes utility time and charges")
 game.paused=false;game.simulation_speed=2;game._process(.5)
 verify(game.city.utilities.power_generation==1 and game.city.utilities.water_generation==2,"the production 2x control halves the real-time water deadline")
 game._process(.5)
 verify(game.city.utilities.power_generation==2 and game.city.utilities.water_generation==2,"the production 2x control halves the real-time power deadline")
 game.power_overlay.tab_open=true;game.power_overlay.update_state(0);var text:String=game.power_overlay.summary.text
 game._process(.1)
 verify(game.power_overlay.summary.text==text,"open overlay numbers stay latched between actual calculation times")
 var calls:int=game.city.power_calls;game.power_overlay.refresh()
 verify(game.city.power_calls==calls,"tab/edit refreshes mark dirty instead of forcing a network solve")
 game.queue_free();await process_frame
 print("RESULT %d/%d utility cadence checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
