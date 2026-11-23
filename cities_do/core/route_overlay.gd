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
var observed_city:WeakRef
var signature:Variant
var camera_key:Variant

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
 game.transit_line_tool.overlay_active=true
 show()
 set_process(true)
 observe_city()
 synchronize()

func close():
 game.transit_line_tool.overlay_active=false
 if observed_city!=null:
  var previous=observed_city.get_ref()
  if previous!=null:previous.transit_changed.disconnect(invalidate)
  observed_city=null
 hide()
 set_process(false)
 mode="";hovered_id=-1;phase=0.0;signature=null;camera_key=null
 stations.clear();station_world.clear();paths.clear();world_paths.clear();lines.clear();colors.clear()
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
 var rails:Dictionary={}
 for route:Dictionary in city.transit_routes:rails[route.id]=route
 for lot:Dictionary in city.public_facilities.lots:
  if lot.public_asset_id!=STATION[mode]:continue
  var p:Vector2=lot.position
  var height:=0.0
  if mode!="bus":
   var points:PackedVector2Array=lot.internal_points
   p=(points[0]+points[-1])/2
   height=world_point(p,rails.get(lot.get("internal_route_id",-1),{}),mode).z
  station_world[lot.id]=Vector3(p.x,p.y,height)
 var network
 if mode=="bus" and not lines.is_empty():
  network=Bus.new();network.build_city(city)
 for line:Dictionary in lines:world_paths.append_array(plan_paths(line,network,rails))
 if rebuild_list:build_list()
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
   var road:Dictionary=game.city.roads[lane.road] if lane.has("road") and lane.road>=0 else {}
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

func project_paths():
 stations.clear();paths.clear()
 for id in station_world:stations[id]=project(station_world[id])
 var accumulated:Dictionary={}
 for piece:Dictionary in world_paths:
  var a:=project(piece.a);var b:=project(piece.b)
  if a.distance_squared_to(b)<.00001:continue
  var side:=(b-a).normalized().orthogonal()*6.0
  var cursor:float=accumulated.get(piece.id,0.0)
  paths.append({"id":piece.id,"index":piece.index,"freight":piece.freight,"a":a+side,"b":b+side,"start":cursor})
  accumulated[piece.id]=cursor+a.distance_to(b)

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
 var tool=game.transit_line_tool
 var was_active:bool=tool.kind==kind
 tool.cancel()
 game.mode="route_overlay" if was_active else ("freight_line" if kind=="freight" else "transit_line")
 if not was_active:tool.kind=kind
 sync_creation()

func sync_creation():
 for kind in create_buttons:create_buttons[kind].set_pressed_no_signal(game.transit_line_tool.kind==kind)

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
 for point:Vector2 in stations.values():draw_arc(point,8,0,TAU,24,INK,2,true)
 for line:Dictionary in lines:
  for id in line.stops:
   if not stations.has(id):continue
   var tint:Color=colors[line.id];tint.a=opacity(line.id)
   draw_circle(stations[id],6,tint,true,-1,true)
 for id in game.transit_line_tool.stops:
  if stations.has(id):draw_circle(stations[id],6,next_color(),true,-1,true)
