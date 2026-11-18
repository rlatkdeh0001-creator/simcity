extends SceneTree
var checks:=0
var failures:=0
func verify(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func _initialize():run.call_deferred()
func click(game,p:Vector2):
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=game.screen(p);event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
  await process_frame
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;game.city.population_enabled=false
 root.add_child(game);await process_frame;game.map_zoom=.75;game.origin=Vector2(850,20)
 game.select_category("transport");await process_frame
 var button=game.drawer_box.find_child("Tool_rail",true,false)
 verify(button!=null,"transport reuses existing tool chooser for rail")
 verify(game.get("transit_view")!=null,"main owns independent transit drawing adapter")
 if button!=null and game.get("transit_view")!=null:
  for down in [true,false]:
   var event:=InputEventMouseButton.new();event.position=button.get_global_rect().get_center();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
  verify(game.mode=="rail" and game.road_modes.visible,"rail reuses existing three-mode palette")
  var roads=game.city.roads.duplicate(true);var zones=game.city.zone_designations.duplicate(true)
  await click(game,Vector2(10,20));game.pointer=Vector2(30,20)
  var candidate:Dictionary=game.transit_view.preview()
  verify(candidate.ok and game.city.transit_routes.is_empty(),"preview does not commit")
  await click(game,Vector2(30,20))
  verify(game.city.transit_routes.size()==1,"second viewport click commits independent rail")
  if not game.city.transit_routes.is_empty():verify(game.city.transit_routes[0].points==candidate.points,"preview and commit use identical resolver points")
  verify(game.city.roads==roads and game.city.zone_designations==zones,"transit leaves roads and zoning untouched")
  var adapter=game.transit_view
  var generation:int=adapter.generation
  game.origin+=Vector2(3,2);game.map_zoom=.8;game.world_renderer._process(0);game.refresh()
  verify(adapter.generation==generation,"camera and refresh retain geometry cache")
  game.activate_tool("rail");await click(game,Vector2(30.3,20.1));game.pointer=Vector2(40,20)
  candidate=adapter.preview()
  verify(candidate.ok and candidate.points[0]==Vector2(30,20),"viewport click snaps to existing rail endpoint")
  await click(game,Vector2(40,20))
  verify(game.city.transit_routes.size()==2 and adapter.generation==generation+1,"route edit immediately invalidates retained cache")
  game.activate_tool("rail");await click(game,Vector2(10,20));game.pointer=Vector2(30,20)
  verify(not adapter.preview().ok,"duplicate rail preview is invalid")
  await click(game,Vector2(30,20));verify(game.city.transit_routes.size()==2,"invalid duplicate click does not commit")
  game.activate_tool("rail");game.road_mode_buttons[1].pressed.emit()
  await click(game,Vector2(15,40));await click(game,Vector2(40,40));game.pointer=Vector2(60,55)
  candidate=adapter.preview()
  verify(candidate.ok and candidate.points.size()>8,"shared curve palette builds sampled transit preview")
  await click(game,Vector2(60,55))
  verify(game.city.transit_routes.size()==3 and game.city.transit_routes[-1].points==candidate.points,"curve third click commits preview exactly")
  game.road_mode_buttons[2].pressed.emit()
  await click(game,Vector2(40.2,20));game.pointer=Vector2(65,30)
  candidate=adapter.preview()
  verify(candidate.ok and candidate.points.size()>8,"shared free curve follows transit terminal tangent")
  await click(game,Vector2(65,30));verify(game.city.transit_routes.size()==4,"free curve commits on second click")
  game.activate_tool("rail");game.road_mode_buttons[0].pressed.emit()
  await click(game,Vector2(10,75));game.pointer=Vector2(110,75)
  verify(not adapter.preview().ok,"out-of-map transit preview rejects")
  var cancel:=InputEventMouseButton.new();cancel.pressed=true;cancel.button_index=MOUSE_BUTTON_RIGHT;cancel.position=game.screen(Vector2(10,75));root.push_input(cancel,true);await process_frame
  verify(game.mode=="select" and adapter.anchors.is_empty(),"right click exits transit and clears stroke")
  game.activate_tool("rail");game.toggle_demolition()
  var target:Dictionary=game.demolition_target(game.screen(Vector2(15,20)))
  verify(target.get("kind","")=="transit_route","shared bulldozer picks visible rail instead of road")
  await click(game,Vector2(15,20))
  verify(game.city.transit_routes.size()==3,"shared bulldozer removes physical rail route")
  game.select_category("transport");game.activate_tool("metro");await process_frame
  verify(adapter.underground and adapter.metro_layer.visible,"metro tool opens underground layer")
  var metro_result:Dictionary=game.city.add_transit_route(PackedVector2Array([Vector2(10,75),Vector2(30,75)]),"metro")
  verify(metro_result.ok,"metro fixture installs independent route")
  var metro_screen:Vector2=game.origin+adapter.project_point(Vector2(20,75),-12.7)*game.map_zoom
  game.toggle_demolition();await process_frame
  target=game.demolition_target(metro_screen)
  verify(adapter.metro_layer.visible and target.get("kind","")=="transit_route","bulldozer preserves underground view and picks depth-projected metro")
  game.select_category("road");await process_frame
  verify(not adapter.underground and not adapter.metro_layer.visible and game.demolition_target(metro_screen).get("kind","")!="transit_route","switching category hides underground rendering and picking")
  game.select_category("transport");game.activate_tool("metro");game.drawer.hide();await process_frame
  verify(not adapter.underground and adapter.anchors.is_empty() and game.mode=="select","closing transit tray cancels hidden underground tool")
  game.select_category("transport");game.activate_tool("metro");await process_frame
  var anchor_screen:Vector2=game.origin+adapter.project_point(Vector2(40,75),-12.7)*game.map_zoom
  for down in [true,false]:
   var event:=InputEventMouseButton.new();event.position=anchor_screen;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
  verify(adapter.anchors.size()==1 and adapter.anchors[0].distance_to(Vector2(40,75))<.001,"metro input uses same depth projection as tunnel and picking")
  game.pointer=Vector2(60,75);candidate=adapter.preview()
  var end_screen:Vector2=game.origin+adapter.project_point(Vector2(60,75),-12.7)*game.map_zoom
  for down in [true,false]:
   var event:=InputEventMouseButton.new();event.position=end_screen;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
  verify(game.city.transit_routes[-1].kind=="metro" and game.city.transit_routes[-1].points==candidate.points,"metro viewport commit matches depth-correct preview")
  verify(adapter.has_method("cursor_preview"),"transit uses existing cursor preview visual language")
  if adapter.has_method("cursor_preview"):
   game.activate_tool("rail");game.pointer=Vector2(-2,20)
   verify(not adapter.cursor_preview().ok,"outside-map first-anchor cursor is red")
   game.pointer=Vector2(40,20)
   verify(adapter.cursor_preview().snapped,"first-anchor ring shows actual transit connection")
  game.activate_tool("rail");game.toggle_demolition()
  var curved_route:Dictionary=game.city.get_transit_route(3)
  target=game.demolition_target(game.screen(curved_route.points[curved_route.points.size()/2]))
  verify(target.get("id",-1)==3 and target.get("polygons",[]).size()>1,"curved-route demolition preview highlights the complete record being removed")
  var unchanged:=var_to_bytes(game.city.transit_routes)
  var press:=InputEventMouseButton.new();press.position=game.screen(curved_route.points[curved_route.points.size()/2]);press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;root.push_input(press,true);await process_frame
  verify(var_to_bytes(game.city.transit_routes)==unchanged,"transit demolition press waits for release")
  var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;root.push_input(escape,true);await process_frame
  press.pressed=false;root.push_input(press,true);await process_frame
  verify(var_to_bytes(game.city.transit_routes)==unchanged,"escape cancels captured transit deletion")
  generation=adapter.generation
  var crossing:Dictionary=game.city.add_road(PackedVector2Array([Vector2(35,10),Vector2(35,30)]))
  game.refresh()
  verify(crossing.ok and adapter.generation==generation+1,"road edit invalidates crossing mask cache")
  game.select_category("transport");game.activate_tool("metro");game.toggle_demolition()
  var metro_count:int=game.city.transit_routes.size()
  for down in [true,false]:
   var event:=InputEventMouseButton.new();event.position=metro_screen;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
  verify(game.city.transit_routes.size()==metro_count-1,"depth-projected metro deletes through shared viewport bulldozer")
 game.queue_free();await process_frame
 print("RESULT %d/%d transit view checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
