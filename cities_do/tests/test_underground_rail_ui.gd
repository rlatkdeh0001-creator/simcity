extends SceneTree
## E3b untimed actual-main UI checks. Captures are explicit (--e3b-capture= / --e3b-underground-capture=), never a side effect.
const Height=preload("res://core/road_height.gd")
const Routes=preload("res://core/transit_routes.gd")
const Trench=preload("res://core/underground_road_renderer.gd")
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
 test_wall_fraction()
 var trench_path:="";var underground_path:=""
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--e3b-capture="):trench_path=arg.trim_prefix("--e3b-capture=")
  elif arg.begins_with("--e3b-underground-capture="):underground_path=arg.trim_prefix("--e3b-underground-capture=")
 await native_capture(trench_path,underground_path) # Same composition without framebuffer access when no path is given.
 print("E3B_UI checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
func test_height_controls():
 await create_timer(1.0).timeout # A native window settles (focus, layout) before the first press.
 game.select_transport_tab(2);await settle()
 game.activate_tool("rail");await settle()
 var control=game.find_child("RailHeightControls",true,false)
 check(control!=null and control.is_visible_in_tree(),"rail tool shows the approved C height controls")
 if control==null:return
 var underground=control.find_child("Underground",true,false)
 check(not underground.disabled,"the rail underground button is enabled (E3b)")
 await click(underground.get_global_rect().get_center());await settle()
 check(game.transit_view.target_height_m==-10 and control.find_child("HeightValue",true,false).text=="−10 m","지하 selects -10 m for the rail tool")
 check(game.transit_view.underground and game.transit_view.metro_layer.visible,"an underground rail target turns the underground view on")
 await click(control.find_child("HeightPlus",true,false).get_global_rect().get_center());await settle()
 check(game.transit_view.target_height_m==-5,"+ raises by 5m")
 await click(control.find_child("HeightPlus",true,false).get_global_rect().get_center());await settle()
 check(game.transit_view.target_height_m==-5,"+ stays on the underground layer (-5m)")
 await key(KEY_PAGEDOWN)
 check(game.transit_view.target_height_m==-10,"PgDn lowers the rail target by 5m")
 await key(KEY_PAGEUP);await key(KEY_PAGEUP)
 check(game.transit_view.target_height_m==0 and control.find_child("Ground",true,false).button_pressed,"PgUp returns to ground")
 check(not game.transit_view.underground,"a ground target turns the underground view off")
 await key(KEY_PAGEDOWN)
 check(game.transit_view.target_height_m==-5 and game.transit_view.underground,"PgDn from ground goes to -5m and shows the underground view")
 await click(control.find_child("Ground",true,false).get_global_rect().get_center());await settle()
 check(game.transit_view.target_height_m==0,"지상 returns to 0 m")
 check(game.road_drawer.target_height_m==0,"the rail height never changes the road tool height")
func test_confirmed_points():
 fresh_city(220,90)
 game.select_transport_tab(2);game.activate_tool("rail");game.set_route_drawing_kind("straight");await settle()
 game.transit_view.set_height(-10)
 game.transit_view.click(Vector2(20.37,30.11))
 game.pointer=Vector2(120.61,30.42)
 var preview:Dictionary=game.transit_view.preview()
 check(preview.ok and preview.heights_m.size()==preview.points.size() and preview.heights_m[0]==0 and preview.heights_m[-1]==-10,"preview descends from the ground start to the -10m target: "+str(preview.get("reason","")))
 game.transit_view.click(Vector2(120.61,30.42))
 var route:Dictionary=game.city.transit_routes[-1] if not game.city.transit_routes.is_empty() else {}
 check(not route.is_empty() and route.points==preview.points and route.heights_m==preview.heights_m,"the committed rail keeps exactly the confirmed preview points and depths")
 check(not route.is_empty() and is_equal_approx(Height.length_cells(PackedVector2Array([route.points[0],route.points[1]]))*4,288.0),"the descent vertex sits at the 288m minimum")
 game.transit_view.cancel();game.transit_view.set_height(0)
func test_warning_b():
 fresh_city(220,90)
 game.city.buildings.append({"id":501,"x":40,"y":49,"size":2,"level":1,"zone":"residential","asset_id":""}) # open trench
 game.city.buildings.append({"id":502,"x":110,"y":49,"size":2,"level":1,"zone":"residential","asset_id":""}) # covered tunnel
 game.city.next_id=503;game.refresh();await settle()
 game.select_transport_tab(2);game.activate_tool("rail");game.set_route_drawing_kind("straight");await settle()
 game.transit_view.set_height(-10)
 game.transit_view.click(Vector2(20,50))
 game.pointer=Vector2(140,50)
 game.transit_view.click(Vector2(140,50));await settle()
 var panel=game.find_child("RoadDemolitionWarning",true,false)
 check(panel!=null and game.transit_view.pending.get("demolish_ids",[])==[501],"warning B lists only the zoned building on the open trench")
 check(game.city.transit_routes.is_empty() and not game.city.find_building(501).is_empty(),"nothing is built or demolished before confirmation")
 if panel!=null:
  await click(panel.find_child("Confirm",true,false).get_global_rect().get_center());await settle()
 check(game.city.transit_routes.size()==1 and game.city.find_building(501).is_empty() and not game.city.find_building(502).is_empty(),"confirm demolishes the trench building; the one above the tunnel stays")
 game.transit_view.cancel();game.transit_view.set_height(0)
## Same worker flow as transit_operations_fixture.populate: fixed development steps until a rail car matches.
func advance_until(city,matches:Callable)->Dictionary:
 var target:Dictionary={}
 for step in range(400):
  city.simulation.resume();city.advance_society(city.config.development_interval_seconds);city.simulation.validation_publish()
  for pose:Dictionary in city.transit_state.get("visible",[]):
   if pose.kind=="rail" and matches.call(pose):target=pose
  if not target.is_empty():break
 city.simulation.resume();game.paused=true
 game.world_renderer.synchronize();game.refresh();await settle();await settle()
 return target
func test_wall_fraction():
 # The middle column is transparent, and the others have unequal opaque heights.
 var columns:=PackedVector2Array([Vector2(.25,.75),Vector2(1,0),Vector2(0,1)])
 var rect:=Rect2(0,0,3,8)
 var edges:Array[PackedVector2Array]=[PackedVector2Array([Vector2(3,6),Vector2(0,6)])]
 check(Trench.exposed_train_fraction(columns,rect,Vector2.ZERO,Vector2.ZERO,edges,2.0)==.5,"the projected lip leaves exactly half of the opaque height")
 var sprite:=Sprite2D.new()
 sprite.set_meta("rail_trench_surface_fraction",.5);sprite.hide()
 game.world_renderer.underground.sync_train_visibility(sprite)
 check(sprite.visible,"exactly half remains visible on the surface")
 sprite.set_meta("rail_trench_surface_fraction",.4999)
 game.world_renderer.underground.sync_train_visibility(sprite)
 check(not sprite.visible,"strictly less than half hides the car on the surface")
 sprite.free()
 edges[0]=PackedVector2Array([Vector2(2,6),Vector2(0,6)])
 check(is_equal_approx(Trench.exposed_train_fraction(columns,rect,Vector2.ZERO,Vector2.ZERO,edges,2.0),5.0/6.0),"the near lip does not occlude columns beyond its finite end")
 check(Trench.exposed_train_fraction(columns,rect,Vector2(0,8),Vector2.ZERO,edges,2.0)==1.0,"a projected wall behind the car does not occlude it")
func train_depth_probes(target:Dictionary,structure:Dictionary):
 if target.is_empty():return
 var renderer=game.world_renderer
 var previous:Array=game.city.transit_state.visible
 var retained:Sprite2D=renderer.transit_cars.get(target.id)
 # Move only the renderer's copy of the real locomotive pose along its own track.
 # The west descent starts at x=16 and drops 10m over 72 cells.
 for expected_depth:float in [0.0,-2.0,-4.0,-4.5,-5.0,-6.0]:
  var pose:=target.duplicate();pose.position.x=(16.0-expected_depth*7.2)*4
  game.city.transit_state.visible=previous.map(func(car):return pose if car.id==pose.id else car)
  renderer.sync_transit_cars()
  var sprite:Sprite2D=renderer.transit_cars.get(pose.id)
  var depth:=Height.height_at(structure,pose.position/4)
  var fraction:=float(sprite.get_meta("rail_trench_surface_fraction",1.0))
  var surface:=sprite.is_visible_in_tree()
  game.transit_view.underground=true;game.transit_view.sync_visibility()
  var below:=sprite.is_visible_in_tree()
  game.transit_view.underground=false;game.transit_view.sync_visibility()
  print("P7B_PROBE depth_m=%.3f fraction=%.6f surface=%s underground=%s"%[depth,fraction,"visible" if surface else "hidden","visible" if below else "hidden"])
  check(is_equal_approx(depth,expected_depth) and sprite==retained and sprite.texture!=null,"probe %.1fm uses the same textured car at the interpolated depth"%depth)
  check(surface==(fraction>=.5) and sprite.is_visible_in_tree()==surface and surface==(expected_depth>= -2.0),"probe %.1fm follows the wall threshold, including a visible shallow car"%depth)
  check(below==(expected_depth<0.0 and expected_depth>= -5.0),"probe %.1fm preserves underground visibility on the same car"%depth)
  if expected_depth== -2.0:
   var old_trench:=sprite.get_parent()
   renderer.structure_signature=null
   renderer.sync_transit_structures()
   renderer.underground.sync_visibility()
   check(renderer.transit_cars.get(pose.id)==sprite and sprite.get_parent()!=old_trench and sprite.get_parent() in renderer.underground.trenches and sprite.is_visible_in_tree() and sprite.get_meta("rail_trench_surface_fraction",-1.0)==fraction,"an unchanged pose rebinds to a rebuilt trench and uses its wall")
 game.city.transit_state.visible=previous
 renderer.sync_transit_cars()
func native_capture(trench_path:String,underground_path:String):
 for path:String in [trench_path,underground_path]:
  if not path.is_empty() and (DisplayServer.get_name()=="headless" or FileAccess.file_exists(path)):
   check(false,"native capture requires a real display and a new destination");return
 game.road_drawer.cancel();game.transit_view.cancel()
 if game.city.simulation!=null:game.city.simulation.shutdown()
 # Real stations, line and trains: ground -> 3.5% trench -> portal -> tunnel under a road -> back up.
 var city=load("res://core/city_model.gd").new(210,100,42)
 city.population_enabled=false;city.happiness_enabled=false;city.funds=1000000
 city.config.development_interval_seconds=.5 # Sample the moving consist finely enough to straddle -5m on publication.
 city.add_road(PackedVector2Array([Vector2(2,40),Vector2(110,40)]),"local",true,4)
 for x:float in [30.0,70.0]:check(city.public_facilities.place("train-station-01",Vector2(x,33.0),0,true).ok,"capture station")
 var a:PackedVector2Array=city.public_facilities.lots[0].internal_points
 var b:PackedVector2Array=city.public_facilities.lots[1].internal_points
 if a[0].x>a[-1].x:a.reverse()
 if b[0].x>b[-1].x:b.reverse()
 check(city.add_transit_route(PackedVector2Array([a[-1],b[0]])).ok,"capture station join")
 var y:float=a[0].y
 check(city.add_road(PackedVector2Array([Vector2(100,y+14),Vector2(100,y+46)])).ok,"capture road over the tunnel")
 # The operating fixture's continuous turnaround loop, with its return straight sunk to -10m.
 var track:=PackedVector2Array([b[-1],Vector2(184,y)]);var heights:=PackedFloat64Array([0,0])
 for i in range(1,49):track.append(Vector2(184,y+15)+Vector2.from_angle(-PI/2+PI*i/48)*15);heights.append(0)
 for item in [[Vector2(112,y+30),-10],[Vector2(88,y+30),-10],[Vector2(16,y+30),0]]:track.append(item[0]);heights.append(item[1])
 for i in range(1,49):track.append(Vector2(16,y+15)+Vector2.from_angle(PI/2+PI*i/48)*15);heights.append(0)
 track.append(a[0]);heights.append(0)
 var loop:Dictionary=city.add_transit_route(track,"rail",true,heights)
 check(loop.ok,"capture loop with a 288m trench, a 96m tunnel under the road and a 288m trench back up: "+str(loop.get("reason","")))
 var line:Dictionary=city.create_transit_line("rail",city.public_facilities.lots.map(func(lot):return lot.id))
 check(line.ok,"capture operating line through the tunnel: "+str(line.get("reason","")))
 # Same worker flow as transit_operations_fixture.populate: fixed development steps.
 game.city=city
 city.enable_simulation_worker();city.simulation.worker.Suspend()
 var portal_x:=16.0+201.6/4.0
 # One moving consist straddles -5m, with its lead car still on the open side of the portal.
 var target:=await advance_until(city,func(pose:Dictionary):
  var p:Vector2=pose.position/4
  return pose.asset_id=="train-loco-01" and pose.heading.x>0 and p.x>52.2 and p.x<54.5 and absf(p.y-(y+30))<1)
 game.public_controller.cancel();game.select_transport_tab(2);game.mode="select"
 var span:=absf((game.world_renderer.iso(Vector2(portal_x+6,y+30))-game.world_renderer.iso(Vector2(16,y+30))).x)
 game.map_zoom=clampf(1500.0/span,.6,1.6)
 game.origin=Vector2(960,430)-game.world_renderer.iso(Vector2((portal_x+36)/2,y+30))*game.map_zoom
 check(not target.is_empty(),"an operating train runs down the trench toward the portal: fault=%s"%str(city.simulation.get_fault()))
 game.world_renderer.synchronize();game.refresh();await settle();await settle()
 var underground=game.world_renderer.underground
 # Node names may be uniquified next to groups still queued for deletion; the source key is stable.
 var rail_trenches:Array=underground.trenches.filter(func(t):return str(t.source_ids[0]).begins_with("rail:"))
 check(rail_trenches.size()==2,"two rail trench clip groups (down and back up): %d"%rail_trenches.size())
 check(underground.portals.filter(func(p):return p.trench in rail_trenches).size()==2,"each rail trench ends in a tunnel portal")
 var structure:=Routes.structure(city.transit_routes[-1])
 train_depth_probes(target,structure)
 rail_trenches=underground.trenches.filter(func(t):return str(t.source_ids[0]).begins_with("rail:"))
 var shallow_sprites:Array[Sprite2D]=[];var deep_sprites:Array[Sprite2D]=[];var depths:Array=[]
 var frame:=Rect2(Vector2.ZERO,root.get_visible_rect().size)
 var portal_screen:Vector2=game.origin+game.transit_view.project_point(Vector2(portal_x,y+30),-7.0)*game.map_zoom
 check(frame.size==Vector2(1920,1080) and frame.has_point(portal_screen) and (not game.drawer.visible or not game.drawer.get_global_rect().has_point(portal_screen)),"1920x1080 descent framing places the portal clear of the drawer")
 for pose:Dictionary in city.transit_state.get("visible",[]):
  if target.is_empty() or pose.line_id!=target.line_id:continue
  var depth:=Height.height_at(structure,pose.position/4)
  depths.append([pose.id,snappedf(depth,.001)])
  var sprite:Sprite2D=game.world_renderer.transit_cars.get(pose.id)
  check(sprite!=null and sprite.texture!=null and pose.get("route_id",-1)==structure.rail_route_id and is_equal_approx(float(sprite.get_meta("rail_height_m",0)),depth),"car %s uses its own rail route and interpolated depth"%pose.id)
  if sprite==null or sprite.texture==null:continue
  if depth< -5 and depth> -7:
   deep_sprites.append(sprite)
   check(not sprite.visible and not sprite.is_visible_in_tree() and sprite.get_parent()!=game.transit_view.metro_layer,"deep open-trench car %s is hidden, not sent to the tunnel layer"%pose.id)
  elif depth>= -5 and depth<0:
   shallow_sprites.append(sprite)
   check(not sprite.is_visible_in_tree() and sprite.get_parent() in rail_trenches and float(sprite.get_meta("rail_trench_surface_fraction",1.0))<.5,"car %s is in the trench but its surface roof sliver is hidden"%pose.id)
   var bounds:=Rect2(game.origin+(sprite.position+sprite.offset*sprite.scale)*game.map_zoom,sprite.texture.get_size()*sprite.scale*game.map_zoom)
   check(frame.encloses(bounds) and (not game.drawer.visible or not bounds.intersects(game.drawer.get_global_rect())),"shallow car %s fits in the viewport clear of the drawer"%pose.id)
 check(shallow_sprites.size()==2 and deep_sprites.size()==1,"one descending consist straddles -5m: %s"%str(depths))
 game.transit_view.underground=true;game.transit_view.sync_visibility()
 check(game.transit_view.metro_layer.visible and not deep_sprites.is_empty() and deep_sprites.all(func(sprite):return not sprite.is_visible_in_tree()),"the deep open-trench car stays hidden in underground view")
 check(not shallow_sprites.is_empty() and shallow_sprites.all(func(sprite):return sprite.is_visible_in_tree()),"both retained shallow coaches reappear in underground view")
 game.transit_view.underground=false;game.transit_view.sync_visibility()
 check(not shallow_sprites.is_empty() and shallow_sprites.all(func(sprite):return not sprite.is_visible_in_tree()),"both retained coaches hide again on returning to surface view")
 var trench_poles:=0
 for node in game.world_renderer.catenary_nodes:
  if node.get_parent() in rail_trenches:trench_poles+=1
 check(trench_poles>0,"trench catenary draws inside the trench clip groups: %d"%trench_poles)
 if not trench_path.is_empty() and failures==0:
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image()
  check(image.get_size()==Vector2i(1920,1080),"native ground view is 1920x1080")
  if image.get_size()==Vector2i(1920,1080):
   check(image.save_png(trench_path)==OK,"trench/portal capture saved")
   print("E3B_CAPTURE ",trench_path," display=",DisplayServer.get_name()," renderer=",RenderingServer.get_current_rendering_method())
 # Then a train inside the covered tunnel, drawn like a metro train in the underground view.
 var inside:=await advance_until(city,func(pose:Dictionary):
  var p:Vector2=pose.position/4
  return pose.id==target.get("id","") and p.x>96 and p.x<106 and absf(p.y-(y+30))<1)
 var lead:Sprite2D=game.world_renderer.transit_cars.get(inside.get("id",""))
 check(not deep_sprites.is_empty() and lead==deep_sprites[0] and lead.visible and lead.get_parent()==game.transit_view.metro_layer and not lead.is_visible_in_tree(),"the same retained lead car enters the covered tunnel, hidden from ground view")
 game.map_zoom=1.25;game.origin=Vector2(960,560)-game.world_renderer.iso(Vector2(100,y+30))*game.map_zoom
 game.transit_view.underground=true;game.transit_view.sync_visibility();game.world_renderer.synchronize();game.refresh();await settle();await settle()
 var bands:Array=game.transit_view.geometry.metro.filter(func(s):return s.get("rail_tunnel",false))
 check(game.transit_view.metro_layer.visible and not bands.is_empty(),"the underground view shows the rail tunnel band: %d shapes"%bands.size())
 var tunnel_cars:=0
 for sprite in game.world_renderer.transit_cars.values():
  if sprite.is_visible_in_tree() and sprite.get_parent()==game.transit_view.metro_layer:tunnel_cars+=1
 check(lead!=null and lead.is_visible_in_tree() and tunnel_cars==3,"the full consist in the covered tunnel draws on the underground layer like a metro train: %d"%tunnel_cars)
 if not underground_path.is_empty():
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image()
  check(image.save_png(underground_path)==OK,"underground view capture saved")
  print("E3B_CAPTURE ",underground_path)
 game.transit_view.underground=false;game.transit_view.sync_visibility()
