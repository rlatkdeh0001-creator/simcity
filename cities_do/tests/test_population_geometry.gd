extends SceneTree
const Population=preload("res://core/population.gd")
class CountingPopulation:
 extends "res://core/population.gd"
 var packs:=0
 func _pack_buildings(buildings:Array)->PackedInt64Array:
  packs+=1
  return super._pack_buildings(buildings)
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label)
func snapshot(pop)->Array:
 var state:Dictionary=pop.core.ExportState()
 return [state,pop.rng.state,pop.next_person,pop.next_household,pop.elapsed_days,pop.birth_day]
func _initialize():run.call_deferred()
func run():
 var managed=CountingPopulation.new(51)
 var legacy=Population.new(51)
 var buildings:Array=[{"id":9,"zone":"residential","size":2,"level":2},{"id":3,"zone":"commercial","size":2,"level":1},{"id":7,"zone":"residential","size":4,"level":1},{"id":2,"zone":"industrial","size":2,"level":1}]
 managed.enable_geometry_transport(buildings)
 check(managed.packs==1,"activation packs full geometry exactly once")
 managed.record_building(buildings[0]);managed.remove_building(999)
 check(managed.core.GetGeometryCount()==4,"unchanged update and unknown removal preserve geometry count")
 for tick in range(48):
  if tick==4:
   buildings[0].level=3;managed.record_building(buildings[0])
  if tick==8:
   managed.remove_building(buildings[1].id);buildings.remove_at(1)
  if tick==12:
   buildings.append({"id":3,"zone":"industrial","size":4,"level":1});managed.record_building(buildings[-1])
  if tick==16:
   buildings[0].zone="commercial";managed.record_building(buildings[0])
  if tick==20:
   buildings[1].size=2;managed.record_building(buildings[1])
  if tick==24:
   for pop in [managed,legacy]:pop.config.working_age_years=30.0
  if tick==28:
   for pop in [managed,legacy]:pop.import_fixture_state(pop.core.ExportState())
  for pop in [managed,legacy]:
   pop.begin_tick();pop.advance(3600,buildings)
  check(snapshot(managed)==snapshot(legacy),"managed state/RNG/order parity tick="+str(tick))
  check(managed.demand(buildings)==legacy.demand(buildings),"demand parity tick="+str(tick))
  if tick%7==0:
   buildings[-1].level=1+(tick%3);managed.record_building(buildings[-1])
   for pop in [managed,legacy]:pop.sync(buildings)
   check(snapshot(managed)==snapshot(legacy) and managed.demand(buildings)==legacy.demand(buildings),"same-tick delta/matching parity tick="+str(tick))
  for pop in [managed,legacy]:pop.end_tick()
  var scans:int=managed.demand_full_scans
  for read in range(3):
   check(managed.stats()==legacy.stats(),"cached stats parity")
   check(managed.demand(buildings)==legacy.demand(buildings),"cached HUD demand parity")
  check(managed.demand_full_scans==scans,"HUD demand reads do not rescan")
 check(managed.packs==1,"advance/sync/demand never repack managed geometry")
 var stats_copy:Dictionary=managed.stats()
 stats_copy.population=-999
 var demand_copy:Dictionary=managed.demand(buildings)
 demand_copy.residential=-999
 check(managed.stats()==legacy.stats() and managed.demand(buildings)==legacy.demand(buildings),"HUD dictionaries cannot mutate cached snapshots")
 # Explicit sync and same-tick demand after a capacity delta.
 buildings[-1].level=2;managed.record_building(buildings[-1])
 for pop in [managed,legacy]:pop.sync(buildings)
 check(snapshot(managed)==snapshot(legacy) and managed.demand(buildings)==legacy.demand(buildings),"delta sync parity")
 # Missed add notification: recover once and tell the caller, never silently stale.
 var recoveries:Array=[]
 managed.geometry_transport_recovered.connect(func(expected:int,actual:int):recoveries.append([expected,actual]))
 buildings.append({"id":99,"zone":"residential","size":2,"level":1})
 managed.sync(buildings);legacy.sync(buildings)
 check(managed.packs==2 and recoveries==[[4,5]],"count mismatch reseeds once and emits recovery")
 managed.sync(buildings)
 check(managed.packs==2,"recovered geometry is persistent")
 check(snapshot(managed)==snapshot(legacy),"recovery state parity")
 # Empty cache uses an initialized, zero-count seed rather than an initial-fallback loop.
 for b:Dictionary in buildings:managed.remove_building(b.id)
 buildings.clear()
 for pop in [managed,legacy]:pop.sync(buildings)
 check(snapshot(managed)==snapshot(legacy) and managed.demand(buildings)==legacy.demand(buildings),"all-building removal parity")
 managed.sync(buildings);managed.demand(buildings)
 check(managed.packs==2 and managed.core.GetGeometryCount()==0,"empty persistent geometry never triggers fallback")
 buildings.append({"id":1,"zone":"residential","size":2,"level":1})
 buildings.append({"id":2,"zone":"residential","size":2,"level":1})
 # Default-off mutable fixture behavior still observes unnotified edits/reordering.
 var fixture=CountingPopulation.new(51)
 fixture.sync(buildings);buildings.reverse();buildings[0].level=4;fixture.sync(buildings)
 check(fixture.packs==2,"legacy mutable fixture continues full packing")
 # Parent model hooks cover pre-append creation, in-place growth and actual demolition.
 var town=load("res://core/city_model.gd").new(100,100,51)
 var row:Dictionary={"id":1,"x":10,"y":10,"size":2,"level":1,"zone":"residential","score":0.0,"asset_id":""}
 town.buildings.append(row);town.next_id=2
 town.happiness.enable_background()
 check(town.population._geometry_transport,"background activation seeds population geometry")
 var missed:Array=[]
 town.population.geometry_transport_recovered.connect(func(a:int,b:int):missed.append([a,b]))
 row.level=3;town.orient_building(row)
 var oracle=Population.new(51)
 town.population.sync(town.buildings);oracle.sync(town.buildings)
 check(snapshot(town.population)==snapshot(oracle),"model orientation forwards growth geometry")
 var added:Dictionary={"id":2,"x":20,"y":10,"size":2,"level":1,"zone":"industrial","score":0.0,"asset_id":""}
 town.orient_building(added);town.buildings.append(added);town.next_id=3
 town.population.sync(town.buildings);oracle.sync(town.buildings)
 check(snapshot(town.population)==snapshot(oracle),"pre-append model notification forwards creation")
 var removed:Dictionary=town.demolish("building",1)
 oracle.sync(town.buildings)
 check(removed.ok and snapshot(town.population)==snapshot(oracle),"model demolition forwards stable removal")
 check(missed.is_empty(),"ordinary model edits never trigger recovery packing")
 town.happiness.suspend_background()
 for failure in failures:push_error("FAIL "+str(failure))
 print("RESULT %d/%d geometry transport checks passed"%[checks-failures.size(),checks])
 quit(1 if not failures.is_empty() else 0)
