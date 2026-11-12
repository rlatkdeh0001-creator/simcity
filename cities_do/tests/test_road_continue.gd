extends SceneTree
var checks:=0
var failures:=0
const Network=preload("res://core/traffic_network.gd")
func verify(value: bool,label: String):
 checks+=1
 if value:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func _initialize():run.call_deferred()
func mouse(game,point: Vector2,down: bool):
 var event:=InputEventMouseButton.new();event.position=game.screen(point);event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
 await process_frame
func draw(game,points: PackedVector2Array):
 await mouse(game,points[0],true)
 for i in range(1,points.size()):
  var event:=InputEventMouseMotion.new();event.position=game.screen(points[i]);root.push_input(event,true);await process_frame
 await mouse(game,points[-1],false);await process_frame
func connected(network,from: int,to: int) -> bool:
 for a: Dictionary in network.lanes:
  if a.road!=from:continue
  for b: Dictionary in network.lanes:
   if b.road==to and not network.route(a.id,b.id).is_empty():return true
 return false
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;game.city.population_enabled=false
 root.add_child(game);await process_frame;game.activate_tool("road")
 game.road_drawer.set_kind("legacy") # Preserve prior freehand regression; hidden in approved player UI.
 await draw(game,PackedVector2Array([Vector2(10,40),Vector2(30,40)]))
 await draw(game,PackedVector2Array([Vector2(30.6,40.3),Vector2(60,40)]))
 verify(game.city.roads.size()==2,"two real freehand strokes remain two original road records")
 if game.city.roads.size()==2:
  verify(game.city.roads[1].points[0].distance_to(Vector2(30,40))<.00001,"near-start snaps exactly to previous road endpoint")
  var network=Network.new();verify(network.build(game.city.roads) and connected(network,0,1) and connected(network,1,0),"endpoint continuation is actually routed both ways by traffic network")
  verify(game.city.zoning_grid.parcels.values().any(func(p):return p.frame.road_index==1),"continued road contributes real roadside parcels")
 await draw(game,PackedVector2Array([Vector2(45,40.6),Vector2(45,70)]))
 var topology: Dictionary=game.city.RoadJunctions.analyze(game.city.roads)
 verify(topology.junctions.any(func(j):return j.position.distance_to(Vector2(45,40))<.00001 and j.arms.size()==3),"near road middle snaps onto centerline and creates actual T junction")
 verify(topology.sections.size()==4 and game.city.roads.size()==3,"existing analyzer splits traffic sections without replacing stable original road IDs")
 var network=Network.new();verify(network.build(game.city.roads) and connected(network,0,2),"traffic route enters newly connected T branch")
 await draw(game,PackedVector2Array([Vector2(45,39.4),Vector2(45,12)]))
 topology=game.city.RoadJunctions.analyze(game.city.roads)
 verify(topology.junctions.any(func(j):return j.position.distance_to(Vector2(45,40))<.00001 and j.arms.size()==4),"second opposite branch reuses same snapped junction to form a cross")
 verify(game.city.roads.size()==4 and game.city.roads[0].parcel_id==0 and game.city.roads[1].parcel_id==1,"road snapping preserves prior IDs and normal demolition boundaries")
 await mouse(game,Vector2(60,60),true);await mouse(game,Vector2(60.4,40.5),false);await process_frame
 verify(game.city.roads.size()==5 and game.city.roads[-1].points[-1].distance_to(Vector2(60,40))<.00001,"real release position snaps even without an intervening mouse-motion event")
 game.queue_free();await process_frame
 for lanes_and_end in [[2,Vector2(60,44)],[4,Vector2(60,40)]]:
  var city=preload("res://core/city_model.gd").new(100,100,42)
  city.add_road(PackedVector2Array([Vector2(10,40),Vector2(30,40)]))
  city.add_road(PackedVector2Array([Vector2(30.4,40.2),lanes_and_end[1]]),"local",true,lanes_and_end[0],true)
  network=Network.new()
  verify(network.build(city.roads) and connected(network,0,1) and connected(network,1,0),"gentle-angle or 2-to-4-lane continuation must remain routable both ways")
  verify(network.junctions.is_empty() and city.road_joins.size()==1,"shallow/lane seams connect without intersection controls or crosswalks")
 var city=preload("res://core/city_model.gd").new(100,100,42)
 city.add_road(PackedVector2Array([Vector2(10,40),Vector2(30,40)]))
 var original:=PackedVector2Array([Vector2(60,40),Vector2(30.6,40.2)])
 var before: int=city.zoning_grid.count();var next: int=city.next_road_id
 verify(city.add_road(original,"local",false,2,true).ok and city.roads.size()==1 and city.zoning_grid.count()==before and city.next_road_id==next,"connected preview never mutates road topology, parcels or IDs")
 verify(original[-1]==Vector2(30.6,40.2),"endpoint projection never edits caller's freehand input")
 verify(city.add_road(original,"local",true,2,true).ok and city.roads[-1].points[-1]==Vector2(30,40),"release/end endpoint snaps as exactly as start endpoint")
 var far:=Vector2(30,41.2)
 verify(city.RoadJunctions.snap_point(far,city.roads).distance_to(far)<.00001,"outside one-cell acquisition band remains unchanged")
 var before_count: int=city.roads.size()
 verify(not city.add_road(PackedVector2Array([Vector2(30.2,40),Vector2(30.4,40)]),"local",true,2,true).ok and city.roads.size()==before_count,"collapsed zero-length snapped stroke is rejected without mutation")
 var path:=PackedVector2Array([Vector2(30.3,40),Vector2(40,46),Vector2(50,44)])
 verify(city.RoadJunctions.snap_path(path,city.roads)[1]==path[1],"freehand interior control points and drawing mode stay unchanged")
 print("RESULT %d/%d road continuation checks passed" % [checks-failures,checks]);quit(1 if failures else 0)
