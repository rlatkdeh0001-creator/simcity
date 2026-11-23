extends "res://tests/test_transport_tabs.gd"

const BusFixture=preload("res://tests/test_scheduled_buses.gd")
const RailFixture=preload("res://tests/transit_operations_fixture.gd")
const RowFixture=preload("res://tests/test_review_fix_dialog.gd")
const Ops=preload("res://core/transit_operations.gd")
var game
var overlay

func settle():
 await process_frame
 await process_frame

func mouse(p:Vector2,button:=0,pressed:=false):
 var evt:InputEventMouse
 if button==0:evt=InputEventMouseMotion.new()
 else:
  var b:=InputEventMouseButton.new();b.button_index=button;b.pressed=pressed;evt=b
 evt.position=p;evt.global_position=p;root.push_input(evt,true)

func tap(p:Vector2,button:=MOUSE_BUTTON_LEFT):
 mouse(p);mouse(p,button,true);mouse(p,button,false)

func drag(a:Vector2,b:Vector2):
 mouse(a);mouse(a,MOUSE_BUTTON_LEFT,true);mouse(b);mouse(b,MOUSE_BUTTON_LEFT,false)

func key(code:int):
 for pressed in [true,false]:
  var evt:=InputEventKey.new();evt.keycode=code;evt.pressed=pressed;root.push_input(evt,true)

func bus_city():
 var city=BusFixture.fixture(4)
 var curb:float=city.RoadProfile.asphalt_width(city.roads[0])/2
 for x:float in [52,70]:assert(city.public_facilities.place("bus-stop-01",Vector2(x,20+curb)).ok)
 return city


func ids()->Array:return game.city.public_facilities.lots.map(func(lot):return lot.id)

func setup(city,tab:int,center:Vector2,zoom:=.82):
 game.city=city
 game.map_zoom=zoom
 game.origin=Vector2(root.size.x*.54,root.size.y*.34)-game.transit_view.project_point(center)*game.map_zoom
 game.select_transport_tab(tab);game.refresh()
 await settle()
 overlay=game.route_overlay

func open_overlay():
 click(game.drawer_box.get_node("Tool_transit_line"));await settle()

func dot(line_id:int,index:int)->Vector2:
 for entry:Dictionary in overlay.dots:
  if entry.id==line_id and entry.index==index:return entry.p
 return Vector2.ZERO

func track(line_id:int,index:int)->Vector2:
 for piece:Dictionary in overlay.paths:
  if piece.id==line_id and piece.index==index and piece.a.distance_to(piece.b)>22:
   for t in [.5,.33,.67]:
    var p:Vector2=piece.a.lerp(piece.b,t)
    if overlay.station_at(p)<0 and overlay.pick(p).get("id",-1)==line_id:return p
 return Vector2.ZERO

func run():
 root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
 game.paused=true;game.city.simulation.shutdown()
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--route-review="):
   await review_fixture(arg.get_slice("=",1))
   return
 await setup(bus_city(),0,Vector2(50,45))
 await open_overlay()
 check(overlay.has_method("drop"),"overlay has owned drag editing")
 if overlay.has_method("drop"):
  await bus_edits()
  await metro_edits()
  await rail_edits()
 print("Route edit: %d passed, %d failed"%[checks-failures,failures])
 quit(1 if failures else 0)

func bus_edits():
 var city=game.city;var s:=ids()
 var a:Dictionary=city.create_transit_line("bus",[s[0],s[2],s[1]])
 var b:Dictionary=city.create_transit_line("bus",[s[0],s[1],s[3]])
 assert(a.ok and b.ok)
 await settle()
 var d:=dot(a.line.id,0)
 check(d!=Vector2.ZERO and d!=dot(b.line.id,0),"shared station supplies two separately selectable route dots")
 var other:Dictionary=city.transit_lines[1].duplicate(true)
 var center:Vector2=overlay.stations[s[0]]
 var offset:Vector2=(d-center).normalized()
 mouse(d);mouse(d,MOUSE_BUTTON_LEFT,true);mouse(center-offset*23)
 check(overlay.candidate(center-offset*23).is_empty(),"23px empty drop from original station is ignored despite offset dot")
 if not overlay.candidate(center-offset*23).is_empty():key(KEY_ESCAPE)
 mouse(center-offset*23,MOUSE_BUTTON_LEFT,false)
 check(city.transit_lines[0].stops==a.line.stops,"inside-radius release preserves route")

 drag(d,overlay.panel.get_global_rect().get_center())
 check(city.transit_lines[0].stops==a.line.stops and overlay.dragged.is_empty(),"release on the list neither edits nor sticks")
 drag(d,center+offset*25)
 check(city.transit_lines[0].stops==[s[2],s[1]] and city.transit_lines[1]==other and not game.route_warning_open(),"25px empty drop from original station removes only A's stop")
 await settle()
 # Zoom so this real destination is near the start, then drop within its snap ring.
 center=overlay.stations[s[2]]
 var zoom:float=game.map_zoom;var origin:Vector2=game.origin
 var scale:=24.0/center.distance_to(overlay.stations[s[3]])
 game.map_zoom*=scale;game.origin=center-(center-origin)*scale
 await settle()
 d=dot(a.line.id,0)
 var short_drop:Vector2=d.move_toward(overlay.stations[s[3]],20)
 check(d.distance_to(short_drop)>4 and d.distance_to(short_drop)<24 and overlay.station_at(short_drop)==s[3],"fixture offers a valid station in a short drag")
 drag(d,short_drop)
 check(city.transit_lines[0].stops==[s[3],s[1]] and city.transit_lines[1]==other,"short drop on B's station replaces A's stop and preserves B")
 game.map_zoom=zoom;game.origin=origin
 await settle()
 var stale:=dot(a.line.id,0)
 var before_drop:Dictionary=city.transit_lines[0].duplicate(true)
 mouse(stale);mouse(stale,MOUSE_BUTTON_LEFT,true);mouse(stale+Vector2(0,-90))
 check(not overlay.dragged.is_empty(),"viewport press actually starts the drag before focus loss")
 root.focus_exited.emit()
 check(overlay.dragged.is_empty() and overlay.preview_paths.is_empty(),"window focus exit clears captured drag and preview")
 mouse(stale+Vector2(0,-90),MOUSE_BUTTON_LEFT,false)
 check(not game.route_warning_open() and city.transit_lines[0]==before_drop,"late release after focus loss does not edit")
 if game.route_warning_open():key(KEY_ESCAPE)
 drag(stale,Vector2(root.get_visible_rect().end.x+20,stale.y))
 check(overlay.dragged.is_empty() and not game.route_warning_open() and city.transit_lines[0]==before_drop,"out-of-viewport release cancels without edit or confirmation")
 if game.route_warning_open():key(KEY_ESCAPE)
 var x:Button=overlay.rows.get_child(0).get_child(2)
 click(x)
 check(game.route_warning_open() and game.route_warning.message.text=="이 노선이 삭제됩니다!","actual X opens the line deletion confirmation")
 key(KEY_ESCAPE)
 check(not game.route_warning_open() and city.transit_lines.size()==2,"Escape cancels confirmation without deleting or closing overlay")
 tap(dot(a.line.id,0),MOUSE_BUTTON_RIGHT)
 check(game.route_warning_open(),"right click leaving one stop uses same deletion confirmation")
 key(KEY_ENTER);await settle()
 check(city.transit_lines.size()==1 and city.transit_lines[0]==other,"confirm removes only collapsed A")
 click(overlay.create_buttons.bus)
 tap(overlay.stations[s[0]]);tap(overlay.stations[s[2]]);tap(overlay.stations[s[0]])
 check(city.transit_lines.size()==2 and game.transit_line_tool.kind=="","C action creates by closing the first stop through viewport input")
 click(overlay.create_buttons.bus)
 key(KEY_ESCAPE)
 check(overlay.visible and game.transit_line_tool.kind=="","Escape first cancels creation")
 tap(Vector2(root.size.x-30,45),MOUSE_BUTTON_RIGHT)
 check(not overlay.visible and not overlay.is_processing() and overlay.paths.is_empty(),"empty right click closes and disables overlay")

func metro_edits():
 await setup(RailFixture.rail_city("metro"),1,Vector2(50,42))
 await open_overlay()
 var s:=ids()
 click(overlay.create_buttons.metro)
 var a:Vector2=overlay.stations[s[0]]
 check(overlay.station_at(a)==s[0] and overlay.station_at(a-Vector2(0,50))<0,"metro picks projected platform, not ground entrance")
 tap(a);tap(overlay.stations[s[1]]);tap(a)
 check(game.city.transit_lines.size()==1 and game.city.transit_lines[0].kind=="metro","metro creation reaches real model via underground picks")
 game.activate_tool("select")
 check(not overlay.visible and not game.transit_view.underground and game.mode=="select","other tool clears underground overlay and stale mode")

func rail_edits():
 var freight_city=RailFixture.rail_city()
 var freight_ids:Array=freight_city.public_facilities.lots.map(func(lot):return lot.id)
 var freight:Dictionary=freight_city.create_transit_line("freight",freight_ids)
 assert(freight.ok)
 await setup(freight_city,2,Vector2(57,42))
 await open_overlay()
 check(overlay.create_buttons.has("freight") and overlay.paths.any(func(p):return p.freight and p.id==freight.line.id),"train tab shows freight action and dashed path geometry")
 var row:=RowFixture.new()
 var built:Dictionary=row.row_city()
 row.free()
 await setup(built.city,2,Vector2(69,34))
 var city=game.city;var s:=ids()
 var make:Dictionary=city.create_transit_line("rail",[s[0],s[2]],{"dwell_seconds":1.0,"headway_seconds":20.0})
 assert(make.ok)
 var op:=Ops.new();op.advance(city,4)
 await open_overlay()
 var before:Dictionary=city.transit_state.trains[make.line.id].duplicate(true)
 check(before.distance>0,"train is moving before the edit")
 var p:=track(make.line.id,0)
 check(p!=Vector2.ZERO,"real drawn track offers an owned insertion segment")
 if p==Vector2.ZERO:return
 tap(p,MOUSE_BUTTON_RIGHT)
 check(game.route_warning_open() and game.route_warning.message.text=="이 노선이 삭제됩니다!","right click on line opens deletion modal")
 key(KEY_ESCAPE)
 check(overlay.station_at(overlay.stations[s[1]])==s[1] and not overlay.pick(overlay.stations[s[1]]).is_empty(),"destination station ring takes priority over a hit track")
 drag(p,overlay.stations[s[1]])
 check(game.route_warning_open() and game.route_warning.message.text=="수정사항이 있는 모든 열차가 초기화됩니다!","arrow insertion uses train reset guard")
 key(KEY_ESCAPE)
 check(city.transit_state.trains[make.line.id]==before and city.transit_lines[0].stops==make.line.stops,"cancel preserves moving consist and route")
 drag(p,overlay.stations[s[1]])
 if not game.route_warning_open():return
 key(KEY_ENTER)
 op.advance(city,Ops.STEP)
 var reset:Dictionary=city.transit_state.trains[make.line.id]
 check(city.transit_lines[0].stops==s and reset.distance==0 and reset.departures==before.departures,"confirm resets same moving train at line start")
 op.advance(city,24)
 check(city.transit_state.trains[make.line.id].distance>0,"confirmed train continues along its new line")

func review_fixture(which:String):
 match which:
  "tray":
   await setup(bus_city(),0,Vector2(50,45))
   var stops:=ids()
   assert(game.city.create_transit_line("bus",[stops[0],stops[2],stops[1]]).ok)
   assert(game.city.create_transit_line("bus",[stops[0],stops[1],stops[3]]).ok)
  "bus":
   var city=BusFixture.fixture(4)
   assert(city.add_road(PackedVector2Array([Vector2(10,50),Vector2(90,50)]),"local",true,4).ok)
   var curb:float=city.RoadProfile.asphalt_width(city.roads[0])/2
   var shared:Dictionary=city.public_facilities.place("bus-stop-01",Vector2(32,50+curb))
   var west_a:Dictionary=city.public_facilities.place("bus-stop-01",Vector2(66,50-curb))
   var west_b:Dictionary=city.public_facilities.place("bus-stop-01",Vector2(48,50-curb))
   assert(shared.ok and west_a.ok and west_b.ok)
   await setup(city,0,Vector2(50,50),.60)
   # Two actual services share an eastbound stop and use both carriageways.
   assert(city.create_transit_line("bus",[shared.record.id,west_a.record.id]).ok)
   assert(city.create_transit_line("bus",[shared.record.id,west_b.record.id,ids()[1]]).ok)
   await open_overlay()
  "metro","freight":
   var metro:=which=="metro"
   await setup(RailFixture.rail_city("metro" if metro else "rail"),1 if metro else 2,Vector2(54,42))
   assert(game.city.create_transit_line(which,ids()).ok)
   await open_overlay()
  "warning":
   var row:=RowFixture.new()
   var built:Dictionary=row.row_city()
   row.free()
   await setup(built.city,2,Vector2(69,34))
   var stops:=ids()
   var made:Dictionary=game.city.create_transit_line("rail",[stops[0],stops[2]],{"dwell_seconds":1.0})
   assert(made.ok)
   Ops.new().advance(game.city,4)
   game.refresh()
   await open_overlay()
   var from:=track(made.line.id,0)
   assert(from!=Vector2.ZERO)
   drag(from,overlay.stations[stops[1]])
   assert(game.route_warning_open())
  _:
   push_error("Unknown route review fixture: "+which);quit(1);return
 if which=="tray":
  for i in range(3):
   click(game.transport_tabs.get_child(i));await settle()
   var close:Button=game.drawer_box.get_child(-1)
   check(game.transport_tab==i and not game.drawer_scroll.get_h_scroll_bar().visible and game.drawer_scroll.get_global_rect().encloses(close.get_global_rect()),"review tray %d has its full chevron and no scrollbar"%i)
  click(game.transport_tabs.get_child(0));await settle()
 elif which=="bus":check_review_bus()
 elif which in ["metro","freight"]:
  check(overlay.visible and overlay.paths.size()>4 and overlay.paths.all(func(p):return p.freight==(which=="freight")),"review is showing the planned "+which+" overlay")
  if which=="freight":
   var dash_lengths:Array=overlay.stroke_primitives.map(func(p):return p.a.distance_to(p.b))
   check(not dash_lengths.is_empty() and dash_lengths.max()<=9.01 and overlay.stroke_primitives.size()>overlay.paths.size(),"freight review emits actual 9px dashed strokes")
 elif which=="warning":
  check(game.route_warning_open(),"review has the real train reset confirmation open")
 if failures>0:quit(1);return
 print("Route review ready: ",which," ",root.get_visible_rect().size)
 if "--fixture-check" in OS.get_cmdline_user_args():
  print("Route review checks: %d passed, %d failed"%[checks-failures,failures]);quit(1 if failures else 0);return
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-route-review="):
   await capture_review(which,arg.trim_prefix("--capture-route-review="))
   quit(1 if failures else 0)
   return

func check_review_bus():
 var lines:Array=game.city.transit_lines
 var network=overlay.bus_network
 var opposed_stretch:=true
 for line:Dictionary in lines:
  var plan:Dictionary=network.line_plan(line.stops)
  var metres:Dictionary={}
  for lane_id in plan.get("route",[]):
   var lane:Dictionary=network.lanes[lane_id]
   var road:int=lane.get("road",-1)
   if road<0 or lane.get("bus_pocket",false):continue
   if not metres.has(road):metres[road]={}
   metres[road][lane.direction]=metres[road].get(lane.direction,0.0)+lane.length
  opposed_stretch=opposed_stretch and metres.values().any(func(direction):return direction.get(-1,0.0)>80 and direction.get(1,0.0)>80)
 check(lines.size()==2 and opposed_stretch,"review fixture has actual opposing bus runs on a shared road stretch")
 check(lines.size()==2 and lines[0].stops[0] in lines[1].stops and dot(lines[0].id,0)!=dot(lines[1].id,0),"bus review has distinct dots at a real shared stop")
 var map_rect:=Rect2(0,0,root.get_visible_rect().size.x,game.transport_tabs.get_global_rect().position.y).grow(-8)
 var list_rect:Rect2=overlay.panel.get_global_rect().grow(8)
 check(overlay.paths.all(func(p):return map_rect.has_point(p.a) and map_rect.has_point(p.b) and not list_rect.has_point(p.a) and not list_rect.has_point(p.b)),"bus review frames the entire route clear of the HUD")
 var normal:Vector2=(overlay.project(Vector3(1,50,0))-overlay.project(Vector3(0,50,0))).normalized().orthogonal()
 for x in [30.0,43.0,57.0,71.0]:
  var center:Vector2=overlay.project(Vector3(x,50,0))
  var offsets:Array=[[],[]]
  var owns:=true
  for p:Dictionary in overlay.paths:
   var hit:Variant=Geometry2D.segment_intersects_segment(p.a,p.b,center-normal*64,center+normal*64)
   if hit==null:continue
   var picked:Dictionary=overlay.pick(hit)
   owns=owns and picked.get("id",-1)==p.id and picked.get("index",-1)==p.index
   offsets[0 if p.id==lines[0].id else 1].append((hit-center).dot(normal))
  for pair:Array in offsets:pair.sort()
  check(offsets[0].size()==2 and offsets[1].size()==2 and absf(offsets[0][1]-offsets[0][0]-12)<.5 and absf(offsets[1][1]-offsets[1][0]-12)<.5 and absf(offsets[1][0]-offsets[0][0])>=20 and owns,"four actual owned bus lanes on shared road at x=%s: %s"%[x,offsets])

func capture_review(which:String,directory:String):
 if which=="tray":
  for tab in range(3):
   click(game.transport_tabs.get_child(tab))
   await settle()
   if not await save_review(directory.path_join("tray-"+str(tab)+".png")):return
 else:
  await save_review(directory.path_join(which+".png"))

func save_review(path:String)->bool:
 for frame in range(120):
  await process_frame
  if not game.building_views.busy and game.building_views.queue.is_empty():break
 await RenderingServer.frame_post_draw
 var frame_image:=root.get_texture().get_image()
 if frame_image==null or frame_image.get_size()!=Vector2i(1920,1080):
  check(false,"capture needs a real 1920x1080 framebuffer")
  return false
 var saved:=frame_image.save_png(path)==OK
 check(saved,"saved "+path)
 if saved:print("Route review captured: ",path)
 return saved
