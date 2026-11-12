extends SceneTree
var checks:=0
var failures:=0
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func _initialize():run.call_deferred()
func click(game,p: Vector2):
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=game.screen(p);event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
  await process_frame
func move(game,p: Vector2):
 var event:=InputEventMouseMotion.new();event.position=game.screen(p);root.push_input(event,true);await process_frame
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;game.city.population_enabled=false
 root.add_child(game);await process_frame;game.map_zoom=.75;game.origin=Vector2(850,20);game.activate_tool("road")
 verify(game.get("road_drawer")!=null,"approved default click-based road drawing controller exists")
 if game.get("road_drawer")!=null:
  var drawing=game.road_drawer
  verify(drawing.kind=="straight","default mode is straight, hidden legacy drag is not the default")
  await click(game,Vector2(10,20));await move(game,Vector2(30,20))
  verify(game.city.roads.is_empty(),"first click and release keep live preview without committing a dragged road")
  var candidate: Dictionary=drawing.preview()
  verify(candidate.ok and candidate.points.size()==2 and candidate.points[0]==Vector2(10,20) and candidate.points[-1]==Vector2(30,20),"straight preview follows cursor with exact two endpoints")
  await click(game,Vector2(30,20))
  verify(game.city.roads.size()==1 and drawing.anchors.size()==1 and drawing.anchors[0]==Vector2(30,20),"second click builds and seeds the next straight segment from the previous end")
  await click(game,Vector2(45,20))
  verify(game.city.roads.size()==2 and game.city.roads[1].points[0]==game.city.roads[0].points[-1],"continuous straight drawing uses next endpoint clicks without another start")
  drawing.cancel();drawing.set_kind("curve")
  await click(game,Vector2(15,40));await click(game,Vector2(15,60));await move(game,Vector2(40,60))
  candidate=drawing.preview()
  verify(game.city.roads.size()==2 and drawing.anchors.size()==2 and candidate.ok,"quadratic mode waits for third click while displaying green preview")
  verify(candidate.points.size()>8 and candidate.points[0]==Vector2(15,40) and candidate.points[-1].distance_to(Vector2(40,60))<=1.001 and game.city.RoadJunctions.length_of(candidate.points)>candidate.points[0].distance_to(candidate.points[-1])+.01 and drawing.LengthUnits.is_build_length(game.city.RoadJunctions.length_of(candidate.points)),"quadratic remains sampled curved geometry with a nearby eight-metre snapped endpoint, not a straight chord")
  await click(game,Vector2(40,60));verify(game.city.roads.size()==3,"third click commits the actual quadratic path")
  drawing.set_kind("free");await click(game,Vector2(45.4,20.1));await move(game,Vector2(65,30));candidate=drawing.preview()
  verify(candidate.ok and candidate.points.size()>8 and candidate.points[0]==game.city.roads[1].points[-1],"free curve snaps to previous quantized road end and makes a real smooth curved path")
  verify((candidate.points[1]-candidate.points[0]).normalized().dot(Vector2.RIGHT)>.995,"free curve initial tangent follows connected road travel direction")
  await click(game,Vector2(65,30));verify(game.city.roads.size()==4,"free curve commits on second endpoint click")
  await click(game,Vector2(70,60));await move(game,Vector2(90,60));candidate=drawing.preview()
  verify(candidate.ok and candidate.points.size()==2,"unconnected free curve falls back to straight")
  var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;root.push_input(escape,true);await process_frame
  verify(drawing.anchors.is_empty() and game.city.roads.size()==4,"real ESC cancels all pending geometry without construction")
  drawing.set_kind("straight");await click(game,Vector2(10,20));await move(game,Vector2(30,20));candidate=drawing.preview()
  verify(not candidate.ok,"overlapping duplicate road is red and not constructible")
  await click(game,Vector2(30,20));verify(game.city.roads.size()==4,"clicking invalid duplicate cannot commit")
  var cancel:=InputEventMouseButton.new();cancel.button_index=MOUSE_BUTTON_RIGHT;cancel.position=game.screen(Vector2(30,20));cancel.pressed=true;root.push_input(cancel,true);await process_frame
  verify(drawing.anchors.is_empty(),"real right click cancels click-based drawing")
  for kind: String in ["straight","curve","free"]:
   game.activate_tool("reset");game.activate_tool("road");drawing.set_kind(kind)
   game.city.add_road(PackedVector2Array([Vector2(10,70),Vector2(90,70)]))
   await click(game,Vector2(40,69.4))
   if kind=="curve":await click(game,Vector2(60,65))
   await move(game,Vector2(65,45));candidate=drawing.preview()
   verify(candidate.ok,kind+" supports snapped middle-road branch preview")
   await click(game,Vector2(65,45))
   var network=preload("res://core/traffic_network.gd").new();var routed:=false
   if network.build(game.city.roads):
    for a in network.lanes:
     if a.road!=0:continue
     for b in network.lanes:
      if b.road==1 and not network.route(a.id,b.id).is_empty():routed=true
   verify(game.city.roads.size()==2 and routed,kind+" creates actual junction and traffic route from existing road to new branch")
  drawing.cancel();drawing.set_kind("straight");drawing.click(Vector2(20,20));game.pointer=Vector2(110,20)
  verify(not drawing.preview().ok,"outside-map preview is red via existing city geometry validation")
  drawing.cancel();drawing.set_kind("curve");drawing.click(Vector2(20,20));drawing.click(Vector2(20,50));game.pointer=Vector2(50,50)
  var count: int=game.city.roads.size();game.road_mode_buttons[0].pressed.emit()
  verify(drawing.kind=="straight" and drawing.anchors.is_empty() and game.city.roads.size()==count,"switching drawing mode cancels pending curve without building")
  game.activate_tool("reset");game.activate_tool("road");game.city.add_road(PackedVector2Array([Vector2(10,30),Vector2(30,30)]))
  drawing.set_kind("free");drawing.click(Vector2(30,30));game.pointer=Vector2(15,30)
  verify(not drawing.preview().ok,"reversing into existing road is rejected by original overlap/turn checks")
  drawing.cancel();drawing.set_kind("straight")
  verify(game.city.add_building(20,27).ok,"collision fixture uses a real valid roadside building")
  drawing.click(Vector2(21,20));game.pointer=Vector2(21,40)
  verify(not drawing.preview().ok and game.city.buildings.size()==1,"new road preview cannot cut existing real building")
  drawing.cancel();drawing.click(Vector2(30,30));game.pointer=Vector2(15,32)
  verify(not drawing.preview().ok,"near-reversing acute endpoint join is red when original traffic rules forbid its U-turn")
 game.queue_free();await process_frame
 print("RESULT %d/%d road draw mode checks passed" % [checks-failures,checks]);quit(1 if failures else 0)
