extends Control
## Screen-space display of authoritative line plans. The HUD list owns GUI input;
## the passive full-screen canvas never blocks world input.
const Bus=preload("res://core/scheduled_bus_network.gd")
const Rail=preload("res://core/transit_line_planner.gd")
const Height=preload("res://core/road_height.gd")
const Paths=preload("res://core/road_junctions.gd")
const COLORS:=[Color("ff6b5b"),Color("ffc23d"),Color("4dd9a6"),Color("b48cff")]
const NAMES:={"bus":"버스","metro":"지하철","rail":"철도","freight":"화물"}
const STATION:={"bus":"bus-stop-01","metro":"subway-entrance-01","rail":"train-station-01"}
const INK:=Color("edf4f5")
const LIST_PAPER:=Color("142b37")
const ACCENT:=Color("36b7ff")
const DIRECTION_OFFSET:=6.0
const CORRIDOR_SPACING:=24.0
const CORRIDOR_EPSILON:=.0001
const ARROW_SPACING:=34.0
const BUS_ARROW_SPACING:=30.0
const BUS_ARROW_LENGTH:=8.0
const STROKE_WIDTH:=4.0
var game
var panel:PanelContainer
var scroll:ScrollContainer
var rows:VBoxContainer
var actions:VBoxContainer
var create_buttons:Dictionary={}
var mode:=""
var phase:=0.0
var hovered_id:=-1
var colors:Dictionary={}
var lines:Array=[]
var stations:Dictionary={}
var station_world:Dictionary={}
var paths:Array=[]
var stroke_primitives:Array=[]
var arrow_primitives:Array=[]
var world_paths:Array=[]
var hosts:Dictionary={}
var bus_network
var bus_stops:Dictionary={}
var station_radii:Dictionary={}
var bus_junction_centers:Array[Vector2]=[]
var creation_paths:Array=[]
var dots:Array=[]
var dragged:Dictionary={}
var pointer:=Vector2.ZERO
var preview_paths:Array=[]
const EMPTY_DROP_RADIUS:=24.0
const DRAG_MOTION_THRESHOLD:=4.0
var observed_city:WeakRef
var signature:Variant
var camera_key:Variant
var delete_icon:Texture2D

func _ready():
 get_window().focus_exited.connect(cancel_drag)

func setup(view):
 game=view
 name="RouteOverlay"
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel=PanelContainer.new()
 panel.name="RouteList"
 panel.position=Vector2(24,24)
 panel.custom_minimum_size.x=300
 var box:StyleBoxFlat=game.style(LIST_PAPER,Color("38515e"))
 for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:box.set_content_margin(side,8)
 panel.add_theme_stylebox_override("panel",box)
 add_child(panel)
 var column:=VBoxContainer.new();panel.add_child(column)
 scroll=ScrollContainer.new();column.add_child(scroll)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 rows=VBoxContainer.new();scroll.add_child(rows)
 rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 actions=VBoxContainer.new();column.add_child(actions)
 var image:=Image.new()
 image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12"><path d="M1 1l10 10m0-10L1 11" fill="none" stroke="#edf4f5" stroke-width="2" stroke-linecap="round"/></svg>')
 delete_icon=ImageTexture.create_from_image(image)
 close()

func open(kind:String):
 mode=kind
 show()
 set_process(true)
 observe_city()
 synchronize()

func close():
 if observed_city!=null:
  var previous=observed_city.get_ref()
  if previous!=null:previous.transit_changed.disconnect(invalidate)
  observed_city=null
 hide()
 set_process(false)
 mode="";hovered_id=-1;phase=0.0;signature=null;camera_key=null
 stations.clear();station_world.clear();paths.clear();stroke_primitives.clear();arrow_primitives.clear()
 world_paths.clear();lines.clear();colors.clear();dots.clear()
 hosts.clear();bus_network=null;creation_paths.clear()
 bus_stops.clear();station_radii.clear();bus_junction_centers.clear()
 cancel_drag()
 clear_children(rows);clear_children(actions);create_buttons.clear()

func observe_city():
 if observed_city!=null and observed_city.get_ref()==game.city:return
 if observed_city!=null and observed_city.get_ref()!=null:observed_city.get_ref().transit_changed.disconnect(invalidate)
 observed_city=weakref(game.city)
 game.city.transit_changed.connect(invalidate)
 invalidate()

func invalidate():
 signature=null

func clear_children(parent:Control):
 for child in parent.get_children():
  parent.remove_child(child)
  child.queue_free()

func synchronize():
 if not visible:return
 observe_city()
 var city=game.city
 # Roads/facilities can change without transit_changed (e.g. queued construction).
 # Check on explicit HUD refresh too; never poll the graph per animation frame.
 var key:=[city.get_instance_id(),hash(city.transit_lines),hash(city.transit_routes),hash(city.roads),hash(city.public_facilities.lots)]
 if signature==key:return
 signature=key
 var next_lines:Array=city.transit_lines.filter(func(line):return line.kind==mode or (mode=="rail" and line.kind=="freight"))
 var ids:Array=next_lines.map(func(line):return line.id)
 for id in colors.keys():
  if id not in ids:colors.erase(id)
 for id in ids:
  if not colors.has(id):colors[id]=next_color()
 var rebuild_list:bool=lines.map(func(line):return line.id)!=ids or create_buttons.is_empty()
 lines=next_lines.duplicate(true)
 station_world.clear();world_paths.clear();bus_stops.clear()
 hosts.clear()
 for route:Dictionary in city.transit_routes:hosts[route.id]=route
 for lot:Dictionary in city.public_facilities.lots:
  if lot.public_asset_id!=STATION[mode]:continue
  var p:Vector2=lot.position
  var height:=0.0
  if mode!="bus":
   var points:PackedVector2Array=lot.internal_points
   p=(points[0]+points[-1])/2
   height=world_point(p,hosts.get(lot.get("internal_route_id",-1),{}),mode).z
  station_world[lot.id]=Vector3(p.x,p.y,height)
 bus_network=null
 if mode=="bus":bus_network=Bus.new();bus_network.build_city(city)
 for line:Dictionary in lines:world_paths.append_array(plan_paths(line,bus_network,hosts,bus_stops))
 if rebuild_list:build_list()
 else:sync_creation()
 camera_key=null
 project_paths()

func next_color()->Color:
 for color in COLORS:
  if color not in colors.values():return color
 return COLORS[colors.size()%COLORS.size()]

func plan_paths(line:Dictionary,network,rails:Dictionary,stop_anchors:Variant=null)->Array:
 var result:Array=[]
 if line.kind=="bus":
  var plan:Dictionary=network.line_plan(line.stops)
  if not plan.ok:return result
  var stop_index:=0
  var before_first_stop:Array=[]
  for i in range(plan.route.size()):
   var lane:Dictionary=network.lanes[plan.route[i]]
   var points:PackedVector2Array=network.points_of(lane)
   var road_index:int=lane.get("road",-1)
   var road:Dictionary=game.city.roads[road_index] if road_index>=0 else {}
   if road_index<0 and lane.has("from"):
    add_bus_turn(result,line,stop_index-1,lane,network)
    continue
   var cursor:=0.0
   while stop_index<plan.stops.size() and plan.stops[stop_index].route_index==i:
    var stop:Dictionary=plan.stops[stop_index]
    var target:Array=before_first_stop if stop_index==0 else result
    add_bus_piece(target,line,posmod(stop_index-1,line.stops.size()),points,road,lane,cursor,float(stop.progress))
    if stop_anchors!=null:
     var p:=on_center(network.sample(lane.id,stop.progress)/4,road)
     if not stop_anchors.has(stop.id):stop_anchors[stop.id]=[]
     stop_anchors[stop.id].append({"id":line.id,"index":stop_index,"p":world_point(p,road,"bus"),"section":lane.section,"direction":lane.direction})
    cursor=float(stop.progress);stop_index+=1
   add_bus_piece(result,line,stop_index-1,points,road,lane,cursor,float(lane.length))
  # First traversal from the first stop owns any repeated visible interval.
  result.append_array(before_first_stop)
 else:
  var plan:=Rail.new().rail_plan(game.city,line)
  if not plan.ok:return result
  var legs:Array=plan.get("legs",[plan])
  for i in range(legs.size()):
   var leg:Dictionary=legs[i]
   var group:=0
   for v in range(1,leg.points.size()):
    while group+1<leg.stops.size() and leg.distances[v-1]>=leg.stops[group+1].distance-.00001:group+=1
    var stop_index:int=(line.stops.size()-2-group) if i==1 else group
    stop_index=clampi(stop_index,0,line.stops.size()-1)
    var route:Dictionary=rails.get(leg.routes[v-1],{})
    var a:Vector2=leg.points[v-1]/4
    var b:Vector2=leg.points[v]/4
    # Rail plans already include physical track and terminal crossover offsets.
    # Draw the service on the traversed ribbon center, not an offset of that rail.
    a=on_center(a,route);b=on_center(b,route)
    add_piece(result,line,stop_index,world_point(a,route,line.kind),world_point(b,route,line.kind),i,not plan.get("turnback",false))
 return result

func add_bus_piece(result:Array,line:Dictionary,index:int,points:PackedVector2Array,road:Dictionary,lane:Dictionary,first:float,last:float):
 if last-first<.001:return
 var sliced:=Paths.slice(points,first,last)
 var a:=world_point(on_center(sliced[0]/4,road),road,"bus")
 for i in range(1,sliced.size()):
  var b:=world_point(on_center(sliced[i]/4,road),road,"bus")
  add_piece(result,line,index,a,b,0,true,{"road":lane.road,"section":lane.section,"direction":lane.direction})
  a=b

func add_bus_turn(result:Array,line:Dictionary,index:int,lane:Dictionary,network):
 var incoming:Dictionary=network.lanes[lane.from]
 var outgoing:Dictionary=network.lanes[lane.to]
 var from:Dictionary=game.city.roads[incoming.road]
 var to:Dictionary=game.city.roads[outgoing.road]
 var a:=world_point(on_center(lane.start/4,from),from,"bus")
 var b:=world_point(on_center(lane.end/4,to),to,"bus")
 result.append({"id":line.id,"index":index,"a":a,"b":b,"road":-1,
  "movement":Vector4i(incoming.section,incoming.direction,outgoing.section,outgoing.direction)})

func on_center(p:Vector2,host:Dictionary)->Vector2:
 if host.is_empty():return p
 var best:=INF;var result:=p
 var points:PackedVector2Array=host.points
 for i in range(1,points.size()):
  var nearest:=Geometry2D.get_closest_point_to_segment(p,points[i-1],points[i])
  var distance:=p.distance_squared_to(nearest)
  if distance<best:best=distance;result=nearest
 return result

func add_piece(result:Array,line:Dictionary,index:int,a:Vector3,b:Vector3,run:int,closed:bool,display:Dictionary={}):
 if a.distance_to(b)<=CORRIDOR_EPSILON:return
 # Merge densely baked straight samples, without losing a stop boundary or a turn.
 if not result.is_empty():
  var previous:Dictionary=result[-1]
  var span:Vector3=previous.b-previous.a
  var next:=b-a
  if previous.get("run",-1)==run and previous.index==index and previous.get("section",-1)==display.get("section",-1) and previous.get("direction",0)==display.get("direction",0) and a.distance_to(previous.b)<=CORRIDOR_EPSILON and span.dot(next)>0 and (b-previous.a).cross(span.normalized()).length()<CORRIDOR_EPSILON:
   previous.b=b
   return
 var piece:Dictionary={"id":line.id,"index":index,"freight":line.kind=="freight","a":a,"b":b,"run":run,"closed":closed}
 piece.merge(display)
 result.append(piece)

func world_point(p:Vector2,host:Dictionary,kind:String)->Vector3:
 return Vector3(p.x,p.y,-12.7 if kind=="metro" else (0.0 if host.is_empty() else Height.height_at(host,p)))

func station_at(p:Vector2)->int:
 var id:=-1
 var best:=INF
 for candidate:int in stations:
  var d:float=p.distance_squared_to(stations[candidate])
  var radius:float=maxf(18.0,station_radii.get(candidate,8.0)+2.0)
  if d<best and d<radius*radius:id=candidate;best=d
 return id

func project(p:Vector3)->Vector2:
 return game.origin+game.transit_view.project_point(Vector2(p.x,p.y),p.z)*game.map_zoom

# Join overlapping collinear world pieces, including reversed and differently
# subdivided plans. Touching endpoints and projected crossings aren't shared track.
func corridor_lanes()->PackedInt32Array:
 var parents:=PackedInt32Array();parents.resize(world_paths.size())
 var order:Array[int]=[]
 var bounds:Array[AABB]=[]
 for i in range(world_paths.size()):
  var piece:Dictionary=world_paths[i]
  var a:Vector3=piece.a;var b:Vector3=piece.b
  bounds.append(AABB(a.min(b),(b-a).abs()))
  parents[i]=i;order.append(i)
 order.sort_custom(func(a:int,b:int):return bounds[a].position.x<bounds[b].position.x)
 for i in range(order.size()):
  var a:int=order[i]
  for j in range(i+1,order.size()):
   var b:int=order[j]
   if bounds[b].position.x>bounds[a].end.x+CORRIDOR_EPSILON:break
   if not bounds[a].grow(CORRIDOR_EPSILON).intersects(bounds[b]):continue
   var root_a:=corridor_root(parents,a);var root_b:=corridor_root(parents,b)
   if root_a!=root_b and corridor_overlap(world_paths[a],world_paths[b]):parents[root_b]=root_a
 var groups:Dictionary={}
 var lanes:=PackedInt32Array();lanes.resize(world_paths.size())
 for i in range(world_paths.size()):
  var root_index:=corridor_root(parents,i)
  if not groups.has(root_index):groups[root_index]=[]
  groups[root_index].append(i)
 for group:Array in groups.values():
  if group.size()<2:continue
  var ids:Dictionary={}
  for i:int in group:ids[world_paths[i].id]=true
  var ordered:=ids.keys();ordered.sort()
  for lane in range(ordered.size()):ids[ordered[lane]]=lane
  # Use the lowest route's travel direction on this corridor, not a world
  # axis sign (which flips at ordinary corners). Both directions share a slot.
  var reference:int=group[0]
  for i:int in group:
   var candidate:Dictionary=world_paths[i];var current:Dictionary=world_paths[reference]
   if candidate.id<current.id or (candidate.id==current.id and candidate.get("run",0)<current.get("run",0)):reference=i
  var axis:Vector3=world_paths[reference].b-world_paths[reference].a
  for i:int in group:
   var direction:Vector3=world_paths[i].b-world_paths[i].a
   lanes[i]=ids[world_paths[i].id]*(1 if axis.dot(direction)>0 else -1)
 return lanes

func corridor_root(parents:PackedInt32Array,index:int)->int:
 while parents[index]!=index:index=parents[index]
 return index

func corridor_overlap(first:Dictionary,second:Dictionary)->bool:
 var span:Vector3=first.b-first.a
 var direction:=span.normalized()
 var a:Vector3=second.a-first.a;var b:Vector3=second.b-first.a
 if a.cross(direction).length()>CORRIDOR_EPSILON or b.cross(direction).length()>CORRIDOR_EPSILON:return false
 var start:=a.dot(direction);var end:=b.dot(direction)
 return minf(span.length(),maxf(start,end))-maxf(0,minf(start,end))>CORRIDOR_EPSILON

func project_paths():
 stations.clear();paths.clear()
 for id in station_world:stations[id]=project(station_world[id])
 station_radii.clear();bus_junction_centers.clear()
 if mode=="bus":
  for junction:Dictionary in bus_network.junctions:
   var p:Vector2=junction.position
   bus_junction_centers.append(project(Vector3(p.x,p.y,junction.height_m)))
  paths=project_bus_paths(world_paths)
  stroke_primitives=paths
  project_bus_stops()
  rebuild_arrows()
  return
 paths=project_runs(world_paths,corridor_lanes())
 stroke_primitives=clip_freight_dashes(paths)
 rebuild_arrows()
 dots.clear()
 var groups:Dictionary={}
 for line:Dictionary in lines:
  for i in range(line.stops.size()):
   var id:int=line.stops[i]
   if not stations.has(id):continue
   if not groups.has(id):groups[id]=[]
   groups[id].append({"id":line.id,"index":i,"p":stations[id]})
 for group:Array in groups.values():
  for i in range(group.size()):
   if group.size()>1:
    var angle:=TAU*i/group.size()
    var radius:=maxf(9.0,group.size()*2.4)
    group[i].p+=Vector2.from_angle(angle)*radius
   dots.append(group[i])

func project_bus_paths(source:Array)->Array:
 # Allocate by directed topology section, not by stop-to-stop interval. An
 # intermediate stop or a pocket split must never change the display slot.
 var slots:Dictionary={}
 for piece:Dictionary in source:
  if piece.road<0:continue
  if not slots.has(piece.section):slots[piece.section]={1:[],-1:[]}
  var ids:Array=slots[piece.section][piece.direction]
  if piece.id not in ids:ids.append(piece.id)
 for pair:Dictionary in slots.values():
  pair[1].sort();pair[-1].sort()
 var output:Array=[]
 var run:Array=[]
 for piece:Dictionary in source:
  if not run.is_empty() and run[-1].id!=piece.id:
   emit_bus_run(run,output);run.clear()
  var screen:=piece.duplicate()
  screen.a=project(piece.a);screen.b=project(piece.b)
  if piece.road>=0:
   var tangent:=Vector2(piece.b.x-piece.a.x,piece.b.y-piece.a.y)
   if screen.a.distance_squared_to(screen.b)<.00001:continue
   var normal:=piece_normal(screen)
   var road:Dictionary=game.city.roads[piece.road]
   var lateral:Vector2=tangent.normalized().orthogonal()*game.city.RoadProfile.asphalt_width(road)/2
   var half_width:=absf((project(piece.a+Vector3(lateral.x,lateral.y,0))-screen.a).dot(normal))
   var pair:Dictionary=slots[piece.section]
   var count:=maxi(pair[1].size(),pair[-1].size())
   var available:=maxf(0.0,half_width-.25)
   # Compress spacing, then reduce the stroke to half width. If that still
   # doesn't fit, the strokes overlap instead of expanding onto the sidewalk.
   var width:=clampf(available/count,STROKE_WIDTH/2,STROKE_WIDTH)
   var spacing:=clampf((available-width/2)/(count-.5),0.0,2*DIRECTION_OFFSET)
   screen.width=width
   screen.offset=spacing*(pair[piece.direction].find(piece.id)+.5)
   screen.arrow_side=minf(3.0,half_width-float(screen.offset)-1.0)
   screen.world=piece
  run.append(screen)
 if not run.is_empty():emit_bus_run(run,output)
 return output

func emit_bus_run(run:Array,output:Array):
 var joins_a:=PackedVector2Array();var joins_b:=PackedVector2Array()
 var movements:Dictionary={}
 var covered:Dictionary={}
 var cursor:=0.0
 joins_a.resize(run.size());joins_b.resize(run.size())
 for i in range(run.size()):
  var piece:Dictionary=run[i]
  if piece.road<0:continue
  var previous:Dictionary=run[posmod(i-1,run.size())]
  var next:Dictionary=run[(i+1)%run.size()]
  var offset:=piece_normal(piece)*float(piece.offset)
  joins_a[i]=offset_join(previous,piece) if previous.road>=0 else piece.a+offset
  joins_b[i]=offset_join(piece,next) if next.road>=0 else piece.b+offset
 for i in range(run.size()):
  var piece:Dictionary=run[i]
  if piece.road<0:
   if movements.has(piece.movement):continue
   movements[piece.movement]=true
   var j:=posmod(i-1,run.size());var k:=(i+1)%run.size()
   var incoming:Dictionary=run[j];var outgoing:Dictionary=run[k]
   if incoming.road<0 or outgoing.road<0:continue
   cursor=emit_bus_turn(output,piece,joins_b[j],joins_a[k],incoming,outgoing,cursor)
   continue
  var a:=joins_a[i];var b:=joins_b[i]
  var key:=Vector2i(piece.section,piece.direction)
  if not covered.has(key):covered[key]=[]
  for interval:Vector2 in uncovered_bus_intervals(piece.world,covered[key]):
   cursor=emit_bus_stroke(output,piece,a.lerp(b,interval.x),a.lerp(b,interval.y),piece.width,cursor)

func uncovered_bus_intervals(piece:Dictionary,covered:Array)->Array[Vector2]:
 # Subtract earlier visits in world space. A later visit often has different
 # stop or pocket cuts, and removing only identical segment pairs misses it.
 var span:Vector3=piece.b-piece.a
 var axis:=span.normalized()
 var length:=span.length()
 var overlaps:Array[Vector2]=[]
 for earlier:Dictionary in covered:
  var from:Vector3=earlier.a-piece.a;var to:Vector3=earlier.b-piece.a
  if from.cross(axis).length()>CORRIDOR_EPSILON or to.cross(axis).length()>CORRIDOR_EPSILON:continue
  var lo:=maxf(0.0,from.dot(axis));var hi:=minf(length,to.dot(axis))
  if hi-lo>CORRIDOR_EPSILON:overlaps.append(Vector2(lo,hi))
 overlaps.sort_custom(func(a:Vector2,b:Vector2):return a.x<b.x)
 var result:Array[Vector2]=[]
 var cursor:=0.0
 for overlap:Vector2 in overlaps:
  if overlap.x-cursor>CORRIDOR_EPSILON:result.append(Vector2(cursor,overlap.x)/length)
  cursor=maxf(cursor,overlap.y)
 if length-cursor>CORRIDOR_EPSILON:result.append(Vector2(cursor,length)/length)
 if not result.is_empty():covered.append(piece)
 return result

func emit_bus_turn(output:Array,piece:Dictionary,a:Vector2,b:Vector2,incoming:Dictionary,outgoing:Dictionary,cursor:float)->float:
 # Join the final offset approaches directly. Offsetting a tight centerline
 # corner after sampling (the old method) can invert the inside of the turn.
 var first:=piece_normal(incoming).orthogonal()*-1
 var last:=piece_normal(outgoing).orthogonal()*-1
 var span:=b-a
 var handle:=span.length()/3
 var first_handle:=handle;var last_handle:=handle
 var cross:=first.cross(last)
 if absf(cross)>.001:
  first_handle=clampf(span.cross(last)/cross*.65,handle*.1,handle*2.5)
  last_handle=clampf(first.cross(span)/cross*.65,handle*.1,handle*2.5)
 var c1:=a+first*first_handle;var c2:=b-last*last_handle
 var previous:=a
 for step in range(1,17):
  var p:=a.bezier_interpolate(c1,c2,b,step/16.0)
  cursor=emit_bus_stroke(output,piece,previous,p,lerpf(incoming.width,outgoing.width,(step-.5)/16),cursor)
  previous=p
 return cursor

func emit_bus_stroke(output:Array,piece:Dictionary,a:Vector2,b:Vector2,width:float,start:float)->float:
 if a.distance_squared_to(b)<=.00001:return start
 output.append({"id":piece.id,"index":piece.index,"freight":false,"a":a,"b":b,"width":width,"start":start,
  "section":piece.get("section",-1),"direction":piece.get("direction",0),"arrow_side":piece.get("arrow_side",0.0)})
 return start+a.distance_to(b)

func project_bus_stops():
 dots.clear()
 var approaches:Dictionary={}
 for piece:Dictionary in paths:
  if piece.section<0:continue
  var key:=Vector3i(piece.id,piece.section,piece.direction)
  if not approaches.has(key):approaches[key]=[]
  approaches[key].append(piece)
 for id in bus_stops:
  var bundle:=PackedVector2Array()
  for stop:Dictionary in bus_stops[id]:
   var anchor:=project(stop.p)
   var closest:=INF
   var dot:=anchor
   for piece:Dictionary in approaches.get(Vector3i(stop.id,stop.section,stop.direction),[]):
    var p:=Geometry2D.get_closest_point_to_segment(anchor,piece.a,piece.b)
    var distance:=anchor.distance_squared_to(p)
    if distance<closest:closest=distance;dot=p
   dots.append({"id":stop.id,"index":stop.index,"p":dot})
   bundle.append(dot)
  if bundle.is_empty():continue
  var bounds:=Rect2(bundle[0],Vector2.ZERO)
  for p:Vector2 in bundle:bounds=bounds.expand(p)
  var center:=bounds.get_center()
  stations[id]=center
  var radius:=8.0
  for p:Vector2 in bundle:radius=maxf(radius,p.distance_to(center)+8.0)
  station_radii[id]=radius

func project_runs(source:Array,lanes:=PackedInt32Array())->Array:
 var output:Array=[]
 var run:Array=[]
 for i in range(source.size()):
  var piece:Dictionary=source[i]
  var a:=project(piece.a);var b:=project(piece.b)
  if a.distance_squared_to(b)<.00001:continue
  if not run.is_empty() and (run[-1].id!=piece.id or run[-1].run!=piece.run):
   emit_run(run,output);run.clear()
  run.append({"id":piece.id,"index":piece.index,"freight":piece.freight,"run":piece.run,"closed":piece.closed,"a":a,"b":b,"offset":DIRECTION_OFFSET+(lanes[i]*CORRIDOR_SPACING if not lanes.is_empty() else 0.0)})
 if not run.is_empty():emit_run(run,output)
 return output

func emit_run(run:Array,output:Array):
 var closed:bool=run[0].closed
 var cursor:=0.0
 var joins:=PackedVector2Array()
 for i in range(run.size()+1):
  if closed or (i>0 and i<run.size()):
   var previous:Dictionary=run[posmod(i-1,run.size())];var next:Dictionary=run[i%run.size()]
   joins.append(offset_join(previous,next))
  elif i==0:
   joins.append(run[0].a+piece_normal(run[0])*run[0].offset)
  else:
   joins.append(run[-1].b+piece_normal(run[-1])*run[-1].offset)
 var stroke:Array=[]
 for i in range(run.size()):
  var piece:Dictionary=run[i]
  var a:=joins[i];var b:=joins[i+1]
  var normal:=piece_normal(piece)
  var length:float=piece.a.distance_to(piece.b)
  var fade:=minf(CORRIDOR_SPACING,length*.3)/length
  # Do not smear a slot change along an entire long shared straight.
  if (closed or i>0) and run[posmod(i-1,run.size())].offset!=piece.offset:
   var at:Vector2=piece.a.lerp(piece.b,fade)+normal*piece.offset
   emit_piece(stroke,piece,a,at);a=at
  if (closed or i+1<run.size()) and run[(i+1)%run.size()].offset!=piece.offset:
   var at:Vector2=piece.a.lerp(piece.b,1.0-fade)+normal*piece.offset
   emit_piece(stroke,piece,a,at);a=at
  emit_piece(stroke,piece,a,b)
 trim_local_loops(stroke,closed)
 for piece:Dictionary in stroke:
  piece.start=cursor
  cursor+=piece.a.distance_to(piece.b)
  output.append(piece)

func emit_piece(stroke:Array,piece:Dictionary,a:Vector2,b:Vector2):
 if a.distance_squared_to(b)>.00001:
  stroke.append({"id":piece.id,"index":piece.index,"freight":piece.freight,"a":a,"b":b,"run":piece.run,"closed":piece.closed})

func piece_normal(piece:Dictionary)->Vector2:
 return (piece.b-piece.a).normalized().orthogonal()

func offset_join(previous:Dictionary,next:Dictionary)->Vector2:
 var n:=piece_normal(previous);var m:=piece_normal(next)
 var vertex:Vector2=(previous.b+next.a)*.5
 var offset:float=(previous.offset+next.offset)*.5
 var normal:Vector2=(n+m).normalized()
 # Keep miters bounded at acute bends. In the ordinary equal-offset case,
 # the same vertex lies on both parallel supports, including on curved track.
 return vertex+normal*offset/maxf(.55,normal.dot(n))

func trim_local_loops(stroke:Array,closed:bool):
 # A large inside offset can double back on a tight bend. Clip only local
 # loops; distant/at-grade crossings in the authoritative itinerary stay.
 var i:=0
 while i<stroke.size():
  var first:Dictionary=stroke[i]
  var distance:=0.0
  var j:=i+2
  while j<(i+stroke.size()-1 if closed else stroke.size()):
   var middle:Dictionary=stroke[(j-1)%stroke.size()]
   distance+=middle.a.distance_to(middle.b)
   if distance>2.0*CORRIDOR_SPACING:break
   var k:=j%stroke.size()
   var last:Dictionary=stroke[k]
   var hit:Variant=Geometry2D.segment_intersects_segment(first.a,first.b,last.a,last.b)
   if hit!=null and first.b.distance_to(hit)>.01 and last.a.distance_to(hit)>.01:
    first.b=hit;last.a=hit
    if k>i:
     for index in range(k-1,i,-1):stroke.remove_at(index)
    else:
     stroke.resize(i+1)
     for index in range(k):stroke.pop_front()
    break
   j+=1
  i+=1

func clip_freight_dashes(projected:Array)->Array:
 var strokes:Array=[]
 for piece:Dictionary in projected:
  if not piece.freight:
   strokes.append(piece)
   continue
  var length:float=piece.a.distance_to(piece.b)
  var dir:Vector2=(piece.b-piece.a)/length
  var d:float=-fposmod(piece.start,16.0)
  while d<length:
   if d+9>0:
    emit_piece(strokes,piece,piece.a+dir*maxf(d,0),piece.a+dir*minf(d+9,length))
   d+=16
 return strokes

func rebuild_arrows():
 arrow_primitives.clear()
 if mode=="bus":
  rebuild_bus_arrows()
  return
 for i in range(paths.size()):
  var piece:Dictionary=paths[i]
  var length:float=piece.a.distance_to(piece.b)
  var dir:Vector2=(piece.b-piece.a)/length
  var step:=fposmod(phase-piece.start,ARROW_SPACING)
  while step<length:
   var tip:Vector2=piece.a+dir*step
   var behind:=5.0-step
   var tail:=tip-dir*5.0
   # Measure 5px back along the same joined path so the arrow's direction
   # doesn't snap to an isolated short edge at a curve sample.
   var j:=i
   while behind>0 and j>0 and paths[j].start>0:
    j-=1
    var previous:Dictionary=paths[j]
    var span:float=previous.a.distance_to(previous.b)
    if behind<=span:
     tail=previous.b.lerp(previous.a,behind/span)
     break
    behind-=span
   var heading:=(tip-tail).normalized()
   if heading==Vector2.ZERO:heading=dir
   tail=tip-heading*5.0
   var side:=heading.orthogonal()*3.0
   arrow_primitives.append({"id":piece.id,"index":piece.index,"points":PackedVector2Array([tail+side,tip,tail-side])})
   step+=ARROW_SPACING

func rebuild_bus_arrows():
 var bins:Dictionary={}
 for i in range(paths.size()):
  var piece:Dictionary=paths[i]
  if piece.section<0 or piece.arrow_side<.5:continue
  var length:float=piece.a.distance_to(piece.b)
  var direction:Vector2=(piece.b-piece.a)/length
  var tail:=direction*BUS_ARROW_LENGTH
  var side:=direction.orthogonal()*float(piece.arrow_side)
  # Don't extrapolate wings off the pavement at the start of a bend. Stop
  # boundaries on a straight can share the preceding support without a gap.
  var lookback:=0.0
  if i>0:
   var previous:Dictionary=paths[i-1]
   if previous.id==piece.id and previous.section==piece.section and previous.b.distance_to(piece.a)<.01 and (previous.b-previous.a).normalized().dot(direction)>.9999:
    lookback=previous.a.distance_to(previous.b)
  var step:=fposmod(phase+piece.id*11.0-piece.start,BUS_ARROW_SPACING)
  while step<length:
   var tip:Vector2=piece.a+direction*step
   var supported:=step+lookback>=BUS_ARROW_LENGTH
   step+=BUS_ARROW_SPACING
   if not supported or bus_arrow_blocked(tip,bins):continue
   arrow_primitives.append({"id":piece.id,"index":piece.index,"points":PackedVector2Array([tip-tail+side,tip,tip-tail-side])})

func bus_arrow_blocked(tip:Vector2,bins:Dictionary)->bool:
 for center:Vector2 in bus_junction_centers:
  if center.distance_squared_to(tip)<144.0:return true
 var bin:=Vector2i((tip/BUS_ARROW_LENGTH).floor())
 for x in range(-1,2):
  for y in range(-1,2):
   for neighbor:Vector2 in bins.get(bin+Vector2i(x,y),[]):
    if neighbor.distance_squared_to(tip)<BUS_ARROW_LENGTH*BUS_ARROW_LENGTH:return true
 if not bins.has(bin):bins[bin]=[]
 bins[bin].append(tip)
 return false

func pick(p:Vector2)->Dictionary:
 var hit:Dictionary={}
 var best:=8.0*8.0
 for dot:Dictionary in dots:
  var d:float=p.distance_squared_to(dot.p)
  if d<best:hit=dot;best=d
 if not hit.is_empty():return {"id":hit.id,"index":hit.index,"stop":true}
 best=8.0*8.0
 for piece:Dictionary in stroke_primitives:
  var d:=p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p,piece.a,piece.b))
  if d<best:hit=piece;best=d
 for arrow:Dictionary in arrow_primitives:
  for i in range(2):
   var d:=p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p,arrow.points[i],arrow.points[i+1]))
   if d<best:hit=arrow;best=d
 if hit.is_empty():return {}
 return {"id":hit.id,"index":hit.index,"stop":false}

func line_at(id:int)->Dictionary:
 for line:Dictionary in game.city.transit_lines:
  if line.id==id:return line
 return {}

func begin_drag(p:Vector2):
 dragged=pick(p)
 if dragged.is_empty():return
 var line:=line_at(dragged.id)
 if line.is_empty():cancel_drag();return
 dragged.from=p;dragged.stops=line.stops.duplicate();dragged.city=game.city.get_instance_id()
 if dragged.stop:
  dragged.station_origin=stations[dragged.stops[dragged.index]]
 pointer=p

func cancel_drag():
 dragged.clear();preview_paths.clear()

func candidate(p:Vector2)->Array:
 if dragged.is_empty() or not get_viewport_rect().has_point(p) or p.distance_to(dragged.from)<=DRAG_MOTION_THRESHOLD:return []
 var stops:Array=dragged.stops.duplicate()
 var station:=station_at(p)
 if station in stops:return []
 if dragged.stop:
  if station<0:
   if p.distance_to(dragged.station_origin)<=EMPTY_DROP_RADIUS:return []
   stops.remove_at(dragged.index)
  else:stops[dragged.index]=station
 elif station>=0:stops.insert(dragged.index+1,station)
 else:return []
 return stops

func move_drag(p:Vector2):
 pointer=p
 var stops:=candidate(p)
 if stops==dragged.get("preview",[]):return
 dragged.preview=stops
 preview_paths.clear()
 if stops.size()>=2:
  var line:=line_at(dragged.id).duplicate()
  if not line.is_empty():
   line.stops=stops
   line.erase("turnback");line.erase("terminal_ports")
   if line.kind in ["rail","metro"]:line.allow_turnback=true
   preview_paths=preview_plan(line)

func preview_plan(line:Dictionary)->Array:
 return plan_paths(line,bus_network,hosts)

func drop(p:Vector2,over_gui:bool):
 if dragged.is_empty():return
 var stops:=[] if over_gui else candidate(p)
 var id:int=dragged.id
 var line:=line_at(id)
 var current:bool=game.city.get_instance_id()==dragged.city and line.get("stops",[])==dragged.stops
 cancel_drag()
 if current and not stops.is_empty():commit_stops(id,stops)

func right_click(p:Vector2)->bool:
 var hit:=pick(p)
 if hit.is_empty():return false
 if hit.stop:
  var line:=line_at(hit.id)
  if not line.is_empty() and hit.index<line.stops.size():
   var stops:Array=line.stops.duplicate();stops.remove_at(hit.index)
   commit_stops(hit.id,stops)
 else:request_delete(hit.id)
 return true

func commit_stops(id:int,stops:Array):
 if stops.size()<2:request_delete(id)
 else:game.edit_transit_line(id,stops)

func build_list():
 clear_children(rows);clear_children(actions);create_buttons.clear();hovered_id=-1
 var button_face:StyleBoxFlat=game.style(LIST_PAPER)
 for line:Dictionary in lines:
  var id:int=line.id
  var row:=HBoxContainer.new();row.custom_minimum_size.y=44;rows.add_child(row)
  var swatch:=Panel.new();swatch.custom_minimum_size=Vector2(16,16);swatch.size_flags_vertical=Control.SIZE_SHRINK_CENTER
  var disc:=StyleBoxFlat.new();disc.bg_color=colors[id];disc.set_corner_radius_all(8)
  swatch.add_theme_stylebox_override("panel",disc)
  swatch.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(swatch)
  var title:=game.label("%s %d"%[NAMES[line.kind],id],20) as Label
  title.add_theme_color_override("font_color",INK)
  title.mouse_filter=Control.MOUSE_FILTER_IGNORE;title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(title)
  var x:=Button.new();x.name="DeleteRoute";x.icon=delete_icon;x.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
  style_list_button(x,button_face)
  x.expand_icon=true;x.add_theme_constant_override("icon_max_width",12)
  x.custom_minimum_size=Vector2(44,36);x.tooltip_text="노선 삭제";row.add_child(x)
  x.pressed.connect(request_delete.bind(id))
  row.mouse_entered.connect(set_hover.bind(id));row.mouse_exited.connect(clear_hover.bind(id))
  x.mouse_entered.connect(set_hover.bind(id));x.mouse_exited.connect(clear_hover.bind(id))
 for kind:String in ([mode,"freight"] if mode=="rail" else [mode]):
  var button:=Button.new();button.text="새 화물 노선 추가" if kind=="freight" else "새 노선 추가"
  style_list_button(button,button_face)
  button.custom_minimum_size.y=40;button.toggle_mode=true;actions.add_child(button)
  button.pressed.connect(start_creation.bind(kind))
  create_buttons[kind]=button
 layout_list()
 sync_creation()

func style_list_button(button:Button,face:StyleBoxFlat):
 button.add_theme_stylebox_override("normal",face)
 for color_key in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
  button.add_theme_color_override(color_key,INK)

func layout_list():
 if not visible:return
 var column:VBoxContainer=scroll.get_parent()
 var chrome:=panel.get_theme_stylebox("panel").get_minimum_size().y+column.get_theme_constant("separation")
 var max_height:float=floorf(game.transport_tabs.get_global_rect().position.y-panel.position.y-actions.get_combined_minimum_size().y-chrome-8)
 scroll.visible=not lines.is_empty()
 var full_height:=ceilf(rows.get_combined_minimum_size().y+scroll.get_theme_stylebox("panel").get_minimum_size().y)
 scroll.custom_minimum_size.y=clampf(max_height,0,full_height) if scroll.visible else 0.0
 panel.reset_size()

func set_hover(id:int):hovered_id=id
func clear_hover(id:int):
 if hovered_id==id:hovered_id=-1

signal delete_requested(id:int)
func request_delete(id:int):
 delete_requested.emit(id)

func start_creation(kind:String):
 cancel_drag()
 var tool=game.transit_line_tool
 var was_active:bool=tool.kind==kind
 tool.cancel()
 if not was_active:tool.kind=kind
 sync_creation()

func sync_creation():
 var tool=game.transit_line_tool
 for kind in create_buttons:create_buttons[kind].set_pressed_no_signal(tool.kind==kind)
 creation_paths.clear()
 if tool.stops.size()>=2:
  creation_paths=preview_plan({"id":-1,"kind":tool.kind,"stops":tool.stops,"allow_turnback":tool.kind in ["rail","metro"]})

func _process(delta:float):
 if signature==null:synchronize()
 var key:=[game.origin,game.map_zoom]
 if camera_key!=key:
  camera_key=key;project_paths()
 phase=fposmod(phase+delta*56.0,BUS_ARROW_SPACING if mode=="bus" else ARROW_SPACING)
 rebuild_arrows()
 queue_redraw()

func opacity(id:int)->float:
 return 1.0 if hovered_id<0 or hovered_id==id else .3

func projected_preview(source:Array)->Array:
 return project_bus_paths(source) if mode=="bus" else clip_freight_dashes(project_runs(source))

func _draw():
 if not visible:return
 draw_rect(Rect2(Vector2.ZERO,size),Color(.03,.055,.08,.55))
 for piece:Dictionary in stroke_primitives:
  var tint:Color=colors[piece.id];tint.a=opacity(piece.id)
  draw_line(piece.a,piece.b,tint,piece.get("width",STROKE_WIDTH),true)
 for arrow:Dictionary in arrow_primitives:
  draw_polyline(arrow.points,Color(INK,opacity(arrow.id)),2,true)
 var new_color:=next_color() if not game.transit_line_tool.stops.is_empty() else Color.TRANSPARENT
 for piece:Dictionary in projected_preview(creation_paths):draw_line(piece.a,piece.b,new_color,minf(3,piece.get("width",STROKE_WIDTH)),true)
 for id in stations:draw_arc(stations[id],station_radii.get(id,8.0),0,TAU,24,INK,2,true)
 for dot:Dictionary in dots:
  var tint:Color=colors[dot.id];tint.a=opacity(dot.id)
  draw_circle(dot.p,6,tint,true,-1,true)
 if not dragged.is_empty() and get_viewport_rect().has_point(pointer) and pointer.distance_to(dragged.from)>DRAG_MOTION_THRESHOLD:
  var tint:Color=colors.get(dragged.id,ACCENT)
  for piece:Dictionary in projected_preview(preview_paths):draw_line(piece.a,piece.b,tint,minf(3,piece.get("width",STROKE_WIDTH)),true)
  var target:=station_at(pointer)
  var position:Vector2=stations.get(target,pointer)
  if target>=0:draw_arc(position,16,0,TAU,24,ACCENT,2,true)
  draw_circle(position,5,tint,true,-1,true)
 for id in game.transit_line_tool.stops:
  if stations.has(id):draw_circle(stations[id],6,new_color,true,-1,true)
