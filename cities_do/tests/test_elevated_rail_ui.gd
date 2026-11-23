extends SceneTree
## E3a untimed actual-main UI checks. The capture is explicit (--e3a-capture=<png>), never a side effect.
const Height=preload("res://core/road_height.gd")
const Routes=preload("res://core/transit_routes.gd")
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
 # Past the OS double-click window, so a native window sees separate presses.
 await create_timer(0.6).timeout
 var motion:=InputEventMouseMotion.new();motion.position=position;root.push_input(motion,true)
 # A real window needs the hover to land before the press (native runs).
 for i in range(3):await process_frame
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=position;event.pressed=pressed;root.push_input(event,true)
  await process_frame
func key(code:Key):
 var event:=InputEventKey.new();event.keycode=code;event.pressed=true;root.push_input(event,true);await settle()
func fresh_city(width:int,height:int):
 game.road_drawer.cancel();game.transit_view.cancel()
 if game.city.simulation!=null:game.city.simulation.shutdown()
 game.city=load("res://core/city_model.gd").new(width,height);game.city.funds=1000000;game.paused=true
func run():
 Engine.max_fps=30
 root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate()
 game.city=load("res://core/city_model.gd").new(160,160)
 game.paused=true;root.add_child(game);current_scene=game
 await settle()
 await test_height_controls()
 await test_confirmed_points()
 await test_warning_b()
 var capture_path:=""
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--e3a-capture="):capture_path=arg.trim_prefix("--e3a-capture=")
 await native_capture(capture_path) # Same composition without framebuffer access when no path is given.
 print("E3A_UI checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
func test_height_controls():
 await create_timer(1.0).timeout # A native window settles (focus, layout) before the first press.
 game.select_transport_tab(2);await settle()
 game.activate_tool("rail");await settle()
 var control=game.find_child("RailHeightControls",true,false)
 check(control!=null and control.is_visible_in_tree(),"rail tool shows the approved C height controls")
 if control==null:return
 check(not control.find_child("Underground",true,false).disabled,"rail underground button is enabled since E3b")
 await click(control.find_child("Elevated",true,false).get_global_rect().get_center());await settle()
 check(game.transit_view.target_height_m==10 and control.find_child("HeightValue",true,false).text=="+10 m","고가 selects +10 m for the rail tool")
 await key(KEY_PAGEUP)
 check(game.transit_view.target_height_m==15,"PgUp raises the rail target by 5m")
 for i in range(2):
  await click(control.find_child("HeightMinus",true,false).get_global_rect().get_center());await settle()
 check(game.transit_view.target_height_m==5,"- lowers by 5m but stays on the elevated layer")
 await key(KEY_PAGEDOWN)
 check(game.transit_view.target_height_m==0 and control.find_child("Ground",true,false).button_pressed,"PgDn returns to ground")
 await key(KEY_PAGEDOWN)
 check(game.transit_view.target_height_m==-5,"E3b: PgDn takes the rail tool below ground in 5m steps")
 await key(KEY_PAGEUP)
 check(game.transit_view.target_height_m==0,"PgUp returns the rail tool to ground")
 check(game.road_drawer.target_height_m==0,"the rail height never changes the road tool height")
func test_confirmed_points():
 fresh_city(220,90)
 game.select_transport_tab(2);game.activate_tool("rail");game.set_route_drawing_kind("straight");await settle()
 game.transit_view.set_height(10)
 game.transit_view.click(Vector2(20.37,30.11))
 game.pointer=Vector2(120.61,30.42)
 var preview:Dictionary=game.transit_view.preview()
 check(preview.ok and preview.heights_m.size()==preview.points.size() and preview.heights_m[0]==0 and preview.heights_m[-1]==10,"preview ramps from the ground start to the +10m target: "+str(preview.get("reason","")))
 game.transit_view.click(Vector2(120.61,30.42))
 var route:Dictionary=game.city.transit_routes[-1] if not game.city.transit_routes.is_empty() else {}
 check(not route.is_empty() and route.points==preview.points and route.heights_m==preview.heights_m,"the committed rail keeps exactly the confirmed preview points and heights")
 check(not route.is_empty() and is_equal_approx(Height.length_cells(PackedVector2Array([route.points[0],route.points[1]]))*4,288.0),"the ramp vertex sits at the 288m minimum")
 game.transit_view.cancel();game.transit_view.set_height(0)
func test_warning_b():
 fresh_city(220,90)
 game.city.buildings.append({"id":501,"x":110,"y":49,"size":2,"level":1,"zone":"residential","asset_id":""})
 game.city.buildings.append({"id":502,"x":110,"y":53,"size":2,"level":1,"zone":"residential","asset_id":""})
 game.city.next_id=503;game.refresh();await settle()
 game.select_transport_tab(2);game.activate_tool("rail");game.set_route_drawing_kind("straight");await settle()
 game.transit_view.set_height(10)
 game.transit_view.click(Vector2(20,50))
 game.pointer=Vector2(140,50)
 game.transit_view.click(Vector2(140,50));await settle()
 var panel=game.find_child("RoadDemolitionWarning",true,false)
 check(panel!=null and game.transit_view.pending.get("demolish_ids",[])==[501],"warning B lists only the zoned building under the viaduct")
 check(game.city.transit_routes.is_empty() and not game.city.find_building(501).is_empty(),"nothing is built or demolished before confirmation")
 if panel!=null:
  await click(panel.find_child("Confirm",true,false).get_global_rect().get_center());await settle()
 check(game.city.transit_routes.size()==1 and game.city.find_building(501).is_empty() and not game.city.find_building(502).is_empty(),"confirm demolishes exactly that building and builds the viaduct")
 game.transit_view.cancel();game.transit_view.set_height(0)
func native_capture(path:String):
 if not path.is_empty() and (DisplayServer.get_name()=="headless" or FileAccess.file_exists(path)):
  check(false,"native capture requires a real display and a new destination");return
 game.road_drawer.cancel();game.transit_view.cancel()
 if game.city.simulation!=null:game.city.simulation.shutdown()
 # Real stations, line and trains: ground -> 3.5% ramp -> viaduct over a road -> ramp down.
 var city=load("res://core/city_model.gd").new(210,100,42)
 city.population_enabled=false;city.happiness_enabled=false;city.funds=1000000
 city.add_road(PackedVector2Array([Vector2(2,40),Vector2(110,40)]),"local",true,4)
 for x:float in [30.0,70.0]:check(city.public_facilities.place("train-station-01",Vector2(x,33.0),0,true).ok,"capture station")
 var a:PackedVector2Array=city.public_facilities.lots[0].internal_points
 var b:PackedVector2Array=city.public_facilities.lots[1].internal_points
 if a[0].x>a[-1].x:a.reverse()
 if b[0].x>b[-1].x:b.reverse()
 check(city.add_transit_route(PackedVector2Array([a[-1],b[0]])).ok,"capture station join")
 var y:float=a[0].y
 check(city.add_road(PackedVector2Array([Vector2(100,y+14),Vector2(100,y+46)])).ok,"capture road under the viaduct")
 # The operating fixture's continuous turnaround loop, with its return straight raised.
 var track:=PackedVector2Array([b[-1],Vector2(184,y)]);var heights:=PackedFloat64Array([0,0])
 for i in range(1,49):track.append(Vector2(184,y+15)+Vector2.from_angle(-PI/2+PI*i/48)*15);heights.append(0)
 for item in [[Vector2(112,y+30),10],[Vector2(88,y+30),10],[Vector2(16,y+30),0]]:track.append(item[0]);heights.append(item[1])
 for i in range(1,49):track.append(Vector2(16,y+15)+Vector2.from_angle(PI/2+PI*i/48)*15);heights.append(0)
 track.append(a[0]);heights.append(0)
 var loop:Dictionary=city.add_transit_route(track,"rail",true,heights)
 check(loop.ok,"capture loop with a 288m ramp, a 96m deck over the road and a 288m ramp down: "+str(loop.get("reason","")))
 var line:Dictionary=city.create_transit_line("rail",city.public_facilities.lots.map(func(lot):return lot.id))
 check(line.ok,"capture operating line over the viaduct: "+str(line.get("reason","")))
 # Same worker flow as transit_operations_fixture.populate: fixed development steps.
 game.city=city
 city.enable_simulation_worker();city.simulation.worker.Suspend()
 var target:Dictionary={}
 for step in range(150):
  city.simulation.resume();city.advance_society(city.config.development_interval_seconds);city.simulation.validation_publish()
  for pose:Dictionary in city.transit_state.get("visible",[]):
   var p:Vector2=pose.position/4
   if pose.kind=="rail" and p.x>91 and p.x<109 and absf(p.y-(y+30))<1:target=pose
  if not target.is_empty():break
 game.public_controller.cancel();game.select_transport_tab(2);game.mode="select"
 game.map_zoom=1.25;game.origin=Vector2(960,560)-game.world_renderer.iso(Vector2(100,y+30))*game.map_zoom
 city.simulation.resume();game.paused=true
 check(not target.is_empty(),"an operating train reaches the deck above the road: fault=%s ready=%s state=%s lines=%s"%[str(city.simulation.get_fault()),str(city.simulation.is_ready()),str(city.transit_state.keys().map(func(k):return [k,city.transit_state[k].size() if city.transit_state[k] is Array or city.transit_state[k] is Dictionary else city.transit_state[k]])),str(city.transit_lines.map(func(l):return [l.get("status",""),l.get("reason",""),l.get("vehicles",[]).size() if l.get("vehicles") is Array else l.get("vehicles")]))])
 game.world_renderer.synchronize();game.refresh();await settle();await settle()
 var lifted:=0
 for sprite in game.world_renderer.transit_cars.values():
  if sprite.visible and float(sprite.get_meta("rail_height_m",0.0))>9.9:lifted+=1
 check(lifted>0,"train cars on the deck are drawn lifted by the deck height: %d"%lifted)
 var structure:Dictionary=Routes.structure(city.transit_routes[-1])
 var deck_items:Array=game.transit_view.geometry.catenary.filter(func(c):return c.get("deck",false))
 check(not deck_items.is_empty() and deck_items.all(func(c):return c.a_height>=Height.height_at(structure,c.a)-.01 and c.b_height>=Height.height_at(structure,c.b)-.01),"deck catenary stands on the ramp/deck surface, never below it")
 var piers:Array=game.world_renderer.elevated.nodes.filter(func(n):return n.footprint.size()==1 and n.road.has("rail_route_id"))
 check(not piers.is_empty(),"concrete viaduct piers are built for the rail deck: nodes=%d rail=%d route_piers=%d"%[game.world_renderer.elevated.nodes.size(),game.world_renderer.elevated.nodes.filter(func(n):return n.road.has("rail_route_id")).size(),city.transit_routes[-1].get("piers",[]).size()])
 if not path.is_empty():
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image()
  check(image.get_size()==Vector2i(1920,1080),"native capture is 1920x1080")
  check(image.save_png(path)==OK,"viaduct capture saved")
  print("E3A_CAPTURE ",path," display=",DisplayServer.get_name()," renderer=",RenderingServer.get_current_rendering_method())
