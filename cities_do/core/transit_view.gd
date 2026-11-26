extends Node2D
## P1 physical route interaction and retained visuals; no operating lines/stations.
const Routes=preload("res://core/transit_routes.gd")
const Crossover=preload("res://core/terminal_crossover.gd")
const Height=preload("res://core/road_height.gd")
const Operations=preload("res://core/transit_operations.gd")
var view
## E3a rail tool height (approved C): 0 = ground, +5m steps above; underground waits for E3b.
var target_height_m:=0.0
var pending:Dictionary={}
var warning_panel:PanelContainer
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
 # Original approved PNGs only; runtime mipmaps do not touch importer metadata.
 # Loaded before geometry so E3a deck pieces can use the same strips.
 for name:String in ["strip","strip_end","strip_rails"]:
  var path:="res://assets/rail/rail-track-01/"+name+".png"
  if not textures.has(name) and FileAccess.file_exists(path):
   var image:=Image.load_from_file(path)
   if image!=null and not image.is_empty():
    image.generate_mipmaps();textures[name]=ImageTexture.create_from_image(image);rail_layer.queue_redraw()
 var key:=hash([view.city.get_instance_id(),view.city.transit_routes,view.city.roads,view.city.public_facilities.lots,terminals,view.city.width,view.city.height])
 if key!=geometry_signature:
  geometry_signature=key;generation+=1;geometry=build_geometry(view.city)
  rail_layer.shapes=geometry.rail;metro_layer.shapes=geometry.metro
  rail_layer.queue_redraw();metro_layer.queue_redraw()
  if retained_renderer!=null:retained_renderer.sync_transit_structures()
 sync_visibility()
## Underground view (user rule 2026-11-19, ASSET_REQUEST_ELEVATED_TUNNEL_KO.md 8항): every entry path
## (road or rail tool below 0m, metro tool, bulldozer PgDn) sets `underground` and comes here. The metro
## layer (tunnels, covered parts, platform silhouettes, trains and cars under cover) shows only
## underground; ground rails and the world renderer's ground layers only on the ground.
func sync_visibility():
 if metro_layer!=null:metro_layer.visible=underground
 if rail_layer!=null:rail_layer.visible=not underground
 if retained_renderer!=null and retained_renderer.has_method("sync_view_layers"):retained_renderer.sync_view_layers()
func project_point(point:Vector2,depth_m:float=0)->Vector2:
 return Vector2((point.x-point.y)*view.tile.x,(point.x+point.y)*view.tile.y-depth_m*view.tile.x/4*sqrt(1.5))
func paint(canvas:CanvasItem,shapes:Array):
 for shape:Dictionary in shapes:
  var points:=PackedVector2Array()
  # E2 road tunnels carry one depth per vertex (ramps); metro uses one depth.
  var depths:PackedFloat64Array=shape.get("depths",PackedFloat64Array())
  for i in range(shape.points.size()):points.append(project_point(shape.points[i],depths[i] if depths.size()==shape.points.size() else shape.depth_m))
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
## E2: covered road sections and covered junctions are painted in the underground
## view like metro tunnels (solid 15181a band at their own road height).
static func append_road_tunnels(output:Array,city,bounds:PackedVector2Array):
 var height=preload("res://core/road_height.gd")
 # Geometry-only callers may pass a transit stub without road topology (read optionally).
 var visuals:Variant=city.get("road_visuals")
 for visual:Dictionary in (visuals if visuals is Array else []):
  if not height.sunken(visual):continue
  for part:Dictionary in height.covered_pieces(visual):
   for ribbon:PackedVector2Array in preload("res://core/road_geometry.gd").ribbons(part.points,float(visual.width),true,true):
    for clipped:PackedVector2Array in Geometry2D.intersect_polygons(ribbon,bounds):
     var band:=shape(clipped,Color("15181a"))
     var depths:=PackedFloat64Array()
     for point:Vector2 in clipped:depths.append(height.height_at(part,point))
     band.depths=depths;band.road_tunnel=true;output.append(band)
 var patches:Array=[]
 for key:String in ["junctions","road_joins"]:
  var value:Variant=city.get(key)
  if value is Array:patches.append_array(value)
 for junction:Dictionary in patches:
  var level:float=float(junction.get("height_m",0))
  if level>=0 or not height.covered_at(level) or not junction.has("box"):continue
  for clipped:PackedVector2Array in Geometry2D.intersect_polygons(junction.footprint,bounds):
   var band:=shape(clipped,Color("15181a"),level);band.road_tunnel=true;output.append(band)
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
## E3a: split a (track) polyline carrying the route heights into ground and raised parts.
## E3b: the ground part of a trench/tunnel route is only its 0m part.
static func level_parts(points:PackedVector2Array,route:Dictionary,raised_part:bool)->Array:
 if not Routes.off_ground(route):return [] if raised_part else [points]
 var carrier:={"points":points,"heights_m":route.heights_m}
 var result:Array=[]
 if raised_part and not Routes.raised(route):return result
 for piece:Dictionary in (Height.pieces_between(carrier,Routes.LEVEL_SPLIT_M,INF) if raised_part else Height.pieces_between(carrier,-Routes.LEVEL_SPLIT_M,Routes.LEVEL_SPLIT_M)):result.append(piece.points)
 return result
## E3b: open trench (0m..-7.0m portal) or covered tunnel (-7.0m and deeper) parts of a track polyline.
static func sunken_parts(points:PackedVector2Array,route:Dictionary,covered:bool)->Array:
 var result:Array=[]
 if not Routes.sunken(route):return result
 var carrier:={"points":points,"heights_m":route.heights_m}
 for piece:Dictionary in (Height.pieces_between(carrier,-INF,Height.RAIL_PORTAL_M) if covered else Height.pieces_between(carrier,Height.RAIL_PORTAL_M,-Routes.LEVEL_SPLIT_M)):result.append(piece.points)
 return result
static func densify(points:PackedVector2Array,step:float)->PackedVector2Array:
 var result:=PackedVector2Array([points[0]])
 for i in range(1,points.size()):
  var count:=maxi(1,ceili(points[i-1].distance_to(points[i])/step))
  for j in range(1,count+1):result.append(points[i-1].lerp(points[i],float(j)/count))
 return result
## Deck shapes keep world points plus one height per vertex; the elevated renderer draws them.
static func deck_shape(item:Dictionary,route:Dictionary)->Dictionary:
 var depths:=PackedFloat64Array()
 for point:Vector2 in item.points:depths.append(Height.height_at(route,point))
 item.depths=depths;item.route_id=route.id
 return item
static func build_geometry(city)->Dictionary:
 var result:={"rail":[],"metro":[],"tracks":{},"catenary":[],"crossovers":{},"deck":[],"trench":[]}
 var bounds:=boundary(city)
 var roads:Array=city.road_pavement+city.junction_pavement
 # All ballast first, then textured running strips, so overlapping branches cannot bury rails.
 for route:Dictionary in city.transit_routes:
  var tracks:Array=[]
  for offset:float in route.track_offsets_m:tracks.append(track_path(route.points,offset))
  result.tracks[route.id]=tracks
  for part:PackedVector2Array in level_parts(route.points,route,true):
   var deck_route:Dictionary=route.duplicate();deck_route.points=densify(part,.5)
   for polygon:PackedVector2Array in ribbons(deck_route):
    for clipped:PackedVector2Array in Geometry2D.intersect_polygons(polygon,bounds):result.deck.append(deck_shape(shape(clipped,Color("a59c8e")),route))
  # E3b: trench ballast is drawn in the trench clip group; the covered tunnel is a solid
  # 15181a band (10m structure) in the underground view at its own depth, like the metro.
  for covered:bool in [false,true]:
   for part:PackedVector2Array in sunken_parts(route.points,route,covered):
    var sunk_route:Dictionary=route.duplicate();sunk_route.points=densify(part,.5)
    if covered:sunk_route.width=Routes.STRUCTURE_WIDTH
    for polygon:PackedVector2Array in ribbons(sunk_route):
     for clipped:PackedVector2Array in Geometry2D.intersect_polygons(polygon,bounds):
      var item:=deck_shape(shape(clipped,Color("15181a") if covered else Color("a59c8e")),route)
      if covered:item.rail_tunnel=true;result.metro.append(item)
      else:result.trench.append(item)
  var ground_polygons:Array=[]
  for part:PackedVector2Array in level_parts(route.points,route,false):
   var ground_route:Dictionary=route.duplicate();ground_route.points=part
   ground_polygons.append_array(ribbons(ground_route))
  for polygon:PackedVector2Array in ground_polygons:
   var clipped:Array=Array(Geometry2D.intersect_polygons(polygon,bounds))
   if route.kind=="rail":
    for piece:PackedVector2Array in subtract_all(clipped,roads):result.rail.append(shape(piece,Color("a59c8e")))
   else:
    for piece:PackedVector2Array in clipped:result.metro.append(shape(piece,Color("15181a"),-12.7))
 append_road_tunnels(result.metro,city,bounds)
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
    # A deck passing overhead is not a junction with this track.
    for part:PackedVector2Array in level_parts(other.points,other,false):
     var ground_other:Dictionary=other.duplicate();ground_other.points=part;masks.append_array(ribbons(ground_other))
  preload("res://core/rail_catenary.gd").append_route(result.catenary,route,terminal(city,route,0),terminal(city,route,route.points.size()-1),city,pole_masks,[],crossovers)
  for path:PackedVector2Array in result.tracks[route.id]:
   var caps:=[terminal(city,route,0),terminal(city,route,route.points.size()-1)]
   for part:PackedVector2Array in level_parts(path,route,false):
    append_track(result.rail,part,caps[0] and part[0].distance_to(path[0])<.0005,caps[1] and part[-1].distance_to(path[-1])<.0005,bounds,masks)
   for part:PackedVector2Array in level_parts(path,route,true):
    var deck_strips:Array=[]
    append_track(deck_strips,part,caps[0] and part[0].distance_to(path[0])<.0005,caps[1] and part[-1].distance_to(path[-1])<.0005,bounds,[])
    for item:Dictionary in deck_strips:result.deck.append(deck_shape(item,route))
   for part:PackedVector2Array in sunken_parts(path,route,false):
    var trench_strips:Array=[]
    append_track(trench_strips,part,caps[0] and part[0].distance_to(path[0])<.0005,caps[1] and part[-1].distance_to(path[-1])<.0005,bounds,[])
    for item:Dictionary in trench_strips:result.trench.append(deck_shape(item,route))
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
 clear_warning()
 anchors.clear();start_tangent=Vector2.ZERO;preview_signature=null
 if view!=null:view.queue_redraw()
## Review fix 1 (user rule 2026-11-19): the bulldozer picks only what its current view shows, roads
## and rails alike, each part where it is drawn. Layers of one road or rail record:
## - "surface": ground parts (flat) and raised parts (ramps, decks) at their height. Ground view only.
## - "open": trenches and portals at their opening on the ground (their content is clipped to it).
##   Both views.
## - "covered": parts at or below the portal, and metro, at their depth. Underground view only.
static func drawn_pieces(record:Dictionary,layer:String,rail:bool)->Array:
 var width:float=float(record.width)
 var count:int=record.points.size()
 if record.get("kind","")=="metro":
  if layer!="covered":return []
  var depths:=PackedFloat64Array();depths.resize(count);depths.fill(float(record.get("rail_top_z_m",-12.7)))
  return [{"points":record.points,"heights":depths,"width":width}]
 if record.get("heights_m",PackedFloat64Array()).size()!=count or not Height.off_ground(record):
  if layer!="surface":return []
  var flat:=PackedFloat64Array();flat.resize(count);flat.fill(0.0)
  return [{"points":record.points,"heights":flat,"width":width}]
 var portal:float=Height.RAIL_PORTAL_M if rail else Height.portal_for(record)
 var structure:float=Routes.STRUCTURE_WIDTH if rail else width
 # [lowest height, highest height, pick width, drawn flat on the ground]
 var bands:Array=[]
 match layer:
  "surface":bands=[[Height.EPS,INF,structure,false],[-Height.EPS,Height.EPS,width,true]]
  "open":bands=[[portal,-Height.EPS,structure,true]]
  "covered":bands=[[-INF,portal,structure,false]]
 var result:Array=[]
 for band:Array in bands:
  for piece:Dictionary in Height.pieces_between(record,band[0],band[1]):
   var heights:PackedFloat64Array=piece.heights_m
   if band[3]:heights=PackedFloat64Array();heights.resize(piece.points.size());heights.fill(0.0)
   result.append({"points":piece.points,"heights":heights,"width":band[2]})
 return result
## Exact hit on straight ribbon segments whose height is linear along them (round vertex joins).
## A point p drawn at height h covers the ground point under the click q when p=q+(1,1)*lift*h.
static func hit_piece(piece:Dictionary,q:Vector2,lift:float)->Dictionary:
 var points:PackedVector2Array=piece.points;var heights:PackedFloat64Array=piece.heights
 var half:float=float(piece.width)/2;var best:Dictionary={}
 for i in range(points.size()):
  var at:Vector2=q+Vector2.ONE*lift*heights[i]
  if at.distance_to(points[i])<=half and (best.is_empty() or heights[i]>best.height):best={"height":heights[i],"point":at}
  if i==0:continue
  var a:Vector2=points[i-1];var d:Vector2=points[i]-a;var dh:float=heights[i]-heights[i-1]
  if d.length_squared()<1e-12:continue
  var n:Vector2=d.normalized().orthogonal();var e:Vector2=d-Vector2.ONE*lift*dh
  var det:float=e.cross(n)
  if absf(det)<1e-9:continue
  var r:Vector2=q-a+Vector2.ONE*lift*heights[i-1]
  var t:float=r.cross(n)/det;var u:float=e.cross(r)/det
  if t<0 or t>1 or absf(u)>half:continue
  var h:float=heights[i-1]+dh*t
  if best.is_empty() or h>best.height:best={"height":h,"point":a+d*t+n*u}
 return best
static func ahead(a:Array,b:Array)->bool:
 for i in range(a.size()):
  if a[i]!=b[i]:return a[i]>b[i]
 return false
## Higher drawn height wins. At a road/rail tie, prefer the bulldozer's source tool when set;
## otherwise keep the old layer order. Transit/transit and road/road ordering stays unchanged.
func pick_drawn(position:Vector2,layers:Array,preferred_kind:String="")->Dictionary:
 var city=view.city;var q:Vector2=view.world(position)
 var lift:float=view.tile.x/4*sqrt(1.5)/(2*view.tile.y)
 var covered:bool=layers.has("covered")
 var best:Dictionary={};var best_key:Array=[]
 for i in range(city.transit_routes.size()):
  var route:Dictionary=city.transit_routes[i]
  for layer:String in layers:
   for piece:Dictionary in drawn_pieces(route,layer,true):
    var hit:=hit_piece(piece,q,lift)
    var key:Array=[hit.get("height",0.0),0 if covered else 1,i]
    if not hit.is_empty() and (best.is_empty() or ahead(key,best_key)):best={"route":route};best_key=key
 # Apply the road/rail preference only after choosing the best transit hit, not between transit hits.
 var rail_hit:bool=not best.is_empty() and best.route.get("kind","")=="rail"
 if rail_hit and preferred_kind=="rail":best_key[1]=2
 var road_priority:int=2 if rail_hit and preferred_kind=="road" else (1 if covered else 0)
 for i in range(city.roads.size()):
  var road:Dictionary=city.roads[i]
  for layer:String in layers:
   for piece:Dictionary in drawn_pieces(road,layer,false):
    var hit:=hit_piece(piece,q,lift)
    var key:Array=[hit.get("height",0.0),road_priority,-i]
    if not hit.is_empty() and (best.is_empty() or ahead(key,best_key)):best={"road":road,"index":i,"point":hit.point};best_key=key
 if best.has("road"):
  var id:int=best.road.get("parcel_id",best.index)
  return {"kind":"road","id":id,"selection":city.road_demolition_selection(id,best.point),"world_point":best.point}
 if best.has("route"):return {"kind":"transit_route","id":best.route.id,"polygons":drawn_polygons(best.route)}
 return {}
## Hover tint of the whole route, each part where it is drawn in the current view.
func drawn_polygons(route:Dictionary)->Array:
 var pieces:Array=[]
 for layer:String in (["surface","open","covered"] if underground else ["surface","open"]):pieces.append_array(drawn_pieces(route,layer,true))
 var result:Array=[]
 for piece:Dictionary in pieces:
  var quads:Array=ribbons({"points":piece.points,"width":piece.width})
  for i in range(quads.size()):
   var projected:=PackedVector2Array()
   for k in range(4):projected.append(view.origin+project_point(quads[i][k],piece.heights[i] if k in [0,3] else piece.heights[i+1])*view.map_zoom)
   result.append(projected)
 return result
func preview()->Dictionary:
 var key:=hash([view.city.get_instance_id(),view.mode,view.road_drawer.kind,anchors,start_tangent,view.pointer,view.city.transit_routes,view.city.roads,view.city.buildings,view.city.public_facilities.lots,view.city.power.plants,view.city.water.facilities])
 key=hash([key,target_height_m if view.mode=="rail" else 0.0])
 if not pending.is_empty():return pending.duplicate(true)
 if key!=preview_signature:
  preview_signature=key
  preview_cache=Routes.resolve(view.city,view.mode,view.road_drawer.kind,anchors,view.pointer,start_tangent,target_height_m if view.mode=="rail" else 0.0)
 return preview_cache.duplicate(true)
func set_height(value:float):
 # E3b: the rail tool also steps below ground (5m layers); a target below ground shows the underground view.
 target_height_m=roundf(value/5)*5
 preview_signature=null
 var controls=view.find_child("RailHeightControls",true,false)
 if controls!=null:
  controls.synchronize()
  if view.has_method("remember_rail_height_control"):view.remember_rail_height_control(controls)
 sync_underground_view()
 view.queue_redraw()
func sync_underground_view():
 if view==null or view.get("mode")!="rail":return
 var below:=target_height_m< -Height.EPS
 if underground!=below:underground=below;sync_visibility()
func clear_warning():
 pending.clear()
 if is_instance_valid(warning_panel):warning_panel.hide();warning_panel.queue_free()
 warning_panel=null
 if view!=null and view.get("world_renderer")!=null:
  for sprite in view.world_renderer.buildings.values():sprite.modulate=Color.WHITE
func confirm_pending():
 if pending.is_empty():return
 var approved:Dictionary=pending.duplicate(true)
 clear_warning()
 if approved.city_id!=view.city.get_instance_id():cancel();return
 commit(approved,true)
func commit(plan:Dictionary,confirmed:bool):
 # Edit warning (user rule 2026-11-19): a track that changes the route of a running rail line waits
 # for 확인 (main.gd guard_route_edit); 취소 keeps the drawing as it was.
 var after:Variant=null
 var trial:Dictionary=view.city.add_transit_route(plan.points,view.mode,false,plan.get("heights_m",PackedFloat64Array()))
 if trial.get("ok",false):
  after=Operations.draft(view.city);after.transit_routes.append(trial.route)
 if view.has_method("guard_route_edit"):view.guard_route_edit(after,build.bind(plan,confirmed))
 else:build(plan,confirmed)
func build(plan:Dictionary,confirmed:bool):
 var points:PackedVector2Array=plan.points
 var heights:PackedFloat64Array=plan.get("heights_m",PackedFloat64Array())
 last_result=view.city.add_transit_route(points,view.mode,true,heights,confirmed,plan.get("demolish_ids",[]) if confirmed else null)
 var accepted:bool=last_result.ok or last_result.get("queued",false)
 view.message="" if accepted else last_result.reason
 if accepted:
  cancel()
  if view.road_drawer.kind=="straight":anchors.append(points[-1]);start_tangent=(points[-1]-points[-2]).normalized()
 view.refresh()
func tool_height()->float:return -12.7 if view.mode=="metro" else target_height_m
func screen_point(point:Vector2,height:float=NAN)->Vector2:
 return view.origin+project_point(point,tool_height() if is_nan(height) else height)*view.map_zoom
func input_point(position:Vector2)->Vector2:
 return view.world(position-project_point(Vector2.ZERO,tool_height())*view.map_zoom)
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
 sync_underground_view()
 if anchors.is_empty():
  if not cursor_preview().ok:view.queue_redraw();return
  var snap:=Routes.snap(view.city,point,view.mode)
  anchors.append(snap.point);start_tangent=snap.tangent;view.queue_redraw();return
 if view.road_drawer.kind=="curve" and anchors.size()==1:
  anchors.append(point);view.queue_redraw();return
 if not pending.is_empty():return
 last_result=preview()
 if not last_result.ok:
  view.message=last_result.reason;view.refresh();return
 last_result.city_id=view.city.get_instance_id()
 if last_result.get("warning",false):
  # Approved warning B, shared with E1 roads: yellow buildings, bubble, confirm/cancel.
  pending=last_result.duplicate(true)
  warning_panel=preload("res://core/road_demolition_warning.gd").new()
  view.drawer.get_parent().add_child(warning_panel)
  warning_panel.setup(self,screen_point(last_result.points[-1],Height.height_at(last_result.route,last_result.points[-1])),pending.demolish_ids.size())
  for id in pending.demolish_ids:
   var sprite=view.world_renderer.buildings.get(id) if view.get("world_renderer")!=null else null
   if sprite!=null:sprite.modulate=Color(1.25,1.12,.35)
  view.queue_redraw();return
 commit(last_result,false)
func handle_input(event:InputEvent)->bool:
 if view.mode not in ["rail","metro"]:return false
 if view.mode=="rail" and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_PAGEUP,KEY_PAGEDOWN]:
  set_height(target_height_m+(5 if event.keycode==KEY_PAGEUP else -5));return true
 if not pending.is_empty() and event is InputEventMouseButton:return false
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
 var heights:PackedFloat64Array=result.get("heights_m",PackedFloat64Array())
 if heights.size()==points.size():route.heights_m=heights;route.width=Routes.STRUCTURE_WIDTH if Routes.off_ground(route) else route.width
 var color:=Color(.94,.32,.31,.5)
 if result.ok:color=Color(1,.82,.15,.55) if result.get("warning",false) else Color(.24,.86,.52,.5)
 for polygon in ribbons(route):
  for clipped in Geometry2D.intersect_polygons(polygon,boundary(view.city)):
   var projected:=PackedVector2Array()
   for p in clipped:projected.append(screen_point(p,-12.7 if view.mode=="metro" else Height.height_at(route,p)))
   view.draw_colored_polygon(projected,color)
