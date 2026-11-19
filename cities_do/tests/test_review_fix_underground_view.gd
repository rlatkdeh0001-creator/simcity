extends SceneTree
## Underground view (user rule 2026-11-19, ASSET_REQUEST_ELEVATED_TUNNEL_KO.md 8항: "지하보기에서는
## 지하에있는 도로,철도,지하철만 보여야해") in the actual main scene, with real keys and clicks.
## Bulldozer: the underground view (PgDn) picks covered road/rail parts and metro, then metro stations
## on their platform silhouette, then trenches and portals. Buildings, public facilities, power and
## ground stations are never picked there.
const City=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
var game
var ids_of:={}
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
 c.buildings.append({"id":901,"x":40,"y":44,"size":4,"level":3,"zone":"residential","asset_id":"mansion-a-4x4-4f"})
 # A building standing over the covered road: the tunnel passes under it.
 c.buildings.append({"id":902,"x":60,"y":58,"size":4,"level":3,"zone":"residential","asset_id":"mansion-a-4x4-4f"})
 c.next_id=maxi(c.next_id,903)
 return {"city":c,"built":built}
func run():
 Engine.max_fps=30
 root.size=Vector2i(1920,1080)
 var made:Dictionary=fixture();var c=made.city;var built:Array=made.built
 check(built.all(func(r):return r.get("ok",false)),"fixture: ground road, ground station, bus stop, metro station, ground rail, road tunnel, E1 deck, metro, power plant: "+str(built.map(func(r):return r.get("reason",""))))
 game=load("res://main.tscn").instantiate();game.city=c;root.add_child(game);current_scene=game
 await settle()
 game.map_zoom=.55;game.origin=Vector2(960,500)-game.world_renderer.iso(Vector2(52,55))*game.map_zoom
 game.refresh();await settle()
 if not built.all(func(r):return r.get("ok",false)):
  finish();return
 ids_of={"tunnel":road_at(c,Vector2(70,60)),"deck":road_at(c,Vector2(70,76)),"road":road_at(c,Vector2(50,40)),
  "metro":int(built[8].route.id),"rail":int(built[5].route.id),"station":int(lot_of(c,"train-station-01").id),
  "bus_stop":int(lot_of(c,"bus-stop-01").id),"subway":int(lot_of(c,"subway-entrance-01").id),"plant":int(built[-1].id)}
 await bulldozer(c)
 finish()
func bulldozer(c):
 var station:=centre(lot_of(c,"train-station-01").polygon);var stop:=centre(lot_of(c,"bus-stop-01").polygon)
 var subway:=centre(lot_of(c,"subway-entrance-01").polygon)
 var corner:Vector2=lot_of(c,"subway-entrance-01").polygon[0].lerp(subway,.2)
 var plant:Vector2=c.power.plants.filter(func(p):return int(p.id)==ids_of.plant)[0].position/4
 game.bulldozer.pressed.emit();await settle()
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
  ["the metro station silhouette where it is drawn (-12.7m) picks the metro station",subway,-12.7,"public_facility",ids_of.subway],
  ["a corner of the metro station silhouette picks the metro station",corner,-12.7,"public_facility",ids_of.subway],
  ["the trench picks the road tunnel",Vector2(20,60.3),0.0,"road",ids_of.tunnel]])
 var buildings:int=c.buildings.size();var lots:int=c.public_facilities.lots.size();var plants:int=c.power.plants.size()
 for spot:Vector2 in [Vector2(42,46),Vector2(62,60),station,stop,plant]:await click(game.screen(spot))
 check(c.buildings.size()==buildings and c.public_facilities.lots.size()==lots and c.power.plants.size()==plants,"underground view: clicking buildings, the ground station, the bus stop and the power plant removes nothing: %d/%d %d/%d %d/%d %s"%[c.buildings.size(),buildings,c.public_facilities.lots.size(),lots,c.power.plants.size(),plants,game.message])
 await click(drawn(subway,-12.7))
 check(lot_of(c,"subway-entrance-01").is_empty() and c.public_facilities.lots.size()==lots-1 and c.buildings.size()==buildings and c.transit_routes.any(func(r):return int(r.id)==ids_of.metro),"underground view: clicking the metro station silhouette removes the metro station only: %s"%game.message)
 await key(KEY_PAGEUP)
 check(game.mode=="demolish" and not game.transit_view.underground,"PgUp returns the bulldozer to the ground view")
 expect("ground after PgUp",[["a building",Vector2(42,46),0.0,"building",901]])
func finish():
 if game!=null and game.city!=null and game.city.simulation!=null:game.city.simulation.shutdown()
 print("UNDERGROUND_VIEW checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
