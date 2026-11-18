extends SceneTree
const Model=preload("res://core/city_model.gd")
const Routes=preload("res://core/transit_routes.gd")
var checks:=0
var failures:=0
func verify(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func contains(shapes:Array,p:Vector2,texture:String)->bool:
 for shape in shapes:
  if shape.texture==texture and Geometry2D.is_point_in_polygon(p,shape.points):return true
 return false
func _initialize():run.call_deferred()
func run():
 var renderer=load("res://core/transit_view.gd").new()
 verify(renderer.has_method("build_geometry"),"transit renderer builds clipped textured ribbons")
 if renderer.has_method("build_geometry"):
  var city=Model.new(100,100,42)
  city.add_transit_route(PackedVector2Array([Vector2(10,20),Vector2(30,20)]))
  var geometry:Dictionary=renderer.build_geometry(city)
  var paths:Array=geometry.tracks[1]
  verify(paths.size()==2 and is_equal_approx(paths[0][0].y,19.5) and is_equal_approx(paths[1][0].y,20.5),"rail track centers are plus/minus 2 metres")
  verify(contains(geometry.rail,Vector2(20,20.94),"") and not contains(geometry.rail,Vector2(20,20.96),""),"ballast full width is 7.6 metres")
  verify(contains(geometry.rail,Vector2(10.4,19.5),"strip_end") and contains(geometry.rail,Vector2(29.6,20.5),"strip_end"),"both blocked terminals use end strips")
  verify(contains(geometry.rail,Vector2(20.2,19.5),"strip") and not contains(geometry.rail,Vector2(20.2,20),"strip"),"two 3.6m textured strips leave plain 0.4m center gap")
  var period_ok:=true
  for shape in geometry.rail:
   if shape.texture!="strip":continue
   for i in range(shape.points.size()):
    # Straight track: one world cell along X equals one complete 4m period.
    if absf(shape.uv[i].x-(shape.points[i].x-10))>.001:period_ok=false
  verify(period_ok,"strip U repeats every 4 metres of its own track length")
  city.add_transit_route(PackedVector2Array([Vector2(30,20),Vector2(40,20)]))
  geometry=renderer.build_geometry(city)
  verify(not contains(geometry.rail,Vector2(29.6,19.5),"strip_end") and not contains(geometry.rail,Vector2(30.4,19.5),"strip_end"),"connected endpoints have no buffers")
  city.add_road(PackedVector2Array([Vector2(20,10),Vector2(20,30)]))
  geometry=renderer.build_geometry(city)
  verify(contains(geometry.rail,Vector2(20.1,19.5),"strip_rails"),"road crossing draws rails-only strip")
  verify(not contains(geometry.rail,Vector2(20.1,19.5),"strip") and not contains(geometry.rail,Vector2(20.1,19.5),""),"crossing removes sleepers and ballast, not road geometry")
  city.add_transit_route(PackedVector2Array([Vector2(0,0),Vector2(20,0)]))
  city.add_transit_route(PackedVector2Array([Vector2(0,50),Vector2(20,50)]),"metro")
  geometry=renderer.build_geometry(city)
  var clipped:=true
  for shape in geometry.rail+geometry.metro:
   for point in shape.points:
    if point.x<-.0001 or point.y<-.0001 or point.x>100.0001 or point.y>100.0001:clipped=false
  verify(clipped,"all rail and tunnel polygons clipped to city boundary")
  var metro_paths:Array=geometry.tracks[4]
  verify(is_equal_approx(metro_paths[0][0].y,50-4.15/4) and is_equal_approx(metro_paths[1][0].y,50+4.15/4),"metro paths centered at plus/minus 4.15 metres")
  verify(not geometry.metro.is_empty() and geometry.metro[0].depth_m==-12.7 and geometry.metro[0].color==Color("15181a"),"metro uses black ribbon at rail-top depth minus 12.7m")
  verify(contains(geometry.metro,Vector2(10,51.49),"") and not contains(geometry.metro,Vector2(10,51.51),""),"metro ribbon full width is 12 metres")
  var curved=Model.new(100,100,43)
  var loop:=PackedVector2Array()
  for i in range(97):loop.append(Vector2(50,50)+Vector2.from_angle(TAU*i/96.0)*12)
  loop[-1]=loop[0]
  verify(curved.add_transit_route(loop).ok,"smooth closed route fixture respects minimum radius")
  geometry=renderer.build_geometry(curved)
  verify(not geometry.rail.any(func(item):return item.texture=="strip_end"),"closed loop has no blocked end buffers")
  paths=geometry.tracks[1]
  verify(absf(paths[0][0].distance_to(Vector2(50,50))-12.5)<.001 and absf(paths[1][0].distance_to(Vector2(50,50))-11.5)<.001,"closed track offsets meet at correct radial normal within polyline miter tolerance")
  verify(paths[0][0].is_equal_approx(paths[0][-1]) and paths[1][0].is_equal_approx(paths[1][-1]),"closed running strips share exact seam coordinates")
  verify(not contains(geometry.rail,Vector2(50,50),""),"closed rail loop never fills its interior with ballast")
 # Exact clipped sliver from the viewport free-curve contact at (40, 20).
 # Absolute projected coordinates lose the winding sign in float32 area sums.
 var sliver:=PackedVector2Array([Vector2(40,20.050003),Vector2(40,20.050636),Vector2(39.99968,20.050003)])
 var uv:=PackedVector2Array([Vector2(0,0),Vector2(0,1),Vector2(1,0)])
 var shapes:Array=[]
 renderer.append_uv_shapes(shapes,[sliver],sliver,uv,"strip_rails")
 verify(shapes.size()==1 and shapes[0].points==sliver,"exact clipped contact sliver is retained, not discarded")
 verify(shapes.size()==1 and shapes[0].get("indices",PackedInt32Array()).size()==3,"contact sliver retains valid world-space triangle indices")
 var mapped_ok:=shapes.size()==1
 if mapped_ok:
  for i in range(3):mapped_ok=mapped_ok and shapes[0].uv[i].is_equal_approx(uv[i])
 verify(mapped_ok,"contact sliver keeps interpolated UVs paired with original vertices")
 renderer.view={"tile":Vector2(14,7)}
 var projected:=PackedVector2Array()
 for point in sliver:projected.append(renderer.project_point(point))
 verify(not Geometry2D.triangulate_polygon(sliver).is_empty() and Geometry2D.triangulate_polygon(projected).is_empty(),"regression fixture reproduces projection-only triangulation failure")
 for name:String in ["strip","strip_end","strip_rails"]:
  var image:=Image.load_from_file("res://assets/rail/rail-track-01/"+name+".png")
  verify(image!=null and image.get_size()==Vector2i(320,288),"approved actual "+name+" texture loads at 320x288")
  if image!=null:
   image.generate_mipmaps();renderer.textures[name]=ImageTexture.create_from_image(image)
   verify(renderer.textures[name].get_image().has_mipmaps(),name+" runtime texture has mipmaps")
 var layer=renderer.PaintLayer.new();layer.owner_view=renderer;layer.shapes=shapes
 root.add_child(renderer);renderer.add_child(layer)
 layer.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
 layer.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 await process_frame
 await process_frame
 renderer.free()
 print("RESULT %d/%d transit render checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
