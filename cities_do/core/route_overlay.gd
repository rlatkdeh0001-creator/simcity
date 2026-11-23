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
const ACCENT:=Color("36b7ff")
const DIRECTION_OFFSET:=6.0
const CORRIDOR_SPACING:=24.0
const CORRIDOR_EPSILON:=.0001
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
var world_paths:Array=[]
var hosts:Dictionary={}
var bus_network
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
 var box:StyleBoxFlat=game.style(Color("142b37"),Color("38515e"))
 for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:box.set_content_margin(side,8)
 panel.add_theme_stylebox_override("panel",box)
 add_child(panel)
 var column:=VBoxContainer.new();panel.add_child(column)
 scroll=ScrollContainer.new();column.add_child(scroll)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 rows=VBoxContainer.new();scroll.add_child(rows)
 rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 actions=VBoxContainer.new();column.add_child(actions)
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
 stations.clear();station_world.clear();paths.clear();world_paths.clear();lines.clear();colors.clear();dots.clear()
 hosts.clear();bus_network=null;creation_paths.clear()
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
 station_world.clear();world_paths.clear()
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
 for line:Dictionary in lines:world_paths.append_array(plan_paths(line,bus_network,hosts))
 if rebuild_list:build_list()
 else:sync_creation()
 camera_key=null
 project_paths()

func next_color()->Color:
 for color in COLORS:
  if color not in colors.values():return color
 return COLORS[colors.size()%COLORS.size()]

func plan_paths(line:Dictionary,network,rails:Dictionary)->Array:
 var result:Array=[]
 if line.kind=="bus":
  var plan:Dictionary=network.line_plan(line.stops)
  if not plan.ok:return result
  var stop_index:=0
  for i in range(plan.route.size()):
   var lane:Dictionary=network.lanes[plan.route[i]]
   var points:PackedVector2Array=network.points_of(lane)
   var road_index:int=lane.get("road",-1)
   if road_index<0 and lane.has("from"):road_index=network.lanes[lane.from].road
   var road:Dictionary=game.city.roads[road_index] if road_index>=0 else {}
   var cursor:=0.0
   while stop_index<plan.stops.size() and plan.stops[stop_index].route_index==i:
    var stop:Dictionary=plan.stops[stop_index]
    add_bus_piece(result,line,(stop_index-1+line.stops.size())%line.stops.size(),points,road,cursor,float(stop.progress))
    cursor=float(stop.progress);stop_index+=1
   add_bus_piece(result,line,stop_index-1,points,road,cursor,float(lane.length))
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
    result.append({"id":line.id,"index":stop_index,"freight":line.kind=="freight","a":world_point(a,route,line.kind),"b":world_point(b,route,line.kind)})
 return result

func add_bus_piece(result:Array,line:Dictionary,index:int,points:PackedVector2Array,road:Dictionary,first:float,last:float):
 if last-first<.001:return
 var sliced:=Paths.slice(points,first,last)
 # Lane bake points can be every 20cm. Merge only collinear runs with the same lift.
 var a:=world_point(sliced[0]/4,road,"bus")
 var b:=a
 for i in range(1,sliced.size()):
  var c:=world_point(sliced[i]/4,road,"bus")
  if a!=b and (b-a).normalized().dot((c-b).normalized())<.9999:
   result.append({"id":line.id,"index":index,"freight":false,"a":a,"b":b})
   a=b
  b=c
 if a!=b:result.append({"id":line.id,"index":index,"freight":false,"a":a,"b":b})

func world_point(p:Vector2,host:Dictionary,kind:String)->Vector3:
 return Vector3(p.x,p.y,-12.7 if kind=="metro" else (0.0 if host.is_empty() else Height.height_at(host,p)))

func station_at(p:Vector2)->int:
 var id:=-1
 var best:=18.0*18.0
 for candidate:int in stations:
  var d:float=p.distance_squared_to(stations[candidate])
  if d<best:id=candidate;best=d
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
  for i:int in group:lanes[i]=ids[world_paths[i].id]
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
 var accumulated:Dictionary={}
 var lanes:=corridor_lanes()
 for i in range(world_paths.size()):
  var piece:Dictionary=world_paths[i]
  var a:=project(piece.a);var b:=project(piece.b)
  if a.distance_squared_to(b)<.00001:continue
  var span:Vector3=piece.b-piece.a
  # The corridor center must move the same way for both directions.
  var axis:=span.x if absf(span.x)>CORRIDOR_EPSILON else (span.y if absf(span.y)>CORRIDOR_EPSILON else span.z)
  var side:=(b-a).normalized().orthogonal()*(DIRECTION_OFFSET+signf(axis)*lanes[i]*CORRIDOR_SPACING)
  var cursor:float=accumulated.get(piece.id,0.0)
  paths.append({"id":piece.id,"index":piece.index,"freight":piece.freight,"a":a+side,"b":b+side,"start":cursor})
  accumulated[piece.id]=cursor+a.distance_to(b)
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

func pick(p:Vector2)->Dictionary:
 var hit:Dictionary={}
 var best:=8.0*8.0
 for dot:Dictionary in dots:
  var d:float=p.distance_squared_to(dot.p)
  if d<best:hit=dot;best=d
 if not hit.is_empty():return {"id":hit.id,"index":hit.index,"stop":true}
 best=8.0*8.0
 for piece:Dictionary in paths:
  var d:=p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p,piece.a,piece.b))
  if d<best:hit=piece;best=d
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
 for line:Dictionary in lines:
  var id:int=line.id
  var row:=HBoxContainer.new();row.custom_minimum_size.y=44;rows.add_child(row)
  var swatch:=ColorRect.new();swatch.custom_minimum_size=Vector2(16,16);swatch.size_flags_vertical=Control.SIZE_SHRINK_CENTER
  swatch.color=colors[id];swatch.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(swatch)
  var title:=game.label("%s %d"%[NAMES[line.kind],id],20) as Label
  title.mouse_filter=Control.MOUSE_FILTER_IGNORE;title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(title)
  var x:=Button.new();x.text="×";x.custom_minimum_size=Vector2(36,36);row.add_child(x)
  x.pressed.connect(request_delete.bind(id))
  row.mouse_entered.connect(set_hover.bind(id));row.mouse_exited.connect(clear_hover.bind(id))
  x.mouse_entered.connect(set_hover.bind(id));x.mouse_exited.connect(clear_hover.bind(id))
 for kind:String in ([mode,"freight"] if mode=="rail" else [mode]):
  var button:=Button.new();button.text="새 화물 노선 추가" if kind=="freight" else "새 노선 추가"
  button.custom_minimum_size.y=40;button.toggle_mode=true;actions.add_child(button)
  button.pressed.connect(start_creation.bind(kind))
  create_buttons[kind]=button
 layout_list()
 sync_creation()

func layout_list():
 if not visible:return
 var max_height:float=maxf(44,game.transport_tabs.get_global_rect().position.y-panel.position.y-actions.get_combined_minimum_size().y-32)
 scroll.visible=not lines.is_empty()
 scroll.custom_minimum_size.y=minf(max_height,lines.size()*48-4) if scroll.visible else 0.0
 panel.size=Vector2(300,0)

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
 phase=fposmod(phase+delta*56.0,34.0)
 queue_redraw()

func opacity(id:int)->float:
 return 1.0 if hovered_id<0 or hovered_id==id else .3

func _draw():
 if not visible:return
 draw_rect(Rect2(Vector2.ZERO,size),Color(.03,.055,.08,.55))
 for piece:Dictionary in paths:
  var tint:Color=colors[piece.id];tint.a=opacity(piece.id)
  var a:Vector2=piece.a;var b:Vector2=piece.b
  var length:=a.distance_to(b);var dir:=(b-a)/length
  if piece.freight:
   var d:float=-fposmod(piece.start,16.0)
   while d<length:
    if d+9>0:draw_line(a+dir*maxf(d,0),a+dir*minf(d+9,length),tint,4,true)
    d+=16
  else:draw_line(a,b,tint,4,true)
  var step:=fposmod(phase-piece.start,34.0)
  while step<length:
   var tip:=a+dir*step;var tail:=tip-dir*5;var side:=dir.orthogonal()*3
   var arrow:=Color(INK,tint.a)
   draw_polyline(PackedVector2Array([tail+side,tip,tail-side]),arrow,2,true)
   step+=34
 var new_color:=next_color() if not game.transit_line_tool.stops.is_empty() else Color.TRANSPARENT
 for piece:Dictionary in creation_paths:draw_line(project(piece.a),project(piece.b),new_color,3,true)
 for point:Vector2 in stations.values():draw_arc(point,8,0,TAU,24,INK,2,true)
 for dot:Dictionary in dots:
  var tint:Color=colors[dot.id];tint.a=opacity(dot.id)
  draw_circle(dot.p,6,tint,true,-1,true)
 if not dragged.is_empty() and get_viewport_rect().has_point(pointer) and pointer.distance_to(dragged.from)>DRAG_MOTION_THRESHOLD:
  var tint:Color=colors.get(dragged.id,ACCENT)
  for piece:Dictionary in preview_paths:draw_line(project(piece.a),project(piece.b),tint,3,true)
  var target:=station_at(pointer)
  var position:Vector2=stations.get(target,pointer)
  if target>=0:draw_arc(position,16,0,TAU,24,ACCENT,2,true)
  draw_circle(position,5,tint,true,-1,true)
 for id in game.transit_line_tool.stops:
  if stations.has(id):draw_circle(stations[id],6,new_color,true,-1,true)
