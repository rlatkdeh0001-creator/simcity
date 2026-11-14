extends SceneTree
const Population=preload("res://core/population.gd")
class Counted extends "res://core/population.gd":
 var matching_calls:=0
 func match_jobs()->void:matching_calls+=1;super.match_jobs()
var passed:=0
var failed:=0
func check(value:bool,label:String):
 if value:passed+=1;print("PASS "+label)
 else:failed+=1;push_error("FAIL "+label)
func original(file:String):
 var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string("D:/project/simcity/docs/population-optimization-validation/reference/"+file+".txt");assert(script.reload()==OK);return script
func _initialize():run.call_deferred()
func state(pop)->Array:return [pop.people,pop.households,pop.workplaces,pop.rng.state]
func run():
 var pop=Counted.new(51)
 check(pop.has_method("begin_tick"),"population demand supports an explicitly bounded tick cache")
 if failed:quit(1);return
 var legacy=original("population.gd").new(51)
 var buildings:Array=[{"id":1,"zone":"residential","size":2,"level":1}]
 for p in [pop,legacy]:
  p.config.commercial_jobs=[0,1,0,0,0];p.config.immigrant_education_weights=[0,1,0,0,0]
  p.households.append({"id":1,"home_id":1});p.next_household=2;p.add_person(p.households[0],0,25,"synthetic");p.sync(buildings)
 buildings.append({"id":3,"zone":"commercial","size":2,"level":1})
 pop.matching_calls=0;pop.begin_tick();pop.advance(48,buildings);legacy.advance(48,buildings)
 check(pop.matching_calls==1,"one full matching pass in a population tick")
 check(state(pop)==state(legacy),"old unemployed cohort keeps its pre-immigration hiring priority exactly")
 var generation:int=pop.demand_full_scans
 for i in range(64):check(pop.demand(buildings)==legacy.demand(buildings),"cached demand equals original query "+str(i))
 check(pop.demand_full_scans==generation+1,"64 demand requests perform exactly one full scan")
 generation=pop.demand_full_scans
 buildings.append({"id":2,"zone":"residential","size":2,"level":1})
 for p in [pop,legacy]:p.sync(buildings)
 check(pop.demand(buildings)==legacy.demand(buildings),"new dwelling decreases demand incrementally within the same tick")
 buildings[-1].level=2
 for p in [pop,legacy]:p.sync(buildings)
 check(pop.demand(buildings)==legacy.demand(buildings),"in-place level change updates only its capacity contribution")
 buildings[1].size=4;buildings[1].level=5
 for p in [pop,legacy]:p.sync(buildings)
 check(pop.demand(buildings)==legacy.demand(buildings) and state(pop)==state(legacy),"workplace stage and area changes update slots and demand contribution incrementally")
 for id in [4,5]:
  buildings.append({"id":id,"zone":"industrial","size":2,"level":1})
  for p in [pop,legacy]:p.sync(buildings)
  check(pop.demand(buildings)==legacy.demand(buildings) and state(pop)==state(legacy),"new workplace updates demand and available-job index without changing assignment order "+str(id))
 buildings.remove_at(0)
 for p in [pop,legacy]:p.sync(buildings)
 check(pop.demand(buildings)==legacy.demand(buildings) and state(pop)==state(legacy),"demolished home rehouses the same households and preserves vacancy accounting")
 buildings=buildings.filter(func(b):return b.id!=3)
 for p in [pop,legacy]:p.sync(buildings)
 check(pop.demand(buildings)==legacy.demand(buildings) and state(pop)==state(legacy),"workplace removal preserves original reassignment results")
 check(pop.demand_full_scans==generation and pop.matching_calls==1,"all same-tick building changes avoid full demand and matching rebuilds")
 pop.end_tick();pop.begin_tick();pop.demand(buildings)
 check(pop.demand_full_scans==generation+1,"the next tick refreshes cached aggregate state")
 pop.end_tick()
 var city=preload("res://core/city_model.gd").new(1000,1000,42)
 city.add_road(PackedVector2Array([Vector2(10,40),Vector2(90,40)]))
 city.buildings.append({"id":1,"zone":"residential","size":4,"level":1,"x":200,"y":200})
 for id in city.zoning_grid.parcels.keys().slice(0,32):city.zone_designations[id]="residential"
 city.advance_society(2)
 check(city.population.demand_full_scans==1 and not city.population.tick_active,"production society and development share one bounded demand cache")
 print("RESULT %d/%d population cache checks passed"%[passed,passed+failed]);quit(1 if failed else 0)
