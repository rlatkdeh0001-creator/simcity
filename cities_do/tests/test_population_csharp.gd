extends SceneTree
const Population=preload("res://core/population.gd")
func _initialize():run.call_deferred()
func run():
 var pop=Population.new(42)
 if not pop.has_method("backend_name"):
  push_error("FAIL population production facade must use the managed core");quit(1);return
 assert(pop.backend_name()=="CSharp")
 var buildings:Array=[{"id":1,"zone":"residential","size":2,"level":1},{"id":2,"zone":"commercial","size":2,"level":1}]
 pop.begin_tick();pop.advance(48,buildings);pop.end_tick()
 assert(pop.stats().population==2 and pop.stats().households==1)
 var resident:Dictionary=pop.people[0];resident.age_years=80
 pop.sync(buildings)
 assert(pop.people[0].age_years==80)
 root.size=Vector2i(1280,820)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame
 game.refresh()
 assert(not game.city.population.get("_views"),"ordinary HUD refresh must not materialize the entire managed population")
 game.queue_free();await process_frame
 var packed=Population.new(42)
 assert(packed.core.has_method("SyncPacked"),"managed building transport must accept compact packed data, not per-building native dictionaries")
 var records:=PackedInt64Array([1,0,2,1,2,1,2,1])
 packed.core.SyncPacked(records);packed.core.AdvancePacked(48,records);packed.core.MatchJobs()
 assert(packed.stats().population==2 and packed.stats().households==1)
 print("RESULT 5/5 managed population facade checks passed")
 quit()
