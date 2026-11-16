extends SceneTree
const Model=preload("res://core/city_model.gd")
var checks:=0
var failed:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failed+=1;push_error(label)
func _initialize():run.call_deferred()
func town(seed_value:int):
 var c=Model.new(100,100,seed_value)
 assert(c.add_road(PackedVector2Array([Vector2(10,40),Vector2(42,40)])).ok)
 var n:=0
 for frame:Dictionary in c.zoning_grid.frames.values():
  if n==8:break
  c.paint_zones(c.Parcels.polygon(frame,0,0,2),"residential" if n%4<2 else ("commercial" if n%4==2 else "industrial"));n+=1
 for i in range(90):c.advance_society(2)
 return c
func geometry(c)->Array:
 var rows:Array=[]
 for b:Dictionary in c.buildings:
  var row:Dictionary=b.duplicate(true)
  for key in ["happiness","happiness_target","happiness_factors"]:row.erase(key)
  rows.append(row)
 return rows
func run():
 # Exercise the actual Model opt-in and all main publication hooks, not only the backend.
 for seed_value in [42,20261114]:
  var c=town(seed_value);var oracle=town(seed_value)
  c.enable_simulation_worker();c.simulation.worker.Suspend()
  for tick in range(5400):
   c.advance_society(2);c.simulation.validation_publish();c.simulation.resume();oracle.advance_society(2)
   check(geometry(c)==geometry(oracle),"geometry seed=%d tick=%d"%[seed_value,tick])
   check(c.population.stats()==oracle.population.stats(),"population stats")
   check(c.population.rng.state==oracle.population.rng.state and c.rng.state==oracle.rng.state and c.appearance_rng.state==oracle.appearance_rng.state,"all RNG roots")
   check(c.clock.game_seconds==oracle.clock.game_seconds and c.funds==oracle.funds and c.next_id==oracle.next_id,"clock/funds/IDs")
   check(c.happiness.average_value()==oracle.happiness.average_value(),"resident-weighted published average")
   for b:Dictionary in c.buildings:check(c.happiness.inspect(b.id)==oracle.happiness.inspect(b.id),"published per-building happiness")
   if tick%1800==1799:
    var state:Dictionary=c.simulation.export_validation_state()
    check(state.population==oracle.population.core.ExportCityCheckpoint(),"complete population/checkpoint at day boundary")
  c.simulation.shutdown()
 # Main clock publication must not bill public upkeep a second time.
 var c=Model.new();var oracle=Model.new()
 for target in [c,oracle]:
  target.happiness_enabled=false
  var asset:String=target.public_facilities.entries.keys()[0]
  target.public_facilities.lots.append({"id":90000,"public_asset_id":asset})
  target.clock.game_seconds=86400.0-48.0
 c.enable_simulation_worker();c.simulation.worker.Suspend()
 c.advance_society(2);c.simulation.validation_publish();oracle.advance_society(2)
 check(c.funds==oracle.funds,"day-boundary public upkeep billed exactly once through actual Model facade")
 c.simulation.shutdown()
 print("CITY_SIMULATION_MODEL checks=%d failed=%d seeds=2 logical_ticks_each=5400"%[checks,failed])
 quit(1 if failed else 0)
