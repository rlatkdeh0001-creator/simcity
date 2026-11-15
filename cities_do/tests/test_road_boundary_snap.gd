extends SceneTree
const City=preload("res://core/city_model.gd")
const Grid=preload("res://core/road_grid_snap.gd")
const Links=preload("res://core/boundary_links.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func run():
 var frame:Dictionary={"origin":Vector2(.5,.5),"along":Vector2.RIGHT,"outward":Vector2.DOWN}
 for pair in [[Vector2(20,40),Vector2(99.7,40),"x_max"],[Vector2(80,40),Vector2(.3,40),"x_min"],[Vector2(50,20),Vector2(50,79.7),"y_max"],[Vector2(50,60),Vector2(50,.3),"y_min"]]:
  var city=City.new(100,80);var points:=Grid.ends(city,pair[0],pair[1],5,frame)
  var expected:float=100 if pair[2]=="x_max" else (80 if pair[2]=="y_max" else 0)
  var axis:int=0 if str(pair[2]).begins_with("x") else 1
  verify(is_equal_approx(points[-1][axis],expected),"grid endpoint within one cell reaches exact map edge "+pair[2])
  var result:Dictionary=city.add_road(points,"local",true,4,false,true,1,frame)
  verify(result.ok and Links.road_links(city).size()==1 and Links.road_links(city)[0].edge==pair[2],"committed grid stroke produces actual regional arrow "+pair[2])
 var city=City.new(100,100)
 verify(Grid.ends(city,Vector2(20,40),Vector2(98.2,40),5,frame)[-1].x<100,"endpoints farther than one cell are not extended")
 verify(Grid.ends(city,Vector2(.2,40),Vector2(60,40),5,frame)[0].x==0,"a new starting endpoint may also attach to the map boundary")
 verify(Grid.ends(city,Vector2(20,40),Vector2(100.3,40),5,frame)[-1].x==100,"half-phase oversnap is clipped back to the true edge")
 city.add_road(PackedVector2Array([Vector2(80,50),Vector2(99.5,50)]))
 verify(Grid.ends(city,Vector2(99.5,50),Vector2(60,50),3,frame)[0].x==99.5,"an existing contact endpoint is never moved away from its junction")
 root.size=Vector2i(1280,820)
 var game=load("res://main.tscn").instantiate();game.paused=true;game.city=City.new(100,100);game.city.add_road(PackedVector2Array([Vector2(20.5,10),Vector2(20.5,80)]));root.add_child(game);await process_frame
 game.road_grid_enabled=true;game.road_lanes=4;game.road_drawer.set_kind("straight");game.road_drawer.click(Vector2(20.5,80));game.pointer=Vector2(99.8,80)
 var preview:Dictionary=game.road_drawer.preview();verify(preview.ok and preview.points[-1].x==100,"real road editor preview resolves a half-phase boundary cap")
 game.road_drawer.click(game.pointer)
 verify(game.city.roads.size()==2 and Links.road_links(game.city).size()==1 and game.city.roads[-1].points==preview.points,"real click commits preview geometry and activates the boundary arrow")
 game.queue_free();await process_frame
 print("RESULT %d/%d boundary grid checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
