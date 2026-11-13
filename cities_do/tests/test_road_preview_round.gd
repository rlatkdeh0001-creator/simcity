extends SceneTree
const City=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.city=City.new(100,100);game.paused=true;root.add_child(game);await process_frame;game.activate_tool("road")
 var drawing=game.road_drawer
 verify(drawing.has_method("preview_polygons"),"road preview has a dedicated smooth round-cap silhouette")
 if drawing.has_method("preview_polygons"):
  for lanes in [2,3,4,5,8]:
   game.road_lanes=lanes
   var points:=PackedVector2Array([Vector2(30,50),Vector2(60,50)])
   var original:=points.duplicate();var shapes: Array=drawing.preview_polygons(points,lanes)
   verify(shapes.size()==1 and shapes[0].size()>=24,"smooth capsule is a single densely sampled strip for "+str(lanes)+" lanes")
   var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF);var radius: float=lanes/2.0;var round_ends:=true
   for p in shapes[0]:
    low=low.min(p);high=high.max(p)
    if p.x<30-.001:round_ends=round_ends and absf(p.distance_to(points[0])-radius)<.01
    if p.x>60+.001:round_ends=round_ends and absf(p.distance_to(points[-1])-radius)<.01
   verify(low.distance_to(Vector2(30-radius,50-radius))<.02 and high.distance_to(Vector2(60+radius,50+radius))<.02,"both semicircle diameters equal the selected road width "+str(lanes))
   verify(round_ends and points==original,"cap vertices stay on the real-radius circles without mutating construction points "+str(lanes))
  var green: Dictionary=drawing.preview_colors(true);var red: Dictionary=drawing.preview_colors(false)
  verify(green.fill==Color(.3,.9,.5,.55) and red.fill==Color(.95,.3,.25,.55),"valid and invalid translucent fill colours retain the existing policy")
  verify(green.outline==Color("3ddc84") and red.outline==Color("ef5350"),"outlines reuse the pre-click disc's green and red colours")
  var stationary: Array=drawing.preview_polygons(PackedVector2Array([Vector2(30,50),Vector2(30,50)]),4)
  verify(stationary.size()==1 and stationary[0].size()>=64,"a stationary first point remains a full road-width disc before stretching into the strip")
  var clipped: Array=drawing.preview_polygons(PackedVector2Array([Vector2(.1,.1),Vector2(10,.1)]),8)
  var inside:=true
  for shape in clipped:
   for p in shape:inside=inside and p.x>=-.0001 and p.y>=-.0001 and p.x<=100.0001 and p.y<=100.0001
  verify(inside and not clipped.is_empty(),"preview keeps the existing map-edge clipping")
  for kind in ["straight","curve","free"]:
   drawing.cancel();game.city=City.new(100,100);game.city.add_road(PackedVector2Array([Vector2(10,30),Vector2(90,30)]));game.road_lanes=3;drawing.set_kind(kind);drawing.click(Vector2(30.2,30.1))
   if kind=="curve":drawing.click(Vector2(45.17,38.23))
   game.pointer=Vector2(32.31,50.28)
   var result: Dictionary=drawing.preview();var before:=var_to_str(result.points);var model:=var_to_str(game.city.roads);var anchors:=var_to_str(drawing.anchors);var measurements:=var_to_str(drawing.measurements(result))
   var shapes: Array=drawing.preview_polygons(result.points,game.road_lanes)
   verify(result.ok and not shapes.is_empty(),kind+" uses the same round-cap silhouette for its actual resolved path")
   verify(var_to_str(result.points)==before and var_to_str(game.city.roads)==model and var_to_str(drawing.anchors)==anchors,kind+" presentation never changes grid, angle, arc length, authored roads or anchors")
   verify(var_to_str(drawing.measurements(result))==measurements,kind+" length and connection-angle annotations remain unchanged")
 game.queue_free();await process_frame
 print("RESULT %d/%d round road preview checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
