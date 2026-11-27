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
 var part:String=""
 var world_bounds:Rect2
 func _draw():
  if texture==null:renderer.fallback(self,record,position)
class Catenary extends Node2D:
 var renderer
 var commands:Array=[]
 var world_bounds:Rect2
 var zoom:float=-1
 var base_depth:float
 var overhead:bool
 var footprint:PackedVector2Array
 func command_visible(command:Dictionary)->bool:
  return zoom>=1 or command.kind in ["pole","horizontal","portal","contact"]
 func line_width(command:Dictionary)->float:
  return .3*renderer.view.tile.x/4*sqrt(2.0) if command.kind=="pole" and zoom>=1 else 1/maxf(.001,zoom)
 func _draw():
  for command:Dictionary in commands:
   if command_visible(command):draw_line(command.projected_a-position,command.projected_b-position,command.color,line_width(command),true)
var catenary_nodes:Array=[]
var catenary_generation:int=-1
static func catenary_draw_pieces(source:Dictionary)->Array:
 if source.kind!="portal":return [source]
 var pieces:Array=[]
 var count:=maxi(1,ceili(source.a.distance_to(source.b)))
 for i in range(count):
  var piece:Dictionary=source.duplicate(true)
  piece.a=source.a.lerp(source.b,float(i)/count);piece.b=source.a.lerp(source.b,float(i+1)/count)
  piece.footprint=PackedVector2Array([piece.a,piece.b]);pieces.append(piece)
 return pieces
## E3a: rail decks are rebuilt with roads or transit geometry, then catenary depths follow them.
var structure_signature:Variant=null
var structure_generation:=0
func sync_transit_structures():
 if elevated==null or actors==null:return
 var key:=hash([view.city.get_instance_id(),view.city.roads,view.city.width,view.city.height,view.transit_view.generation])
 var rebuilt:bool=key!=structure_signature
 if rebuilt:
  structure_generation+=1
  structure_signature=key;elevated.rebuild();catenary_generation=-1
  # E2 road trenches and E3b rail trenches follow roads and transit geometry alike.
  if underground!=null:underground.rebuild()
  transit_snapshot_signature=null
 sync_catenary()
 if rebuilt:sync_transit_cars() # An unchanged pose still needs its new trench and wall.
## Deck catenary draws after its own deck surface and trains, before the near barrier face.
func deck_catenary_depth(commands:Array,fronts:Array,depth:float)->float:
 var best:=-INF
 for piece in fronts:
  for command:Dictionary in commands:
   for p:Vector2 in command.footprint:
    if Geometry2D.is_point_in_polygon(p,piece.footprint):best=maxf(best,piece.position.y-.005)
 return best if is_finite(best) else depth
## Review fix 2: a train picture follows only the structure of the route its car runs on (the
## plan leg's route id). No id means 0m. One cached dictionary lookup per call.
var rail_structures:Dictionary={}
var rail_structure_key:Variant=null
var rail_deck_checks:=0
func rail_deck_at(pose:Dictionary)->Dictionary:
 if not pose.has("route_id"):return {}
 var key:Array=[view.city.get_instance_id(),view.transit_view.generation]
 if key!=rail_structure_key:
  rail_structure_key=key;rail_structures.clear()
  for route:Dictionary in view.city.transit_routes:
   if route.kind=="rail" and route.has("heights_m"):rail_structures[int(route.id)]=preload("res://core/transit_routes.gd").structure(route)
 rail_deck_checks+=1
 return rail_structures.get(int(pose.route_id),{})
func sync_catenary():
 if catenary_generation==view.transit_view.generation:return
 catenary_generation=view.transit_view.generation
 for node in catenary_nodes:
  node.hide();node.queue_free()
 catenary_nodes.clear()
 var groups:Dictionary={};var sources:Array=[]
 for source:Dictionary in view.transit_view.geometry.get("catenary",[]):sources.append_array(catenary_draw_pieces(source))
 for source:Dictionary in sources:
  var command:Dictionary=source.duplicate(true)
  var pole:bool=command.kind in ["pole","cap"]
  var key:Variant=[command.route_id,command.get("support",command.a) if pole else command.footprint,"pole" if pole else "overhead"]
  if not groups.has(key):groups[key]=[]
  command.projected_a=view.transit_view.project_point(command.a,command.a_height)
  command.projected_b=view.transit_view.project_point(command.b,command.b_height)
  groups[key].append(command)
 var rail_fronts:Dictionary={}
 if elevated!=null:
  for piece in elevated.decks:
   if piece.front_face and piece.road.has("rail_route_id"):
    if not rail_fronts.has(piece.road.rail_route_id):rail_fronts[piece.road.rail_route_id]=[]
    rail_fronts[piece.road.rail_route_id].append(piece)
 for key in groups:
  var node:=Catenary.new();node.renderer=self;node.commands=groups[key]
  var depth:float=-INF
  var bounds:=Rect2(node.commands[0].projected_a,Vector2.ZERO)
  for command:Dictionary in node.commands:
   for p:Vector2 in command.footprint:depth=maxf(depth,iso(p).y)
   bounds=bounds.expand(command.projected_a).expand(command.projected_b)
  if node.commands[0].get("deck",false):depth=deck_catenary_depth(node.commands,rail_fronts.get(int(node.commands[0].route_id),[]),depth)
  node.overhead=key[2]=="overhead";node.base_depth=depth
  node.footprint=node.commands[0].footprint
  node.position.y=depth+(.02 if node.overhead else 0.0)
  node.world_bounds=bounds.grow(2)
  # E3b: trench catenary is clipped by its trench outline (far edge raised 6m), like trench trains.
  var parent:Node2D=actors
  if node.commands[0].get("trench",false) and underground!=null:
   var trench=underground.trench_at({"rail_route_id":int(node.commands[0].route_id)},node.footprint[0])
   if trench!=null:parent=trench
  parent.add_child(node);catenary_nodes.append(node)
 catenary_depth_signature=null
 catenary_buckets.clear()
 for node in catenary_nodes:
  if not node.overhead:continue
  var box:=Rect2(node.footprint[0],Vector2.ZERO)
  for point:Vector2 in node.footprint:box=box.expand(point)
  for cell:Vector2i in catenary_cells(box):
   if not catenary_buckets.has(cell):catenary_buckets[cell]=[]
   catenary_buckets[cell].append(node)
 sync_catenary_visibility()
func sync_catenary_visibility():
 var viewport:=Rect2(Vector2.ZERO,view.get_viewport_rect().size)
 for node in catenary_nodes:
  node.visible=not view.transit_view.underground and view.map_zoom>=.4 and viewport.intersects(Rect2(view.origin+node.world_bounds.position*view.map_zoom,node.world_bounds.size*view.map_zoom))
  if node.zoom!=view.map_zoom:node.zoom=view.map_zoom;node.queue_redraw()
var catenary_depth_signature:Variant=null
var catenary_buckets:Dictionary={}
var catenary_vehicle_depths:Dictionary={}
static func catenary_cells(box:Rect2)->Array[Vector2i]:
 var cells:Array[Vector2i]=[]
 for x in range(floori(box.position.x/4),floori(box.end.x/4)+1):
  for y in range(floori(box.position.y/4),floori(box.end.y/4)+1):cells.append(Vector2i(x,y))
 return cells
static func catenary_overlap(footprint:PackedVector2Array,body:PackedVector2Array)->bool:
 if footprint.size()>=3:return not Geometry2D.intersect_polygons(footprint,body).is_empty()
 for point:Vector2 in footprint:
  if Geometry2D.is_point_in_polygon(point,body):return true
 if footprint.size()==2:
  for i in range(body.size()):
   if Geometry2D.segment_intersects_segment(footprint[0],footprint[1],body[i],body[(i+1)%body.size()])!=null:return true
 return false
func sync_catenary_depth():
 var poses:Array=[]
 for pose:Dictionary in view.city.transit_state.get("visible",[]):
  if pose.kind!="metro":
   var copy:=pose.duplicate();copy.sprite=transit_cars.get(pose.id);poses.append(copy)
 if view.traffic!=null and view.traffic.running and view.traffic.simulation!=null:
  for vehicle:Dictionary in view.traffic.simulation.vehicles:
   if not cars.has(vehicle.id) or not cars[vehicle.id].visible:continue
   if absf(float(cars[vehicle.id].get_meta("road_height_m",0)))>0:continue # Deck/trench cars never reorder ground catenary.
   poses.append({"id":vehicle.id,"sprite":cars[vehicle.id],"position":view.traffic.simulation.position(vehicle),"heading":view.traffic.simulation.heading(vehicle),"length_m":vehicle.length,"width_m":2.5})
 var active:bool=not view.transit_view.underground and view.map_zoom>=.4
 var key:=hash([catenary_generation,active,poses])
 if key!=catenary_depth_signature:
  catenary_depth_signature=key;catenary_vehicle_depths.clear()
  for node in catenary_nodes:node.position.y=node.base_depth+(.02 if node.overhead else 0.0)
  for pose:Dictionary in poses:
   var p:Vector2=pose.position/4;var along:Vector2=pose.heading*float(pose.get("length_m",10))/8
   var side:Vector2=pose.heading.orthogonal()*float(pose.get("width_m",3))/8
   var body:=PackedVector2Array([p-along-side,p+along-side,p+along+side,p-along+side])
   var box:=Rect2(body[0],Vector2.ZERO)
   for point:Vector2 in body:box=box.expand(point)
   var candidates:Dictionary={}
   if active:
    for cell:Vector2i in catenary_cells(box):
     for node in catenary_buckets.get(cell,[]):candidates[node]=true
   var overlaps:Array=[];var depth:float=iso(p).y
   # E3a: a lifted deck train keeps its deck depth and only reorders deck catenary.
   var lifted:bool=pose.get("sprite")!=null and float(pose.sprite.get_meta("rail_height_m",0.0))>0
   if lifted:depth=pose.sprite.position.y
   for node in candidates:
    if lifted!=bool(node.commands[0].get("deck",false)):continue
    if catenary_overlap(node.footprint,body):
     overlaps.append(node)
     if not lifted:depth=maxf(depth,node.base_depth)
   catenary_vehicle_depths[pose.id]=depth
   for node in overlaps:node.position.y=maxf(node.position.y,depth+.02)
  # A nearby support follows its suspended bracket, but a far support keeps its base.
  var support_depths:Dictionary={}
  for node in catenary_nodes:
   if not node.overhead:continue
   for command:Dictionary in node.commands:
    if command.get("near",false):support_depths[command.support]=maxf(support_depths.get(command.support,-INF),node.position.y+.02)
  for node in catenary_nodes:
   if not node.overhead and node.commands[0].get("near",false):node.position.y=maxf(node.position.y,support_depths.get(node.commands[0].support,node.base_depth))
  # Anchor movement requires a redraw; geometry remains cached and artwork stays fixed.
  for node in catenary_nodes:node.queue_redraw()
 for pose:Dictionary in poses:
  var sprite:Sprite2D=pose.sprite
  if sprite==null or sprite.texture==null:continue
  var depth:float=catenary_vehicle_depths.get(pose.id,iso(pose.position/4).y)
  if pose.get("cargo",false):depth+=.001
  sprite.offset.y-=(depth-sprite.position.y)/sprite.scale.y;sprite.position.y=depth
var view
var city_reference
var ground
var zones
var grid
var roads
var marks
var actors:Node2D
var actor_sort:Node2D
var trench_actors:Node2D
var buildings:Dictionary={}
var station_parts:Dictionary={}
var metro_stations:Dictionary={}
var cars:Dictionary={}
var transit_cars:Dictionary={}
var transit_snapshot_signature:Variant=null
func sync_transit_cars():
 if view.traffic==null:return
 var snapshot:Array=view.city.transit_state.get("visible",[])
 var key:int=hash([view.city.get_instance_id(),snapshot])
 if key==transit_snapshot_signature:return
 transit_snapshot_signature=key
 var keep:Dictionary={};var ppm:float=view.tile.x/4*sqrt(2.0)
 for pose:Dictionary in snapshot:
  keep[pose.id]=true
  var sprite:Sprite2D=transit_cars.get(pose.id)
  if sprite==null:
   sprite=Sprite2D.new();sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
   var parent:Node2D=view.transit_view.metro_layer if pose.kind=="metro" else actors
   parent.add_child(sprite);transit_cars[pose.id]=sprite
  var target_parent:Node2D=view.transit_view.metro_layer if pose.kind=="metro" else actors
  if sprite.get_parent()!=target_parent:sprite.reparent(target_parent,false)
  if sprite.has_meta("rail_trench_surface_fraction"):sprite.remove_meta("rail_trench_surface_fraction")
  var ground_point:=iso(pose.position/4)
  var rect:Rect2=view.traffic.sprite_rect(pose.asset_id,Vector2.ZERO,ppm)
  sprite.position=ground_point
  if pose.get("cargo",false):sprite.position.y+=.001
  sprite.texture=view.traffic.texture_for(pose.asset_id,pose.heading)
  if sprite.texture==null:sprite.visible=false;continue
  var height:float=pose.height_m*view.tile.x/4*sqrt(1.5)
  sprite.scale=rect.size/Vector2(sprite.texture.get_size())
  sprite.offset=(rect.position-Vector2(0,height+sprite.position.y-ground_point.y))/sprite.scale
  sprite.visible=true
  sprite.set_meta("rail_height_m",0.0)
  if pose.kind!="metro":
   # E3a: only the picture rises onto the ramp/deck (E1 lift_vehicle); operation is unchanged.
   var deck:Dictionary=rail_deck_at(pose)
   var point:Vector2=pose.position/4
   var lift:float=preload("res://core/road_height.gd").height_at(deck,point) if not deck.is_empty() else 0.0
   if lift>0:
    var along:Vector2=pose.heading*float(pose.get("length_m",10))/8;var across:Vector2=pose.heading.orthogonal()*float(pose.get("width_m",3))/8
    elevated.lift_vehicle(sprite,deck,point,PackedVector2Array([point-along-across,point+along-across,point+along+across,point-along+across]))
    if pose.get("cargo",false):sprite.position.y+=.001
    sprite.set_meta("rail_height_m",lift)
   elif lift< -preload("res://core/road_height.gd").EPS and underground!=null:
    # E3b: trench trains drop into the trench clip group; tunnel trains draw like metro trains.
    sprite.set_meta("rail_height_m",lift)
    underground.place_train(sprite,deck,point,pose)
 for id:Variant in transit_cars.keys():
  if not keep.has(id):transit_cars[id].queue_free();transit_cars.erase(id)
 sync_catenary_depth()
var road_generation:=0
var elevated
var underground
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
var direction_arrows:Array[PackedVector2Array]=[]
var line_mesh:ArrayMesh
var line_material:ShaderMaterial
var line_zoom:float=-1.0
var car_frames:Dictionary={}
var car_widths:Dictionary={}
var vehicle_road_lookups:=0
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
 # Underground view (user rule 2026-11-19): WorldActors holds every ground actor and is hidden as one
 # layer; trench barriers and portal tops stay in TrenchBarriers. Both are y-sorted children of the
 # y-sorted ActorSort, so the engine sorts all their children together as one WorldActors did.
 actor_sort=Node2D.new();actor_sort.name="ActorSort";actor_sort.z_index=9;actor_sort.y_sort_enabled=true;add_child(actor_sort)
 actors=Node2D.new();actors.name="WorldActors";actors.y_sort_enabled=true;actor_sort.add_child(actors)
 trench_actors=Node2D.new();trench_actors.name="TrenchBarriers";trench_actors.y_sort_enabled=true;actor_sort.add_child(trench_actors)
 elevated=preload("res://core/elevated_road_renderer.gd").new(self)
 underground=preload("res://core/underground_road_renderer.gd").new(self)
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
  sync_transit_structures()
  for polygon in view.city.road_pavement+view.city.junction_pavement:road_shapes.append([project(polygon),Color("c8cbc3")])
  for polygon in view.city.road_asphalt+view.city.junction_asphalt:road_shapes.append([project(polygon),Color("4c5659")])
  for polygon in view.city.road_crosswalks+view.city.road_stop_lines:stripes.append(project(polygon))
  direction_arrows.clear()
  for polygon in view.city.road_direction_arrows:direction_arrows.append(project(polygon))
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
 var signature:Array=[view.city.get_instance_id(),rs]
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
   if record.get("public_asset_id","")=="train-station-01":continue
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
   if str(record.get("public_asset_id","")).begins_with("park-"):
    for deck in elevated.decks:
     if not Geometry2D.intersect_polygons(view.city.footprint(record),deck.footprint).is_empty():depth=minf(depth,deck.position.y-.01)
   node.position=Vector2(iso(center).x,depth)
   bind_building(node)
  for id in buildings.keys():
   if not keep.has(id):buildings[id].queue_free();buildings.erase(id)
 sync_station_parts()
 sync_metro_stations()
 sync_transit_cars()
func sync_metro_stations():
 var keep:Dictionary={}
 for lot:Dictionary in view.city.public_facilities.lots:
  if lot.get("public_asset_id","")!="subway-entrance-01":continue
  keep[lot.id]=true
  var node:Building=metro_stations.get(lot.id)
  if node==null:
   node=Building.new();node.renderer=self;node.centered=false;view.transit_view.metro_layer.add_child(node);metro_stations[lot.id]=node
  node.record=lot.duplicate(true);node.record.public_asset_id="subway-platform-silhouette-01";node.record.render_depth_m=-12.7
  node.position=iso(lot.position);bind_building(node)
 for id in metro_stations.keys():
  if not keep.has(id):metro_stations[id].queue_free();metro_stations.erase(id)
func sync_station_parts():
 var keep:Dictionary={}
 for record:Dictionary in view.city.public_facilities.lots:
  if record.get("public_asset_id","")!="train-station-01":continue
  var front:Vector2=record.front_direction
  var near_part:String="StationFront" if front.x+front.y>=0 else "StationRear"
  var low:float=INF;var high:float=-INF
  for point:Vector2 in record.internal_points:
   low=minf(low,iso(point).y);high=maxf(high,iso(point).y)
  for part:String in ["StationFront","StationRear"]:
   var key:String="%d:%s"%[record.id,part];keep[key]=true
   var node:Building=station_parts.get(key)
   if node==null:
    node=Building.new();node.renderer=self;node.centered=false;node.part=part;actors.add_child(node);station_parts[key]=node
   node.record=record
   node.position=Vector2(iso(record.position).x,high+view.tile.y*2 if part==near_part else low-view.tile.y*2)
   bind_building(node)
 for key in station_parts.keys():
  if not keep.has(key):station_parts[key].queue_free();station_parts.erase(key)
func bind_building(node:Building):
 var b:Dictionary=node.record
 var visual:Dictionary=view.public_controller.visual(b,node.part) if b.has("public_asset_id") else view.building_visual(b)
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
 for node in buildings.values()+station_parts.values()+metro_stations.values():bind_building(node)
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
   canvas.draw_colored_polygon(project(PackedVector2Array([Vector2.ZERO,Vector2(view.city.width,0),Vector2(view.city.width,view.city.height),Vector2(0,view.city.height)])),terrain_color())
   # Verges and entrance paving belong to ground roads and lots: the underground view leaves them out.
   if terrain_faded:return
   for polygon in verges:canvas.draw_colored_polygon(polygon,preload("res://core/roadside_verges.gd").COLOR)
   for polygon in accessways:canvas.draw_colored_polygon(polygon,preload("res://core/entrance_accessways.gd").COLOR)

  "roads":
   for shape in road_shapes:canvas.draw_colored_polygon(shape[0],shape[1])
   for polygon in stripes:canvas.draw_colored_polygon(polygon,Color("e8e7dc"))
   for polygon in direction_arrows:canvas.draw_colored_polygon(polygon,Color("e8e7dc"))
   for polygon in arrows:canvas.draw_colored_polygon(polygon,Boundary.PAINT)
  "marks":
   if line_mesh!=null and line_mesh.get_surface_count()>0:canvas.draw_mesh(line_mesh,null)
## Underground view (user rule 2026-11-19, ASSET_REQUEST_ELEVATED_TUNNEL_KO.md 8항): only underground
## roads, rails and metro show, with trenches and portals (both views). Every entry path sets
## transit_view.underground and calls transit_view.sync_visibility(), which comes here. Ground layers
## (zoning, roads, marks, WorldActors, power and water) are hidden as whole parents, so objects built
## while the view is open stay hidden too. The terrain stays, desaturated and a little lighter, never
## darker: the 15181a tunnel bands keep more than 3:1 contrast on it.
const TERRAIN:=Color("7e9275")
const UNDERGROUND_TERRAIN:=Color("9a9e97")
var terrain_faded:=false
func terrain_color()->Color:return UNDERGROUND_TERRAIN if terrain_faded else TERRAIN
func sync_view_layers():
 var shown:bool=not view.transit_view.underground
 for node:CanvasItem in [roads,marks,actors]:node.visible=shown
 zones.visible=shown and view.show_zoning_tiles();grid.visible=zones.visible and view.map_zoom>=.4
 for overlay in [view.get("power_overlay"),view.get("water_overlay")]:
  if overlay is CanvasItem:overlay.visible=shown
 if terrain_faded==shown:
  terrain_faded=not shown;ground.queue_redraw()
  for sprite:Sprite2D in transit_cars.values():underground.sync_train_visibility(sprite)
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
func vehicle_road(lanes:Array,lane_id:int)->Dictionary:
 var lane:Dictionary=lanes[lane_id]
 var owner:=int(lane.get("road",-1))
 if owner<0:owner=int(lanes[lane.from].road)
 vehicle_road_lookups+=1
 return view.city.roads[owner]
func _process(_delta:float):
 vehicle_road_lookups=0
 if view==null:return
 if city_reference!=view.city:synchronize()
 view.transit_view.sync_visibility()
 sync_catenary_visibility()
 if position!=view.origin:position=view.origin
 if elevated!=null:elevated.sync_visibility()
 if underground!=null:underground.sync_visibility()
 if scale!=Vector2.ONE*view.map_zoom:scale=Vector2.ONE*view.map_zoom
 zones.set_grid_visible(view.map_zoom>=.4)
 if line_zoom!=view.map_zoom:
  line_zoom=view.map_zoom;line_material.set_shader_parameter("zoom",line_zoom)
 var screen_bounds:=Rect2(Vector2.ZERO,view.get_viewport_rect().size)
 for node in buildings.values()+station_parts.values()+metro_stations.values():node.visible=screen_bounds.intersects(Rect2(view.origin+node.world_bounds.position*view.map_zoom,node.world_bounds.size*view.map_zoom))
 var active:Dictionary={}
 if view.traffic!=null and view.traffic.running and view.traffic.simulation!=null:
  var ppm:float=view.tile.x/4*sqrt(2.0)
  var lanes:Array=view.traffic.simulation.network.lanes
  for vehicle in view.traffic.simulation.vehicles:
   if not display_eligible(vehicle):continue
   var point:Vector2=view.traffic.simulation.position(vehicle)/4
   var p:=iso(point)
   var road:=vehicle_road(lanes,vehicle.lane)
   var height:float=preload("res://core/road_height.gd").height_at(road,point)
   if not car_frames.has(vehicle.asset_id):
    car_frames[vehicle.asset_id]=view.traffic.sprite_rect(vehicle.asset_id,Vector2.ZERO,ppm)
    car_widths[vehicle.asset_id]=float(view.traffic.catalog.filter(func(a):return a.id==vehicle.asset_id)[0].width_m)
   var rect:Rect2=car_frames[vehicle.asset_id]
   var visible_box:=Rect2(view.origin+(p+rect.position-Vector2(0,height*view.tile.x/4*sqrt(1.5)))*view.map_zoom,rect.size*view.map_zoom)
   if not screen_bounds.intersects(visible_box):continue
   active[vehicle.id]=true
   var sprite:Sprite2D=cars.get(vehicle.id)
   if sprite==null:sprite=Sprite2D.new();sprite.centered=false;actors.add_child(sprite);cars[vehicle.id]=sprite
   var direction:Vector2=view.traffic.simulation.heading(vehicle)
   sprite.visible=true;sprite.position=p;sprite.texture=view.traffic.texture_for(vehicle.asset_id,direction)
   sprite.set_meta("road_height_m",height)
   sprite.scale=rect.size/Vector2(sprite.texture.get_size());sprite.offset=rect.position/sprite.scale
   var along:Vector2=direction*float(vehicle.length)/8
   var across:Vector2=direction.orthogonal()*float(car_widths[vehicle.asset_id])/8
   elevated.lift_vehicle(sprite,road,point,PackedVector2Array([point-along-across,point+along-across,point+along+across,point-along+across]))
   underground.place_vehicle(sprite,road,point)
 for id in cars:
  if not active.has(id):cars[id].visible=false
 sync_catenary_depth()
