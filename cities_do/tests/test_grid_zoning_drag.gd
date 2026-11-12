extends SceneTree
var checks:=0
var failed:=0
func _initialize():run.call_deferred()
func verify(ok: bool,detail: String):
 checks+=1
 if ok:print("PASS "+detail)
 else:failed+=1;push_error("FAIL "+detail)
func press(game,p: Vector2):
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=game.screen(p);game._unhandled_input(e)
func run():
 root.size=Vector2i(1920,1080)
 var roads:=[PackedVector2Array([Vector2(20,35),Vector2(60,35)]),PackedVector2Array([Vector2(20,30),Vector2(60,50)]),PackedVector2Array([Vector2(20,35),Vector2(30,35),Vector2(40,40),Vector2(45,50)])]
 for points in roads:
  var game=load("res://main.tscn").instantiate();game.paused=true;game.city.population_enabled=false;game.city.add_road(points);root.add_child(game);await process_frame
  game.map_zoom=1;game.origin=Vector2(850,-20);game.select_category("build");game.activate_tool("build_commercial")
  var frames: Array=game.city.zoning_grid.frames.values().filter(func(f):return game.city.zoning_grid.has_parcel(f.id,0,0) and game.city.zoning_grid.has_parcel(f.id,2,1))
  if points.size()>2:frames=frames.filter(func(f):return absf(f.along.y)>.1)
  verify(not frames.is_empty(),"real local road grid fixture exists")
  if not frames.is_empty():
   var f: Dictionary=frames[0];var a: Vector2=f.origin+f.along*.5+f.outward*.5;var b: Vector2=f.origin+f.along*2.5+f.outward*1.5
   for reverse in [false,true]:
    game.city.zone_designations.clear();game.city.paint_zones(game.city.Parcels.polygon(f,0,0),"residential")
    press(game,b if reverse else a);game.zoning_end=game.screen(a if reverse else b)
    var actual: PackedVector2Array=game.zoning_selection()
    var expected:=PackedVector2Array([f.origin,f.origin+f.along*3,f.origin+f.along*3+f.outward*2,f.origin+f.outward*2])
    verify(actual.size()==4 and actual[0].is_equal_approx(expected[0]) and actual[1].is_equal_approx(expected[1]) and actual[2].is_equal_approx(expected[2]) and actual[3].is_equal_approx(expected[3]),"preview is inclusive 3x2 rectangle on anchor road axes reverse="+str(reverse))
    verify(game.city.zone_designations.size()==1,"grid preview does not paint before release")
    game.finish_zoning(game.zoning_end)
    verify(game.city.zone_designations.size()==6 and game.city.zone_designations.values().count("residential")==1 and game.city.zone_designations.values().count("commercial")==5,"release paints exactly six grid cells and preserves existing different use")
   if points.size()>2:
    var others: Array=game.city.zoning_grid.parcels.values().filter(func(p):return absf(p.frame.along.cross(f.along))>.1)
    verify(not others.is_empty(),"curve fixture includes a differently oriented neighboring local grid")
    if not others.is_empty():
     press(game,a);game.zoning_end=game.screen(others[0].center)
     var locked: PackedVector2Array=game.zoning_selection()
     verify(game.zoning_anchor.frame.id==f.id and (locked[1]-locked[0]).normalized().dot(f.along)>.9999,"moving onto a different curve block never rotates the anchor grid axes")
     game.cancel_zoning_drag()
   game.cancel_zoning_drag();press(game,Vector2(1,1));verify(not game.zoning_drag,"press outside all grid cells does not invent an anchor")
  game.queue_free();await process_frame
 print("RESULT %d/%d grid-axis zoning drag checks passed"%[checks-failed,checks]);quit(1 if failed else 0)
