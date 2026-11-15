extends "res://tests/test_population_cache.gd"
const Model=preload("res://core/city_model.gd")
func town(script,pop_script,seed_value:int):
 var city=script.new(100,100,seed_value);city.population=pop_script.new(seed_value)
 # This is the frozen unchanged-policy port oracle, not a test of newly enabled growth.
 if script==Model:city.happiness_enabled=false
 assert(city.add_road(PackedVector2Array([Vector2(10,40),Vector2(42,40)])).ok)
 var i:=0
 for frame in city.zoning_grid.frames.values():
  if i==8:break
  var family:String="residential" if i%4<2 else ("commercial" if i%4==2 else "industrial")
  city.paint_zones(city.Parcels.polygon(frame,0,0,2),family);i+=1
 assert(city.zone_designations.size()>0);return city
func original(file:String):
 var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string("D:/project/simcity/docs/csharp-population-validation/reference/"+file+".txt");assert(script.reload()==OK);return script
func run():
 var old_model=original("city_model.gd");var old_pop=original("population.gd");var rows:Array=[]
 var multi_before=town(old_model,old_pop,77);var multi_after=town(Model,Population,77)
 multi_before.advance_development(16);multi_after.advance_development(16)
 check(multi_before.buildings==multi_after.buildings and state(multi_before.population)==state(multi_after.population),"eight catch-up construction steps preserve original building count and types")
 check(multi_after.buildings.size()==4 and multi_after.population.demand(multi_after.buildings).residential==0,"same-call demand decrement prevents extra construction after four homes exhaust initial demand")
 for seed_value in [42,20261114]:
  var before=town(old_model,old_pop,seed_value);var after=town(Model,Population,seed_value)
  var equal:=true
  for tick in range(5400):
   before.advance_society(2)
   # Run the managed side through production storage, not mutable fixture-view transport.
   if after.population.has_method("release_compatibility_views"):after.population.release_compatibility_views()
   after.advance_society(2)
   if before.buildings!=after.buildings or state(before.population)!=state(after.population):
    print("DIFFERENCE seed=",seed_value," tick=",tick);equal=false;break
  check(equal and before.clock.game_seconds==259200 and after.clock.game_seconds==259200,"three full game days preserve every building, person, household, job assignment and RNG state seed="+str(seed_value))
  check(after.buildings.size()>1 and after.population.people.size()>0,"comparison exercises real development and immigration seed="+str(seed_value))
  rows.append({"seed":seed_value,"ticks":5400,"game_days":3,"buildings":after.buildings.size(),"stats":after.population.stats(),"exact_state_equal":equal})
 var file:=FileAccess.open("D:/project/simcity/docs/csharp-population-validation/three-days.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"  "));file.close()
 print("RESULT %d/%d three-day equality checks passed"%[passed,passed+failed]);quit(1 if failed else 0)
