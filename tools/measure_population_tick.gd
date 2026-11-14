extends SceneTree
class TimedPopulation extends "res://core/population.gd":
 var sync_us:=0
 var sync_match_us:=0
 var jobs_us:=0
 var jobs_calls:=0
 var demand_us:=0
 var demand_calls:=0
 var advance_us:=0
 var inside_sync:=false
 func sync(buildings:Array)->void:
  var start:=Time.get_ticks_usec();inside_sync=true;super.sync(buildings);inside_sync=false;sync_us+=Time.get_ticks_usec()-start
 func match_jobs()->void:
  var start:=Time.get_ticks_usec();super.match_jobs();var cost:=Time.get_ticks_usec()-start;jobs_us+=cost;jobs_calls+=1
  if inside_sync:sync_match_us+=cost
 func demand(buildings:Array)->Dictionary:
  var start:=Time.get_ticks_usec();var result:=super.demand(buildings);demand_us+=Time.get_ticks_usec()-start;demand_calls+=1;return result
 func advance(seconds:float,buildings:Array)->void:
  var start:=Time.get_ticks_usec();super.advance(seconds,buildings);advance_us+=Time.get_ticks_usec()-start
 func reset_times():sync_us=0;sync_match_us=0;jobs_us=0;jobs_calls=0;demand_us=0;demand_calls=0;advance_us=0
class TimedCity extends "res://core/city_model.gd":
 var development_us:=0
 func advance_development(seconds:float)->Array[Dictionary]:
  var start:=Time.get_ticks_usec();var result:=super.advance_development(seconds);development_us+=Time.get_ticks_usec()-start;return result
func _initialize():run.call_deferred()
func fixture(count:int):
 var city=TimedCity.new(1000,1000,20261114);var pop=TimedPopulation.new(20261114);city.population=pop
 city.add_road(PackedVector2Array([Vector2(10,40),Vector2(90,40)]))
 var homes:=ceili(float(count)/4)
 for i in range(homes):city.buildings.append({"id":i+1,"x":200+(i%40)*3,"y":200+floori(float(i)/40)*3,"size":2,"level":1,"zone":"residential","score":0.0,"asset_id":""})
 var jobs:=ceili(float(count)/6)
 for i in range(jobs):city.buildings.append({"id":homes+i+1,"x":400+(i%40)*3,"y":200+floori(float(i)/40)*3,"size":2,"level":1,"zone":"commercial" if i%2==0 else "industrial","score":0.0,"asset_id":""})
 city.next_id=homes+jobs+1
 for i in range(ceili(float(count)/2)):
  var household:Dictionary={"id":i+1,"home_id":i/2+1};pop.households.append(household)
  for j in range(2):
   if pop.people.size()<count:pop.add_person(household,pop.people.size()%5,30,"synthetic-measurement")
 pop.next_household=pop.households.size()+1;pop.sync(city.buildings)
 var ids:Array=city.zoning_grid.parcels.keys()
 for i in range(mini(32,ids.size())):city.zone_designations[ids[i]]="residential"
 pop.reset_times();city.development_us=0
 return city
func run():
 var rows:Array=[]
 for count in [0,240,1000]:
  var city=fixture(count);var pop=city.population;assert(pop.people.size()==count)
  var start:=Time.get_ticks_usec();city.advance_society(2);var total:=Time.get_ticks_usec()-start
  assert(pop.jobs_calls>=2 and city.clock.game_seconds==48)
  var row:={"population_before":count,"population_after":pop.people.size(),"households":pop.households.size(),"buildings":city.buildings.size(),"zoned_cells":city.zone_designations.size(),"total_tick_ms":total/1000.0,"population_advance_inclusive_ms":pop.advance_us/1000.0,"sync_excluding_jobs_ms":(pop.sync_us-pop.sync_match_us)/1000.0,"match_jobs_total_ms":pop.jobs_us/1000.0,"match_jobs_calls":pop.jobs_calls,"development_inclusive_ms":city.development_us/1000.0,"demand_ms":pop.demand_us/1000.0,"demand_calls":pop.demand_calls}
  rows.append(row);print("POPULATION_TICK ",JSON.stringify(row))
 var folder:="D:/project/simcity/docs/zoning-mesh-validation";DirAccess.make_dir_recursive_absolute(folder)
 var file:=FileAccess.open(folder.path_join("population-tick.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"method":"one production advance_society(2) tick; steady-state jobs primed; original policies, 32 zoned real parcels; subclass timers only; development includes demand","rows":rows},"  "));file.close()
 print("POPULATION_MEASUREMENT_PASS original production algorithms unchanged");quit()
