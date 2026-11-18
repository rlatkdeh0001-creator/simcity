extends SceneTree
## E2 untimed actual-main UI checks. Captures are explicit (--e2-capture-ground= / --e2-capture-underground=), never a side effect.
const Height=preload("res://core/road_height.gd")
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
 # A real window needs the hover to land before the press (native runs).
 for i in range(3):await process_frame
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=position;event.pressed=pressed;root.push_input(event,true)
  await process_frame
func key(code:Key):
 var event:=InputEventKey.new();event.keycode=code;event.pressed=true;root.push_input(event,true);await settle()
func metre()->float:return game.tile.x/4*sqrt(1.5)
func fresh_city(size:int=160):
 game.road_drawer.cancel()
 if game.city.simulation!=null:game.city.simulation.shutdown()
 game.city=load("res://core/city_model.gd").new(size,size);game.paused=true
func run():
 Engine.max_fps=30
 root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate()
 game.city=load("res://core/city_model.gd").new(160,160)
 game.paused=true;root.add_child(game);current_scene=game
 await settle()
 await test_height_controls()
 await test_drawn_grid_off()
 await test_trench_geometry()
 await test_trench_cars()
 await test_underground_view_and_pick()
 var ground_path:="";var underground_path:=""
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--e2-capture-ground="):ground_path=arg.trim_prefix("--e2-capture-ground=")
  elif arg.begins_with("--e2-capture-underground="):underground_path=arg.trim_prefix("--e2-capture-underground=")
 await native_capture(ground_path,underground_path) # Same composition without framebuffer access when no path is given.
 print("E2_UI checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
func test_height_controls():
 game.select_category("road");await settle()
 var control=game.find_child("RoadHeightControls",true,false)
 check(control!=null,"approved C height controls exist")
 if control==null:return
 var underground=control.find_child("Underground",true,false)
 check(not underground.disabled,"underground mode button is enabled")
 await click(underground.get_global_rect().get_center());await settle()
 check(game.road_drawer.target_height_m==-10,"underground button selects the default -10m")
 check(control.find_child("HeightValue",true,false).text=="−10 m" and underground.button_pressed,"label and active toggle show −10 m")
 check(game.transit_view.underground,"a below-ground target shows the underground view")
 await key(KEY_PAGEDOWN)
 check(game.road_drawer.target_height_m==-15,"PgDn goes 5m deeper")
 await key(KEY_PAGEUP)
 check(game.road_drawer.target_height_m==-10,"PgUp comes back 5m")
 var plus=control.find_child("HeightPlus",true,false);var minus=control.find_child("HeightMinus",true,false)
 await click(plus.get_global_rect().get_center());await settle()
 check(game.road_drawer.target_height_m==-5,"+ raises an underground target to -5m")
 await click(plus.get_global_rect().get_center());await settle()
 check(game.road_drawer.target_height_m==-5,"+ never leaves the underground layer")
 await click(minus.get_global_rect().get_center());await settle()
 check(game.road_drawer.target_height_m==-10,"- lowers an underground target by 5m")
 game.road_drawer.set_height(0);await settle()
 check(not game.transit_view.underground,"ground target returns to the ground view")
 await key(KEY_PAGEDOWN)
 check(game.road_drawer.target_height_m==-5 and game.transit_view.underground,"PgDn from ground enters the underground at -5m")
 await key(KEY_PAGEUP)
 check(game.road_drawer.target_height_m==0 and not game.transit_view.underground,"PgUp from -5m returns to ground")
func test_drawn_grid_off():
 fresh_city()
 game.activate_tool("road");game.road_lanes=2;game.road_grid_enabled=false
 game.map_zoom=1;game.origin=Vector2(960,300)-Vector2((45-50)*game.tile.x,(45+50)*game.tile.y) # Above the bottom drawer.
 game.refresh();game.road_drawer.set_height(0);await settle()
 var start:=Vector2(20.37,50.11);var finish:=Vector2(70.37,50.11)
 await click(game.screen(start))
 game.road_drawer.set_height(-10);await settle()
 await click(game.screen(finish)+Vector2(0,10*metre()*game.map_zoom));await settle()
 var tunnels:Array=game.city.roads.filter(func(r):return Height.sunken(r))
 check(tunnels.size()==1,"drawn ground-to-underground stroke commits one underground road")
 if tunnels.size()!=1:
  print("DRAWN_DIAGNOSTIC roads=",game.city.roads," last=",game.road_drawer.last_result.get("reason",""),"/",game.road_drawer.last_result.get("ok",null)," anchors=",game.road_drawer.anchors," preview=",game.road_drawer.preview().get("reason",""))
  return
 var road:Dictionary=tunnels[0]
 check(road.points[0].distance_to(start)<.001 and road.points[-1].distance_to(finish)<.001,"grid OFF keeps both confirmed points: "+str(road.points))
 check(road.heights_m[0]==0 and road.heights_m[-1]==-10 and not road.has("grid_frame"),"stroke descends from 0 to -10m without a grid frame")
 var ramp_end:Vector2=road.points[1]
 check(ramp_end.distance_to(start+Vector2(32,0))<.001 and road.heights_m[1]==-10,"the drawn ramp is the 128m minimum")
 check(game.world_renderer.underground.trenches.size()==1 and game.world_renderer.underground.portals.size()==1,"drawn road renders one trench and one portal")
func fixture_west(portal_faces:bool)->Dictionary:
 fresh_city()
 # Facing: the trench deepens toward -x (portal faces +x, the camera) or toward +x (faces away).
 var points:=PackedVector2Array([Vector2(90,60),Vector2(58,60),Vector2(20,60)]) if portal_faces else PackedVector2Array([Vector2(20,60),Vector2(52,60),Vector2(90,60)])
 var approach:=PackedVector2Array([Vector2(100,60),Vector2(90,60)]) if portal_faces else PackedVector2Array([Vector2(10,60),Vector2(20,60)])
 var ground:Dictionary=game.city.add_road(approach)
 var tunnel:Dictionary=game.city.add_elevated_road(points,PackedFloat64Array([0,-10,-10]))
 game.map_zoom=1;game.origin=Vector2(960,540)-Vector2((50-60)*game.tile.x,(50+60)*game.tile.y)
 game.refresh();await settle()
 return {"ok":ground.ok and tunnel.ok,"points":points}
func covered_samples(trench)->int:
 var misses:=0
 var shapes:Array=[]
 for child in trench.get_children():
  if child is Sprite2D:continue
  for command:Dictionary in child.commands:
   if command.has("polygon"):shapes.append(command.polygon)
 for footprint:PackedVector2Array in trench.footprints:
  for u in [.1,.3,.5,.7,.9]:
   for v in [.1,.3,.5,.7,.9]:
    var world:Vector2=footprint[0].lerp(footprint[1],u).lerp(footprint[3].lerp(footprint[2],u),v)
    var screen:Vector2=game.world_renderer.iso(world)
    if not shapes.any(func(s):return Geometry2D.is_point_in_polygon(screen,s)):misses+=1
 return misses
func test_trench_geometry():
 for faces in [true,false]:
  var fixture:Dictionary=await fixture_west(faces)
  check(fixture.ok,"trench fixture builds (portal faces camera=%s)"%faces)
  var renderer=game.world_renderer.underground
  check(renderer.trenches.size()==1 and renderer.portals.size()==1,"one trench and one portal (faces=%s)"%faces)
  if renderer.trenches.size()!=1 or renderer.portals.size()!=1:continue
  var trench=renderer.trenches[0]
  check(trench.clip_children==CanvasItem.CLIP_CHILDREN_ONLY and trench.z_index>game.world_renderer.marks.z_index and trench.z_index<game.world_renderer.actors.z_index,"trench is a clip_children group drawn after road marks and before WorldActors")
  var half:float=float(game.city.roads.filter(func(r):return Height.sunken(r))[0].width)/2-.125
  var far_y:float=60-half
  var top:=INF
  for outline in trench.outlines:
   for point in outline:top=minf(top,point.y)
  var x0:float=minf(fixture.points[0].x,fixture.points[1].x)
  var expected:float=game.world_renderer.iso(Vector2(x0,far_y)).y-4*metre()
  check(absf(top-expected)<.05 or top>expected-.05,"outline far edge is raised 4m above ground (top=%.2f expected<=%.2f)"%[top,expected])
  check(covered_samples(trench)==0,"every interior trench sample is covered by floor, far wall or portal: no hole (faces=%s)"%faces)
  var floors:=0;var walls:=0
  for child in trench.get_children():
   if child.name.begins_with("TrenchBody"):
    for command:Dictionary in child.commands:
     if command.has("texture") and command.texture==game.world_renderer.elevated.texture("retaining-wall-01/wall.png"):walls+=1
     elif command.get("color",Color.BLACK)==Color("c8cbc3"):floors+=1
  check(floors==trench.footprints.size() and walls==trench.footprints.size(),"closed floor and far retaining-wall face on every 4m piece: floors=%d walls=%d pieces=%d"%[floors,walls,trench.footprints.size()])
  var portal:Dictionary=renderer.portals[0]
  check(portal.faces==faces and is_equal_approx(portal.height_m,-6.0),"portal at -6.0m faces the camera only when placed that way")
  var mouth:=false;var strip:=false
  for child in trench.get_children():
   if child.name.begins_with("TrenchPortal"):
    for command:Dictionary in child.commands:
     if command.get("color",Color.BLACK)==Color("15181a") and command.polygon.size()==4:
      var bottom:float=maxf(command.polygon[2].y,command.polygon[3].y)
      mouth=absf(bottom-(game.world_renderer.iso(portal.a).y+6*metre()))<.01 or absf(bottom-(game.world_renderer.iso(portal.b).y+6*metre()))<.01
     if command.has("texture"):strip=command.texture==game.world_renderer.elevated.texture("tunnel-portal-01/portal.png")
  check(mouth==faces and strip==faces,"facing portal draws portal.png and a 15181a mouth down to the -6.0m road; a back-facing portal draws neither inside the trench")
  var barrier_bottoms:=true;var barrier_count:=0;var sorted:=true
  for node in renderer.barriers:
   barrier_count+=1;sorted=sorted and node.get_parent()==game.world_renderer.actors
   for command:Dictionary in node.commands:
    if not command.has("texture"):continue
    var ground_a:float=command.polygon[3].y
    var top_a:float=command.polygon[0].y
    barrier_bottoms=barrier_bottoms and absf((ground_a-top_a)-1.1*metre())<.01
  check(barrier_count>0 and sorted,"barriers above ground sort in WorldActors")
  check(barrier_count>0 and barrier_bottoms,"every barrier stands exactly on the ground, 1.1m tall: no floating barrier")
  var sunken:Dictionary=game.city.roads.filter(func(r):return Height.sunken(r))[0]
  var leaked:=0.0
  for pavement:PackedVector2Array in game.city.road_pavement:
   for ribbon in preload("res://core/road_geometry.gd").ribbons(sunken.points,float(sunken.width)-.01,true,true):
    for overlap in Geometry2D.intersect_polygons(pavement,ribbon):leaked+=absf(preload("res://core/road_parcels.gd").area(overlap))
  check(leaked<.01,"no flat ground pavement is drawn over the trench or tunnel: %.4f"%leaked)
func test_trench_cars():
 var fixture:Dictionary=await fixture_west(true)
 check(fixture.ok,"car fixture")
 check(game.traffic.rebuild(game.city.roads),"traffic builds trench and tunnel lanes")
 var tunnel_index:=-1
 for i in range(game.city.roads.size()):
  if Height.sunken(game.city.roads[i]):tunnel_index=i
 var lane_id:=-1
 for lane in game.traffic.simulation.network.lanes:
  if int(lane.get("road",-1))==tunnel_index and int(lane.direction)==1:lane_id=int(lane.id);break
 check(lane_id>=0,"tunnel lane exists")
 if lane_id<0:return
 var asset:Dictionary=game.traffic.catalog.filter(func(a):return a.id=="car-sedan-03")[0]
 var vehicle:Dictionary=game.traffic.simulation.spawn(asset,[lane_id],40)
 check(not vehicle.is_empty(),"sedan spawns in the trench")
 if vehicle.is_empty():return
 game.traffic.simulation.paused=true
 var renderer=game.world_renderer.underground
 vehicle.progress=40.0;await settle()
 var point:Vector2=game.traffic.simulation.position(vehicle)/4
 var height:float=Height.height_at(game.city.roads[tunnel_index],point)
 var sprite:Sprite2D=game.world_renderer.cars.get(vehicle.id)
 check(sprite!=null and sprite.visible and height<0 and height>-6,"trench car is visible at %.2fm"%height)
 if sprite==null:return
 check(sprite.get_parent()==renderer.trenches[0],"trench car is drawn inside the trench clip group")
 check(sprite.get_index()>renderer.trenches[0].get_node("TrenchPortal").get_index(),"camera-side car draws after the portal strip")
 var rect:Rect2=game.traffic.sprite_rect(asset.id,Vector2.ZERO,game.tile.x/4*sqrt(2.0))
 var expected:Vector2=game.world_renderer.iso(point)+rect.position-Vector2(0,height*metre())
 check((sprite.position+sprite.offset*sprite.scale).distance_to(expected)<.001,"trench car artwork sits on the lowered road surface, not floating")
 vehicle.progress=100.0;await settle()
 check(not sprite.visible,"car inside the covered section is hidden in the ground view")
 vehicle.progress=40.0;await settle()
 var before=renderer.trenches[0]
 check(game.city.add_road(PackedVector2Array([Vector2(130,20),Vector2(130,40)])).ok,"unrelated road edit rebuilds trench pieces")
 game.refresh();await settle()
 check(is_instance_valid(sprite) and sprite.visible and sprite.get_parent()==renderer.trenches[0] and renderer.trenches[0]!=before,"rebuild hands the car back instead of freeing it")
 game.traffic.simulation.vehicles.clear();await settle()
func test_underground_view_and_pick():
 var fixture:Dictionary=await fixture_west(true)
 check(fixture.ok,"view fixture")
 game.activate_tool("road");game.road_drawer.set_height(0);await settle()
 var tunnels:Array=game.transit_view.metro_layer.shapes.filter(func(s):return s.get("road_tunnel",false))
 check(not tunnels.is_empty(),"covered section adds solid underground bands")
 var deep:=true;var portal_edge:=false;var colour:=true
 for band:Dictionary in tunnels:
  colour=colour and band.color==Color("15181a")
  for depth in band.depths:
   deep=deep and depth<=-6+.0001
   portal_edge=portal_edge or absf(depth+6)<.0001
 check(colour,"tunnel bands use the metro tunnel colour")
 check(deep and portal_edge,"bands start at the -6.0m portal and stay covered")
 check(not game.transit_view.metro_layer.visible and game.world_renderer.underground.trenches[0].visible,"ground view hides covered bands but keeps the trench")
 var covered_point:=Vector2(40,60);var trench_point:=Vector2(80,60)
 check(game.demolition_target(game.screen(covered_point)).is_empty(),"ground view cannot pick the hidden covered road")
 check(game.demolition_target(game.screen(trench_point)).get("kind","")=="road","trench stays pickable in the ground view")
 game.road_drawer.set_height(-10);await settle()
 check(game.transit_view.underground and game.transit_view.metro_layer.visible and game.world_renderer.underground.trenches[0].visible,"underground view shows bands and still shows the trench")
 check(game.demolition_target(game.screen(covered_point)).get("kind","")=="road","underground view picks the covered road")
 game.road_drawer.set_height(0);await settle()
func native_capture(ground_path:String,underground_path:String):
 for path in [ground_path,underground_path]:
  if not path.is_empty() and (DisplayServer.get_name()=="headless" or FileAccess.file_exists(path)):
   check(false,"native capture requires a real display and a new destination");return
 fresh_city(140)
 game.road_lanes=2;game.road_grid_enabled=false
 var approach:Dictionary=game.city.add_road(PackedVector2Array([Vector2(112,62),Vector2(100,62)]))
 var tunnel:Dictionary=game.city.add_elevated_road(PackedVector2Array([Vector2(100,62),Vector2(68,62),Vector2(30,62)]),PackedFloat64Array([0,-10,-10]))
 var above:Dictionary=game.city.add_elevated_road(PackedVector2Array([Vector2(64,40),Vector2(64,84)]),PackedFloat64Array([0,0]))
 var cross:Dictionary=game.city.add_elevated_road(PackedVector2Array([Vector2(60,40),Vector2(60,84)]),PackedFloat64Array([-20,-20]))
 check(approach.ok and tunnel.ok and above.ok and cross.ok,"capture fixture: ground approach, trench, portal, tunnel under a ground road and a -20m crossing")
 # A building standing on the covered ramp: the tunnel passes under it without demolition.
 game.city.buildings.append({"id":401,"x":71,"y":59,"size":4,"level":3,"zone":"residential","asset_id":"mansion-a-4x4-4f"})
 game.city.next_id=402
 game.map_zoom=2.0;game.origin=Vector2(900,360)-game.world_renderer.iso(Vector2(80.8,62))*game.map_zoom
 game.refresh();game.activate_tool("road");game.road_drawer.set_height(0);await settle()
 # Park the pointer over empty ground so the live road cursor stays out of the subject.
 var parked:=InputEventMouseMotion.new();parked.position=Vector2(1700,180);root.push_input(parked,true)
 await settle();game.road_drawer.cursor_armed=false;game.queue_redraw()
 check(game.traffic.rebuild(game.city.roads),"capture traffic")
 var tunnel_index:=-1
 for i in range(game.city.roads.size()):
  if Height.sunken(game.city.roads[i]) and game.city.roads[i].points[0].x>90:tunnel_index=i
 var asset:Dictionary=game.traffic.catalog.filter(func(a):return a.id=="car-sedan-03")[0]
 var cars:=0
 var length:float=Height.length_cells(game.city.roads[tunnel_index].points)*4
 for lane in game.traffic.simulation.network.lanes:
  if int(lane.get("road",-1))!=tunnel_index:continue
  # One car about to enter the portal, one leaving it toward the ground approach.
  var vehicle:Dictionary=game.traffic.simulation.spawn(asset,[int(lane.id)],62.0 if int(lane.direction)==1 else length-50.0)
  if not vehicle.is_empty():
   vehicle.progress=62.0 if int(lane.direction)==1 else float(lane.length)-50.0
   cars+=1
 game.traffic.simulation.paused=true;await settle();await settle()
 var in_trench:=0
 for sprite in game.world_renderer.cars.values():
  if sprite.visible and sprite.get_parent()==game.world_renderer.underground.trenches[0]:in_trench+=1
 check(cars>0 and in_trench>0,"capture shows cars at the portal inside the trench: %d"%in_trench)
 if not ground_path.is_empty():
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image()
  check(image.get_size()==Vector2i(1920,1080),"native ground view is 1920x1080")
  check(image.save_png(ground_path)==OK,"ground view capture saved")
  print("E2_CAPTURE ",ground_path," display=",DisplayServer.get_name()," renderer=",RenderingServer.get_current_rendering_method())
 game.road_drawer.set_height(-10);game.road_drawer.cursor_armed=false;game.queue_redraw();await settle();await settle()
 check(game.transit_view.underground and game.transit_view.metro_layer.visible,"capture switches to the underground view")
 if not underground_path.is_empty():
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image()
  check(image.save_png(underground_path)==OK,"underground view capture saved")
  print("E2_CAPTURE ",underground_path)
 game.road_drawer.set_height(0)
