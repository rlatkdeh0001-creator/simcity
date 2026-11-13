extends SceneTree
const City=preload("res://core/city_model.gd")
const Network=preload("res://core/traffic_network.gd")
var checks:=0
var failures:=0
var lattice:={"origin":Vector2.ZERO,"along":Vector2.RIGHT,"outward":Vector2.DOWN}
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func base():
 var city:=City.new(100,100);city.add_road(PackedVector2Array([Vector2(20,40),Vector2(40,40)]));return city
func propose(city,points: PackedVector2Array,commit: bool=false,lanes: int=2,kind: String="local") -> Dictionary:return city.add_road(points,kind,commit,lanes,false,true,1,lattice)
func run():
 for points in [PackedVector2Array([Vector2(20,40.2),Vector2(60,40.2)]),PackedVector2Array([Vector2(20,40),Vector2(60,40)+Vector2(0,tan(deg_to_rad(1))*40)])]:
  var city=base();var result:=propose(city,points)
  verify(not result.ok and "겹" in result.get("reason",""),"parallel offset or one-degree overpaint is rejected specifically as surface overlap")
 for variant in [[4,"local"],[2,"highway"]]:
  var city=base();verify(not propose(city,PackedVector2Array([Vector2(20,40),Vector2(60,40)]),false,variant[0],variant[1]).ok,"collinear overpaint cannot replace a different lane count or road kind")
 var city=base();city.funds=0;var original: PackedVector2Array=city.roads[0].points.duplicate()
 var p:=PackedVector2Array([Vector2(20,40),Vector2(60,40)]);var before:=var_to_str(city.roads);var preview:=propose(city,p)
 verify(preview.ok and var_to_str(city.roads)==before,"exact same-direction overdraw has a pure green construction plan")
 verify(preview.get("new_length_m",-1)==80 and preview.get("retained_length_m",-1)==80,"plan measures only the genuinely new eighty metres")
 verify(preview.get("construction_cost",-1)==0,"existing free-road policy remains unchanged rather than activating unapproved tariffs")
 var committed:=propose(city,p,true)
 verify(committed.ok and city.roads.size()==2 and city.roads[0].points==original,"commit retains the old record and adds only the uncovered extension")
 verify(city.roads[-1].points==PackedVector2Array([Vector2(40,40),Vector2(60,40)]) and city.road_visuals.size()==1,"new-only extension forms one continuous rendered road")
 city=base();var both:=propose(city,PackedVector2Array([Vector2(10,40),Vector2(60,40)]),true)
 verify(both.ok and city.roads.size()==3 and both.get("new_length_m",-1)==120,"two-sided overdraw preserves the middle and constructs only both free tails")
 city=base();verify(not propose(city,PackedVector2Array([Vector2(20,40),Vector2(40,40)])).ok,"fully retained duplicate with no new construction stays red")
 verify(not propose(city,PackedVector2Array([Vector2(60,40),Vector2(20,40)])).ok,"reverse-authored overlapping direction is not a same-direction overlay")
 for gap in [3,4,20]:
  city=City.new(100,100)
  for y in [30,30+gap]:city.add_road(PackedVector2Array([Vector2(10,y),Vector2(90,y)]))
  var result:=propose(city,PackedVector2Array([Vector2(50,10),Vector2(50,80)]),true)
  verify(result.ok==(gap>=4),"junction spacing along the new road enforces exactly four cells: "+str(gap))
  if result.ok:verify(city.junctions.size()==2 and city.roads[-1].points[-1]==Vector2(50,80),"crossing continues to the requested end and creates every junction")
 city=City.new(100,100);city.add_road(PackedVector2Array([Vector2(10,30),Vector2(90,30)]));city.add_road(PackedVector2Array([Vector2(40,10),Vector2(40,70)]))
 verify(not propose(city,PackedVector2Array([Vector2(43,10),Vector2(43,70)])).ok,"spacing also measures new versus existing junctions along an existing host road")
 city=City.new(1000,1000);city.add_road(PackedVector2Array([Vector2(100,300),Vector2(500,300)]));var direction:=Vector2.from_angle(deg_to_rad(.5))
 var shallow:=propose(city,PackedVector2Array([Vector2(300,300)-direction*200,Vector2(300,300)+direction*200]),true)
 verify(shallow.ok and city.junctions.size()==1,"a genuine half-degree crossing is allowed when all arms actually escape the other road")
 city=City.new(100,100)
 verify(not propose(city,PackedVector2Array([Vector2(20,20),Vector2(60,20),Vector2(60,20.5),Vector2(20,20.5)])).ok,"a hairpin cannot hide a long parallel self-overlap")
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.city=base();game.paused=true;root.add_child(game);await process_frame;game.road_grid_enabled=false;game.activate_tool("road");game.road_drawer.set_kind("straight");game.road_drawer.click(Vector2(20,40));game.pointer=Vector2(60,40)
 var result: Dictionary=game.road_drawer.preview()
 verify(result.ok,"drawing preview routes only the uncovered pieces rather than rejecting its retained duplicate")
 game.road_drawer.click(game.pointer);verify(game.city.roads.size()==2 and game.city.roads[-1].points==PackedVector2Array([Vector2(40,40),Vector2(60,40)]),"real drawing controller commits the identical new-only overlay plan")
 game.queue_free();await process_frame
 print("RESULT %d/%d road overlap policy checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
