extends SceneTree
## Untimed actual-main UI checks. Capture is explicit, never an incidental side effect.
var checks:=0
var failures:=0
var game
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;printerr("FAIL ",label)
func settle():
 for i in range(6):await process_frame
func click(position:Vector2):
 var motion:=InputEventMouseMotion.new();motion.position=position;root.push_input(motion,true)
 await process_frame
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=position;event.pressed=pressed;root.push_input(event,true)
  await process_frame
func run():
 Engine.max_fps=30
 root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate()
 game.city=load("res://core/city_model.gd").new(160,160)
 game.paused=true;root.add_child(game);current_scene=game
 await settle()
 game.select_category("road");await settle()
 var control=game.find_child("RoadHeightControls",true,false)
 check(control!=null,"approved C height controls exist in native road drawer")
 if control!=null:
  var elevated=control.find_child("Elevated",true,false)
  await click(elevated.get_global_rect().get_center());await settle()
  check(game.road_drawer.target_height_m==10,"actual elevated button selects +10m")
  var up:=InputEventKey.new();up.keycode=KEY_PAGEUP;up.pressed=true;root.push_input(up,true);await settle()
  check(game.road_drawer.target_height_m==15,"PgUp changes selected height by 5m")
  var down:=InputEventKey.new();down.keycode=KEY_PAGEDOWN;down.pressed=true;root.push_input(down,true);await settle()
  check(game.road_drawer.target_height_m==10,"PgDn changes selected height by 5m")
  check(control.find_child("Underground",true,false).disabled,"E1 exposes but does not enable deferred underground mode")
  game.road_grid_enabled=false;game.road_drawer.set_height(0)
  game.map_zoom=.8;game.origin=Vector2(960,260)-Vector2((20-50)*14,(20+50)*7)*game.map_zoom
  await click(game.screen(Vector2(20,50)))
  game.road_drawer.set_height(10)
  var finish:Vector2=game.screen(Vector2(60,50))-Vector2(0,10*game.tile.x/4*sqrt(1.5)*game.map_zoom)
  var motion:=InputEventMouseMotion.new();motion.position=finish;root.push_input(motion,true);await settle()
  var preview:Dictionary=game.road_drawer.preview()
  check(preview.get("heights_m",PackedFloat64Array()).size()>0,"native preview resolves per-point heights")
  await click(finish);await settle()
  check(game.city.roads.size()==1 and game.city.roads[0].get("heights_m",PackedFloat64Array()).has(10),"native endpoint commits ramp and raised deck")
  check(game.world_renderer.actors.find_children("ElevatedDeck*","",false,false).size()>0,"production WorldActors owns elevated deck pieces")
  game.road_drawer.cancel();game.road_drawer.set_height(0);game.activate_tool("road")
  game.city.buildings.append({"id":91,"x":30,"y":70,"size":2,"level":1,"zone":"residential","asset_id":""});game.city.next_id=92;game.refresh();await settle()
  await click(game.screen(Vector2(20,70)));await click(game.screen(Vector2(40,70)));await settle()
  var warning=game.find_child("RoadDemolitionWarning",true,false)
  check(warning!=null and warning.visible,"approved B warning appears beside clicked endpoint")
  check(game.city.find_building(91).size()>0,"warning does not destroy before confirmation")
  if warning!=null:
   await click(warning.find_child("Confirm",true,false).get_global_rect().get_center());await settle()
   check(game.city.find_building(91).is_empty(),"actual warning confirmation removes private building")
 game.road_drawer.cancel()
 var horizontal:Dictionary=game.city.add_elevated_road(PackedVector2Array([Vector2(70,30),Vector2(110,30)]),PackedFloat64Array([10,10]))
 var vertical:Dictionary=game.city.add_elevated_road(PackedVector2Array([Vector2(90,10),Vector2(90,50)]),PackedFloat64Array([10,10]))
 check(horizontal.ok and vertical.ok,"same-height elevated intersection commits")
 game.refresh();await settle()
 check(game.world_renderer.actors.find_children("ElevatedJunction*","",false,false).size()>0,"production renderer owns raised junction asphalt and continuous side surfaces")
 await test_stacked_flow()
 await test_grid_height_transition()
 await test_grid_off_fixed_height_contacts()
 await test_production_ramp_car()
 await test_upper_crossing_car()
 await test_park_depth()
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--e1-capture="):await native_capture(arg.trim_prefix("--e1-capture="))
 if OS.get_cmdline_user_args().is_empty():await native_capture("") # Same composition, without framebuffer access.
 game.queue_free();await process_frame
 print("E1_UI checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
func test_stacked_flow():
 for grid in [false,true]:
  game.road_drawer.cancel()
  if game.city.simulation!=null:game.city.simulation.shutdown()
  game.city=load("res://core/city_model.gd").new(100,100)
  check(game.city.add_road(PackedVector2Array([Vector2(20,40),Vector2(60,40)])).ok,"stacked road ground fixture")
  game.road_lanes=8;game.road_grid_enabled=grid
  game.map_zoom=.8;game.origin=Vector2(800,-100)
  game.refresh();game.activate_tool("road");game.road_drawer.set_height(10);await settle()
  if not grid:
   check(game.road_drawer.snap(Vector2(20.4,40.4)).distance_to(Vector2(20.4,40.4))<.001,"raised cursor does not snap to ground-layer endpoint")
   check(game.road_drawer.tangent_at(Vector2(20,40))==Vector2.ZERO,"raised free-curve does not inherit ground tangent")
  var lift:=Vector2(0,10*game.tile.x/4*sqrt(1.5)*game.map_zoom)
  await click(game.screen(Vector2(20,40))-lift)
  var finish:Vector2=game.screen(Vector2(60,40))-lift
  var motion:=InputEventMouseMotion.new();motion.position=finish;root.push_input(motion,true);await settle()
  if not grid:
   game.road_lanes=2
   check(game.road_drawer.resolved_path().ok,"same-profile different-height overlap reaches height-aware admission, not already-road rejection")
   game.road_lanes=8
  check(game.road_drawer.preview().ok,"height-layer stacked preview accepts genuine XY overlap grid="+str(grid))
  await click(finish);await settle()
  check(game.city.roads.size()==2 and game.city.roads[1].heights_m==PackedFloat64Array([10,10]),"actual mouse commits stacked +10 road grid="+str(grid))
func test_grid_height_transition():
 game.road_drawer.cancel()
 if game.city.simulation!=null:game.city.simulation.shutdown()
 game.city=load("res://core/city_model.gd").new(120,120)
 var anchor:=Vector2(30.25,40.25);var finish:=Vector2(72.25,40.25)
 var frame:Dictionary={"origin":Vector2(10.25,41.75),"along":Vector2.RIGHT,"outward":Vector2.DOWN}
 check(game.city.add_road(PackedVector2Array([Vector2(10.25,40.25),anchor]),"local",true,2,false,false,1,frame).ok,"off-phase ground anchor host")
 check(game.city.add_road(PackedVector2Array([Vector2(73,15),Vector2(73,65)])).ok,"different-layer nearest continuation lattice")
 game.road_grid_enabled=true;game.road_lanes=2;game.map_zoom=.8;game.origin=Vector2(780,-105)
 game.refresh();game.activate_tool("road");game.road_drawer.set_height(0);await settle()
 await click(game.screen(anchor))
 check(game.road_drawer.anchors==[anchor] and game.road_drawer.grid_frame==frame,"native grid accepts and captures off-phase ground anchor")
 for height in [5,10]:
  var up:=InputEventKey.new();up.keycode=KEY_PAGEUP;up.pressed=true;root.push_input(up,true);await settle()
  var mouse:=InputEventMouseMotion.new();mouse.position=game.screen(finish)-Vector2(0,height*game.tile.x/4*sqrt(1.5)*game.map_zoom);root.push_input(mouse,true);await settle()
  var raw:PackedVector2Array=game.road_drawer.raw_path()
  check(raw[0].is_equal_approx(anchor) and game.road_drawer.grid_frame==frame,"PgUp preserves accepted ramp start and lattice at +"+str(height)+"; start="+str(raw[0]))
 var turn:=InputEventMouseMotion.new();turn.position=game.screen(anchor+Vector2(0,40))-Vector2(0,10*game.tile.x/4*sqrt(1.5)*game.map_zoom);root.push_input(turn,true);await settle()
 var turned:PackedVector2Array=game.road_drawer.raw_path()
 check(turned[0].is_equal_approx(anchor),"height transition cannot re-phase the accepted anchor on a perpendicular lattice axis: "+str(turned[0]))
 var endpoint:Vector2=game.screen(finish)-Vector2(0,10*game.tile.x/4*sqrt(1.5)*game.map_zoom)
 await click(endpoint);await settle()
 check(game.city.roads.size()==3 and game.city.roads[-1].points[0].is_equal_approx(anchor) and game.city.roads[-1].get("grid_frame",{})==frame,"native ramp commit stores exact anchor and explicit lattice; "+str(game.road_drawer.last_result.get("reason","")))
 if game.city.roads.size()==3:
  check(game.road_drawer.grid_frame==frame and game.road_drawer.start_height_m==10,"auto-continuation selects the endpoint layer, not the closer ground road")
func test_grid_off_fixed_height_contacts():
 for aligned in [false,true]:
  game.road_drawer.cancel()
  if game.city.simulation!=null:game.city.simulation.shutdown()
  game.city=load("res://core/city_model.gd").new(120,120)
  var anchor:=Vector2(20,40);var finish:=Vector2(61 if aligned else 61.25,40)
  check(game.city.add_road(PackedVector2Array([Vector2(5,40),anchor])).ok,"fixed ground contact host")
  check(game.city.add_elevated_road(PackedVector2Array([finish,Vector2(90,40)]),PackedFloat64Array([10,10])).ok,"fixed elevated contact host")
  game.road_grid_enabled=false;game.road_lanes=2;game.map_zoom=.8;game.origin=Vector2(780,-105)
  game.refresh();game.activate_tool("road");game.road_drawer.set_height(0);await settle()
  await click(game.screen(anchor))
  check(game.road_drawer.anchors==[anchor],"viewport accepted the exact fixed ground contact")
  # Move away from the first click before changing height, as in a ramp drag preview.
  var move:=InputEventMouseMotion.new();move.position=game.screen(finish);root.push_input(move,true);await settle()
  for i in range(2):
   var up:=InputEventKey.new();up.keycode=KEY_PAGEUP;up.pressed=true;root.push_input(up,true);await settle()
  var endpoint:Vector2=game.screen(finish)-Vector2(0,10*game.tile.x/4*sqrt(1.5)*game.map_zoom)
  var motion:=InputEventMouseMotion.new();motion.position=endpoint;root.push_input(motion,true);await settle()
  var preview:Dictionary=game.road_drawer.preview()
  var points:PackedVector2Array=preview.points
  check(preview.ok==aligned and points[0]==anchor and points[-1]==finish,"grid-off mixed-height preview keeps both contacts; aligned="+str(aligned)+" points="+str(points)+" reason="+preview.reason)
  var before:=var_to_bytes([game.city.roads,game.city.next_road_id])
  await click(endpoint);await settle()
  if aligned:
   check(game.city.roads.size()==3 and game.city.roads[-1].points==points and game.city.roads[-1].heights_m==preview.heights_m,"4m-aligned ramp commits exact preview endpoints and heights")
  else:
   check(var_to_bytes([game.city.roads,game.city.next_road_id])==before and game.road_drawer.anchors==[anchor] and game.road_drawer.last_result.reason=="기존 도로 연결은 4m 단위로 건설해야 합니다","misaligned fixed ramp rejects atomically without moving the accepted anchor")

func test_upper_crossing_car():
 game.road_drawer.cancel()
 if game.city.simulation!=null:game.city.simulation.shutdown()
 game.city=load("res://core/city_model.gd").new(100,100)
 var low:Dictionary=game.city.add_elevated_road(PackedVector2Array([Vector2(20,40),Vector2(80,40)]),PackedFloat64Array([10,10]),"local",true,8)
 var high:Dictionary=game.city.add_elevated_road(PackedVector2Array([Vector2(50,15),Vector2(50,75)]),PackedFloat64Array([20,20]))
 check(low.ok and high.ok,"production stacked car crossing fixture: "+high.reason)
 if not (low.ok and high.ok):return
 game.map_zoom=.8;game.origin=Vector2(800,-100);game.refresh();await settle()
 check(game.traffic.rebuild(game.city.roads),"stacked decks produce real lanes")
 var lane:Dictionary=game.traffic.network.lanes.filter(func(item):return item.road==1 and item.direction==1)[0]
 var asset:Dictionary=game.traffic.catalog.filter(func(a):return a.id=="car-sedan-03")[0]
 var vehicle:Dictionary=game.traffic.simulation.spawn(asset,[lane.id],96)
 check(not vehicle.is_empty(),"real upper deck sedan spawned")
 if vehicle.is_empty():return
 game.traffic.simulation.paused=true;await settle()
 var point:Vector2=game.traffic.simulation.position(vehicle)/4
 var direction:Vector2=game.traffic.simulation.heading(vehicle)
 var along:=direction*float(asset.length_m)/8;var across:=direction.orthogonal()*float(asset.width_m)/8
 var body:=PackedVector2Array([point-along-across,point+along-across,point+along+across,point-along+across])
 var rear:float=-INF;var front:float=-INF;var lower_depth:float=-INF
 var interdeck_order:=true;var crossing_pairs:=0
 for piece in game.world_renderer.elevated.decks:
  if piece.height_m!=20 or Geometry2D.intersect_polygons(piece.footprint,body).is_empty():continue
  var lower:float=-INF
  for other in game.world_renderer.elevated.decks:
   if other.height_m==10 and not Geometry2D.intersect_polygons(other.footprint,piece.footprint).is_empty():lower=maxf(lower,other.position.y)
  if is_finite(lower):
   crossing_pairs+=1;interdeck_order=interdeck_order and lower<piece.position.y;lower_depth=maxf(lower_depth,lower)
  var footprint_depth:float=-INF
  for corner:Vector2 in piece.footprint:footprint_depth=maxf(footprint_depth,game.world_renderer.iso(corner).y)
  if absf(piece.base_depth-footprint_depth)<.001:front=maxf(front,piece.position.y)
  else:rear=maxf(rear,piece.position.y)
 var sprite:Sprite2D=game.world_renderer.cars.get(vehicle.id)
 check(sprite!=null and sprite.visible and crossing_pairs>0 and interdeck_order,"stacked car and all affected lower/upper piece pairs remain ordered")
 check(sprite!=null and lower_depth<rear and rear<sprite.position.y and sprite.position.y<front,"stacked crossing leaves strict upper rear/car/front slots: "+str([lower_depth,rear,sprite.position.y if sprite!=null else INF,front,point]))
 game.traffic.stop()
func test_production_ramp_car():
 game.road_drawer.cancel()
 if game.city.simulation!=null:game.city.simulation.shutdown()
 game.city=load("res://core/city_model.gd").new(100,100)
 check(game.city.add_elevated_road(PackedVector2Array([Vector2(20,40),Vector2(52,40),Vector2(80,40)]),PackedFloat64Array([0,10,10])).ok,"production ramp car road fixture")
 game.map_zoom=.8;game.origin=Vector2(800,-100);game.refresh();await settle()
 check(game.traffic.rebuild(game.city.roads),"production traffic builds ramp lanes")
 var asset:Dictionary=game.traffic.catalog.filter(func(a):return a.id=="car-sedan-03")[0]
 var vehicle:Dictionary=game.traffic.simulation.spawn(asset,[0],64)
 check(not vehicle.is_empty(),"real traffic simulation spawns ramp sedan")
 game.traffic.simulation.paused=true
 for progress in [64.0,144.0]:
  vehicle.progress=progress;await settle()
  var point:Vector2=game.traffic.simulation.position(vehicle)/4
  var height:float=load("res://core/road_height.gd").height_at(game.city.roads[0],point)
  var sprite:Sprite2D=game.world_renderer.cars.get(vehicle.id)
  check(sprite!=null and sprite.visible,"production retained car survives raised culling")
  if sprite==null:continue
  var p:Vector2=game.world_renderer.iso(point)
  var rect:Rect2=game.traffic.sprite_rect(asset.id,Vector2.ZERO,game.tile.x/4*sqrt(2.0))
  var expected:Vector2=p+rect.position-Vector2(0,height*game.tile.x/4*sqrt(1.5))
  check((sprite.position+sprite.offset*sprite.scale).distance_to(expected)<.001,"actual production car artwork lifts by interpolated ramp/deck height")
  var direction:Vector2=game.traffic.simulation.heading(vehicle)
  var along:Vector2=direction*float(asset.length_m)/8
  var across:Vector2=direction.orthogonal()*float(asset.width_m)/8
  var body:=PackedVector2Array([point-along-across,point+along-across,point+along+across,point-along+across])
  var front:float=-INF;var rear:float=-INF
  for node in game.world_renderer.elevated.decks:
   if Geometry2D.intersect_polygons(node.footprint,body).is_empty():continue
   var footprint_depth:float=-INF
   for corner:Vector2 in node.footprint:footprint_depth=maxf(footprint_depth,game.world_renderer.iso(corner).y)
   if absf(node.base_depth-footprint_depth)<.001:front=maxf(front,node.position.y)
   else:rear=maxf(rear,node.position.y)
  if not (sprite.position.y>rear and sprite.position.y<front):print("CAR_DEPTH_DIAGNOSTIC ",sprite.position.y," rear=",rear," front=",front," point=",point," road=",game.city.roads[0].parcel_id)
  check(sprite.position.y>rear and sprite.position.y<front,"production multi-piece car sorts between furthest overlapping rear and front")
 game.traffic.stop()
func test_park_depth():
 game.road_drawer.cancel()
 if game.city.simulation!=null:game.city.simulation.shutdown()
 game.city=load("res://core/city_model.gd").new(100,100);game.city.funds=1000000
 game.city.add_road(PackedVector2Array([Vector2(33.5,10),Vector2(33.5,90)]))
 var park:Dictionary=game.city.public_facilities.place("park-plaza-4x4",Vector2(30,30),0)
 check(park.ok,"production park render fixture placement")
 if not park.ok:return
 game.refresh();await settle()
 var node=game.world_renderer.buildings[park.record.id]
 var original:Rect2=node.world_bounds
 check(game.city.add_elevated_road(PackedVector2Array([Vector2(30,10),Vector2(30,90)]),PackedFloat64Array([10,10])).ok,"deck added above retained park")
 game.refresh();await settle()
 var overlaps:=0;var ordered:=true
 for deck in game.world_renderer.elevated.decks:
  if Geometry2D.intersect_polygons(deck.footprint,park.record.polygon).is_empty():continue
  overlaps+=1;ordered=ordered and node.position.y<deck.position.y
 check(overlaps>0 and ordered,"actual cached park precedes every footprint-overlapping deck piece")
 check(node.world_bounds.is_equal_approx(original),"park depth dependency preserves cached visual bounds")
 if node.texture!=null:check((node.position+node.offset*node.scale).distance_to(node.world_bounds.position)<.001,"native park sprite offset compensates its sort anchor")
func native_capture(path:String):
 if not path.is_empty() and (DisplayServer.get_name()=="headless" or FileAccess.file_exists(path)):
  check(false,"native capture requires a real display and a new destination");return
 game.road_drawer.cancel()
 if game.city.simulation!=null:game.city.simulation.shutdown()
 game.city=load("res://core/city_model.gd").new(140,140);game.paused=true
 game.road_lanes=2;game.road_grid_enabled=false
 game.map_zoom=1;game.origin=Vector2(720,-180)
 var ground:Dictionary=game.city.add_road(PackedVector2Array([Vector2(72,20),Vector2(72,65)]))
 var ramp:Dictionary=game.city.add_elevated_road(PackedVector2Array([Vector2(20,40),Vector2(52,40),Vector2(92,40)]),PackedFloat64Array([0,10,10]),"local",true,4)
 var upper:Dictionary=game.city.add_elevated_road(PackedVector2Array([Vector2(82,20),Vector2(82,66)]),PackedFloat64Array([20,20]))
 check(ground.ok and ramp.ok and upper.ok,"capture fixture commits ground, retaining ramp, +10m deck and +20m crossing")
 game.city.buildings.append({"id":301,"x":62,"y":54,"size":4,"level":4,"zone":"residential","asset_id":"mansion-a-4x4-4f"})
 game.city.buildings.append({"id":302,"x":44,"y":32,"size":4,"level":4,"zone":"residential","asset_id":"mansion-a-4x4-4f"})
 game.city.next_id=303;game.refresh();game.activate_tool("road");game.road_drawer.set_height(10);await settle()
 var lift:=Vector2(0,10*game.tile.x/4*sqrt(1.5))
 await click(game.screen(Vector2(42,55))-lift);await click(game.screen(Vector2(80,55))-lift);await settle()
 var warning=game.find_child("RoadDemolitionWarning",true,false)
 check(warning!=null and warning.visible,"single native capture includes live approved B confirmation and C height controls")
 if warning==null:print("FIXTURE_WARNING_DIAGNOSTIC preview=",game.road_drawer.preview()," endpoint=",game.screen(Vector2(80,55))-lift," hovered=",root.gui_get_hovered_control()," drawer=",game.drawer.get_global_rect())
 if path.is_empty():return
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 check(image.get_size()==Vector2i(1920,1080),"native viewport is exactly 1920x1080")
 check(image.save_png(path)==OK,"one native viewport capture saved")
 print("E1_CAPTURE ",path," display=",DisplayServer.get_name()," renderer=",RenderingServer.get_current_rendering_method()," max_fps=",Engine.max_fps)
