extends "res://tests/test_transport_tabs.gd"

const BusFixture=preload("res://tests/test_scheduled_buses.gd")
const RailFixture=preload("res://tests/transit_operations_fixture.gd")
const TrainRow=preload("res://tests/test_review_fix_dialog.gd")

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
  await check_short_list(overlay,1)
  check(overlay.stations.size()==2 and overlay.paths.size()>4,"station rings and real returning road geometry")
  check_loop(overlay,result.line.id,"bus")
  check_ink(overlay)
  var report:Dictionary=city.create_transit_line("bus",ids)
  await process_frame
  await process_frame
  check(overlay.colors[result.line.id]!=overlay.colors[report.line.id],"uses an unused palette color before reuse")
  await check_short_list(overlay,2)
  check_shared_corridor(overlay,result.line.id,report.line.id)
  check_loop(overlay,report.line.id,"shared bus")
  var row:Control=overlay.rows.get_child(0)
  var hover:=InputEventMouseMotion.new()
  hover.position=row.get_global_rect().get_center()
  root.push_input(hover,true)
  check(row.get_child(1).get_theme_font_size("font_size")==20 and overlay.opacity(result.line.id)==1 and overlay.opacity(report.line.id)<1,"real list hover emphasizes only its route; 20px names")
  for i in range(24):city.create_transit_line("bus",ids)
  for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
   root.size=resolution
   await process_frame
   await process_frame
   var bar:VScrollBar=overlay.scroll.get_v_scroll_bar()
   check(bar.visible and bar.max_value>bar.page and overlay.panel.get_global_rect().end.y<=game.transport_tabs.get_global_rect().position.y,"long C list scrolls without touching the tray at %s"%resolution)
   overlay.scroll.scroll_vertical=int(ceilf(bar.max_value))
   await process_frame
   await process_frame
   var last:Control=overlay.rows.get_child(-1)
   check(overlay.scroll.get_global_rect().grow(.01).encloses(last.get_global_rect()),"scroll reaches the final full row and X at %s"%resolution)
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
  check_loop(overlay,game.city.transit_lines[0].id,"curved metro")
  check_ink(overlay)
  await check_rail_gap(game,overlay)
  check_ink(overlay)
  check_reversed_corridor(overlay,1,2)
 print("Route overlay: %d passed, %d failed"%[checks-failures,failures])
 quit(1 if failures else 0)

func check_ink(overlay):
 var strokes:Array=overlay.stroke_primitives
 var arrows:Array=overlay.arrow_primitives
 check(not strokes.is_empty() and strokes==overlay.paths,"solid service strokes have no artificial dash gaps")
 var visible:=0
 var owned:=true
 for arrow:Dictionary in arrows:
  var wing:Vector2=arrow.points[0]
  if overlay.station_at(wing)>=0:continue
  var picked:Dictionary=overlay.pick(wing)
  owned=owned and picked.get("id",-1)==arrow.id and picked.get("index",-1)==arrow.index
  if wing.distance_to(arrow.points[1])>=4.0:visible+=1
 check(visible>0 and owned,"visible arrow wings pick their drawn route ID and stop interval")

func check_loop(overlay,id:int,kind:String):
 var pieces:Array=overlay.paths.filter(func(p):return p.id==id)
 var gap:=0.0
 var crossings:=0
 for i in range(pieces.size()):
  gap=maxf(gap,pieces[i].b.distance_to(pieces[(i+1)%pieces.size()].a))
  for j in range(i+2,pieces.size()):
   var p:Dictionary=pieces[i];var q:Dictionary=pieces[j]
   var hit:Variant=Geometry2D.segment_intersects_segment(p.a,p.b,q.a,q.b)
   if hit!=null and minf(hit.distance_to(p.a),hit.distance_to(p.b))>.25 and minf(hit.distance_to(q.a),hit.distance_to(q.b))>.25:crossings+=1
 check(pieces.size()>4 and gap<=2.0,"%s emitted loop continuity at most 2px (worst %.2fpx)"%[kind,gap])
 check(crossings==0,"%s has no proper X joins (%d crossings)"%[kind,crossings])

func check_rail_gap(game,overlay):
 var fixture:=TrainRow.new()
 var row:=fixture.row_city();fixture.free()
 if game.city.simulation!=null:game.city.simulation.shutdown()
 game.city=row.city
 var made:Dictionary=game.city.create_transit_line("rail",row.ids)
 check(made.ok,"two real opposed rail legs on physical double track")
 if not made.ok:return
 game.select_transport_tab(2)
 await process_frame
 await process_frame
 click(game.drawer_box.get_node("Tool_transit_line"))
 await process_frame
 var internal:PackedVector2Array=game.city.public_facilities.lots[1].internal_points
 var origin:Vector2=overlay.project(Vector3(internal[0].x,internal[0].y,0))
 var edge:Vector2=overlay.project(Vector3(internal[1].x,internal[1].y,0))-origin
 var axis:=edge.normalized();var normal:=axis.orthogonal()
 for zoom in [.5,.82,1.25]:
  game.map_zoom=zoom
  game.origin=Vector2(800,450)
  await process_frame
  await process_frame
  var owned:=true
  var gap_error:=0.0
  var worst_side:=0.0
  for x in [48.0,57.0,82.0,91.0]:
   var point:Vector2=overlay.project(Vector3(x,internal[0].y,0))
   var hits:Array=[]
   for p:Dictionary in overlay.paths:
    var hit:Variant=Geometry2D.segment_intersects_segment(p.a,p.b,point-normal*60,point+normal*60)
    if hit==null:continue
    var projected:Vector2=hit
    var picked:Dictionary=overlay.pick(projected)
    owned=owned and p.id==picked.get("id",-1) and p.index==picked.get("index",-1) and not p.freight
    hits.append((projected-point).dot(normal))
   if hits.size()!=2:gap_error=INF;continue
   gap_error=maxf(gap_error,absf(absf(hits[0]-hits[1])-12.0))
   worst_side=maxf(worst_side,absf(hits[0]+hits[1]))
  check(gap_error<=.5 and worst_side<=.5,"physical rail overlays stay +/-6px at zoom %.2f (gap error %.2f, center error %.2f)"%[zoom,gap_error,worst_side])
  check(owned and gap_error<INF,"actual emitted rail lanes pick their own stop interval at zoom %.2f"%zoom)

func check_short_list(overlay,count:int):
 for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
  root.size=resolution
  await process_frame
  await process_frame
  var last:HBoxContainer=overlay.rows.get_child(-1)
  var dot:Control=last.get_child(0)
  var cross:Button=last.get_child(2)
  var clip:Rect2=overlay.scroll.get_global_rect()
  check(not overlay.scroll.get_v_scroll_bar().visible and clip.encloses(last.get_global_rect()) and clip.encloses(cross.get_global_rect()),"%d full rows and actual X, no scrollbar at %s"%[count,resolution])
  check(not dot is ColorRect and cross.icon!=null and cross.get_theme_constant("icon_max_width")==12,"round dot and explicit 12px X at %s"%resolution)

func check_shared_corridor(overlay,first:int,second:int):
 var a_paths:Array=overlay.paths.filter(func(p):return p.id==first)
 var b_paths:Array=overlay.paths.filter(func(p):return p.id==second)
 check(a_paths.size()==b_paths.size() and not a_paths.is_empty() and not a_paths.any(func(a):
  return b_paths.any(func(b):return a.a.is_equal_approx(b.a) and a.b.is_equal_approx(b.b))
 ),"two real bus lines sharing the full corridor have no coincident draw pieces")
 var corner_clearance:=INF
 var corners:=0
 for i in range(a_paths.size()):
  var a:Dictionary=a_paths[i];var b:Dictionary=a_paths[(i+1)%a_paths.size()]
  var first_dir:Vector2=(a.b-a.a).normalized();var second_dir:Vector2=(b.b-b.a).normalized()
  if first_dir.dot(second_dir)>.999:continue
  corners+=1
  for other:Dictionary in b_paths:
   corner_clearance=minf(corner_clearance,a.b.distance_to(Geometry2D.get_closest_point_to_segment(a.b,other.a,other.b)))
 # The road-width cap replaces the fixed 24px route spacing. Distinct
 # centerlines must still survive on this two-service, four-lane fixture.
 check(corners>=4 and corner_clearance>2.0,"real shared bus turns retain distinct centers (nearest %.2fpx)"%corner_clearance)

func check_reversed_corridor(overlay,first:int,second:int):
 # Isolate a partial, reversed overlap as rail plans need not segment the track identically.
 var original:Array=overlay.world_paths.duplicate()
 var a:=Vector3(100,100,0);var b:=Vector3(160,100,0)
 var mid:=a.lerp(b,.5)
 overlay.world_paths=[
  {"id":first,"index":0,"freight":false,"a":a,"b":b,"run":0,"closed":false},
  {"id":first,"index":1,"freight":false,"a":b,"b":a,"run":1,"closed":false},
  {"id":second,"index":0,"freight":true,"a":mid,"b":b,"run":0,"closed":false},
  {"id":second,"index":1,"freight":true,"a":b,"b":mid,"run":1,"closed":false},
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
 check(absf(centers[first][0]-centers[first][1]-12.0)<.01 and absf(centers[second][0]-centers[second][1]-12.0)<.01,"each direction stays 6px from its route center")
 check(absf(centers[first][0]-centers[second][0])>=20.0,"partially overlapping bidirectional route pairs have separate centers")
 var before:Array=overlay.paths.duplicate(true)
 overlay.world_paths.reverse();overlay.project_paths()
 check(before.all(func(p):return overlay.paths.any(func(q):return p.id==q.id and p.index==q.index and p.a==q.a and p.b==q.b)),"corridor positions are deterministic under input reordering")
 overlay.world_paths=original;overlay.project_paths()
