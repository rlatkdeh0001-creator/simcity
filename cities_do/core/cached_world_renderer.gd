extends Node2D
## Retained world-space canvas commands; camera changes update only this transform.
const Profile=preload("res://core/road_profile.gd")
const Boundary=preload("res://core/boundary_links.gd")
class Layer extends Node2D:
 var renderer
 var kind:String
 func _init(owner_node,layer_kind:String):renderer=owner_node;kind=layer_kind
 func _draw():renderer.paint(self,kind)
class Building extends Sprite2D:
 var renderer
 var record:Dictionary
 var world_bounds:Rect2
 func _draw():
  if texture==null:renderer.fallback(self,record,position)
var view
var city_reference
var ground
var zones
var grid
var roads
var marks
var actors:Node2D
var buildings:Dictionary={}
var cars:Dictionary={}
var road_generation:=0
var grid_generation:=0
var building_sorts:=0
var road_signature:=0
var zone_signature:=0
var building_signature:Array=[]
var ordered:Array=[]

var road_shapes:Array=[]
var verges:Array=[]
var accessways:Array=[]
var access_signature:Array=[]
var access_generation:=0
var stripes:Array=[]

var arrows:Array=[]
var line_mesh:ArrayMesh
var line_material:ShaderMaterial
var line_zoom:float=-1.0
var car_frames:Dictionary={}
const DISPLAY_STRIDE:=100
func setup(owner_view):
 view=owner_view;z_index=-10
 ground=Layer.new(self,"ground");add_child(ground)
 zones=preload("res://core/zoning_mesh_renderer.gd").new();zones.z_index=1;add_child(zones);zones.setup(view)
 grid=Node2D.new();grid.z_index=2;add_child(grid) # Existing outline visibility contract; no line drawing.
 roads=Layer.new(self,"roads");roads.z_index=3;add_child(roads)
 marks=Layer.new(self,"marks");marks.z_index=4;add_child(marks)
 line_material=ShaderMaterial.new();var shader:=Shader.new()
 shader.code="shader_type canvas_item; render_mode unshaded; uniform float zoom=1.0; varying float across; varying float half_width; void vertex(){half_width=max(0.6,zoom)*0.5; float extent=half_width+1.0; VERTEX+=vec2(cos(UV.x),sin(UV.x))*UV.y*extent/zoom; across=UV.y*extent;} void fragment(){COLOR.a*=clamp(half_width+1.0-abs(across),0.0,1.0);}"
 line_material.shader=shader;marks.material=line_material
 actors=Node2D.new();actors.name="WorldActors";actors.z_index=9;actors.y_sort_enabled=true;add_child(actors)
 view.transit_view.attach(self)
 view.building_views.changed.connect(refresh_building_images)
 synchronize();_process(0)
func iso(p:Vector2)->Vector2:return Vector2((p.x-p.y)*view.tile.x,(p.x+p.y)*view.tile.y)
func project(points:PackedVector2Array)->PackedVector2Array:
 var result:=PackedVector2Array()
 for p in points:result.append(iso(p))
 return result
func synchronize():
 if view==null:return
 var changed:bool=city_reference!=view.city
 if changed:
  if city_reference!=null and city_reference.society_changed.is_connected(synchronize):city_reference.society_changed.disconnect(synchronize)
  view.city.society_changed.connect(synchronize)
 city_reference=view.city
 view.transit_view.synchronize()
 var rs:=hash([view.city.get_instance_id(),view.city.roads,view.city.width,view.city.height])
 if changed or rs!=road_signature:
  road_signature=rs;road_generation+=1;road_shapes.clear();stripes.clear();arrows.clear()
  for polygon in view.city.road_pavement+view.city.junction_pavement:road_shapes.append([project(polygon),Color("c8cbc3")])
  for polygon in view.city.road_asphalt+view.city.junction_asphalt:road_shapes.append([project(polygon),Color("4c5659")])
  for polygon in view.city.road_crosswalks+view.city.road_stop_lines:stripes.append(project(polygon))
  var boundary:=PackedVector2Array([Vector2.ZERO,Vector2(view.city.width,0),Vector2(view.city.width,view.city.height),Vector2(0,view.city.height)])
  for link in Boundary.road_links(view.city):
   for shape in Boundary.arrow_shapes(link):
    for clipped in Geometry2D.intersect_polygons(shape,boundary):arrows.append(project(clipped))
  verges.clear()
  for polygon in preload("res://core/roadside_verges.gd").build(view.city):verges.append(project(polygon))
  zones.rebuild()
  build_marks();ground.queue_redraw();roads.queue_redraw();marks.queue_redraw()
 var zs:=hash([rs,view.city.zone_designations,view.city.zoning_grid.parcels.size()])
 if changed or zs!=zone_signature:
  if not changed and zones.cell_slots.size()!=view.city.zoning_grid.count():zones.rebuild()
  zone_signature=zs;grid_generation+=1;zones.update_palette()
 var records:Array=view.city.buildings.duplicate();records.append_array(view.city.public_facilities.lots)
 var signature:Array=[view.city.get_instance_id()]
 for record in records:signature.append([record.id,record.get("asset_id",""),record.get("public_asset_id",""),record.get("level",0),view.city.footprint(record),view.city.front_direction(record)])
 var access_key:Array=[rs,signature,records.map(func(record):return [record.get("front_road_id",-1),record.get("entrance_spans_m",[])])]
 if access_key!=access_signature:
  access_signature=access_key;access_generation+=1;accessways.clear()
  for polygon in preload("res://core/entrance_accessways.gd").build(view.city):accessways.append(project(polygon))
  ground.queue_redraw()
 if changed or signature!=building_signature:
  building_signature=signature;ordered=view.building_draw_order();building_sorts+=1
  var keep:Dictionary={};var previous_depth:float=-INF;var rank:=0
  for record in ordered:
   keep[record.id]=true
   var node:Building=buildings.get(record.id)
   if node==null:node=Building.new();node.renderer=self;node.centered=false;actors.add_child(node);buildings[record.id]=node
   # Engine Y-sort resolves approximately equal anchors by sibling order.
   # Keep that stable tie-break in painter order, not construction order.
   actors.move_child(node,rank);rank+=1
   node.record=record
   var center:=Vector2.ZERO
   for p in view.city.footprint(record):center+=p
   center/=4
   # Retain footprint dependency order, including tied far-corner public lots.
   var depth:float=maxf(view.building_depth(record)*view.tile.y,previous_depth+.0001);previous_depth=depth
   node.position=Vector2(iso(center).x,depth)
   bind_building(node)
  for id in buildings.keys():
   if not keep.has(id):buildings[id].queue_free();buildings.erase(id)
func bind_building(node:Building):
 var b:Dictionary=node.record
 var visual:Dictionary=view.public_controller.visual(b) if b.has("public_asset_id") else view.building_visual(b)
 if not visual.is_empty():
  node.texture=visual.texture;node.scale=visual.rect.size/Vector2(node.texture.get_size())/view.map_zoom
  node.offset=((visual.rect.position-view.origin)/view.map_zoom-node.position)/node.scale
  node.world_bounds=Rect2((visual.rect.position-view.origin)/view.map_zoom,visual.rect.size/view.map_zoom)
 else:
  node.texture=null;node.scale=Vector2.ONE;node.offset=Vector2.ZERO
  var points:=project(view.city.footprint(b));var box:=Rect2(points[0],Vector2.ZERO)
  for p in points:box=box.expand(p)
  var lift:float=float(view.public_controller.asset(b.public_asset_id).get("height_m",0))*view.tile.x/4*sqrt(1.5) if b.has("public_asset_id") else view.visual_lift(b)
  box.position.y-=lift;box.size.y+=lift;node.world_bounds=box
 node.queue_redraw()
func refresh_building_images():
 for node in buildings.values():bind_building(node)
func build_marks():
 var vertices:=PackedVector3Array();var colors:=PackedColorArray();var uv:=PackedVector2Array()
 for pair in [[view.city.road_medians,Color("e4bd5f")],[view.city.road_lane_marks,Color("e8e7dc")]]:
  for line in pair[0]:
   var a:=iso(line[0]);var b:=iso(line[-1]);var normal:=Vector2(-(b-a).y,(b-a).x).normalized()
   for corner in [[a,-1],[a,1],[b,1],[a,-1],[b,1],[b,-1]]:
    vertices.append(Vector3(corner[0].x,corner[0].y,0));colors.append(pair[1]);uv.append(Vector2(normal.angle(),corner[1]))
 line_mesh=ArrayMesh.new()
 if not vertices.is_empty():
  var data:Array=[];data.resize(Mesh.ARRAY_MAX);data[Mesh.ARRAY_VERTEX]=vertices;data[Mesh.ARRAY_COLOR]=colors;data[Mesh.ARRAY_TEX_UV]=uv
  line_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
func paint(canvas:CanvasItem,kind:String):
 match kind:
  "ground":
   canvas.draw_colored_polygon(project(PackedVector2Array([Vector2.ZERO,Vector2(view.city.width,0),Vector2(view.city.width,view.city.height),Vector2(0,view.city.height)])),Color("7e9275"))
   for polygon in verges:canvas.draw_colored_polygon(polygon,preload("res://core/roadside_verges.gd").COLOR)
   for polygon in accessways:canvas.draw_colored_polygon(polygon,preload("res://core/entrance_accessways.gd").COLOR)

  "roads":
   for shape in road_shapes:canvas.draw_colored_polygon(shape[0],shape[1])
   for polygon in stripes:canvas.draw_colored_polygon(polygon,Color("e8e7dc"))
   for polygon in arrows:canvas.draw_colored_polygon(polygon,Boundary.PAINT)
  "marks":
   if line_mesh!=null and line_mesh.get_surface_count()>0:canvas.draw_mesh(line_mesh,null)
func fallback(canvas:CanvasItem,b:Dictionary,anchor:Vector2):
 if b.has("public_asset_id"):return
 var base:=project(view.city.footprint(b));var top:=base.duplicate();var lift:float=view.visual_lift(b)
 for i in range(4):base[i]-=anchor;top[i]-=anchor+Vector2(0,lift)
 var color:Color={"residential":Color("65a87b"),"commercial":Color("629dce"),"industrial":Color("d8ac60")}[b.zone]
 var faces:Array=[]
 for i in range(4):faces.append({"depth":(base[i].y+base[(i+1)%4].y)/2,"points":PackedVector2Array([base[i],base[(i+1)%4],top[(i+1)%4],top[i]]),"shade":.15 if i%2 else .35})
 faces.sort_custom(func(a,c):return a.depth<c.depth)
 for face in faces:canvas.draw_colored_polygon(face.points,color.darkened(face.shade))
 canvas.draw_colored_polygon(top,color)
 var center:=Vector2.ZERO
 for p in view.city.footprint(b):center+=p
 center/=4
 var front:Vector2=view.city.front_direction(b);var middle:Vector2=center+front*float(b.size)/2
 if iso(middle).y<iso(center).y-.001:return
 var side:=Vector2(-front.y,front.x)*.15;var a:=iso(middle-side)-anchor;var z:=iso(middle+side)-anchor
 var height:=Vector2(0,minf(lift*.8,2.2*view.tile.x/4*sqrt(1.5)))
 canvas.draw_colored_polygon(PackedVector2Array([a,z,z-height,a-height]),Color("293c46"))
static func display_eligible(vehicle:Dictionary)->bool:
 # Existing synthetic fleet entries are already display samples. Never sample them twice.
 return not vehicle.has("trip_ordinal") or int(vehicle.trip_ordinal)%DISPLAY_STRIDE==0
func _process(_delta:float):
 if view==null:return
 if city_reference!=view.city:synchronize()
 view.transit_view.sync_visibility()
 if position!=view.origin:position=view.origin
 if scale!=Vector2.ONE*view.map_zoom:scale=Vector2.ONE*view.map_zoom
 zones.visible=view.show_zoning_tiles();grid.visible=zones.visible and view.map_zoom>=.4
 zones.set_grid_visible(view.map_zoom>=.4)
 if line_zoom!=view.map_zoom:
  line_zoom=view.map_zoom;line_material.set_shader_parameter("zoom",line_zoom)
 var screen_bounds:=Rect2(Vector2.ZERO,view.get_viewport_rect().size)
 for node in buildings.values():node.visible=screen_bounds.intersects(Rect2(view.origin+node.world_bounds.position*view.map_zoom,node.world_bounds.size*view.map_zoom))
 var active:Dictionary={}
 if view.traffic!=null and view.traffic.running and view.traffic.simulation!=null:
  var ppm:float=view.tile.x/4*sqrt(2.0)
  for vehicle in view.traffic.simulation.vehicles:
   if not display_eligible(vehicle):continue
   var p:=iso(view.traffic.simulation.position(vehicle)/4)
   if not car_frames.has(vehicle.asset_id):car_frames[vehicle.asset_id]=view.traffic.sprite_rect(vehicle.asset_id,Vector2.ZERO,ppm)
   var rect:Rect2=car_frames[vehicle.asset_id];var visible_box:=Rect2(view.origin+(p+rect.position)*view.map_zoom,rect.size*view.map_zoom)
   if not screen_bounds.intersects(visible_box):continue
   active[vehicle.id]=true
   var sprite:Sprite2D=cars.get(vehicle.id)
   if sprite==null:sprite=Sprite2D.new();sprite.centered=false;actors.add_child(sprite);cars[vehicle.id]=sprite
   sprite.visible=true;sprite.position=p;sprite.texture=view.traffic.texture_for(vehicle.asset_id,view.traffic.simulation.heading(vehicle))
   sprite.scale=rect.size/Vector2(sprite.texture.get_size());sprite.offset=rect.position/sprite.scale
 for id in cars:
  if not active.has(id):cars[id].visible=false
