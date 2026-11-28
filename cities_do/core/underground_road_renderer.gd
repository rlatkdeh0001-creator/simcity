extends RefCounted
## E2 trench and portal pieces. Everything below ground (far retaining-wall face,
## road surface, portal strip, portal mouth and cars in the trench) sits in one
## clip_children group per trench, drawn before WorldActors. Barriers above
## ground are retained pieces in TrenchBarriers, y-sorted together with WorldActors
## and shown in both views. Covered parts are not drawn here: the underground view
## paints them like metro tunnels (transit_view.gd).
const Height=preload("res://core/road_height.gd")
const Profile=preload("res://core/road_profile.gd")
const Geometry=preload("res://core/road_geometry.gd")
const Elevated=preload("res://core/elevated_road_renderer.gd")
const WALL:="retaining-wall-01/wall.png"
const PORTAL:="tunnel-portal-01/portal.png"
const WALL_STRIP_M:=9.0 # wall.png 720px at 80px/m
const PORTAL_STRIP_M:=2.6 # portal.png 208px at 80px/m
const BARRIER_M:=1.1 # Shared top 88px: barrier above ground; ground level is v=1.1m.
const WALL_INSET:=.125 # retaining-wall-01 spec wall_thickness_m 0.5m: inner width W-1.0m.
const BARRIER_WIDTH:=.1 # 0.4m barrier top band (cells).
const CENTER_BARRIER_HALF:=.0625 # 0.5m overall width in a 16m centre.
const FAR_RAISE_M:=4.0 # Clip outline far edge raise (ASSET_REQUEST 5절 6번).
const RAIL_FAR_RAISE_M:=6.0 # E3b: rail trenches carry catenary (5.3m poles), so the far edge rises 6m.
const UNDERGROUND_RAIL_CAR_HIDE_BELOW_M:=-5.0
const MIN_RAIL_BODY_EXPOSURE:=.5
const MOUTH_TOP_M:=-1.5 # tunnel-portal-01 spec mouth_top_below_ground_m.
const WALL_SHADE:=[.775339076072665,1.05279764424266] # retaining-wall-01 spec.json face_shade +X/-Y.
const PORTAL_SHADE:=[.77429849084644,1.05327280147779] # tunnel-portal-01 spec.json face_shade +X/-Y.
const INTERIOR:=Color("15181a") # tunnel-portal-01 spec interior_color, same as the metro tunnel.
class Trench extends Node2D:
 var outlines:Array[PackedVector2Array]=[]
 var footprints:Array[PackedVector2Array]=[]
 var near_edges:Array[PackedVector2Array]=[] # Inner barrier edges projected at ground level.
 var source_ids:Array=[]
 var world_bounds:Rect2
 func _draw():
  for outline:PackedVector2Array in outlines:
   if outline.size()>=3 and not Geometry2D.triangulate_polygon(outline).is_empty():draw_colored_polygon(outline,Color.WHITE)
var owner_reference:WeakRef
var renderer:
 get:return owner_reference.get_ref()
var trenches:Array=[]
var trenches_by_source:Dictionary={}
var vehicle_trench_lookups:=0
var vehicle_trench_group_visits:=0
var vehicle_trench_footprint_visits:=0
var barriers:Array=[]
var portals:Array=[]
var rail_silhouettes:Dictionary={}
func _init(owner):owner_reference=weakref(owner)
func project(point:Vector2,height_m:float)->Vector2:return renderer.elevated.project(point,height_m)
func projected(polygon_value:PackedVector2Array,source:Dictionary)->PackedVector2Array:
 var result:=PackedVector2Array()
 for point in polygon_value:result.append(project(point,Height.height_at(source,point)))
 return result
func shade(pair:Array,normal:Vector2)->float:
 return lerpf(pair[0],pair[1],absf(normal.y)/maxf(.0001,absf(normal.x)+absf(normal.y)))
func polygon(node,shape:PackedVector2Array,color:Color):
 if shape.size()>=3 and not Geometry2D.triangulate_polygon(shape).is_empty():node.commands.append({"polygon":shape,"color":color})
## Vertical strip face from top (ta,tb) to bottom (ba,bb); v starts v_top metres into the strip.
func band(node,a:Vector2,b:Vector2,ta:float,tb:float,ba:float,bb:float,u:float,path:String,strip_m:float,v_top:float,value:float,phase_length:float=-1.0):
 var image:Texture2D=renderer.elevated.texture(path)
 if image==null:return
 var points:=PackedVector2Array([project(a,ta),project(b,tb),project(b,bb),project(a,ba)])
 if Geometry2D.triangulate_polygon(points).is_empty():return
 var length:=a.distance_to(b) if phase_length<0.0 else phase_length
 var uv:=PackedVector2Array([Vector2(u,v_top/strip_m),Vector2(u+length,v_top/strip_m),Vector2(u+length,(v_top+tb-bb)/strip_m),Vector2(u,(v_top+ta-ba)/strip_m)])
 node.commands.append({"polygon":points,"color":Color(value,value,value),"uv":uv,"texture":image})
func piece(name_value:String,road:Dictionary,footprint:PackedVector2Array)->Elevated.Piece:
 var node:=Elevated.Piece.new();node.name=name_value;node.road=road;node.footprint=footprint
 node.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED;node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 return node
func barrier_piece(road:Dictionary,footprint:PackedVector2Array)->Elevated.Piece:
 var node:=piece("TrenchBarrier",road,footprint)
 var depth:float=-INF
 for point in footprint:depth=maxf(depth,renderer.iso(point).y)
 node.base_depth=depth;node.position.y=depth
 renderer.trench_actors.add_child(node);barriers.append(node)
 return node
func rebuild():
 for trench:Trench in trenches:
  # Cars, trains and catenary are owned by the world renderer: hand them back before freeing the group.
  for child in trench.get_children():
   if not child is Elevated.Piece:child.reparent(renderer.actors,false)
  trench.hide();trench.queue_free()
 for node in barriers:node.hide();node.queue_free()
 trenches.clear();barriers.clear();portals.clear()
 trenches_by_source.clear()
 var city=renderer.view.city
 for visual:Dictionary in city.road_visuals:
  if not Height.sunken(visual):continue
  # E4d retains a flat split/merge lead just above the trench. Do not
  # admit the 0m lead through the legacy tolerance at the -EPS clip limit.
  for part:Dictionary in Height.pieces_between(visual,Height.PORTAL_M,-Height.EPS,Profile.is_center_structure(visual)):build_trench(city,visual,part)
 # E3b: rail trenches reuse the same clip group, walls, barriers and portal as a 10m structure.
 var routes=preload("res://core/transit_routes.gd")
 for route:Dictionary in city.transit_routes:
  if not routes.sunken(route):continue
  var structure:Dictionary=routes.structure(route)
  # Like E2 the clip group starts at -EPS, so its 0m mouth gets no end wall across the track.
  for part:Dictionary in Height.pieces_between(structure,Height.RAIL_PORTAL_M,-Height.EPS):build_trench(city,structure,part)
 # Trench catenary is re-parented into the new clip groups on the next catenary sync.
 renderer.catenary_generation=-1
 for trench:Trench in trenches:
  var first:=true
  for outline in trench.outlines:
   for point in outline:
    if first:trench.world_bounds=Rect2(point,Vector2.ZERO);first=false
    else:trench.world_bounds=trench.world_bounds.expand(point)
  for child in trench.get_children():
   if child is Elevated.Piece:
    for command:Dictionary in child.commands:
     for point:Vector2 in command.get("polygon",command.get("line",PackedVector2Array())):trench.world_bounds=trench.world_bounds.expand(point)
    child.queue_redraw()
  trench.world_bounds=trench.world_bounds.grow(2);trench.queue_redraw()
 for node:Elevated.Piece in barriers:
  var first:=true
  for command:Dictionary in node.commands:
   for point:Vector2 in command.get("polygon",PackedVector2Array()):
    if first:node.world_bounds=Rect2(point,Vector2.ZERO);first=false
    else:node.world_bounds=node.world_bounds.expand(point)
  node.world_bounds=node.world_bounds.grow(2);node.queue_redraw()
func trench_key(road:Dictionary)->Variant:return "rail:%d"%int(road.rail_route_id) if road.has("rail_route_id") else int(road.get("parcel_id",-1))
## E3b: trench track (ballast, then running strips) from the transit geometry, at its own depth.
func rail_commands(road:Dictionary)->Array:
 var result:Array=[]
 var transit=renderer.view.transit_view
 for item:Dictionary in transit.geometry.get("trench",[]):
  if int(item.route_id)!=int(road.rail_route_id):continue
  var centre:=Vector2.ZERO
  for point:Vector2 in item.points:centre+=point
  centre/=item.points.size()
  if not Elevated.near_path(road.points,centre,float(road.width)/2):continue # Another trench part of the same route.
  var shape:=PackedVector2Array()
  for k in range(item.points.size()):shape.append(project(item.points[k],item.depths[k]))
  if Geometry2D.triangulate_polygon(shape).is_empty():continue
  var command:Dictionary={"polygon":shape,"color":item.color}
  if not item.texture.is_empty():
   var image=transit.textures.get(item.texture)
   if image==null:continue
   command.color=Color.WHITE;command.uv=item.uv;command.texture=image
  result.append(command)
 return result
func build_trench(city,visual:Dictionary,part:Dictionary):
 var road:Dictionary=visual.duplicate();road.points=part.points;road.heights_m=part.heights_m
 var rail:=road.has("rail_route_id")
 var center:=Profile.is_center_structure(road)
 var divided:=center and int(road.get("lanes",0))==4
 var source:Dictionary={"points":part.points,"heights_m":part.heights_m}
 # 1-cell stations, like E1 deck pieces, keep each barrier sort slot short.
 var length:=Height.length_cells(part.points);var cuts:Array[float]=[0.0]
 var travelled:=0.0
 for i in range(1,part.points.size()):
  travelled+=part.points[i-1].distance_to(part.points[i]);cuts.append(travelled)
 var vertex:=1
 for i in range(1,ceili(length)):
  while vertex<part.points.size()-1 and cuts[vertex]<i:vertex+=1
  # The -EPS clip starts slightly inside the ramp. Prefer its real bend
  # over a nearby synthetic 4m station that would create a degenerate face.
  if center and minf(absf(cuts[vertex]-i),absf(cuts[vertex-1]-i))<=4*Height.EPS:continue
  cuts.append(float(i))
 cuts.sort()
 var distances:Array[float]=[];var points:=PackedVector2Array()
 for distance in cuts:
  if not distances.is_empty() and absf(distances[-1]-distance)<.0001:continue
  distances.append(distance);points.append(Height.point_at(part.points,distance))
 if points.size()<2:return
 var half:float=float(road.width)/2-WALL_INSET
 var left:=Profile.offset_path(points,half);var right:=Profile.offset_path(points,-half)
 var outer_left:=Profile.offset_path(points,half+BARRIER_WIDTH) if center else PackedVector2Array()
 var outer_right:=Profile.offset_path(points,-half-BARRIER_WIDTH) if center else PackedVector2Array()
 var median_left:=Profile.offset_path(points,CENTER_BARRIER_HALF) if divided else PackedVector2Array()
 var median_right:=Profile.offset_path(points,-CENTER_BARRIER_HALF) if divided else PackedVector2Array()
 var asphalt_half:=half if rail else minf(Profile.asphalt_width(road)/2,half)
 var asphalt_left:=Profile.offset_path(points,asphalt_half);var asphalt_right:=Profile.offset_path(points,-asphalt_half)
 var trench:=Trench.new();trench.name="RailTrench" if rail else "UndergroundTrench";trench.z_index=7;trench.clip_children=CanvasItem.CLIP_CHILDREN_ONLY
 trench.source_ids=[trench_key(visual)] if rail else visual.get("source_ids",[visual.get("parcel_id",-1)]).duplicate()
 if trench.source_ids.is_empty():trench.source_ids=[visual.get("parcel_id",-1)]
 renderer.add_child(trench);trenches.append(trench)
 for id in trench.source_ids:
  var owned:Array=trenches_by_source.get_or_add(id,[])
  if owned.is_empty() or owned[-1]!=trench:owned.append(trench)
 var body:=piece("TrenchBody",road,PackedVector2Array());trench.add_child(body)
 var markings:Array=[] if rail else Geometry.lane_marks(road)
 if not rail:markings.append_array(Geometry.shoulder_marks(road))
 var median:=PackedVector2Array() if rail or divided else Profile.offset_path(road.points,Profile.median_offset(road))
 var raise:=RAIL_FAR_RAISE_M if rail else FAR_RAISE_M
 var walls:Array=[]
 var side_station:=Vector2.ZERO
 for i in range(1,points.size()):
  var footprint:=PackedVector2Array([left[i-1],left[i],right[i],right[i-1]])
  trench.footprints.append(footprint)
  # Clip outline = the ground footprint plus a band above its far edge raised 4m, so
  # the end edges stay square (a raised end vertex would shear off a floor wedge).
  trench.outlines.append(PackedVector2Array([project(left[i-1],0),project(left[i],0),project(right[i],0),project(right[i-1],0)]))
  for pair in [[left,points],[right,points]]:
   var edge:PackedVector2Array=pair[0]
   var outward:Vector2=edge[i-1]-points[i-1]
   if outward.x+outward.y<0:trench.outlines.append(PackedVector2Array([project(edge[i-1],0),project(edge[i],0),project(edge[i],raise),project(edge[i-1],raise)]))
  polygon(body,projected(footprint,source),Color("c8cbc3"))
  if not rail:polygon(body,projected(PackedVector2Array([asphalt_left[i-1],asphalt_left[i],asphalt_right[i],asphalt_right[i-1]]),source),Color("4c5659"))
  for line in markings:
   for clipped in Geometry2D.intersect_polyline_with_polygon(line,footprint):body.commands.append({"line":projected(clipped,source),"color":Color("e8e7dc"),"width":.65})
  if median.size()>=2:
   for clipped in Geometry2D.intersect_polyline_with_polygon(median,footprint):body.commands.append({"line":projected(clipped,source),"color":Color("e8be57"),"width":.8})
  var ha:=Height.height_at(source,points[i-1]);var hb:=Height.height_at(source,points[i])
  for side in range(2):
   var edge:PackedVector2Array=left if side==0 else right
   var a:=edge[i-1];var b:=edge[i]
   var normal:Vector2=(a-points[i-1]).normalized()
   var far:=normal.x+normal.y<0
   var u:=side_station[side] if center else distances[i-1]
   var span:=a.distance_to(b)
   var outer_a:=a+normal*BARRIER_WIDTH;var outer_b:=b+normal*BARRIER_WIDTH
   if center:
    var rim:PackedVector2Array=outer_left if side==0 else outer_right
    outer_a=rim[i-1];outer_b=rim[i]
    side_station[side]+=span
   # Only the far wall's trench face looks at the camera; it is cut at the road surface.
   if far:walls.append([a,b,ha,hb,u,-normal])
   if rail and normal.x+normal.y>Height.EPS:trench.near_edges.append(PackedVector2Array([project(a,0),project(b,0)]))
   build_barrier(road,PackedVector2Array([a,b,outer_b,outer_a]),normal,u,far,span if center else -1.0)
  if divided:build_center_barrier(trench,road,PackedVector2Array([median_left[i-1],median_left[i],median_right[i],median_right[i-1]]),ha,hb,i)
 if rail:body.commands.append_array(rail_commands(road))
 for wall:Array in walls:band(body,wall[0],wall[1],0,0,wall[2],wall[3],wall[4],WALL,WALL_STRIP_M,BARRIER_M,shade(WALL_SHADE,wall[5]))
 for end:int in [0,points.size()-1]:
  var h:=Height.height_at(source,points[end])
  if h>-2*Height.EPS:continue # Meets the at-grade road surface.
  var tangent:Vector2=(points[1]-points[0]).normalized() if end==0 else (points[-1]-points[-2]).normalized()
  var inward:=tangent if end==0 else -tangent
  var a:Vector2=left[end];var b:Vector2=right[end]
  var visual_end:bool=points[end].distance_to(visual.points[0])<.001 or points[end].distance_to(visual.points[-1])<.001
  if absf(h-Height.portal_for(road))<.001 and not visual_end:build_portal(trench,road,a,b,inward,h)
  elif not joined(city,visual,points[end],h):build_end_wall(trench,body,road,a,b,inward,h)
func joined(city,visual:Dictionary,point:Vector2,h:float)->bool:
 if visual.has("rail_route_id"):
  for other:Dictionary in city.transit_routes:
   if other.kind!="rail" or int(other.id)==int(visual.rail_route_id) or not Height.sunken(other):continue
   for end:Vector2 in [other.points[0],other.points[-1]]:
    if end.distance_to(point)<.001 and absf(Height.height_at(other,end)-h)<.001:return true
  return false
 for other:Dictionary in city.road_visuals:
  if other==visual or not Height.sunken(other):continue
  for end:Vector2 in [other.points[0],other.points[-1]]:
   if end.distance_to(point)<.001 and absf(Height.height_at(other,end)-h)<.001:return true
 return false
func build_barrier(road:Dictionary,footprint:PackedVector2Array,normal:Vector2,u:float,far:bool,phase_length:float=-1.0):
 var a:=footprint[0];var b:=footprint[1];var outer_b:=footprint[2];var outer_a:=footprint[3]
 var node:=barrier_piece(road,footprint)
 if far:band(node,a,b,BARRIER_M,BARRIER_M,0,0,u,WALL,WALL_STRIP_M,0,shade(WALL_SHADE,-normal),phase_length)
 else:band(node,outer_a,outer_b,BARRIER_M,BARRIER_M,0,0,u,WALL,WALL_STRIP_M,0,shade(WALL_SHADE,normal),phase_length)
 polygon(node,PackedVector2Array([project(a,BARRIER_M),project(b,BARRIER_M),project(outer_b,BARRIER_M),project(outer_a,BARRIER_M)]),Color("ced0c7"))
func build_center_barrier(trench:Trench,road:Dictionary,footprint:PackedVector2Array,ha:float,hb:float,station:int):
 var node:=piece("UnderpassMedian%d"%station,road,footprint)
 trench.add_child(node)
 var a:=footprint[0];var b:=footprint[1];var c:=footprint[2];var d:=footprint[3]
 var top_a:=ha+BARRIER_M;var top_b:=hb+BARRIER_M
 # Draw the facing wall and a joined cap below the clip's terrain lip.
 var near:=a+b-c-d
 var x:=a if near.x+near.y>=0 else d
 var y:=b if near.x+near.y>=0 else c
 polygon(node,PackedVector2Array([project(x,top_a),project(y,top_b),project(y,hb),project(x,ha)]),Color("9d9f96"))
 polygon(node,PackedVector2Array([project(a,top_a),project(b,top_b),project(c,top_b),project(d,top_a)]),Color("ced0c7"))
## Portal: strip below ground (cap + beam to -1.5m) and the 15181a mouth to the
## road surface, inside the clip group, only when the face looks at the camera.
func build_portal(trench:Trench,road:Dictionary,a:Vector2,b:Vector2,inward:Vector2,h:float):
 var faces:=inward.x+inward.y>0
 if faces:
  var node:=piece("TrenchPortal",road,PackedVector2Array([a,b]));trench.add_child(node)
  band(node,a,b,0,0,MOUTH_TOP_M,MOUTH_TOP_M,0,PORTAL,PORTAL_STRIP_M,BARRIER_M,shade(PORTAL_SHADE,inward))
  polygon(node,PackedVector2Array([project(a,MOUTH_TOP_M),project(b,MOUTH_TOP_M),project(b,h),project(a,h)]),INTERIOR)
 var cover:=-inward*BARRIER_WIDTH
 var top:=barrier_piece(road,PackedVector2Array([a,b,b+cover,a+cover]));top.name="TrenchPortalBarrier"
 if faces:band(top,a,b,BARRIER_M,BARRIER_M,0,0,0,PORTAL,PORTAL_STRIP_M,0,shade(PORTAL_SHADE,inward))
 else:band(top,a+cover,b+cover,BARRIER_M,BARRIER_M,0,0,0,PORTAL,PORTAL_STRIP_M,0,shade(PORTAL_SHADE,-inward))
 polygon(top,PackedVector2Array([project(a,BARRIER_M),project(b,BARRIER_M),project(b+cover,BARRIER_M),project(a+cover,BARRIER_M)]),Color("ced0c7"))
 portals.append({"trench":trench,"a":a,"b":b,"inward":inward,"faces":faces,"height_m":h})
## A dead end at depth closes the trench with the same retaining-wall strip.
func build_end_wall(trench:Trench,body,road:Dictionary,a:Vector2,b:Vector2,inward:Vector2,h:float):
 if inward.x+inward.y>0:band(body,a,b,0,0,h,h,0,WALL,WALL_STRIP_M,BARRIER_M,shade(WALL_SHADE,inward))
 var cap:Vector2=-inward*BARRIER_WIDTH
 build_barrier(road,PackedVector2Array([a,b,b+cap,a+cap]),-inward,0,inward.x+inward.y>0)
## Count actual road-car clip work only; rail, catenary and test probes use the
## same index without contributing to the road-pose counters.
func reset_vehicle_work():
 vehicle_trench_lookups=0
 vehicle_trench_group_visits=0
 vehicle_trench_footprint_visits=0
func trench_at(road:Dictionary,point:Vector2,vehicle_probe:bool=false)->Trench:
 if vehicle_probe:vehicle_trench_lookups+=1
 var owned:Array=trenches_by_source.get(trench_key(road),[])
 for trench:Trench in owned:
  if vehicle_probe:vehicle_trench_group_visits+=1
  for footprint in trench.footprints:
   if vehicle_probe:vehicle_trench_footprint_visits+=1
   if Geometry2D.is_point_in_polygon(point,footprint):return trench
 for trench:Trench in owned:
  if vehicle_probe:vehicle_trench_group_visits+=1
  for footprint in trench.footprints:
   if vehicle_probe:vehicle_trench_footprint_visits+=1
   for i in range(footprint.size()):
    if point.distance_to(Geometry2D.get_closest_point_to_segment(point,footprint[i],footprint[(i+1)%footprint.size()]))<.5:return trench
 return null
## Open-trench cars move into their clip group. Ordinary E2 covered cars
## remain visible in the underground view, unlike the E4d central underpass.
func place_vehicle(sprite:Sprite2D,road:Dictionary,point:Vector2):
 var height:=Height.height_at(road,point)
 var parent:Node2D=renderer.actors
 if height< -Height.EPS:
  var covered:=Height.covered_at(height)
  var trench:Trench=null if covered else trench_at(road,point,true)
  if trench!=null or covered:
   parent=trench if trench!=null else renderer.view.transit_view.metro_layer
   sprite.offset.y-=height*renderer.view.tile.x/4*sqrt(1.5)/sprite.scale.y
  if covered and Profile.is_center_structure(road):sprite.hide()
 if sprite.get_parent()!=parent:sprite.reparent(parent,false)
## Cache each directional sprite's opaque column extents without reading the GPU on pose updates.
func rail_silhouette(texture:Texture2D,pose:Dictionary)->PackedVector2Array:
 if not rail_silhouettes.has(texture):
  var path:String=renderer.view.traffic.sprite_path(pose.asset_id,pose.heading)
  var image:Image=Image.load_from_file(path) if FileAccess.file_exists(path) else null
  if image==null and DisplayServer.get_name()!="headless":image=texture.get_image()
  if image!=null and image.is_compressed() and image.decompress()!=OK:image=null
  var columns:=PackedVector2Array()
  if image!=null and not image.is_empty():
   var width:=image.get_width();var height:=image.get_height()
   columns.resize(width)
   for x in range(width):
    var top:=height;var bottom:=0
    for y in range(height):
     if image.get_pixel(x,y).a>=.5:top=mini(top,y);bottom=y+1
    columns[x]=Vector2(float(top)/height,float(bottom)/height)
  rail_silhouettes[texture]=columns
 return rail_silhouettes[texture]
## Compare opaque height above the foremost occluding lip at each screen X. The
## ground-projected car axis keeps a wall behind the car from counting as foreground.
static func exposed_train_fraction(columns:PackedVector2Array,rect:Rect2,axis:Vector2,half_axis:Vector2,edges:Array[PackedVector2Array],lip_raise:float)->float:
 var candidates:Array[PackedVector2Array]=[]
 for edge in edges:
  var lo:=minf(edge[0].x,edge[1].x);var hi:=maxf(edge[0].x,edge[1].x)
  if hi-lo>Height.EPS and hi>rect.position.x and lo<rect.end.x:candidates.append(edge)
 if candidates.is_empty():return 1.0
 var full:=0.0;var exposed:=0.0
 for i in range(columns.size()):
  var column:=columns[i];var height:=column.y-column.x
  if height<=0.0:continue
  var x:=rect.position.x+(i+.5)*rect.size.x/columns.size()
  var along:=clampf((x-axis.x)/half_axis.x,-1,1) if absf(half_axis.x)>Height.EPS else 0.0
  var car_ground_y:=axis.y+along*half_axis.y
  var clip_y:=INF
  for edge in candidates:
   var t:=(x-edge[0].x)/(edge[1].x-edge[0].x)
   if t<0.0 or t>1.0:continue # Never extend a wall past its ends.
   var wall_y:=lerpf(edge[0].y,edge[1].y,t)
   if wall_y>car_ground_y+Height.EPS:clip_y=minf(clip_y,wall_y-lip_raise)
  full+=height
  exposed+=clampf((clip_y-rect.position.y)/rect.size.y-column.x,0.0,height)
 return exposed/full if full>0.0 else 1.0
func sync_train_visibility(sprite:Sprite2D):
 if not sprite.has_meta("rail_trench_surface_fraction"):return
 if renderer.view.transit_view.underground:
  sprite.visible=float(sprite.get_meta("rail_height_m"))>=UNDERGROUND_RAIL_CAR_HIDE_BELOW_M
 else:sprite.visible=float(sprite.get_meta("rail_trench_surface_fraction"))>=MIN_RAIL_BODY_EXPOSURE
## Each rail car follows its own depth. Only open-trench surface visibility uses
## the wall and silhouette; the underground cutoff and covered layer are unchanged.
func place_train(sprite:Sprite2D,structure:Dictionary,point:Vector2,pose:Dictionary):
 var height:=Height.height_at(structure,point)
 var parent:Node2D=renderer.actors
 var trench:Trench=null
 if height< -Height.EPS:
  if Height.covered_at(height,Height.RAIL_PORTAL_M):parent=renderer.view.transit_view.metro_layer
  else:
   trench=trench_at(structure,point)
   if trench!=null:parent=trench
  sprite.offset.y-=height*renderer.view.tile.x/4*sqrt(1.5)/sprite.scale.y
 if sprite.get_parent()!=parent:sprite.reparent(parent,false)
 if trench!=null:
  var rect:=Rect2(sprite.position+sprite.offset*sprite.scale,sprite.texture.get_size()*sprite.scale)
  var half_axis:Vector2=renderer.iso(pose.heading*float(pose.get("length_m",10))/8)
  var lip_raise:=project(Vector2.ZERO,0).y-project(Vector2.ZERO,BARRIER_M).y
  var fraction:=exposed_train_fraction(rail_silhouette(sprite.texture,pose),rect,renderer.iso(point),half_axis,trench.near_edges,lip_raise)
  sprite.set_meta("rail_trench_surface_fraction",fraction)
  sync_train_visibility(sprite)
func sync_visibility():
 var view=renderer.view;var viewport:=Rect2(Vector2.ZERO,view.get_viewport_rect().size)
 for node in trenches+barriers:node.visible=viewport.intersects(Rect2(view.origin+node.world_bounds.position*view.map_zoom,node.world_bounds.size*view.map_zoom))
