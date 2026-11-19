extends SceneTree
## Review fixes 1 (BLOCK) and 2 (MAJOR) in the actual main scene.
## Fix 1, user rule 2026-11-19: the bulldozer starts in the ground view, which picks only ground
## objects (ground roads and rails, decks, trenches, portals). PgDn shows the underground view, which
## picks only underground objects (covered road/rail parts, metro) plus trenches and portals, and
## never falls back to ground objects; PgUp returns. Inside a view the top-most drawn part wins (a
## deck over the road below it). Rails follow the same rules as roads.
## Fix 2: a ground train crossing a covered tunnel at a shallow angle is drawn on the ground.
## Capture is explicit (--review-capture=).
const City=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
var game
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;printerr("FAIL ",label)
func settle():
 for i in range(4):await process_frame
func path(values:Array)->PackedVector2Array:
 var r:=PackedVector2Array()
 for v in values:r.append(v)
 return r
func levels(values:Array)->PackedFloat64Array:
 var r:=PackedFloat64Array()
 for v in values:r.append(float(v))
 return r
func describe(t:Dictionary)->String:return "none" if t.is_empty() else "%s#%s"%[t.get("kind",""),str(t.get("id",""))]
## Screen position of a world cell drawn at height h (the transit_view.project_point lift).
func drawn(cell:Vector2,h:float)->Vector2:return game.screen(cell)-Vector2(0,h*game.tile.x/4*sqrt(1.5)*game.map_zoom)
## Ground cells that a +h deck point is drawn over: shifted by h*lift/(2*tile.y) along (-1,-1).
func shift(h:float)->float:return h*game.tile.x/4*sqrt(1.5)/(2*game.tile.y)
func road_at(c,cell:Vector2)->int:
 for i in range(c.roads.size()):
  var road:Dictionary=c.roads[i]
  for j in range(1,road.points.size()):
   if Geometry2D.get_closest_point_to_segment(cell,road.points[j-1],road.points[j]).distance_to(cell)<.05:return int(road.get("parcel_id",i))
 return -1
func is_target(t:Dictionary,kind:String,id:int)->bool:return t.get("kind","")==kind and int(t.get("id",-2))==id
## Rows: [label, cell, drawn height, expected kind ("" = nothing), expected id].
func expect(view:String,rows:Array):
 for row:Array in rows:
  var t:Dictionary=game.demolition_target(drawn(row[1],row[2]))
  check(t.is_empty() if row[3]=="" else is_target(t,row[3],row[4]),"%s view: %s: %s"%[view,row[0],describe(t)])
func click(position:Vector2):
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=position
  game._unhandled_input(event)
 for i in range(4):await process_frame
 # The running simulation may queue the edit; a full development step publishes and replays it
 # (the lift scene's barrier).
 var sim=game.city.simulation
 for i in range(20):
  if sim==null or sim.queued_edit_count()==0:break
  sim.resume();game.city.advance_society(game.city.config.development_interval_seconds);sim.validation_publish();await process_frame
 if sim!=null:sim.resume()
 await settle()
## Real key presses through the viewport, as the player gives them.
func key(code:int):
 for pressed in [true,false]:
  var event:=InputEventKey.new();event.keycode=code;event.pressed=pressed;root.push_input(event,true)
  await settle()
func view_is(below:bool)->bool:return game.mode=="demolish" and game.transit_view.underground==below and game.transit_view.metro_layer.visible==below
func ids(c)->Array:return c.transit_routes.map(func(r):return r.id)
func run():
 Engine.max_fps=30
 root.size=Vector2i(1920,1080)
 var c=City.new(220,130);c.funds=100000000
 var built:Array=[
  c.add_road(path([Vector2(150,4),Vector2(150,52)])),
  c.add_transit_route(path([Vector2(10,30),Vector2(82,30),Vector2(210,30)]),"rail",true,levels([0,-10,-10])),
  c.add_road(path([Vector2(160,56),Vector2(160,96)])),
  c.add_transit_route(path([Vector2(10,76),Vector2(82,76),Vector2(210,76)]),"rail",true,levels([0,10,10])),
  c.add_road(path([Vector2(120,100),Vector2(120,128)])),
  c.add_elevated_road(path([Vector2(10,112),Vector2(42,112),Vector2(150,112)]),levels([0,10,10])),
  c.add_elevated_road(path([Vector2(10,16),Vector2(42,16),Vector2(140,16)]),levels([0,-10,-10])),
  c.add_transit_route(path([Vector2(100,44),Vector2(140,44)]),"rail"),
  c.add_transit_route(path([Vector2(170,100),Vector2(210,100)]),"metro")]
 check(built.all(func(r):return r.ok),"fixture: road over a -10m rail tunnel, road under a +10m viaduct, ground road under an E1 deck, E2 road tunnel, ground rail, metro: "+str(built.map(func(r):return r.get("reason",""))))
 game=load("res://main.tscn").instantiate();game.city=c;root.add_child(game);current_scene=game
 await settle()
 game.bulldozer.pressed.emit();await settle()
 check(view_is(false),"the bulldozer starts in the ground view")
 if not built.all(func(r):return r.ok):
  finish("");return
 var tunnel:int=built[1].route.id;var viaduct:int=built[3].route.id;var rail:int=built[7].route.id;var metro:int=built[8].route.id
 var road_a:=road_at(c,Vector2(150,10));var road_b:=road_at(c,Vector2(160,60));var road_c:=road_at(c,Vector2(120,120))
 var deck:=road_at(c,Vector2(100,112));var road_tunnel:=road_at(c,Vector2(100,16))
 # Trench and portal sides: the rail portal (-7.0m) is at x=60.4, the road portal (-6.0m) at x=29.2.
 var open:Array=[
  ["the rail trench picks the rail tunnel at its opening",Vector2(40,30.3),0.0,"transit_route",tunnel],
  ["the rail portal picks the rail tunnel",Vector2(60.2,30.3),0.0,"transit_route",tunnel],
  ["the road trench picks the road tunnel at its opening",Vector2(20,16.3),0.0,"road",road_tunnel],
  ["the road portal picks the road tunnel",Vector2(29,16.3),0.0,"road",road_tunnel]]
 var ground_view:Array=[
  ["the road over the covered rail tunnel picks the road",Vector2(150,30.3),0.0,"road",road_a],
  ["the covered rail tunnel where the underground view draws it (-10m) is not picked",Vector2(120,30.3),-10.0,"",-1],
  ["metro where the underground view draws it (-12.7m) is not picked",Vector2(190,100.3),-12.7,"",-1],
  ["empty ground over the covered rail tunnel picks nothing",Vector2(120,30.3),0.0,"",-1],
  ["empty ground over the covered road tunnel picks nothing",Vector2(100,16.3),0.0,"",-1],
  ["the covered road tunnel where the underground view draws it (-10m) is not picked",Vector2(100,16.3),-10.0,"",-1],
  ["a ground road picks the road",Vector2(150,10.3),0.0,"road",road_a],
  ["a ground rail picks the rail",Vector2(120,44.3),0.0,"transit_route",rail],
  ["the viaduct deck where it is drawn (+10m) picks the viaduct",Vector2(120,76.3),10.0,"transit_route",viaduct],
  ["the road under the viaduct, outside the drawn deck, picks the road",Vector2(160,76.3),0.0,"road",road_b],
  ["where the drawn viaduct deck covers the road below, the deck wins",Vector2(160,76-shift(10)),0.0,"transit_route",viaduct],
  ["the E1 deck where it is drawn (+10m) picks the elevated road",Vector2(100,112.3),10.0,"road",deck],
  ["the road under the E1 deck, outside the drawn deck, picks the road",Vector2(120,112.3),0.0,"road",road_c],
  ["where the drawn E1 deck covers the road below, the deck wins",Vector2(120,112-shift(10)),0.0,"road",deck]]
 var underground_view:Array=[
  ["the covered rail tunnel where it is drawn (-10m) picks the tunnel",Vector2(120,30.3),-10.0,"transit_route",tunnel],
  ["the covered road tunnel where it is drawn (-10m) picks the road tunnel",Vector2(100,16.3),-10.0,"road",road_tunnel],
  ["metro where it is drawn (-12.7m) picks the metro",Vector2(190,100.3),-12.7,"transit_route",metro],
  ["the ground road over the rail tunnel is not picked",Vector2(150,30.3),0.0,"",-1],
  ["a ground road is not picked",Vector2(150,10.3),0.0,"",-1],
  ["a ground rail is not picked",Vector2(120,44.3),0.0,"",-1],
  ["the viaduct deck where it is drawn (+10m) is not picked",Vector2(120,76.3),10.0,"",-1],
  ["the road under the viaduct is not picked",Vector2(160,76.3),0.0,"",-1],
  ["where the viaduct deck covers the road below, neither is picked",Vector2(160,76-shift(10)),0.0,"",-1],
  ["the E1 deck where it is drawn (+10m) is not picked",Vector2(100,112.3),10.0,"",-1],
  ["the road under the E1 deck is not picked",Vector2(120,112.3),0.0,"",-1],
  ["where the E1 deck covers the road below, neither is picked",Vector2(120,112-shift(10)),0.0,"",-1]]
 expect("ground",ground_view+open)
 await key(KEY_PAGEDOWN)
 check(view_is(true) and game.road_drawer.target_height_m==0 and game.transit_view.target_height_m==0,"PgDn in the bulldozer shows the underground view; build tool heights stay 0m")
 await key(KEY_PAGEDOWN)
 check(view_is(true),"PgDn again stays in the underground view (the bulldozer has no height steps)")
 expect("underground",underground_view+open)
 await key(KEY_PAGEUP)
 check(view_is(false),"PgUp returns the bulldozer to the ground view")
 await key(KEY_PAGEUP)
 check(view_is(false),"PgUp again stays in the ground view")
 expect("ground after PgUp",ground_view.slice(0,3))
 var before:Array=ids(c)
 await click(game.screen(Vector2(150,30.3)))
 check(ids(c)==before and road_at(c,Vector2(150,30))==-1,"ground view: clicking the road over the rail tunnel removes the road and keeps every rail route: %s -> %s"%[str(before),str(ids(c))])
 await key(KEY_PAGEDOWN)
 var roads:int=c.roads.size()
 var t:Dictionary=game.demolition_target(drawn(Vector2(120,30.3),-10))
 await click(drawn(Vector2(120,30.3),-10))
 check(not ids(c).has(tunnel) and ids(c).size()==before.size()-1 and c.roads.size()==roads,"underground view: clicking the covered rail tunnel where it is drawn removes only the tunnel: %s %s -> %s %s"%[describe(t),str(before),str(ids(c)),game.message])
 await key(KEY_PAGEUP)
 check(view_is(false),"PgUp after the underground removal returns to the ground view")
 var capture:=""
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--review-capture="):capture=arg.trim_prefix("--review-capture=")
 await shallow_tunnel(capture)
 finish("")
func finish(_note:String):
 if game!=null and game.city!=null and game.city.simulation!=null:game.city.simulation.shutdown()
 print("REVIEW_FIX_UI checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
## Same worker flow as the E3b capture: fixed development steps until a rail car matches.
func advance_until(city,matches:Callable)->Dictionary:
 var target:Dictionary={}
 for step in range(400):
  city.simulation.resume();city.advance_society(city.config.development_interval_seconds);city.simulation.validation_publish()
  for pose:Dictionary in city.transit_state.get("visible",[]):
   if pose.kind=="rail" and matches.call(pose.position/4):target=pose
  if not target.is_empty():break
 city.simulation.resume();game.paused=true
 game.world_renderer.synchronize();game.refresh();await settle();await settle()
 return target
func shallow_tunnel(capture:String):
 if not capture.is_empty() and (DisplayServer.get_name()=="headless" or FileAccess.file_exists(capture)):
  check(false,"native capture requires a real display and a new destination");return
 game.mode="select"
 if game.city.simulation!=null:game.city.simulation.shutdown()
 # Real stations and an operating line on a ground track that crosses a covered tunnel at 15 degrees.
 var city=City.new(240,110,42)
 city.population_enabled=false;city.happiness_enabled=false;city.funds=1000000
 city.add_road(path([Vector2(2,40),Vector2(230,40)]),"local",true,4)
 for x:float in [30.0,190.0]:check(city.public_facilities.place("train-station-01",Vector2(x,33.0),0,true).ok,"lift scene station at x=%d"%x)
 var a:PackedVector2Array=city.public_facilities.lots[0].internal_points
 var b:PackedVector2Array=city.public_facilities.lots[1].internal_points
 if a[0].x>a[-1].x:a.reverse()
 if b[0].x>b[-1].x:b.reverse()
 var join:Dictionary=city.add_transit_route(PackedVector2Array([a[-1],b[0]]))
 var y:float=a[0].y;var cross:=Vector2(110,y);var d:=Vector2.from_angle(deg_to_rad(15.0))
 # 3.5% descent reaching -10m 10 cells before the crossing; the -7.0m portal is 31.6 cells before it.
 var tunnel:Dictionary=city.add_transit_route(PackedVector2Array([cross-d*82,cross-d*10,cross+d*50]),"rail",true,levels([0,-10,-10]))
 check(join.ok and tunnel.ok,"lift scene: ground line over a 15 degree covered tunnel: %s %s"%[join.get("reason",""),tunnel.get("reason","")])
 var line:Dictionary=city.create_transit_line("rail",city.public_facilities.lots.map(func(lot):return lot.id))
 check(line.ok,"lift scene: operating line on the ground track: "+str(line.get("reason","")))
 if not (join.ok and tunnel.ok and line.ok):return
 game.city=city
 city.enable_simulation_worker();city.simulation.worker.Suspend()
 var target:=await advance_until(city,func(p:Vector2):return absf(p.x-cross.x)<2.5 and absf(p.y-y)<1)
 check(not target.is_empty(),"an operating train reaches the crossing over the tunnel: fault=%s"%str(city.simulation.get_fault()))
 game.public_controller.cancel();game.select_category("transport");game.mode="select"
 # Frame the open trench, the portal and the crossing above the bottom toolbar.
 var portal:=cross-d*31.6
 game.map_zoom=.85
 game.origin=Vector2(960,370)-game.world_renderer.iso((portal+cross)/2)*game.map_zoom
 game.world_renderer.synchronize();game.refresh();await settle();await settle()
 var near:=0;var ground:=0;var own:=0;var rows:Array=[]
 for pose:Dictionary in city.transit_state.get("visible",[]):
  if pose.kind!="rail" or (pose.position/4).distance_to(cross)>25:continue
  near+=1
  if int(pose.get("route_id",-1))==int(join.route.id):own+=1
  var sprite=game.world_renderer.transit_cars.get(pose.id)
  if sprite!=null and sprite.visible and sprite.get_parent()==game.world_renderer.actors and float(sprite.get_meta("rail_height_m",1.0))==0.0:ground+=1
  rows.append([str(pose.id),pose.get("route_id","none"),snappedf(float(sprite.get_meta("rail_height_m",0.0)) if sprite!=null else NAN,.01),sprite.get_parent().name if sprite!=null else "none"])
 check(near>0 and own==near,"cars within 100m of the crossing carry the ground route they run on: %d/%d %s"%[own,near,str(rows)])
 check(near>0 and ground==near,"every car within 100m of the crossing is drawn on the ground, none in the tunnel: %d/%d"%[ground,near])
 if not capture.is_empty():
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image()
  check(image.get_size()==Vector2i(1920,1080),"native capture is 1920x1080")
  check(image.save_png(capture)==OK,"shallow-angle tunnel crossing capture saved")
  print("REVIEW_CAPTURE ",capture," display=",DisplayServer.get_name())
