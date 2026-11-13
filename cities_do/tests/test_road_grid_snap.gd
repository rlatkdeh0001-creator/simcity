extends SceneTree
const City=preload("res://core/city_model.gd")
const Paths=preload("res://core/road_junctions.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func reset(game,host: int=2,new_count: int=2):
 game.road_drawer.cancel();game.city=City.new(100,100);game.city.add_road(PackedVector2Array([Vector2(10,30),Vector2(90,30)]),"local",true,host);game.road_lanes=new_count;game.road_grid_enabled=true;game.road_drawer.set_kind("straight")
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame
 var drawing=game.road_drawer
 verify(drawing.has_method("grid_reference"),"road drawing owns an immutable local grid reference")
 if drawing.has_method("grid_reference"):
  reset(game);verify(drawing.snap(Vector2(28.37,30.2)).distance_to(Vector2(28.5,30))<.001,"new three-cell-wide two-lane branch uses half-cell centres")
  game.road_grid_enabled=false;verify(drawing.snap(Vector2(28.37,30.2)).distance_to(Vector2(28.37,30))<.001,"grid off preserves the exact old free-position contact")
  reset(game,4,3);verify(drawing.snap(Vector2(28.37,30.2)).distance_to(Vector2(28.5,30))<.001,"odd-width branch centre offsets by half a cell so both road edges land on cell boundaries")
  for pair in [[2,2],[4,2],[3,4],[4,3],[5,8],[8,5]]:
   reset(game,pair[0],pair[1]);var host_width:float=game.city.RoadProfile.width_for("local",pair[0]);var new_width:float=game.city.RoadProfile.width_for("local",pair[1]);var y: float=30+(host_width+new_width)/2.0+8
   var original: PackedVector2Array=game.city.roads[0].points.duplicate()
   drawing.click(Vector2(20.24,y+.23));game.pointer=Vector2(76.37,y+.19)
   var p: Dictionary=drawing.preview()
   verify(p.ok and absf(p.points[0].y-y)<.001 and absf(p.points[-1].y-y)<.001,"parallel centreline accounts for both road widths "+str(pair))
   drawing.click(game.pointer)
   verify(game.city.roads.size()==2 and game.city.roads[0].points==original,"grid commit preserves the authored host road "+str(pair))
   var edge: float=30+host_width/2.0
   var lot:=PackedVector2Array([Vector2(32,edge),Vector2(40,edge),Vector2(40,edge+8),Vector2(32,edge+8)])
   verify(game.city.zoning_grid.has_opposing_lot(lot),"exactly eight integer rows form a valid opposed 4+4 eight-by-eight lot "+str(pair))
  reset(game,8,4);drawing.click(Vector2(28.3,30.1));game.pointer=Vector2(28.3,41.7)
  var exception: Dictionary=drawing.preview()
  verify(exception.ok and absf(Paths.length_of(exception.points)*4-46)<.001,"grid-aligned mixed-width straight connection allows the approved forty-six-metre exception")
  var expected: PackedVector2Array=exception.points.duplicate();drawing.click(game.pointer)
  verify(game.city.roads.size()==2 and game.city.roads[-1].points==expected,"exception commit is byte-identical to its green preview")
  reset(game);game.city.roads.clear();game.city.add_road(PackedVector2Array([Vector2(20,20),Vector2(68,56)]));var axis:=Vector2(.8,.6);var normal:=Vector2(-.6,.8)
  var rotated: Vector2=drawing.snap(Vector2(20,20)+axis*7.31+normal*.2)
  verify(rotated.distance_to(Vector2(20,20)+axis*7.5)<.001,"rotated three-cell roads snap in local half-cell phases, not screen axes")
  for kind in ["curve","free"]:
   reset(game,2,3);drawing.set_kind(kind);drawing.click(Vector2(30.2,30.1))
   if kind=="curve":
    var control:=Vector2(45.17,38.23);drawing.click(control)
    verify(drawing.anchors[1].distance_to(control)<.001,"curve control remains free rather than quantized to the endpoint grid")
   game.pointer=Vector2(32.31,50.28);var p: Dictionary=drawing.preview()
   verify(p.ok and p.points[-1].distance_to(Vector2(32.5,50))<.001,kind+" snaps only its destination while retaining a curved path")
   verify(game.city.RoadUnits.is_build_length(Paths.length_of(p.points),1),kind+" retains four-metre arc-length validation with fixed grid endpoints")
   if kind=="free":verify(absf((p.points[1]-p.points[0]).normalized().dot(Vector2.RIGHT))<.00001,"grid ON retains the free curve's exact ninety-degree departure assistance")
  for kind in ["straight","curve","free"]:
   reset(game);drawing.set_kind(kind);drawing.click(Vector2(90,30))
   if kind=="curve":drawing.click(Vector2(90.5,30))
   game.pointer=Vector2(91,30);var p: Dictionary=drawing.preview()
   verify(p.ok and absf(Paths.length_of(p.points)-1)<.001,kind+" grid ON still offers a player-confirmed four-metre extension")
   drawing.click(game.pointer);verify(game.city.roads.size()==2,kind+" four-metre grid extension is actually committed")
  reset(game);var frame: Dictionary=drawing.grid_reference(Vector2(30,30))
  game.city.add_road(PackedVector2Array([Vector2(20.5,50),Vector2(36.5,50)]),"local",true,3,false,false,1,frame)
  var continuous:=true
  for x in range(21,36):
   var cell: Dictionary=game.city.zoning_grid.parcel_at(Vector2(x+.5,48))
   continuous=continuous and not cell.is_empty()
  verify(continuous,"half-phase authored junctions retain complete aligned columns across internal eight-cell block seams")
  verify(game.city.zoning_grid.parcel_at(Vector2(20.5,48.5)).is_empty() and game.city.zoning_grid.parcel_at(Vector2(36.5,48.5)).is_empty(),"alignment never invents full frontage beyond the first or last real road endpoint")
 game.queue_free();await process_frame
 print("RESULT %d/%d road grid snap checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
