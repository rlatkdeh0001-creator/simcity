extends SceneTree
## Underground view (user rule 2026-11-19, ASSET_REQUEST_ELEVATED_TUNNEL_KO.md 8항: "지하보기에서는
## 지하에있는 도로,철도,지하철만 보여야해") in the actual main scene, with real keys and clicks.
## Display: every entry path (road tool below 0m, rail tool below 0m, metro tool, bulldozer PgDn)
## hides the ground layers as whole parents (zoning, grid, ground roads and rails, WorldActors with
## buildings, decks, stations, catenary and ground cars, power and water) and shows the underground
## layer, trenches and portals; the terrain stays, desaturated and not darker. The ground view returns
## everything, including a building built while the underground view was open.
## Bulldozer: in the underground view (PgDn), an independent metro ribbon can be picked outside a
## station silhouette, but inside the silhouette the station wins. Ground objects are not picked.
## Captures are explicit: --underground-capture=<png> and --ground-capture=<png> (native display).
## Part 1 captures: --outline-ground-capture=<png>, --outline-underground-capture=<png>,
## --station-overlap-capture=<png>.
const City=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
var game
var ids_of:={}
var depth_car:Sprite2D
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
func road_at(c,cell:Vector2)->int:
 for i in range(c.roads.size()):
  var road:Dictionary=c.roads[i]
  for j in range(1,road.points.size()):
   if Geometry2D.get_closest_point_to_segment(cell,road.points[j-1],road.points[j]).distance_to(cell)<.05:return int(road.get("parcel_id",i))
 return -1
func lot_of(c,asset:String)->Dictionary:
 for lot:Dictionary in c.public_facilities.lots:
  if lot.get("public_asset_id","")==asset:return lot
 return {}
func centre(polygon:PackedVector2Array)->Vector2:
 var sum:=Vector2.ZERO
 for p in polygon:sum+=p
 return sum/maxf(1,polygon.size())
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
 await publish_edit()
func publish_edit():
 # The running simulation may queue the edit; a full development step publishes and replays it.
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
## Buildings, a ground road and rail with a ground station, a bus stop, a power plant, an E1 deck,
## an E2 road tunnel (trench, portal, covered part with a building over it), metro and a metro station.
func fixture()->Dictionary:
 var c=City.new(100,90)
 c.population_enabled=false;c.happiness_enabled=false;c.funds=100000000
 var built:Array=[c.add_road(path([Vector2(2,40),Vector2(94,40)]),"local",true,4)]
 for item in [["train-station-01",Vector2(30,33)],["bus-stop-01",Vector2(15,37.8125)],["subway-entrance-01",Vector2(85,36.5)]]:
  built.append(c.public_facilities.place(item[0],item[1],0,true))
 built.append_array([
  c.add_transit_route(path([Vector2(10,30.5),Vector2(26,30.5)]),"rail"),
  c.add_transit_route(path([Vector2(34,30.5),Vector2(66,30.5)]),"rail"),
  c.add_elevated_road(path([Vector2(10,60),Vector2(42,60),Vector2(94,60)]),levels([0,-10,-10])),
  c.add_elevated_road(path([Vector2(10,76),Vector2(42,76),Vector2(94,76)]),levels([0,10,10])),
  c.add_transit_route(path([Vector2(46,50),Vector2(94,50)]),"metro")])
 # A power plant needs a lot right beside a 2-lane road (half-cell centreline phase, as in test_demolition).
 built.append(c.add_road(path([Vector2(4,50.5),Vector2(30,50.5)])))
 var plant:Dictionary={}
 for spot:Vector2 in [Vector2(16,47)]:
  plant=c.add_power_plant(spot)
  if plant.ok:break
 built.append(plant)
 c.buildings.append({"id":901,"x":40,"y":44,"size":4,"level":3,"zone":"residential","asset_id":"mansion-a-4x4-4f","score":0.0})
 # A building standing over the covered road: the tunnel passes under it.
 c.buildings.append({"id":902,"x":60,"y":58,"size":4,"level":3,"zone":"residential","asset_id":"mansion-a-4x4-4f"})
 c.next_id=maxi(c.next_id,903)
 var station:=lot_of(c,"subway-entrance-01")
 var result:Dictionary={}
 if not station.is_empty():
  var center:=centre(station.polygon)
  var across:=station_cross_direction(station)
  # Author a saved-layout overlap: current construction rejects a ribbon crossing the existing lot.
  # Both records use normal model APIs and silhouettes; this fixture does not relax construction.
  var lot_index:int=c.public_facilities.lots.find(station)
  c.public_facilities.lots.remove_at(lot_index)
  result=c.add_transit_route(path([center-across*12,center+across*12]),"metro")
  c.public_facilities.lots.insert(lot_index,station)
 return {"city":c,"built":built,"crossing":result}
func run():
 Engine.max_fps=30
 root.size=Vector2i(1920,1080)
 var made:Dictionary=fixture();var c=made.city;var built:Array=made.built
 check(built.all(func(r):return r.get("ok",false)),"fixture: ground road, ground station, bus stop, metro station, ground rail, road tunnel, E1 deck, metro, power plant: "+str(built.map(func(r):return r.get("reason",""))))
 check(made.crossing.get("ok",false),"fixture: independent metro crosses the station silhouette: %s"%made.crossing.get("reason",""))
 if not built.all(func(r):return r.get("ok",false)) or not made.crossing.get("ok",false):
  finish();return
 game=load("res://main.tscn").instantiate();game.city=c;root.add_child(game);current_scene=game
 await settle()
 game.map_zoom=.55;game.origin=Vector2(960,500)-game.world_renderer.iso(Vector2(52,55))*game.map_zoom
 game.refresh();await settle()
 ids_of={"tunnel":road_at(c,Vector2(70,60)),"deck":road_at(c,Vector2(70,76)),"road":road_at(c,Vector2(50,40)),
  "metro":int(built[8].route.id),"crossing":int(made.crossing.route.id),"rail":int(built[5].route.id),"station":int(lot_of(c,"train-station-01").id),
  "bus_stop":int(lot_of(c,"bus-stop-01").id),"subway":int(lot_of(c,"subway-entrance-01").id),"plant":int(built[-1].id)}
 await display(c)
 if DisplayServer.get_name()!="headless":await selected_outline(c)
 await bulldozer(c)
 if DisplayServer.get_name()!="headless":await trench_occlusion(c)
 finish()
## WCAG relative luminance and contrast ratio.
func luminance(colour:Color)->float:
 var linear:=func(v:float)->float:return v/12.92 if v<=.04045 else pow((v+.055)/1.055,2.4)
 return .2126*linear.call(colour.r)+.7152*linear.call(colour.g)+.0722*linear.call(colour.b)
func contrast(a:Color,b:Color)->float:
 var la:=luminance(a);var lb:=luminance(b)
 return (maxf(la,lb)+.05)/(minf(la,lb)+.05)
func capture_arg(name:String)->String:
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--%s="%name):return arg.trim_prefix("--%s="%name)
 return ""
func framebuffer()->Image:
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func move_pointer(position:Vector2):
 var event:=InputEventMouseMotion.new();event.position=position;root.push_input(event,true)
 await settle()
func viewport_click(position:Vector2):
 await move_pointer(position)
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=position
  root.push_input(event,true)
  await settle()
func white_added(before:Image,after:Image,area:Rect2i)->int:
 var count:=0
 for y in range(area.position.y,area.end.y):
  for x in range(area.position.x,area.end.x):
   if after.get_pixel(x,y).is_equal_approx(Color.WHITE) and not before.get_pixel(x,y).is_equal_approx(Color.WHITE):count+=1
 return count
func selected_outline(c):
 var old_zoom:float=game.map_zoom;var old_origin:Vector2=game.origin
 game.map_zoom=1.0
 game.origin=Vector2(960,470)-game.world_renderer.iso(Vector2(47,50))*game.map_zoom
 game.mode="select";game.refresh();await settle()
 var building:Dictionary=c.find_building(901)
 var area:=Rect2i(Rect2(game.screen(Vector2(42,46))-Vector2(45,75),Vector2(90,110)))
 var baseline:Image=await framebuffer()
 # Click the actual rendered sprite (not the ground footprint behind its transparent pixels).
 var visual:Dictionary=game.building_visual(building)
 var target:Vector2=visual.rect.get_center() if not visual.is_empty() else game.screen(Vector2(42,46))-Vector2(0,game.visual_lift(building)*game.map_zoom)
 await viewport_click(target)
 check(game.selected==901,"native map click selects the building")
 await viewport_click(game.bulldozer.get_global_rect().get_center())
 await move_pointer(Vector2(1830,140))
 check(game.mode=="demolish" and game.selected==901,"bulldozer preserves the selected building above ground")
 var selected_ground:Image=await framebuffer()
 var outline_pixels:=white_added(baseline,selected_ground,area)
 check(outline_pixels>20,"selected building shows a white contour above ground (%d pixels)"%outline_pixels)
 await key(KEY_PAGEDOWN)
 check(game.transit_view.underground and game.selected==901,"PgDn preserves the selected building ID")
 var selected_below:Image=await framebuffer()
 await save_capture(capture_arg("outline-underground-capture"),"selected building: underground view",selected_below)
 game.selected=-1;game.queue_redraw();await settle()
 var unselected_below:Image=await framebuffer()
 check(selected_below.get_region(area).get_data()==unselected_below.get_region(area).get_data(),"the selected building leaves no contour pixels underground")
 game.selected=901;game.queue_redraw();await settle()
 await key(KEY_PAGEUP)
 var restored_ground:Image=await framebuffer()
 check(game.selected==901 and restored_ground.get_region(area).get_data()==selected_ground.get_region(area).get_data(),"PgUp restores the identical selected-building contour")
 await save_capture(capture_arg("outline-ground-capture"),"selected building: restored ground view",restored_ground)
 game.map_zoom=old_zoom;game.origin=old_origin
 game.selected=-1;game.refresh();await settle()
func save_capture(path:String,label:String,image:Image=null)->Image:
 if path.is_empty():return null
 if DisplayServer.get_name()=="headless" or FileAccess.file_exists(path):
  check(false,"native capture requires a real display and a new destination: "+path);return null
 if image==null:image=await framebuffer()
 check(image.get_size()==Vector2i(1920,1080),label+" capture is 1920x1080")
 check(image.save_png(path)==OK,label+" capture saved")
 print("UNDERGROUND_CAPTURE ",path," display=",DisplayServer.get_name())
 return image
## Nodes the underground view hides (ground objects) and shows (underground roads, rails, metro,
## trenches and portals). Missing nodes are reported as failures by the callers.
func hidden_nodes()->Dictionary:
 var r=game.world_renderer
 return {"zoning colours":r.zones,"zoning grid":r.grid,"ground roads":r.roads,"road marks":r.marks,"ground rails":game.transit_view.rail_layer,
  "WorldActors":r.actors,"a building":r.buildings.get(901),"the building over the covered road":r.buildings.get(902),
  "an E1 deck piece":r.elevated.nodes[0] if not r.elevated.nodes.is_empty() else null,
  "a ground station part":r.station_parts.values()[0] if not r.station_parts.is_empty() else null,
  "the bus stop":r.buildings.get(ids_of.bus_stop),"the metro station entrance":r.buildings.get(ids_of.subway),
  "a catenary node":r.catenary_nodes[0] if not r.catenary_nodes.is_empty() else null,
  "power":game.power_overlay,"water":game.water_overlay}
func shown_nodes()->Dictionary:
 var r=game.world_renderer
 return {"the terrain":r.ground,"the underground layer":game.transit_view.metro_layer,
  "the trench":r.underground.trenches[0] if not r.underground.trenches.is_empty() else null,
  "a trench barrier":r.underground.barriers[0] if not r.underground.barriers.is_empty() else null,
  "the metro station silhouette":r.metro_stations.get(ids_of.subway)}
func states()->Dictionary:
 var result:={}
 for group:Dictionary in [hidden_nodes(),shown_nodes()]:
  for label:String in group:result[label]=group[label]!=null and group[label].is_visible_in_tree()
 return result
func terrain()->Color:
 var r=game.world_renderer
 return r.terrain_color() if r.has_method("terrain_color") else Color("7e9275")
## The underground view of one entry path: ground layers hidden, underground ones shown, terrain faded.
func underground_layers(path_name:String):
 check(game.transit_view.underground and game.transit_view.metro_layer.visible,path_name+": the underground view is on")
 var hidden:Dictionary=hidden_nodes();var shown:Dictionary=shown_nodes()
 var leaked:Array=[];var missing:Array=[]
 for label:String in hidden:
  if hidden[label]==null or hidden[label].is_visible_in_tree():leaked.append(label)
 for label:String in shown:
  if shown[label]==null or not shown[label].is_visible_in_tree():missing.append(label)
 check(leaked.is_empty(),path_name+": ground layers are hidden: shown=%s"%str(leaked))
 check(missing.is_empty(),path_name+": the underground layer, trench, barrier, silhouette and terrain show: hidden=%s"%str(missing))
 var catenary:Array=game.world_renderer.catenary_nodes.filter(func(n):return n.is_visible_in_tree())
 check(not game.world_renderer.catenary_nodes.is_empty() and catenary.is_empty(),path_name+": no catenary shows: %d"%catenary.size())
 var ground:=Color("7e9275");var faded:=terrain()
 check(faded.s<ground.s*.5 and luminance(faded)>=luminance(ground) and contrast(faded,Color("15181a"))>=3.0,path_name+": the terrain is desaturated, not darker, and keeps 3:1 contrast with the 15181a bands: %s s=%.2f/%.2f L=%.3f/%.3f contrast=%.2f"%[faded.to_html(false),faded.s,ground.s,luminance(faded),luminance(ground),contrast(faded,Color("15181a"))])
## Back in the ground view every layer is as it was before the underground view.
func restored(path_name:String,before:Dictionary):
 var now:=states();var changed:Array=[]
 for label:String in before:
  if now[label]!=before[label]:changed.append(label)
 check(not game.transit_view.underground and changed.is_empty() and terrain()==Color("7e9275"),path_name+": the ground view restores every layer and the terrain: changed=%s terrain=%s"%[str(changed),terrain().to_html(false)])
func ground_baseline(path_name:String)->Dictionary:
 var before:=states();var off:Array=[]
 for label:String in ["ground roads","road marks","ground rails","WorldActors","a building","an E1 deck piece","a ground station part","the bus stop","the metro station entrance","power","water","the trench","a trench barrier","the terrain"]:
  if not before[label]:off.append(label)
 check(not game.transit_view.underground and off.is_empty() and not before["the underground layer"],path_name+": the ground view shows the ground layers first: hidden=%s"%str(off))
 return before
func lane_on(c,index:int,direction:int)->int:
 for lane in game.traffic.simulation.network.lanes:
  if int(lane.get("road",-1))==index and int(lane.direction)==direction:return int(lane.id)
 return -1
func display(c):
 game.mode="select";game.refresh();await settle()
 # 1. Road tool below 0m (real PgDn/PgUp).
 game.select_category("road");game.activate_tool("road");await settle()
 var before:=ground_baseline("road tool")
 await key(KEY_PAGEDOWN)
 check(game.mode=="road" and game.road_drawer.target_height_m<0,"road tool: PgDn steps below 0m: %.1fm"%game.road_drawer.target_height_m)
 underground_layers("road tool")
 await key(KEY_PAGEUP)
 restored("road tool",before)
 # 2. Rail tool below 0m.
 game.select_category("transport");game.activate_tool("rail");await settle()
 before=ground_baseline("rail tool")
 await key(KEY_PAGEDOWN)
 check(game.mode=="rail" and game.transit_view.target_height_m<0,"rail tool: PgDn steps below 0m: %.1fm"%game.transit_view.target_height_m)
 underground_layers("rail tool")
 await key(KEY_PAGEUP)
 restored("rail tool",before)
 # 3. Metro tool; closing the tray returns to the ground view.
 game.drawer.hide();await settle()
 game.select_category("transport");await settle()
 before=ground_baseline("metro tool")
 game.activate_tool("metro");await settle()
 check(game.mode=="metro","metro tool is active")
 underground_layers("metro tool")
 game.drawer.hide();await settle()
 restored("metro tool",before)
 # 4. Bulldozer PgDn, with a car on the ground road and one in the covered part of the road tunnel.
 game.mode="select";game.refresh();await settle()
 game.bulldozer.pressed.emit();await settle()
 var tunnel_index:=-1;var road_index:=-1
 for i in range(c.roads.size()):
  if preload("res://core/road_height.gd").sunken(c.roads[i]):tunnel_index=i
  elif int(c.roads[i].get("parcel_id",i))==ids_of.road:road_index=i
 check(game.traffic.rebuild(c.roads),"traffic builds the ground and tunnel lanes")
 var asset:Dictionary=game.traffic.catalog.filter(func(a):return a.id=="car-sedan-03")[0]
 var cars:={}
 for item in [["covered",tunnel_index,160.0],["ground",road_index,150.0]]:
  var lane:=lane_on(c,item[1],1)
  var vehicle:Dictionary=game.traffic.simulation.spawn(asset,[lane],item[2]) if lane>=0 else {}
  if not vehicle.is_empty():vehicle.progress=item[2];cars[item[0]]=vehicle.id
 game.traffic.simulation.paused=true;await settle()
 check(cars.size()==2,"a car on the ground road and one in the covered part: %s"%str(cars))
 var covered=game.world_renderer.cars.get(cars.get("covered",-1));var ground_car=game.world_renderer.cars.get(cars.get("ground",-1))
 depth_car=ground_car
 before=ground_baseline("bulldozer")
 check(ground_car!=null and ground_car.is_visible_in_tree() and covered!=null and not covered.is_visible_in_tree(),"ground view: the ground car shows, the car under cover does not")
 # Park the pointer off the map so no hover tint covers the subject.
 var parked:=InputEventMouseMotion.new();parked.position=Vector2(1840,140);root.push_input(parked,true)
 await key(KEY_PAGEDOWN)
 check(game.mode=="demolish","bulldozer: PgDn keeps the bulldozer")
 underground_layers("bulldozer")
 check(ground_car!=null and not ground_car.is_visible_in_tree(),"bulldozer: the car on the ground road is hidden")
 check(covered!=null and covered.is_visible_in_tree() and covered.get_parent()==game.transit_view.metro_layer,"bulldozer: the car in the covered part shows in the underground layer at its depth")
 await settle()
 var image:Image=await save_capture(capture_arg("underground-capture"),"underground view")
 if image!=null:
  # Darkest underground band (covered road and metro tunnels, solid 15181a) against bare terrain.
  var bands:Array=[drawn(Vector2(80,60),-10),drawn(Vector2(70,50),-12.7),drawn(Vector2(88,60),-10)]
  var band:=Color.WHITE
  for p:Vector2 in bands:
   var pixel:=image.get_pixelv(Vector2i(p))
   if luminance(pixel)<luminance(band):band=pixel
  var soil:Color=image.get_pixelv(Vector2i(game.screen(Vector2(70,15))))
  print("UNDERGROUND_CONTRAST band=#%s terrain=#%s ratio=%.2f"%[band.to_html(false),soil.to_html(false),contrast(band,soil)])
  check(contrast(band,soil)>=3.0,"capture: darkest underground band against the terrain is at least 3:1: %.2f"%contrast(band,soil))
 # A building built while the underground view is open stays hidden until the ground view returns.
 c.buildings.append({"id":903,"x":48,"y":44,"size":4,"level":3,"zone":"residential","asset_id":"mansion-a-4x4-4f"})
 c.next_id=maxi(c.next_id,904)
 game.refresh();await settle()
 var late=game.world_renderer.buildings.get(903)
 check(late!=null and not late.is_visible_in_tree(),"a building built in the underground view stays hidden")
 await key(KEY_PAGEUP)
 restored("bulldozer",before)
 check(late!=null and late.is_visible_in_tree(),"the building built in the underground view shows in the ground view")
 check(ground_car!=null and ground_car.is_visible_in_tree() and covered!=null and not covered.is_visible_in_tree(),"ground view again: the ground car shows, the car under cover does not")
 await save_capture(capture_arg("ground-capture"),"ground view")
 game.traffic.simulation.vehicles.clear();await settle()
func bulldozer(c):
 var station:=centre(lot_of(c,"train-station-01").polygon);var stop:=centre(lot_of(c,"bus-stop-01").polygon)
 var subway:=centre(lot_of(c,"subway-entrance-01").polygon)
 var corner:Vector2=lot_of(c,"subway-entrance-01").polygon[0].lerp(subway,.2)
 var plant:Vector2=c.power.plants.filter(func(p):return int(p.id)==ids_of.plant)[0].position/4
 if game.mode!="demolish":game.bulldozer.pressed.emit();await settle()
 check(game.mode=="demolish" and not game.transit_view.underground,"the bulldozer starts in the ground view")
 # The ground view keeps picking ground objects (unchanged), so the same spots are real targets.
 expect("ground",[
  ["a building",Vector2(42,46),0.0,"building",901],
  ["the building over the covered road",Vector2(62,60),0.0,"building",902],
  ["the ground train station",station,0.0,"public_facility",ids_of.station],
  ["the bus stop",stop,0.0,"public_facility",ids_of.bus_stop],
  ["the metro station entrance on the ground",subway,0.0,"public_facility",ids_of.subway],
  ["the power plant",plant,0.0,"power_plant",ids_of.plant],
  ["the trench picks the road tunnel",Vector2(20,60.3),0.0,"road",ids_of.tunnel],
  ["the covered road where the underground view draws it is not picked",Vector2(80,60.3),-10.0,"",-1]])
 await key(KEY_PAGEDOWN)
 check(game.mode=="demolish" and game.transit_view.underground,"PgDn in the bulldozer shows the underground view")
 expect("underground",[
  ["a building is not picked",Vector2(42,46),0.0,"",-1],
  ["the building over the covered road is not picked",Vector2(62,60),0.0,"",-1],
  ["the ground train station is not picked",station,0.0,"",-1],
  ["the bus stop is not picked",stop,0.0,"",-1],
  ["the power plant is not picked",plant,0.0,"",-1],
  ["the ground road is not picked",Vector2(50,40.3),0.0,"",-1],
  ["the ground rail is not picked",Vector2(50,30.5),0.0,"",-1],
  ["the E1 deck where it is drawn (+10m) is not picked",Vector2(70,76.3),10.0,"",-1],
  ["the covered road where it is drawn (-10m) picks the road tunnel",Vector2(80,60.3),-10.0,"road",ids_of.tunnel],
  ["under the building, the covered road where it is drawn (-10m) picks the road tunnel",Vector2(62,60.3),-10.0,"road",ids_of.tunnel],
  ["metro where it is drawn (-12.7m) picks the metro",Vector2(70,50.3),-12.7,"transit_route",ids_of.metro],
  ["a corner of the metro station silhouette picks the metro station",corner,-12.7,"public_facility",ids_of.subway],
  ["the trench picks the road tunnel",Vector2(20,60.3),0.0,"road",ids_of.tunnel]])
 var buildings:int=c.buildings.size();var lots:int=c.public_facilities.lots.size();var plants:int=c.power.plants.size()
 for spot:Vector2 in [Vector2(42,46),Vector2(62,60),station,stop,plant]:await click(game.screen(spot))
 check(c.buildings.size()==buildings and c.public_facilities.lots.size()==lots and c.power.plants.size()==plants,"underground view: clicking buildings, the ground station, the bus stop and the power plant removes nothing: %d/%d %d/%d %d/%d %s"%[c.buildings.size(),buildings,c.public_facilities.lots.size(),lots,c.power.plants.size(),plants,game.message])
 await station_overlap(c,buildings,lots)
 await key(KEY_PAGEUP)
 check(game.mode=="demolish" and not game.transit_view.underground,"PgUp returns the bulldozer to the ground view")
 expect("ground after PgUp",[["a building",Vector2(42,46),0.0,"building",901]])
func station_cross_direction(station:Dictionary)->Vector2:
 var platform:PackedVector2Array=station.internal_points
 return platform[0].direction_to(platform[-1]).orthogonal()
func station_overlap(c,buildings:int,lots:int):
 var station:=lot_of(c,"subway-entrance-01")
 var center:=centre(station.polygon)
 var id:int=ids_of.crossing
 # Tighten framing around the intersection without altering its world coordinates or projection.
 game.map_zoom=1.2
 game.origin=Vector2(960,430)-game.transit_view.project_point(center,-12.7)*game.map_zoom
 game.refresh();await settle()
 var inside:=drawn(center,-12.7)
 var outside:=drawn(center+station_cross_direction(station)*9,-12.7)
 check(is_target(game.transit_view.pick_drawn(inside,["covered"]),"transit_route",id),"the independent metro ribbon really lies under the station hit")
 await move_pointer(outside)
 check(is_target(game.demolition_hover,"transit_route",id),"hover outside the silhouette picks the independent metro ribbon")
 var unhovered:Image
 var native:=DisplayServer.get_name()!="headless"
 if native:
  var platform:Sprite2D=game.world_renderer.metro_stations.get(ids_of.subway)
  check(platform!=null and platform.is_visible_in_tree() and platform.texture!=null,"the real station silhouette texture is visible at the overlap")
  await move_pointer(Vector2(1830,140))
  unhovered=await framebuffer()
 await move_pointer(inside)
 check(is_target(game.demolition_hover,"public_facility",ids_of.subway),"hover at the overlap highlights the station, not the independent ribbon")
 if native:
  var hovered:Image=await framebuffer()
  var plain:=unhovered.get_pixelv(Vector2i(inside));var tint:=hovered.get_pixelv(Vector2i(inside))
  var outside_before:=unhovered.get_pixelv(Vector2i(outside));var outside_after:=hovered.get_pixelv(Vector2i(outside))
  check(tint.r>plain.r+.15 and outside_before==outside_after,"framebuffer tints the overlap but not the rest of the independent ribbon (inside %s → %s; outside %s → %s)"%[plain.to_html(false),tint.to_html(false),outside_before.to_html(false),outside_after.to_html(false)])
  await save_capture(capture_arg("station-overlap-capture"),"station hover over an independent metro ribbon",hovered)
 await viewport_click(inside)
 await publish_edit()
 check(lot_of(c,"subway-entrance-01").is_empty() and c.public_facilities.lots.size()==lots-1 and c.buildings.size()==buildings,"click inside the overlap removes only the station lot")
 check(not c.get_transit_route(id).is_empty() and not c.get_transit_route(ids_of.metro).is_empty() and c.get_transit_route(int(station.internal_route_id)).is_empty(),"the station's own platform is removed but both independent routes remain")
 game.map_zoom=.55;game.origin=Vector2(960,500)-game.world_renderer.iso(Vector2(52,55))*game.map_zoom
 game.refresh();await settle()
## Native depth oracle: compare the production nested groups to the original flat y-sort on the
## same framebuffer. Confirm both directions actually overlap with two isolated visibility masks.
func trench_occlusion(c):
 var r=game.world_renderer
 c.buildings.append({"id":904,"x":25,"y":61.6,"size":4,"level":3,"zone":"residential","asset_id":"mansion-a-4x4-4f","score":0.0})
 game.map_zoom=2.0
 game.origin=Vector2(960,500)-r.iso(Vector2(26,61.5))*game.map_zoom
 await move_pointer(Vector2(1830,140));game.refresh();await settle()
 var building:CanvasItem=r.buildings.get(904)
 check(building!=null and building.is_visible_in_tree() and depth_car!=null and depth_car.texture!=null,"occlusion fixture uses the retained mansion and traffic sedan")
 if building==null or depth_car==null or depth_car.texture==null:return
 # Pose the production ground-traffic sprite at a tightly framed overlap. Freeze auto placement
 # and culling for the visibility passes, without changing its offset, scale, texture or shader.
 r.set_process(false)
 var group:Node2D=r.trench_actors
 var barriers:=group.get_children()
 var car_cell:=Vector2(20.0,61.2)
 depth_car.position=r.iso(car_cell);depth_car.show()
 var building_area:=Rect2i(Rect2(game.screen(Vector2(26,61.5))-Vector2(80,55),Vector2(160,115)))
 var car_area:=Rect2i(Rect2(game.screen(car_cell)-Vector2(25,25),Vector2(50,50)))
 var nested:Image=await framebuffer()
 for barrier in barriers:barrier.reparent(r.actors,false)
 var flat:Image=await framebuffer()
 for barrier in barriers:barrier.reparent(group,false)
 group.hide()
 var actor_only:Image=await framebuffer()
 building.hide();depth_car.hide()
 var neither:Image=await framebuffer()
 group.show()
 var barrier_only:Image=await framebuffer()
 building.show();depth_car.show()
 # Known-bad orders are negative controls: each must fail the same overlap comparison.
 group.z_index=1
 var barrier_front:Image=await framebuffer()
 group.z_index=-1
 var barrier_back:Image=await framebuffer()
 group.z_index=0;depth_car.hide();r.set_process(true)
 check_overlap("foreground building",building_area,nested,flat,actor_only,barrier_only,neither,actor_only,barrier_front)
 check_overlap("foreground trench barrier over ground car",car_area,nested,flat,actor_only,barrier_only,neither,barrier_only,barrier_back)
func check_overlap(label:String,area:Rect2i,nested:Image,flat:Image,actor_only:Image,barrier_only:Image,neither:Image,winner:Image,bad:Image):
 var overlap:=0;var matched:=0;var flat_mismatch:=0;var bad_mismatch:=0
 for y in range(area.position.y,area.end.y):
  for x in range(area.position.x,area.end.x):
   var empty:=neither.get_pixel(x,y)
   var actor:=actor_only.get_pixel(x,y);var barrier:=barrier_only.get_pixel(x,y)
   if actor==empty or barrier==empty or actor==barrier:continue
   overlap+=1
   var actual:=nested.get_pixel(x,y)
   if actual==winner.get_pixel(x,y):matched+=1
   if actual!=flat.get_pixel(x,y):flat_mismatch+=1
   if actual!=bad.get_pixel(x,y):bad_mismatch+=1
 check(overlap>=10 and matched>=10,"%s has real overlap pixels in the correct foreground (match %d/%d)"%[label,matched,overlap])
 check(overlap>=10 and flat_mismatch==0,"%s: nested y-sort matches flat y-sort on all %d overlap pixels (mismatches %d)"%[label,overlap,flat_mismatch])
 check(bad_mismatch>=10,"%s: forced reverse draw order changes %d overlap pixels"%[label,bad_mismatch])
func finish():
 if game!=null and game.city!=null and game.city.simulation!=null:game.city.simulation.shutdown()
 print("UNDERGROUND_VIEW checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
