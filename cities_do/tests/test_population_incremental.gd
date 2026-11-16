extends SceneTree
const Population=preload("res://core/population.gd")
var checks:=0
var failures:Array=[]
func check(condition:bool,label:String):
 checks+=1
 if not condition:failures.append(label)
func state(pop)->Array:return [pop.people,pop.households,pop.workplaces,pop.rng.state,pop.next_person,pop.next_household,pop.elapsed_days,pop.birth_day]
func _initialize():run.call_deferred()
func run():
 # Frozen pre-optimization implementation: compare full state/RNG, not just totals.
 var source:=GDScript.new()
 source.source_code=FileAccess.get_file_as_string("D:/project/simcity/docs/csharp-population-validation/reference/population.gd.txt")
 if source.reload()!=OK:
  push_error("FAIL frozen population oracle did not compile");quit(1);return
 var actual=Population.new(51)
 var expected=source.new(51)
 var buildings:Array=[{"id":1,"zone":"residential","size":2,"level":2},{"id":2,"zone":"commercial","size":2,"level":1},{"id":3,"zone":"residential","size":2,"level":1},{"id":4,"zone":"industrial","size":2,"level":1}]
 for pop in [actual,expected]:
  pop.config.birth_probability_per_household_day=0.25
  pop.households.append({"id":1,"home_id":1});pop.next_household=2
  pop.add_person(pop.households[0],0,25,"fixture")
  pop.add_person(pop.households[0],1,17.9999,"fixture")
  pop.sync(buildings)
 for tick in range(96):
  # Reordering, deletion/reuse, conversion, and scalar capacity changes are in-place.
  if tick==8:buildings.reverse()
  if tick==16:buildings[0].level=2
  if tick==24:buildings=buildings.filter(func(b):return b.id!=1)
  if tick==32:buildings.append({"id":1,"zone":"industrial","size":2,"level":1})
  if tick==40:buildings[0].zone="residential"
  if tick==48:buildings.append({"id":5,"zone":"residential","size":4,"level":1})
  actual.release_compatibility_views();actual.begin_tick()
  actual.advance(3600,buildings);expected.advance(3600,buildings)
  check(state(actual)==state(expected),"cross-tick state/RNG equality tick="+str(tick))
  check(actual.demand(buildings)==expected.demand(buildings),"prepared demand equality tick="+str(tick))
  if tick%7==0:
   buildings[-1].level=1+(tick%3)
   actual.sync(buildings);expected.sync(buildings)
   check(state(actual)==state(expected) and actual.demand(buildings)==expected.demand(buildings),"same-tick incremental edit equality tick="+str(tick))
  actual.end_tick()
 for failure in failures:push_error("FAIL "+str(failure))
 print("RESULT %d/%d incremental population checks passed"%[checks-failures.size(),checks])
 quit(1 if not failures.is_empty() else 0)
