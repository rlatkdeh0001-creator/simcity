extends SceneTree
const Model=preload("res://core/city_model.gd")
const Managed=preload("res://core/population.gd")
var reference
func _initialize():run.call_deferred()
func seed_city(count:int):
 var city=Model.new(1000,1000,20261114);city.happiness_enabled=false;var pop=reference.new(20261114);city.population=pop
 assert(city.add_road(PackedVector2Array([Vector2(10,40),Vector2(90,40)])).ok)
 var homes:=ceili(float(count)/4);var jobs:=ceili(float(count)/6)
 for i in range(homes):city.buildings.append({"id":i+1,"x":200+(i%40)*3,"y":200+floori(float(i)/40)*3,"size":2,"level":1,"zone":"residential","score":0.0,"asset_id":""})
 for i in range(jobs):city.buildings.append({"id":homes+i+1,"x":400+(i%40)*3,"y":200+floori(float(i)/40)*3,"size":2,"level":1,"zone":"commercial" if i%2==0 else "industrial","score":0.0,"asset_id":""})
 city.next_id=homes+jobs+1
 for i in range(ceili(float(count)/2)):
  var h:Dictionary={"id":i+1,"home_id":i/2+1};pop.households.append(h)
  for j in range(2):
   if pop.people.size()<count:pop.add_person(h,pop.people.size()%5,30,"synthetic-measurement")
 pop.next_household=pop.households.size()+1;pop.sync(city.buildings)
 var ids:Array=city.zoning_grid.parcels.keys()
 for i in range(mini(32,ids.size())):city.zone_designations[ids[i]]="residential"
 return city
func snapshot(pop)->Dictionary:
 return {"people":pop.people.duplicate(true),"households":pop.households.duplicate(true),"workplaces":pop.workplaces.duplicate(true),"next_person":pop.next_person,"next_household":pop.next_household,"rng_state":pop.rng.state,"elapsed_days":pop.elapsed_days,"birth_day":pop.birth_day}
func measured(count:int,managed:bool)->Dictionary:
 var city=seed_city(count)
 if managed:
  var initial:Dictionary=snapshot(city.population);var pop=Managed.new(20261114)
  pop.import_fixture_state(initial);pop.sync(city.buildings);city.population=pop
  assert(not pop.get("_views"))
 var start:=Time.get_ticks_usec();city.advance_society(2);var cost:=Time.get_ticks_usec()-start
 assert(city.clock.game_seconds==48)
 var result:={"ms":cost/1000.0,"state":snapshot(city.population),"buildings":city.buildings.duplicate(true)}
 return result
func run():
 reference=GDScript.new();reference.source_code=FileAccess.get_file_as_string("D:/project/simcity/docs/csharp-population-validation/reference/population.gd.txt");assert(reference.reload()==OK)
 # JIT warm-up is outside measurements. Every recorded sample starts from the same fresh fixture.
 measured(240,true);measured(240,false)
 var rows:Array=[]
 for count in [0,240,1000,5000]:
  var gd:Array=[];var cs:Array=[]
  for sample in range(5):
   var before:Dictionary=measured(count,false);var after:Dictionary=measured(count,true)
   assert(before.state==after.state and before.buildings==after.buildings,"both backends must produce exactly the same post-tick data")
   gd.append(before.ms);cs.append(after.ms)
  var sorted_gd:Array=gd.duplicate();var sorted_cs:Array=cs.duplicate();sorted_gd.sort();sorted_cs.sort()
  var row:={"population":count,"gd_ms":sorted_gd[2],"csharp_ms":sorted_cs[2],"gd_samples_ms":gd,"csharp_samples_ms":cs,"exact_post_tick_equal":true};rows.append(row);print("CSHARP_TICK ",JSON.stringify(row))
 var file:=FileAccess.open("D:/project/simcity/docs/csharp-population-validation/ticks.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"reference":"e3a7c84 optimized GDScript population","method":"median of five fresh identical fixtures per backend; one production advance_society(2), 48 game seconds, full homes, primed jobs, 32 zoned cells; includes development; JIT warm-up excluded; managed production storage, not mutable compatibility views","rows":rows},"  "));file.close()
 print("CSHARP_TICK_PASS 4 populations, 20 exact paired post-tick comparisons");quit()
