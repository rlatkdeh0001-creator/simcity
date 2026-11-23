extends "res://tests/test_transport_tabs.gd"

const BusFixture=preload("res://tests/test_scheduled_buses.gd")
const RailFixture=preload("res://tests/transit_operations_fixture.gd")

func run():
 root.size=Vector2i(1280,720)
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 game.paused=true
 game.city.simulation.shutdown()
 game.city=BusFixture.fixture(4)
 var city=game.city
 var ids:Array=city.public_facilities.lots.map(func(lot):return lot.id)
 var result:Dictionary=city.create_transit_line("bus",ids)
 check(result.ok,"fixture creates a real bus line")
 game.select_category("transport")
 await process_frame
 await process_frame
 click(game.drawer_box.get_node("Tool_transit_line"))
 await process_frame
 var overlay=game.get("route_overlay")
 check(overlay!=null and overlay.visible,"route card opens the real overlay")
 if overlay!=null:
  check(overlay.panel.size.x==300 and overlay.rows.get_child_count()==1,"C list has a 300px width and the active mode's line")
  check(overlay.stations.size()==2 and overlay.paths.size()>4,"station rings and real returning road geometry")
  var report:Dictionary=city.create_transit_line("bus",ids)
  await process_frame
  await process_frame
  check(overlay.colors[result.line.id]!=overlay.colors[report.line.id],"uses an unused palette color before reuse")
  check_shared_corridor(overlay,result.line.id,report.line.id)
  var row:Control=overlay.rows.get_child(0)
  var hover:=InputEventMouseMotion.new()
  hover.position=row.get_global_rect().get_center()
  root.push_input(hover,true)
  check(row.get_child(1).get_theme_font_size("font_size")==20 and overlay.opacity(result.line.id)==1 and overlay.opacity(report.line.id)<1,"real list hover emphasizes only its route; 20px names")
  for i in range(10):city.create_transit_line("bus",ids)
  await process_frame
  await process_frame
  check(overlay.scroll.get_v_scroll_bar().visible and overlay.panel.get_global_rect().end.y<=game.transport_tabs.get_global_rect().position.y,"long C list scrolls without touching the tray: %s %s %s"%[overlay.scroll.get_v_scroll_bar().visible,overlay.panel.get_global_rect(),game.transport_tabs.get_global_rect()])
  click(overlay.create_buttons["bus"])
  check(game.transit_line_tool.kind=="bus" and game.transit_line_tool.stops.is_empty(),"C button starts creation without leaking a map click")
  game.select_transport_tab(1)
  check(not overlay.visible and not overlay.is_processing() and overlay.paths.is_empty(),"closed overlay has no process and drops draw geometry")
  game.city=RailFixture.rail_city("metro")
  ids=game.city.public_facilities.lots.map(func(lot):return lot.id)
  check(game.city.create_transit_line("metro",ids).ok,"fixture creates a real metro line")
  await process_frame
  await process_frame
  click(game.drawer_box.get_node("Tool_transit_line"))
  await process_frame
  check(game.transit_view.underground and overlay.visible and overlay.stations.size()==2,"metro overlay opens over underground station positions")
  var lot:Dictionary=game.city.public_facilities.lots[0]
  var p:Vector2=(lot.internal_points[0]+lot.internal_points[-1])/2
  check(overlay.stations[lot.id].is_equal_approx(game.origin+game.transit_view.project_point(p,-12.7)*game.map_zoom),"metro rings use the drawn platform height")
 print("Route overlay: %d passed, %d failed"%[checks-failures,failures])
 quit(1 if failures else 0)

func check_shared_corridor(overlay,first:int,second:int):
 var a_paths:Array=overlay.paths.filter(func(p):return p.id==first)
 var b_paths:Array=overlay.paths.filter(func(p):return p.id==second)
 check(a_paths.size()==b_paths.size() and not a_paths.is_empty() and not a_paths.any(func(a):
  return b_paths.any(func(b):return a.a.is_equal_approx(b.a) and a.b.is_equal_approx(b.b))
 ),"two real bus lines sharing the full corridor have no coincident draw pieces")
 # Isolate a partial, reversed overlap as rail plans need not segment the track identically.
 var original:Array=overlay.world_paths.duplicate()
 var a:=Vector3(100,100,0);var b:=Vector3(160,100,0)
 var mid:=a.lerp(b,.5)
 overlay.world_paths=[
  {"id":first,"index":0,"freight":false,"a":a,"b":b},
  {"id":first,"index":1,"freight":false,"a":b,"b":a},
  {"id":second,"index":0,"freight":true,"a":mid,"b":b},
  {"id":second,"index":1,"freight":true,"a":b,"b":mid},
 ]
 overlay.project_paths()
 var screen_a:Vector2=overlay.project(a);var screen_b:Vector2=overlay.project(b)
 var normal:Vector2=(screen_b-screen_a).normalized().orthogonal()
 var centers:Dictionary={}
 var owned:=true
 for p:Dictionary in overlay.paths:
  var point:Vector2=p.a.lerp(p.b,.5)
  var hit:Dictionary=overlay.pick(point)
  owned=owned and hit.get("id",-1)==p.id and hit.get("index",-1)==p.index and not hit.get("stop",true)
  if not centers.has(p.id):centers[p.id]=[]
  centers[p.id].append((point-screen_a).dot(normal))
 check(owned,"drawn path centers pick their exact line and direction segment on shared rail/freight")
 check(is_equal_approx(centers[first][0]-centers[first][1],12.0) and is_equal_approx(centers[second][0]-centers[second][1],12.0),"each direction stays 6px from its route center")
 check(absf(centers[first][0]-centers[second][0])>=20.0,"partially overlapping bidirectional route pairs have separate centers")
 var before:Array=overlay.paths.duplicate(true)
 overlay.world_paths.reverse();overlay.project_paths()
 check(before.all(func(p):return overlay.paths.any(func(q):return p.id==q.id and p.index==q.index and p.a==q.a and p.b==q.b)),"corridor positions are deterministic under input reordering")
 overlay.world_paths=original;overlay.project_paths()
