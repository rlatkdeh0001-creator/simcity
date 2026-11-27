extends SceneTree
## No clocks/timings, no fleet loops. Capture is opt-in and saves exactly one frame.
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;printerr("FAIL "+label)
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1920,1080)
 var view=load("res://tests/rail_catenary_fixture.gd").new();root.add_child(view)
 var added:Dictionary=view.city.add_transit_route(PackedVector2Array([Vector2(10,20),Vector2(45,20)]))
 check(added.ok,"real model ground route creation")
 await process_frame
 var renderer=view.world_renderer
 check(renderer.has_method("sync_catenary"),"retained WorldActors catenary integration exists")
 if renderer.has_method("sync_catenary"):
  renderer.synchronize();await process_frame
  check(not renderer.catenary_nodes.is_empty(),"route event creates retained overhead draw nodes")
  var ids:Array=renderer.catenary_nodes.map(func(n):return n.get_instance_id())
  var signature:=var_to_bytes([view.city.transit_routes,view.city.external_infrastructure,view.city.transit_lines,view.city.transit_state])
  for zoom:float in [.399,.4,.65,.999,1.0,3.0]:
   view.map_zoom=zoom;await process_frame
   var active:Array=renderer.catenary_nodes.filter(func(n):return n.visible)
   check(active.is_empty() if zoom<.4 else not active.is_empty(),"exact zoom visibility gate %s"%zoom)
   var kinds:Array=[]
   for node in active:
    for command:Dictionary in node.commands:
     if node.command_visible(command):kinds.append(command.kind)
   check(not kinds.has("messenger") and not kinds.has("diagonal") and not kinds.has("pull") and not kinds.has("cap") if zoom<1 else kinds.has("messenger") and kinds.has("diagonal") and kinds.has("pull") and kinds.has("cap"),"exact detail LOD %s"%zoom)
   for node in active:
    for command:Dictionary in node.commands:
     if command.kind=="contact":
      check(is_equal_approx(node.line_width(command)*zoom,1),"contact one screen pixel at zoom %s"%zoom);break
    if not node.commands.is_empty():break
  check(ids==renderer.catenary_nodes.map(func(n):return n.get_instance_id()),"zoom retains nodes and cached geometry")
  view.map_zoom=1.5;view.transit_view.underground=true;await process_frame
  check(renderer.catenary_nodes.all(func(n):return not n.visible),"underground view hides every overhead node")
  view.transit_view.underground=false;view.origin=Vector2(-10000,-10000);await process_frame
  check(renderer.catenary_nodes.all(func(n):return not n.visible),"offscreen projected-height bounds culled")
  view.origin=Vector2(850,30);await process_frame
  check(renderer.catenary_nodes.any(func(n):return n.visible),"camera returns without geometry rebuild")
  check(signature==var_to_bytes([view.city.transit_routes,view.city.external_infrastructure,view.city.transit_lines,view.city.transit_state]),"camera and catenary gates leave routing and operations unchanged")
  var wire_widths:=true;var pole_widths:=true;var projected:=true;var contacts:=0
  for node in renderer.catenary_nodes:
   for c:Dictionary in node.commands:
    if c.kind=="contact":contacts+=1;wire_widths=wire_widths and is_equal_approx(node.line_width(c)*view.map_zoom,1)
    if c.kind=="pole":pole_widths=pole_widths and is_equal_approx(node.line_width(c),.3*14/4*sqrt(2.0))
    projected=projected and c.projected_a.is_equal_approx(view.transit_view.project_point(c.a,c.a_height))
  check(contacts>0 and wire_widths and pole_widths,"actual commands use fixed 1px wire and physical .3m detailed poles")
  check(projected,"cached commands use height-aware projection without moving ground anchors")
  var pose:Dictionary={"id":"fixture-train","asset_id":"train-loco-01","position":Vector2(100,78),"heading":Vector2.RIGHT,"height_m":0.0,"kind":"rail","length_m":10.0,"width_m":3.0}
  view.city.transit_state.visible=[pose];renderer.sync_transit_cars();await process_frame
  var body:=PackedVector2Array([Vector2(23.75,19.125),Vector2(26.25,19.125),Vector2(26.25,19.875),Vector2(23.75,19.875)])
  var sprite:Sprite2D=renderer.transit_cars["fixture-train"]
  var above:=true;var overlap_count:=0
  for node in renderer.catenary_nodes:
   for c:Dictionary in node.commands:
    if c.kind=="contact" and not Geometry2D.intersect_polygons(c.footprint,body).is_empty():
     overlap_count+=1;above=above and node.position.y>sprite.position.y
  check(overlap_count>=2 and above,"every 4m overhead fragment covering a full train draws after its longest-depth fragment")
  check(sprite.texture!=null and sprite.get_parent()==renderer.actors,"real original v3 train sprite shares WorldActors")
  view.city.transit_state.visible=[];renderer.sync_transit_cars()
  var moved:Dictionary=view.city.update_transit_route(added.route.id,PackedVector2Array([Vector2(10,25),Vector2(45,25)]))
  await process_frame
  check(moved.ok and renderer.catenary_nodes.all(func(n):return n.commands.all(func(c):return c.a.y>=23.9249)),"real route edit replaces actual retained commands")
  check(view.city.remove_transit_route(added.route.id).ok,"real route deletion accepted")
  await process_frame
  check(renderer.catenary_nodes.is_empty(),"deletion removes retained draw nodes")
  for flag:String in ["covered","underground"]:
   view.city.add_transit_route(PackedVector2Array([Vector2(10,20),Vector2(45,20)]))
   view.city.transit_routes[0][flag]=true;view.city.transit_changed.emit();await process_frame
   check(renderer.catenary_nodes.is_empty(),flag+" gate removes actual retained commands")
   view.city.remove_transit_route(view.city.transit_routes[0].id)
  var mixed:Dictionary=view.city.add_transit_route(PackedVector2Array([Vector2(10,20),Vector2(25,20),Vector2(45,20)]))
  for flag:String in ["covered_segments","underground_segments"]:
   view.city.transit_routes[0][flag]=PackedInt32Array([1]);view.city.transit_changed.emit();await process_frame
   check(not renderer.catenary_nodes.is_empty() and renderer.catenary_nodes.all(func(n):return n.commands.all(func(c):return c.a.x<=25.0001 and c.b.x<=25.0001)),flag+" removes only hidden segment in actual renderer")
   view.city.transit_routes[0].erase(flag)
  view.city.remove_transit_route(mixed.route.id)
  await portal_checks(view)
  await stage_checks(view)
 view.free()
 print("CATENARY_RENDER checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
func portal_checks(view):
 var a:Dictionary=view.city.add_transit_route(PackedVector2Array([Vector2(5,30),Vector2(70,30)]))
 var b:Dictionary=view.city.add_transit_route(PackedVector2Array([Vector2(20,28),Vector2(40,30)]))
 check(a.ok and b.ok,"real model accepts shallow branch portal fixture")
 await process_frame
 var renderer=view.world_renderer
 var beams:Array=renderer.catenary_nodes.filter(func(n):return n.commands.any(func(c):return c.kind=="portal"))
 var tubes:Array=renderer.catenary_nodes.filter(func(n):return n.commands.any(func(c):return c.kind=="portal_tube"))
 check(not beams.is_empty() and not tubes.is_empty(),"actual retained renderer receives portal beams and track tubes")
 check(not beams.is_empty() and beams.all(func(n):return n.commands.all(func(c):return c.kind!="portal" or c.a.distance_to(c.b)<=1.0001)),"portal beam draw pieces at most 4m for vehicle depth sorting")
 for zoom:float in [.65,1.0]:
  view.map_zoom=zoom;await process_frame
  check(beams.all(func(n):return n.commands.all(func(c):return c.kind!="portal" or (n.command_visible(c) and is_equal_approx(n.line_width(c)*zoom,1)))),"portal beam visible at fixed 1px zoom %s"%zoom)
  check(tubes.all(func(n):return n.commands.all(func(c):return c.kind!="portal_tube" or n.command_visible(c)==(zoom>=1))),"portal tube detail gate zoom %s"%zoom)
 view.city.transit_state.visible=[{"id":"portal-train","asset_id":"train-loco-01","position":Vector2(108,118),"heading":Vector2.RIGHT,"height_m":0.0,"kind":"rail","length_m":10.0,"width_m":3.0}]
 renderer.sync_transit_cars();await process_frame
 var sprite:Sprite2D=renderer.transit_cars["portal-train"]
 var body:=PackedVector2Array([Vector2(25.75,29.125),Vector2(28.25,29.125),Vector2(28.25,29.875),Vector2(25.75,29.875)])
 var overlapping:Array=beams.filter(func(n):return renderer.catenary_overlap(n.footprint,body))
 check(not overlapping.is_empty() and overlapping.all(func(n):return n.position.y>sprite.position.y),"portal fragments above real train footprint and sprite")
 var near_ok:=not beams.is_empty()
 for node in renderer.catenary_nodes:
  if node.overhead or not node.commands[0].get("near",false):continue
  for beam in beams:
   if beam.commands[0].get("support",Vector2.INF)==node.commands[0].support:near_ok=near_ok and node.position.y>beam.position.y
 check(near_ok and beams.all(func(n):return n.commands[0].has("support")),"near portal pole follows its beam fragments in y-sort")
 view.city.transit_state.visible=[];renderer.sync_transit_cars()
func stage_checks(view):
 view.stage();await process_frame
 var renderer=view.world_renderer
 var lot:Dictionary=view.city.public_facilities.lots[0]
 var far=renderer.station_parts["%d:StationRear"%lot.id]
 var near=renderer.station_parts["%d:StationFront"%lot.id]
 var order_ok:=true;var wires:=0
 for node in renderer.catenary_nodes:
  for c:Dictionary in node.commands:
   if c.kind=="contact" and c.route_id==lot.internal_route_id:
    wires+=1;order_ok=order_ok and node.position.y>far.position.y and node.position.y<near.position.y
 check(wires>0 and order_ok,"real station far group then overhead then near group depth")
 for sprite in renderer.transit_cars.values():check(sprite.position.y>far.position.y and sprite.position.y<near.position.y,"actual train sprite remains between station groups")
 check(renderer.catenary_nodes.all(func(n):return n.get_parent()==renderer.actors),"every catenary node is in WorldActors y-sort")
 var poles_ok:=true;var far_count:=0;var near_count:=0
 for node in renderer.catenary_nodes:
  if node.overhead:continue
  var c:Dictionary=node.commands[0]
  if not c.get("near",false):far_count+=1;poles_ok=poles_ok and is_equal_approx(node.position.y,renderer.iso(c.support).y)
  else:
   near_count+=1
   for bracket in renderer.catenary_nodes:
    if bracket.overhead and bracket.commands[0].get("support",Vector2.INF)==c.support:poles_ok=poles_ok and node.position.y>bracket.position.y
 check(far_count>0 and near_count>0 and poles_ok,"far poles use ground base and near poles follow overhead brackets")
 var vehicle:Dictionary=view.traffic.simulation.vehicles[0]
 var pos:Vector2=view.traffic.simulation.position(vehicle)/4
 var body:=PackedVector2Array([pos+Vector2(-vehicle.length/8,-.3125),pos+Vector2(vehicle.length/8,-.3125),pos+Vector2(vehicle.length/8,.3125),pos+Vector2(-vehicle.length/8,.3125)])
 var crossing:=0;var crossing_ok:=true
 for node in renderer.catenary_nodes:
  for c:Dictionary in node.commands:
   if c.kind=="contact" and renderer.catenary_overlap(c.footprint,body):crossing+=1;crossing_ok=crossing_ok and node.position.y>renderer.cars[vehicle.id].position.y
 check(crossing>0 and crossing_ok,"actual road fire engine is below every crossing-wire fragment")
 var image_rect:Rect2=view.traffic.sprite_rect(vehicle.asset_id,Vector2.ZERO,view.tile.x/4*sqrt(2.0))
 var car:Sprite2D=renderer.cars[vehicle.id]
 check((car.position+car.offset*car.scale).is_equal_approx(renderer.iso(pos)+image_rect.position),"depth anchor compensation preserves real road sprite screen position")
 if DisplayServer.get_name()=="headless":return
 for i in range(90):
  await process_frame
  if not view.building_views.busy and view.building_views.queue.is_empty():break
 check(far.texture!=null and near.texture!=null,"original station v2 split textures loaded without import or build")
 await RenderingServer.frame_post_draw
 var present:Image=root.get_texture().get_image()
 view.transit_view.underground=true
 await process_frame;await RenderingServer.frame_post_draw
 var hidden:Image=root.get_texture().get_image()
 check(present.get_data()!=hidden.get_data(),"actual GL framebuffer changes when overhead is hidden")
 view.transit_view.underground=false
 await process_frame;await RenderingServer.frame_post_draw
 var restored:Image=root.get_texture().get_image()
 check(present.get_data()==restored.get_data(),"actual GL framebuffer exactly restores retained overhead")
 var save:=OS.get_cmdline_user_args().has("--capture-catenary")
 if save and failures==0:
  check(restored.get_size()==Vector2i(1920,1080),"exact native framebuffer 1920x1080")
  if failures==0:
   var path:="res://../docs/catenary-validation/catenary-1920.png"
   check(restored.save_png(path)==OK,"one requested stage frame saved")
   print("CATENARY_CAPTURE "+ProjectSettings.globalize_path(path))
