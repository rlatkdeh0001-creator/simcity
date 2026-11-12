extends SceneTree
var checks:=0
var failed:=0
func _initialize():run.call_deferred()
func verify(ok: bool,detail: String):
 checks+=1
 if ok:print("PASS "+detail)
 else:failed+=1;push_error("FAIL "+detail)
func reset(game):
 game.activate_tool("reset");game.activate_tool("road")
 game.city.add_road(PackedVector2Array([Vector2(10,30),Vector2(70,30)]))
func run():
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame
 var drawing=game.road_drawer
 for kind in ["straight","curve","free"]:
  reset(game);drawing.set_kind(kind);drawing.click(Vector2(30,30))
  if kind=="curve":drawing.click(Vector2(33,50));game.pointer=Vector2(50,60)
  else:game.pointer=Vector2(33,50)
  var candidate: Dictionary=drawing.preview();var points: PackedVector2Array=candidate.points
  verify(candidate.ok and absf((points[1]-points[0]).normalized().dot(Vector2.RIGHT))<.00001,kind+" near-perpendicular first segment snaps exactly 90 degrees with green preview")
  var expected: PackedVector2Array=points.duplicate();drawing.click(game.pointer)
  verify(game.city.roads.size()==2 and game.city.roads[-1].points==expected,kind+" commit uses identical angle-snapped preview geometry")
 reset(game);drawing.set_kind("straight");drawing.click(Vector2(70,30));game.pointer=Vector2(90,33)
 verify(drawing.preview().ok and absf(drawing.path()[-1].y-30)<.00001,"near-parallel extension at authored endpoint snaps exactly 0 degrees")
 reset(game);drawing.set_kind("straight");drawing.click(Vector2(33,10));game.pointer=Vector2(30,30)
 var end_path: PackedVector2Array=drawing.path()
 verify(end_path[-1]==Vector2(30,30) and absf(end_path[0].x-30)<.00001 and drawing.preview().ok,"ending at existing middle preserves contact and snaps arriving direction 90 degrees")
 for degrees in [10.0,11.0]:
  reset(game);drawing.set_kind("straight");drawing.click(Vector2(30,30))
  var raw:=Vector2(30,30)+Vector2.DOWN.rotated(deg_to_rad(degrees))*20;game.pointer=raw
  var path: PackedVector2Array=drawing.path()
  verify(absf(path[-1].x-30)<.00001 if degrees==10 else path[-1].is_equal_approx(raw),"temporary threshold includes10 and preserves11 degrees: "+str(degrees))
 reset(game);game.city.add_road(PackedVector2Array([Vector2(10,60),Vector2(70,60)]));drawing.set_kind("straight");drawing.click(Vector2(30,30));game.pointer=Vector2(33,60)
 var both: PackedVector2Array=drawing.path()
 verify(both[0]==Vector2(30,30) and both[-1].is_equal_approx(Vector2(30,60)) and drawing.preview().ok,"both connected endpoints remain on host centerlines while orthogonal alignment is solved")
 reset(game);drawing.set_kind("straight");drawing.click(Vector2(20,10));game.pointer=Vector2(23,25)
 var unconnected: PackedVector2Array=drawing.path()
 verify(unconnected[0]==Vector2(20,10) and (unconnected[-1]-unconnected[0]).normalized().dot(Vector2(3,15).normalized())>.99999 and drawing.LengthUnits.is_build_length(game.city.RoadJunctions.length_of(unconnected)),"unconnected path retains its oblique heading while snapping length to eight-metre units")
 for kind in ["curve","free"]:
  reset(game);drawing.set_kind(kind);drawing.click(Vector2(33,10))
  if kind=="curve":drawing.click(Vector2(30,15))
  game.pointer=Vector2(30,30)
  var incoming: Dictionary=drawing.preview();var path: PackedVector2Array=incoming.points
  verify(incoming.ok and absf((path[-1]-path[-2]).normalized().dot(Vector2.RIGHT))<.00001,kind+" ending at existing road also constrains the actual final segment")
 for host in [PackedVector2Array([Vector2(10,30),Vector2(70,50)]),PackedVector2Array([Vector2(10,30),Vector2(40,30),Vector2(60,45)])]:
  game.activate_tool("reset");game.activate_tool("road");game.city.add_road(host);drawing.set_kind("straight")
  var tangent: Vector2=(host[-1]-host[-2]).normalized();var normal:=Vector2(-tangent.y,tangent.x);var contact: Vector2=(host[-1]+host[-2])/2
  drawing.click(contact);game.pointer=contact+normal.rotated(deg_to_rad(8))*20
  var path: PackedVector2Array=drawing.path()
  verify(drawing.preview().ok and absf((path[-1]-path[0]).normalized().dot(tangent))<.00001,"snap uses local diagonal/curve-polyline segment tangent rather than global axes")
 reset(game);game.city.add_road(PackedVector2Array([Vector2(10,60),Vector2(33,60)]));drawing.set_kind("straight");drawing.click(Vector2(30,30));game.pointer=Vector2(33,60)
 var pinned: PackedVector2Array=drawing.path()
 verify(pinned[0].is_equal_approx(Vector2(33,30)) and pinned[-1]==Vector2(33,60),"authored endpoint stays pinned while the other middle contact slides along its host")
 reset(game);game.city.add_road(PackedVector2Array([Vector2(10,60),Vector2(67,60)]));drawing.set_kind("straight");drawing.click(Vector2(70,30));game.pointer=Vector2(67,60)
 verify(drawing.path()==PackedVector2Array([Vector2(70,30),Vector2(67,60)]),"incompatible fixed authored endpoints preserve topology rather than disconnecting a host")
 game.queue_free();await process_frame
 print("RESULT %d/%d road angle snap checks passed"%[checks-failed,checks]);quit(1 if failed else 0)
