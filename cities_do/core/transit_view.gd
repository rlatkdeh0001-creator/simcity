extends Node2D
## P1 physical route interaction and retained visuals; no operating lines/stations.
const Routes=preload("res://core/transit_routes.gd")
const Crossover=preload("res://core/terminal_crossover.gd")
var view
var anchors:=PackedVector2Array()
var start_tangent:=Vector2.ZERO
var last_result:Dictionary={}
var underground:=false
var preview_signature:Variant=null
var preview_cache:Dictionary={}
var city_reference
var geometry_signature:Variant=null
var generation:=0
var geometry:Dictionary={"rail":[],"metro":[],"tracks":{}}
var textures:Dictionary={}
var rail_layer:Node2D
var metro_layer:Node2D
class PaintLayer extends Node2D:
 var owner_view
 var shapes:Array=[]
 func _draw():owner_view.paint(self,shapes)
func setup(owner_view):view=owner_view
var retained_renderer
func attach(renderer:Node2D):
 retained_renderer=renderer
 rail_layer=PaintLayer.new();rail_layer.owner_view=self;rail_layer.z_index=5;renderer.add_child(rail_layer)
 metro_layer=PaintLayer.new();metro_layer.owner_view=self;metro_layer.z_index=10;renderer.add_child(metro_layer)
 for layer in [rail_layer,metro_layer]:
  layer.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
  layer.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 synchronize()
func synchronize():
 if rail_layer==null:return
 if city_reference!=view.city:
  if city_reference!=null and city_reference.transit_changed.is_connected(synchronize):city_reference.transit_changed.disconnect(synchronize)
  city_reference=view.city;city_reference.transit_changed.connect(synchronize)
 var terminals:Array=[]
 for line:Dictionary in view.city.transit_lines:
  if line.has("terminal_ports"):terminals.append([line.id,line.terminal_ports])
 var key:=hash([view.city.get_instance_id(),view.city.transit_routes,view.city.roads,view.city.public_facilities.lots,terminals,view.city.width,view.city.height])
 if key!=geometry_signature:
  geometry_signature=key;generation+=1;geometry=build_geometry(view.city)
  rail_layer.shapes=geometry.rail;metro_layer.shapes=geometry.metro
  rail_layer.queue_redraw();metro_layer.queue_redraw()
  if retained_renderer!=null:retained_renderer.sync_catenary()
 # Original approved PNGs only; runtime mipmaps do not touch importer metadata.
 for name:String in ["strip","strip_end","strip_rails"]:
  var path:="res://assets/rail/rail-track-01/"+name+".png"
  if not textures.has(name) and FileAccess.file_exists(path):
   var image:=Image.load_from_file(path)
   if image!=null and not image.is_empty():
    image.generate_mipmaps();textures[name]=ImageTexture.create_from_image(image);rail_layer.queue_redraw()
 sync_visibility()
func sync_visibility():
 if metro_layer!=null:metro_layer.visible=underground
func project_point(point:Vector2,depth_m:float=0)->Vector2:
 return Vector2((point.x-point.y)*view.tile.x,(point.x+point.y)*view.tile.y-depth_m*view.tile.x/4*sqrt(1.5))
func paint(canvas:CanvasItem,shapes:Array):
 for shape:Dictionary in shapes:
  var points:=PackedVector2Array()
  for p:Vector2 in shape.points:points.append(project_point(p,shape.depth_m))
  if shape.texture.is_empty():canvas.draw_colored_polygon(points,shape.color)
  elif textures.has(shape.texture):
   # Reuse world-space triangulation: projection can lose the winding of tiny
   # clipped contact slivers through float32 cancellation. Keep their UVs/area.
   RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),shape.indices,points,PackedColorArray([Color.WHITE]),shape.uv,PackedInt32Array(),PackedFloat32Array(),textures[shape.texture].get_rid())

static func boundary(city)->PackedVector2Array:
 return PackedVector2Array([Vector2.ZERO,Vector2(city.width,0),Vector2(city.width,city.height),Vector2(0,city.height)])
static func normal_at(points:PackedVector2Array,i:int)->Vector2:
 var before:Vector2=(points[i]-points[i-1]).normalized() if i>0 else (points[1]-points[0]).normalized()
 var after:Vector2=(points[i+1]-points[i]).normalized() if i<points.size()-1 else before
 if points.size()>2 and points[0].distance_to(points[-1])<.0005 and i in [0,points.size()-1]:
  before=(points[0]-points[-2]).normalized();after=(points[1]-points[0]).normalized()
 var normal:=Vector2(-(before+after).y,(before+after).x).normalized()
 return normal/maxf(.5,normal.dot(Vector2(-after.y,after.x)))
static func track_path(points:PackedVector2Array,offset_m:float)->PackedVector2Array:
 var result:=PackedVector2Array()
 for i in range(points.size()):result.append(points[i]+normal_at(points,i)*offset_m/4)
 return result
static func terminal(city,route:Dictionary,index:int)->bool:
 if route.points[0].distance_to(route.points[-1])<.0005:return false
 var point:Vector2=route.points[index]
 if point.x<=.0005 or point.y<=.0005 or point.x>=city.width-.0005 or point.y>=city.height-.0005:return false
 for other:Dictionary in city.transit_routes:
  if other.id==route.id or other.kind!=route.kind:continue
  for i in range(1,other.points.size()):
   if Geometry2D.get_closest_point_to_segment(point,other.points[i-1],other.points[i]).distance_to(point)<.0005:return false
 return true
static func subtract_all(polygons:Array,masks:Array)->Array:
 var result:Array=polygons
 for mask:PackedVector2Array in masks:
  var next:Array=[]
  for polygon:PackedVector2Array in result:next.append_array(Geometry2D.clip_polygons(polygon,mask))
  result=next
 return result
static func shape(points:PackedVector2Array,color:Color,depth_m:float=0,texture:String="",uv:PackedVector2Array=PackedVector2Array())->Dictionary:
 return {"points":points,"color":color,"depth_m":depth_m,"texture":texture,"uv":uv}
static func ribbons(route:Dictionary)->Array:
 # Segment quads, not independent fill of offset_polyline outer/hole contours.
 # A closed route's interior is terrain, never a solid ballast/tunnel polygon.
 var result:Array=[]
 var points:PackedVector2Array=route.points
 for i in range(1,points.size()):
  var a:=normal_at(points,i-1)*float(route.width)/2
  var b:=normal_at(points,i)*float(route.width)/2
  result.append(PackedVector2Array([points[i-1]-a,points[i]-b,points[i]+b,points[i-1]+a]))
 return result
static func build_geometry(city)->Dictionary:
 var result:={"rail":[],"metro":[],"tracks":{},"catenary":[],"crossovers":{}}
 var bounds:=boundary(city)
 var roads:Array=city.road_pavement+city.junction_pavement
 # All ballast first, then textured running strips, so overlapping branches cannot bury rails.
 for route:Dictionary in city.transit_routes:
  var tracks:Array=[]
  for offset:float in route.track_offsets_m:tracks.append(track_path(route.points,offset))
  result.tracks[route.id]=tracks
  for polygon:PackedVector2Array in ribbons(route):
   var clipped:Array=Array(Geometry2D.intersect_polygons(polygon,bounds))
   if route.kind=="rail":
    for piece:PackedVector2Array in subtract_all(clipped,roads):result.rail.append(shape(piece,Color("a59c8e")))
   else:
    for piece:PackedVector2Array in clipped:result.metro.append(shape(piece,Color("15181a"),-12.7))
 var pole_masks:Array=[]
 for pavement:PackedVector2Array in roads:pole_masks.append_array(Geometry2D.offset_polygon(pavement,.25,Geometry2D.JOIN_MITER))
 for lot:Dictionary in city.public_facilities.lots:
  if lot.get("public_asset_id","")=="train-station-01":pole_masks.append_array(Geometry2D.offset_polygon(lot.polygon,.25,Geometry2D.JOIN_MITER))
 var crossovers: Array = []
 var crossover_rails: Array = []
 for x:Dictionary in Crossover.owned(city).values():
  if x.kind!="rail":continue
  result.crossovers[x.key]=x
  crossovers.append(x)
  for path_m:PackedVector2Array in x.paths:
   var path:=PackedVector2Array()
   for point:Vector2 in path_m:path.append(point/4.0)
   append_track(result.rail,path,false,false,bounds,[])
   append_track(crossover_rails,path,false,false,bounds,[],"strip_rails")
 for route:Dictionary in city.transit_routes:
  if route.kind!="rail":continue
  var masks:Array=roads.duplicate()
  for other:Dictionary in city.transit_routes:
   if other.kind=="rail" and other.id!=route.id:
    masks.append_array(ribbons(other))
  preload("res://core/rail_catenary.gd").append_route(result.catenary,route,terminal(city,route,0),terminal(city,route,route.points.size()-1),city,pole_masks,[],crossovers)
  for path:PackedVector2Array in result.tracks[route.id]:
   append_track(result.rail,path,terminal(city,route,0),terminal(city,route,route.points.size()-1),bounds,masks)
 var catenary=preload("res://core/rail_catenary.gd")
 var portals:Array=catenary.plan_portals(result.catenary,city.transit_routes,pole_masks)
 if not portals.is_empty():
  result.catenary.clear()
  for route:Dictionary in city.transit_routes:
   catenary.append_route(result.catenary,route,terminal(city,route,0),terminal(city,route,route.points.size()-1),city,pole_masks,portals,crossovers)
  result.catenary=catenary.apply_portals(result.catenary,portals)
 result.rail.append_array(crossover_rails)
 for x:Dictionary in crossovers:catenary.append_crossover(result.catenary,x,city,pole_masks)
 result.catenary=catenary.combine_inner_poles(result.catenary)
 var unique:Array=[];var seen:Dictionary={}
 for item:Dictionary in result.catenary:
  var key:Variant=[item.kind,Vector2(snappedf(item.a.x,.0001),snappedf(item.a.y,.0001)),Vector2(snappedf(item.b.x,.0001),snappedf(item.b.y,.0001)),item.a_height,item.b_height]
  if not seen.has(key):seen[key]=true;unique.append(item)
 result.catenary=[]
 catenary.append_clipped(result.catenary,unique,city)
 return result
static func append_track(output:Array,path:PackedVector2Array,start_cap:bool,end_cap:bool,bounds:PackedVector2Array,masks:Array,texture:String="strip"):
 var total:=Routes.Paths.length_of(path)
 var samples:=PackedVector2Array([path[0]])
 var distances:=PackedFloat64Array([0.0])
 var travelled:=0.0
 for i in range(1,path.size()):
  var length:=path[i-1].distance_to(path[i])
  var cuts:Array[float]=[]
  for step in range(1,maxi(1,ceili(length/.5))+1):cuts.append(length*step/maxi(1,ceili(length/.5)))
  for split:float in [1.0,total-1.0]:
   if split>travelled+.00001 and split<travelled+length-.00001:cuts.append(split-travelled)
  cuts.sort()
  for cut:float in cuts:
   if travelled+cut-distances[-1]<.00001:continue
   samples.append(path[i-1].lerp(path[i],cut/length));distances.append(travelled+cut)
  travelled+=length
 for i in range(1,samples.size()):
  var a:=samples[i-1];var b:=samples[i]
  var n0:=normal_at(samples,i-1)*.45;var n1:=normal_at(samples,i)*.45
  var quad:=PackedVector2Array([a-n0,b-n1,b+n1,a+n0])
  var u0:=distances[i-1];var u1:=distances[i];var name:=texture
  if start_cap and u1<=1.00001:name="strip_end";u0=1-distances[i-1];u1=1-distances[i]
  elif end_cap and u0>=total-1.00001:name="strip_end";u0=distances[i-1]-(total-1);u1=distances[i]-(total-1)
  var uv:=PackedVector2Array([Vector2(u0,0),Vector2(u1,0),Vector2(u1,1),Vector2(u0,1)])
  for indices:Array in [[0,1,2],[0,2,3]]:
   var tri:=PackedVector2Array([quad[indices[0]],quad[indices[1]],quad[indices[2]]])
   var tuv:=PackedVector2Array([uv[indices[0]],uv[indices[1]],uv[indices[2]]])
   var clipped:Array=Array(Geometry2D.intersect_polygons(tri,bounds))
   var remaining:Array=clipped
   var crossings:Array=[]
   for mask:PackedVector2Array in masks:
    var next:Array=[]
    for polygon:PackedVector2Array in remaining:
     crossings.append_array(Geometry2D.intersect_polygons(polygon,mask))
     next.append_array(Geometry2D.clip_polygons(polygon,mask))
    remaining=next
   append_uv_shapes(output,remaining,tri,tuv,name)
   # Buffer images must never cover the road surface or a branching running rail.
   var running_uv:=PackedVector2Array([Vector2(distances[i-1],0),Vector2(distances[i],0),Vector2(distances[i],1),Vector2(distances[i-1],1)])
   append_uv_shapes(output,crossings,tri,PackedVector2Array([running_uv[indices[0]],running_uv[indices[1]],running_uv[indices[2]]]),"strip_rails")
static func append_uv_shapes(output:Array,polygons:Array,tri:PackedVector2Array,uv:PackedVector2Array,name:String):
 var axis:=tri[1]-tri[0];var side:=tri[2]-tri[0];var area:=axis.cross(side)
 if absf(area)<.0000001:return
 for polygon:PackedVector2Array in polygons:
  if polygon.size()<3:continue
  var indices:=Geometry2D.triangulate_polygon(polygon)
  if indices.is_empty():continue
  var mapped:=PackedVector2Array()
  for point:Vector2 in polygon:
   var delta:=point-tri[0]
   mapped.append(uv[0]+(uv[1]-uv[0])*delta.cross(side)/area+(uv[2]-uv[0])*axis.cross(delta)/area)
  var item:=shape(polygon,Color.WHITE,0,name,mapped)
  item.indices=indices;output.append(item)
func cancel():
 anchors.clear();start_tangent=Vector2.ZERO;preview_signature=null
 if view!=null:view.queue_redraw()
func pick(position:Vector2,kind:String="")->Dictionary:
 for i in range(view.city.transit_routes.size()-1,-1,-1):
  var route:Dictionary=view.city.transit_routes[i]
  if not kind.is_empty() and route.kind!=kind:continue
  if route.kind=="metro" and not underground:continue
  var polygons:Array=[];var hit:=false
  for ribbon:PackedVector2Array in ribbons(route):
   for clipped:PackedVector2Array in Geometry2D.intersect_polygons(ribbon,boundary(view.city)):
    var projected:=PackedVector2Array()
    for p:Vector2 in clipped:projected.append(view.origin+project_point(p,route.rail_top_z_m)*view.map_zoom)
    polygons.append(projected)
    if Geometry2D.is_point_in_polygon(position,projected):hit=true
  if hit:return {"kind":"transit_route","id":route.id,"polygons":polygons}
 return {}
func preview()->Dictionary:
 var key:=hash([view.city.get_instance_id(),view.mode,view.road_drawer.kind,anchors,start_tangent,view.pointer,view.city.transit_routes,view.city.roads,view.city.buildings,view.city.public_facilities.lots,view.city.power.plants,view.city.water.facilities])
 if key!=preview_signature:
  preview_signature=key
  preview_cache=Routes.resolve(view.city,view.mode,view.road_drawer.kind,anchors,view.pointer,start_tangent)
 return preview_cache.duplicate(true)
func screen_point(point:Vector2)->Vector2:
 return view.origin+project_point(point,-12.7 if view.mode=="metro" else 0.0)*view.map_zoom
func input_point(position:Vector2)->Vector2:
 return view.world(position-project_point(Vector2.ZERO,-12.7 if view.mode=="metro" else 0.0)*view.map_zoom)
func cursor_preview()->Dictionary:
 var snap:=Routes.snap(view.city,view.pointer,view.mode)
 var p:Vector2=snap.point
 var width:float=Routes.profile(view.mode).width
 var valid:bool=p.is_finite() and p.x>=0 and p.y>=0 and p.x<=view.city.width and p.y<=view.city.height
 var probe:={"points":PackedVector2Array([p,p]),"width":width}
 var obstacles:Array=[]
 for b:Dictionary in view.city.buildings:obstacles.append(view.city.footprint(b))
 for lot:Dictionary in view.city.public_facilities.lots:
  var station_port:=false
  if view.mode=="rail" and lot.has("station_ports"):
   for port:Dictionary in lot.station_ports:
    if Vector2(port.point).distance_to(p)<Routes.EPS:station_port=true
  if not station_port:obstacles.append(lot.polygon)
 for facility:Dictionary in view.city.power.plants+view.city.water.facilities:obstacles.append(view.city.power_plant_footprint(facility))
 for polygon:PackedVector2Array in obstacles:
  if view.city._polygon_road_distance(polygon,probe)<-.0005:valid=false
 return {"center":p,"radius":width/2,"ok":valid,"snapped":snap.snapped}
func cursor_ring(center:Vector2,radius:float)->PackedVector2Array:
 var points:=PackedVector2Array()
 for i in range(65):points.append(screen_point(center+Vector2.from_angle(TAU*i/64.0)*radius))
 return points
func click(point:Vector2):
 view.pointer=point
 if anchors.is_empty():
  if not cursor_preview().ok:view.queue_redraw();return
  var snap:=Routes.snap(view.city,point,view.mode)
  anchors.append(snap.point);start_tangent=snap.tangent;view.queue_redraw();return
 if view.road_drawer.kind=="curve" and anchors.size()==1:
  anchors.append(point);view.queue_redraw();return
 last_result=preview()
 if not last_result.ok:
  view.message=last_result.reason;view.refresh();return
 var points:PackedVector2Array=last_result.points
 last_result=view.city.add_transit_route(points,view.mode,true)
 var accepted:bool=last_result.ok or last_result.get("queued",false)
 view.message="" if accepted else last_result.reason
 if accepted:
  cancel()
  if view.road_drawer.kind=="straight":anchors.append(points[-1]);start_tangent=(points[-1]-points[-2]).normalized()
 view.refresh()
func handle_input(event:InputEvent)->bool:
 if view.mode not in ["rail","metro"]:return false
 if event is InputEventMouseMotion:
  if view.panning:return false
  view.pointer=input_point(event.position);view.queue_redraw();return true
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:click(input_point(event.position))
  return true
 return false
func draw_preview():
 if view.mode not in ["rail","metro"] or view.get_viewport().gui_get_hovered_control()!=null:return
 if anchors.is_empty():
  var state:=cursor_preview();var edge:=Color("3ddc84") if state.ok else Color("ef5350")
  var tint:=edge;tint.a=.35
  var disc:=cursor_ring(state.center,state.radius)
  view.draw_colored_polygon(disc,tint);view.draw_polyline(disc,edge,2,true)
  if state.snapped:
   var ring:=cursor_ring(state.center,state.radius*1.33)
   for i in range(0,64,4):view.draw_polyline(ring.slice(i,i+3),Color("36b7ff"),2,true)
  return
 if view.road_drawer.kind=="curve" and anchors.size()==1:
  view.draw_line(screen_point(anchors[0]),screen_point(view.pointer),Color("36b7ff"),2,true);return
 var result:=preview()
 var points:PackedVector2Array=result.get("points",PackedVector2Array([anchors[0],view.pointer]))
 if points.size()<2:return
 var route:=Routes.profile(view.mode);route.points=points
 for polygon in ribbons(route):
  for clipped in Geometry2D.intersect_polygons(polygon,boundary(view.city)):
   var projected:=PackedVector2Array()
   for p in clipped:projected.append(screen_point(p))
   view.draw_colored_polygon(projected,Color(.24,.86,.52,.5) if result.ok else Color(.94,.32,.31,.5))
