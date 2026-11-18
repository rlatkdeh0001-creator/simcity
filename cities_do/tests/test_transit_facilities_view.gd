extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func _initialize():run.call_deferred()
func click(p:Vector2):
 var motion:=InputEventMouseMotion.new();motion.position=p;root.push_input(motion,true);await process_frame
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=p;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
  root.push_input(event,true);await process_frame
func expose(game,item):
 for i in range(3):await process_frame
 var strip=game.drawer_scroll
 for i in range(16):
  if strip.get_global_rect().has_point(item.get_global_rect().get_center()):return
  var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_RIGHT if item.global_position.x>strip.global_position.x else MOUSE_BUTTON_WHEEL_LEFT
  wheel.pressed=true;wheel.position=strip.get_global_rect().get_center();root.push_input(wheel,true);wheel=wheel.duplicate();wheel.pressed=false;root.push_input(wheel,true);await process_frame
func run():
 root.size=Vector2i(1280,820)
 var game=load("res://main.tscn").instantiate();game.paused=true;game.city.population_enabled=false;game.city.happiness_enabled=false
 root.add_child(game);await process_frame
 game.map_zoom=.65;game.origin=Vector2(620,-100)
 game.city.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
 game.select_category("transport");await process_frame
 var card=game.drawer_box.find_child("Facility_train-station-01",true,false)
 check(card!=null,"station in existing transport chooser")
 if card!=null:
  await expose(game,card)
  await click(card.get_global_rect().get_center())
  check(game.mode=="public_placement","real card press selects station")
  await click(game.screen(Vector2(30,33)))
  check(game.city.public_facilities.lots.size()==1,"viewport press places station")
  for i in range(100):
   await process_frame
   if not game.building_views.busy and game.building_views.queue.is_empty():break
  if not game.city.transit_routes.is_empty():
   var internal:Dictionary=game.city.transit_routes[0]
   game.activate_tool("rail");game.pointer=internal.points[0]
   check(game.transit_view.cursor_preview().ok,"station port accepts first anchor cursor")
   await click(game.screen(internal.points[0]))
   await click(game.screen(internal.points[0]-Vector2(8,0)))
   check(game.city.transit_routes.size()==2,"actual viewport extends station rail")
  check(game.world_renderer.get("station_parts")!=null,"station has split retained render slots")
  if game.world_renderer.get("station_parts")!=null and not game.city.public_facilities.lots.is_empty():
   check(game.world_renderer.station_parts.size()==2,"two original GLB parts")
   for node in game.world_renderer.station_parts.values():
    check(node.texture!=null,"split GLB rendered")
    if node.texture!=null:check(node.texture.get_image().get_used_rect().has_area(),"original part has visible pixels")
   var record:Dictionary=game.city.public_facilities.lots[0]
   var far=game.world_renderer.station_parts["%d:StationRear"%record.id]
   var near=game.world_renderer.station_parts["%d:StationFront"%record.id]
   check(far.texture.get_image().get_data()!=near.texture.get_image().get_data(),"original GLB groups render separately not duplicate whole station")
   for point:Vector2 in record.internal_points:
    var depth:float=game.world_renderer.iso(point).y
    check(far.position.y<depth and near.position.y>depth,"future train slot between far and near station parts")
  game.toggle_demolition()
  await click(game.screen(Vector2(30,33)))
  check(game.city.public_facilities.lots.is_empty(),"shared viewport bulldozer removes station")
  check(game.city.transit_routes.size()==1,"viewport demolition retains external extension")
 for id in ["bus-stop-01","bus-station-01","subway-entrance-01","park-large-8x8"]:
  game.select_category("park" if id=="park-large-8x8" else "transport");await process_frame
  var item=game.drawer_box.find_child("Facility_"+id,true,false)
  check(item!=null,"existing chooser card "+id)
  if item==null:continue
  await expose(game,item)
  if id=="park-large-8x8":
   var strip=game.drawer_scroll
   for i in range(12):
    var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_RIGHT;wheel.pressed=true;wheel.position=strip.get_global_rect().get_center();root.push_input(wheel,true);wheel=wheel.duplicate();wheel.pressed=false;root.push_input(wheel,true);await process_frame
   check(strip.get_global_rect().has_point(item.get_global_rect().get_center()),"native wheel exposes large park at 1280px")

  await click(item.get_global_rect().get_center())

  check(game.mode=="public_placement" and game.public_controller.asset_id==id,"native card selects "+id)
  var depth:float=game.city.public_facilities.entries[id].depth
  var point:=Vector2(50,37.5-depth/2)
  if id=="bus-stop-01":point=Vector2(50,37.8125)
  await click(game.screen(point))
  check(game.city.public_facilities.lots.size()==1,"native placement "+id)
  for i in range(100):
   await process_frame
   if not game.building_views.busy and game.building_views.queue.is_empty():break
  if game.city.public_facilities.lots.size()==1:
   var record:Dictionary=game.city.public_facilities.lots[0]
   var visual:Dictionary=game.public_controller.visual(record)
   check(not visual.is_empty() and visual.image.get_used_rect().has_area(),"original GLB draws "+id)
   if id=="subway-entrance-01":
    check(game.world_renderer.get("metro_stations")!=null,"subway has original underground silhouette slot")
    if game.world_renderer.get("metro_stations")!=null:
     check(game.world_renderer.metro_stations.size()==1,"one silhouette per placed entrance")
     var node=game.world_renderer.metro_stations.values()[0]
     check(node.texture!=null and node.texture.get_image().get_used_rect().has_area(),"underground original GLB rendered")
     check(not node.is_visible_in_tree(),"silhouette hidden above ground")
     game.select_category("transport");game.activate_tool("metro");await process_frame
     check(node.is_visible_in_tree(),"existing metro view reveals silhouette")
   game.city.public_facilities.remove(record.id)
 var fixture=load("res://tests/transit_facilities_fixture.gd")
 for result:Dictionary in fixture.populate(game):check(result.ok,"capture-ready fixture transaction")
 for i in range(180):
  await process_frame
  if not game.building_views.busy and game.building_views.queue.is_empty():break
 for record:Dictionary in game.city.public_facilities.lots:
  if record.public_asset_id!="train-station-01":continue
  var front_near:bool=record.front_direction.x+record.front_direction.y>=0
  var front=game.world_renderer.station_parts["%d:StationFront"%record.id]
  var rear=game.world_renderer.station_parts["%d:StationRear"%record.id]
  check((front.position.y>rear.position.y)==front_near,"station part ordering flips with camera-facing side")
 if OS.get_cmdline_user_args().has("--hold-p2-fixture"):
  print("P2_FIXTURE_READY checks=%d failed=%d"%[checks,failures]);return
 game.queue_free();await process_frame
 print("TRANSIT_FACILITIES_VIEW checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
