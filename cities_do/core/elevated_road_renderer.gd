extends RefCounted
## Retained 4m deck pieces, original structure strips and assembled original pier sprites.
const Height=preload("res://core/road_height.gd")
const Profile=preload("res://core/road_profile.gd")
const Geometry=preload("res://core/road_geometry.gd")
class Piece extends Node2D:
 var commands:Array=[]
 var footprint:PackedVector2Array
 var world_bounds:Rect2
 var road:Dictionary
 var height_m:float
 var base_depth:float
 var front_face:=false
 func _draw():
  for command:Dictionary in commands:
   if command.has("rect"):
    var rect:Rect2=command.rect;rect.position-=position
    draw_texture_rect(command.texture,rect,false)
   elif command.has("line"):
    var line:PackedVector2Array=command.line.duplicate()
    for i in range(line.size()):line[i]-=position
    if line.size()>1:draw_polyline(line,command.color,command.get("width",.7),true)
   else:
    var polygon:PackedVector2Array=command.polygon.duplicate()
    for i in range(polygon.size()):polygon[i]-=position
    if command.has("texture"):draw_polygon(polygon,PackedColorArray([command.color]),command.uv,command.texture)
    elif polygon.size()>=3:draw_colored_polygon(polygon,command.color)
var owner_reference:WeakRef
var renderer:
 get:return owner_reference.get_ref()
var nodes:Array=[]
var decks:Array=[]
var textures:Dictionary={}
var manifest:Dictionary={}
func _init(owner):owner_reference=weakref(owner)
func texture(path:String)->Texture2D:
 if not textures.has(path):
  var image:=Image.load_from_file("res://assets/structures/"+path)
  if image==null or image.is_empty():return null
  image.generate_mipmaps();textures[path]=ImageTexture.create_from_image(image)
 return textures[path]
func project(point:Vector2,height_m:float)->Vector2:
 return renderer.iso(point)-Vector2(0,height_m*renderer.view.tile.x/4*sqrt(1.5))
func projected(polygon:PackedVector2Array,road:Dictionary,extra:float=0)->PackedVector2Array:
 var result:=PackedVector2Array()
 for point in polygon:result.append(project(point,Height.height_at(road,point)+extra))
 return result
func make_piece(name_value:String,road:Dictionary,footprint:PackedVector2Array,depth:float)->Piece:
 var node:=Piece.new();node.name=name_value;node.road=road;node.footprint=footprint
 node.base_depth=depth;node.position.y=depth
 node.height_m=Height.height_at(road,footprint[0]);node.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
 node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 renderer.actors.add_child(node);nodes.append(node)
 return node
func polygon(node:Piece,shape:PackedVector2Array,color:Color):
 if shape.size()>=3 and not Geometry2D.triangulate_polygon(shape).is_empty():node.commands.append({"polygon":shape,"color":color})
func side(node:Piece,a:Vector2,b:Vector2,ha:float,hb:float,ba:float,bb:float,u:float,path:String,strip_height:float,shade:float):
 var image:=texture(path)
 if image==null:return
 var points:=PackedVector2Array([project(a,ha),project(b,hb),project(b,bb),project(a,ba)])
 if Geometry2D.triangulate_polygon(points).is_empty():return
 var length:=a.distance_to(b)
 var uv:=PackedVector2Array([Vector2(u,0),Vector2(u+length,0),Vector2(u+length,(hb-bb)/strip_height),Vector2(u,(ha-ba)/strip_height)])
 node.commands.append({"polygon":points,"color":Color(shade,shade,shade),"uv":uv,"texture":image})
func rebuild():
 for node in nodes:node.hide();node.queue_free()
 nodes.clear();decks.clear()
 for road:Dictionary in renderer.view.city.road_visuals:
  if not Height.raised(road):continue
  build_road(road)
 for junction:Dictionary in renderer.view.city.junctions+renderer.view.city.road_joins:
  if float(junction.get("height_m",0))>0 and junction.has("box"):build_junction(junction)
 # Raise the entire upper sort slot, not both faces to the same anchor.
 decks.sort_custom(func(a,b):return a.height_m<b.height_m)
 for high:Piece in decks:
  for low:Piece in decks:
   if low.height_m>=high.height_m-.001:continue
   if not Geometry2D.intersect_polygons(low.footprint,high.footprint).is_empty():high.position.y=maxf(high.position.y,low.position.y+(.12 if high.front_face else .1))
 for node:Piece in nodes:
  var first:=true
  for command:Dictionary in node.commands:
   if command.has("rect"):
    node.world_bounds=command.rect if first else node.world_bounds.merge(command.rect);first=false
   else:
    for point:Vector2 in command.get("polygon",command.get("line",PackedVector2Array())):
     if first:node.world_bounds=Rect2(point,Vector2.ZERO);first=false
     else:node.world_bounds=node.world_bounds.expand(point)
  node.world_bounds=node.world_bounds.grow(2);node.queue_redraw()
func build_road(road:Dictionary):
 var regions:Array[PackedVector2Array]=[];var mark_regions:Array[PackedVector2Array]=[]
 var bounds:=Vector2(renderer.view.city.width,renderer.view.city.height)
 for junction:Dictionary in renderer.view.city.junctions+renderer.view.city.road_joins:
  if not junction.has("box") or absf(float(junction.get("height_m",0))-Height.height_at(road,junction.position))>.0001:continue
  regions.append(junction.box);mark_regions.append_array(renderer.view.city.RoadJunctions.lane_mark_regions(junction))
 var length:=Height.length_cells(road.points);var cuts:Array[float]=[0.0]
 for i in range(1,ceili(length)):cuts.append(float(i))
 var travelled:=0.0
 for i in range(1,road.points.size()):
  var span:float=road.points[i-1].distance_to(road.points[i])
  var first:=Height.height_at(road,road.points[i-1]);var last:=Height.height_at(road,road.points[i])
  if (first<5 and last>5) or (first>5 and last<5):cuts.append(travelled+span*(5-first)/(last-first))
  travelled+=span;cuts.append(travelled)
 cuts.sort()
 var distances:Array[float]=[];var points:=PackedVector2Array()
 for distance in cuts:
  if not distances.is_empty() and absf(distances[-1]-distance)<.0001:continue
  distances.append(distance);points.append(Height.point_at(road.points,distance))
 var left:=Profile.offset_path(points,float(road.width)/2);var right:=Profile.offset_path(points,-float(road.width)/2)
 var asphalt_left:=Profile.offset_path(points,Profile.asphalt_width(road)/2);var asphalt_right:=Profile.offset_path(points,-Profile.asphalt_width(road)/2)
 var inner_left:=Profile.offset_path(points,float(road.width)/2-.1);var inner_right:=Profile.offset_path(points,-float(road.width)/2+.1)
 var markings:Array=Geometry.lane_marks(road);markings.append_array(Geometry.shoulder_marks(road))
 var median:=Profile.offset_path(road.points,Profile.median_offset(road))
 for i in range(1,points.size()):
  var footprint:=PackedVector2Array([left[i-1],left[i],right[i],right[i-1]])
  var depth:float=-INF
  for point in footprint:depth=maxf(depth,renderer.iso(point).y)
  var rear:=make_piece("ElevatedDeckRear",road,footprint,depth-.02)
  var front:=make_piece("ElevatedDeckFront",road,footprint,depth)
  front.front_face=true
  decks.append(rear);decks.append(front)
  for shape in Geometry.outside_regions([footprint],regions):polygon(rear,projected(shape,road),Color("c8cbc3"))
  for shape in Geometry.outside_regions([PackedVector2Array([asphalt_left[i-1],asphalt_left[i],asphalt_right[i],asphalt_right[i-1]])],regions):polygon(rear,projected(shape,road),Color("4c5659"))
  for line in markings:
   for clipped in Geometry2D.intersect_polyline_with_polygon(line,footprint):
    for visible in Geometry.visible_lines(clipped,bounds,mark_regions):rear.commands.append({"line":projected(visible,road),"color":Color("e8e7dc"),"width":.65})
  for clipped in Geometry2D.intersect_polyline_with_polygon(median,footprint):
   for visible in Geometry.visible_lines(clipped,bounds,mark_regions):rear.commands.append({"line":projected(visible,road),"color":Color("e8be57"),"width":.8})
  var ha:=Height.height_at(road,points[i-1]);var hb:=Height.height_at(road,points[i]);var retaining:=minf(ha,hb)<5-.0001
  for pair in [[left,inner_left,1.0],[right,inner_right,-1.0]]:
   var edge:PackedVector2Array=pair[0];var inner:PackedVector2Array=pair[1]
   var a:Vector2=edge[i-1];var b:Vector2=edge[i]
   var normal:Vector2=(a-points[i-1]).normalized()
   var near:=normal.x+normal.y>=0
   var node:Piece=front if near else rear
   # Measured source face_shade (+X and Blender -Y == game +y).
   var shade:=lerpf(.775084854390681,1.053687485609,absf(normal.y)/(absf(normal.x)+absf(normal.y)))
   for visible in Geometry.visible_lines(PackedVector2Array([a,b]),bounds,regions):
    var va:Vector2=visible[0];var vb:Vector2=visible[-1]
    var ah:=Height.height_at(road,va);var bh:=Height.height_at(road,vb)
    if near:side(node,va,vb,ah+1.1,bh+1.1,0 if retaining else ah-2,0 if retaining else bh-2,distances[i-1],"retaining-wall-01/wall.png" if retaining else "viaduct-side-01/deck_side.png",9 if retaining else 3.1,shade)
    else:side(node,va-normal*.1,vb-normal*.1,ah+1.1,bh+1.1,ah,bh,distances[i-1],"viaduct-side-01/barrier_inner.png",1.1,shade)
    polygon(node,projected(PackedVector2Array([va,vb,vb-normal*.1,va-normal*.1]),road,1.1),Color("ced0c7"))
  if retaining and absf(hb-5)<.0001:side(front,left[i],right[i],hb,hb,0,0,0,"retaining-wall-01/wall.png",9,.85)
  if retaining and absf(ha-5)<.0001:side(front,left[i-1],right[i-1],ha,ha,0,0,0,"retaining-wall-01/wall.png",9,.85)
 var support_plan:Dictionary=Height.supports(renderer.view.city,road) if not road.has("piers") else {"piers":road.piers}
 for station:Dictionary in support_plan.piers:
  for point:Vector2 in station.positions:build_pier(road,point,station.height_m)
func build_junction(junction:Dictionary):
 var height:float=junction.height_m;var shape:PackedVector2Array=junction.footprint
 var road:Dictionary={"points":PackedVector2Array([junction.position,junction.position+Vector2(.001,0)]),"heights_m":PackedFloat64Array([height,height]),"source_ids":[]}
 var masks:Array[PackedVector2Array]=[]
 for source:Dictionary in renderer.view.city.roads:
  if absf(Height.height_at(source,junction.position)-height)>.0001:continue
  if preload("res://core/road_length_units.gd").projection(source.points,junction.position).distance>.0001:continue
  road.source_ids.append(source.parcel_id)
 for arm:Dictionary in junction.arms:masks.append_array(Geometry.ribbons(arm.points,arm.width-.001,true,true))
 var depth:float=-INF
 for point in shape:depth=maxf(depth,renderer.iso(point).y)
 var node:=make_piece("ElevatedJunction",road,shape,depth-.02);decks.append(node)
 polygon(node,projected(shape,road),Color("c8cbc3"));polygon(node,projected(junction.asphalt,road),Color("4c5659"))
 var bounds:=Vector2(renderer.view.city.width,renderer.view.city.height)
 for i in range(shape.size()):
  var a:=shape[i];var b:=shape[(i+1)%shape.size()]
  var normal:=Vector2(-(b-a).y,(b-a).x).normalized()
  if Geometry2D.is_point_in_polygon((a+b)/2+normal*.01,shape):normal=-normal
  var near:=normal.x+normal.y>=0
  for edge in Geometry.visible_lines(PackedVector2Array([a,b]),bounds,masks):
   var front:=make_piece("ElevatedJunctionSide",road,shape,depth);decks.append(front)
   front.front_face=true
   if near:side(front,edge[0],edge[-1],height+1.1,height+1.1,height-2,height-2,0,"viaduct-side-01/deck_side.png",3.1,.85)
   else:side(node,edge[0]-normal*.1,edge[-1]-normal*.1,height+1.1,height+1.1,height,height,0,"viaduct-side-01/barrier_inner.png",1.1,.85)
   polygon(front if near else node,projected(PackedVector2Array([edge[0],edge[-1],edge[-1]-normal*.1,edge[0]-normal*.1]),road,1.1),Color("ced0c7"))
func build_pier(road:Dictionary,point:Vector2,height_m:float):
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/structures/viaduct-pier-01/render_manifest.json"))
 var scale:float=renderer.view.tile.x/4*sqrt(2.0)/float(manifest.pixels_per_metre)
 var node:=make_piece("ElevatedPier",road,PackedVector2Array([point]),renderer.iso(point).y)
 for part:String in ["shaft","base","cap"]:
  var image:=texture("viaduct-pier-01/pier_"+part+".png")
  if image==null:continue
  var origin:Array=manifest.parts[part].origin_pixel
  var position:Vector2=project(point,height_m-4 if part=="cap" else 0)
  var rect:=Rect2(position-Vector2(origin[0],origin[1])*scale,Vector2(image.get_size())*scale)
  if part=="shaft":
   var underlap:float=manifest.assembly.shaft_underlap_pixels_each_end*scale
   rect.position=project(point,height_m-4)-Vector2(float(origin[0])*scale,underlap)
   rect.size.y=(height_m-4.3)*32*scale+2*underlap
  node.commands.append({"texture":image,"rect":rect})
func sync_visibility():
 var view=renderer.view;var viewport:=Rect2(Vector2.ZERO,view.get_viewport_rect().size)
 for node:Piece in nodes:node.visible=not view.transit_view.underground and viewport.intersects(Rect2(view.origin+node.world_bounds.position*view.map_zoom,node.world_bounds.size*view.map_zoom))
func lift_vehicle(sprite:Sprite2D,road:Dictionary,point:Vector2,body:PackedVector2Array):
 var height:=Height.height_at(road,point)
 if height<=0:return
 var front_depth:float=-INF
 for node:Piece in decks:
  if not node.front_face:continue
  if not node.road.get("source_ids",[node.road.get("parcel_id",-1)]).has(road.get("parcel_id",-2)):continue
  if not Geometry2D.intersect_polygons(node.footprint,body).is_empty():front_depth=maxf(front_depth,node.position.y)
 var depth:float=front_depth-.01 if is_finite(front_depth) else renderer.iso(point).y
 sprite.offset.y-=(height*renderer.view.tile.x/4*sqrt(1.5)+depth-sprite.position.y)/sprite.scale.y
 sprite.position.y=depth
