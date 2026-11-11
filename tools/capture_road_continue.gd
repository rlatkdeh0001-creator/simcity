extends SceneTree
var game
func _initialize():run.call_deferred()
func mouse(point: Vector2,down: bool):
 var event:=InputEventMouseButton.new();event.position=game.screen(point);event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
 await process_frame
func draw(points: PackedVector2Array):
 await mouse(points[0],true)
 for index in range(1,points.size()):
  var event:=InputEventMouseMotion.new();event.position=game.screen(points[index]);root.push_input(event,true);await process_frame
 await mouse(points[-1],false);await process_frame
func run():
 var path:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
 if path.is_empty():quit(1);return
 game=load("res://main.tscn").instantiate();game.paused=true;game.city.population_enabled=false
 root.add_child(game);current_scene=game
 for frame in range(5):await process_frame
 game.select_category("road");game.activate_tool("road");game.drawer.hide()
 for points in [PackedVector2Array([Vector2(10,40),Vector2(30,40)]),PackedVector2Array([Vector2(30.6,40.3),Vector2(60,40)]),PackedVector2Array([Vector2(45,40.6),Vector2(45,65)]),PackedVector2Array([Vector2(45,39.4),Vector2(45,12)])]:await draw(points)
 if game.city.roads.size()!=4 or game.city.roads[1].points[0].distance_to(Vector2(30,40))>.00001:quit(1);return
 var topology: Dictionary=game.city.RoadJunctions.analyze(game.city.roads)
 if topology.junctions.size()!=1 or topology.junctions[0].arms.size()!=4:quit(1);return
 game.map_zoom=1.3;game.origin=Vector2(1000,-150);game.queue_redraw()
 for frame in range(3):await process_frame
 await RenderingServer.frame_post_draw
 var seam: Color=root.get_texture().get_image().get_pixelv(Vector2i(game.screen(Vector2(29.15,40.2)).round()))
 var asphalt:=Color("4c5659")
 if Vector3(seam.r-asphalt.r,seam.g-asphalt.g,seam.b-asphalt.b).length()>.08:
  push_error("Joined road sidewalk cap covers existing asphalt: "+str(seam));quit(1);return
 game.toggle_traffic()
 if not game.traffic.running:quit(1);return
 var network=game.traffic.network;var route: Array=[]
 for a in network.lanes:
  if a.road!=0:continue
  for b in network.lanes:
   if b.road==2:
    var found: Array=network.route(a.id,b.id)
    if not found.is_empty():route=found
 if route.is_empty():quit(1);return
 game.traffic.update(3.0);game.map_zoom=1.3;game.origin=Vector2(1000,-150)
 for frame in range(15):await process_frame
 await RenderingServer.frame_post_draw
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"input":"four actual freehand mouse drags","roads":game.city.roads,"junctions":topology.junctions,"sections":topology.sections.size(),"lane_count":network.lanes.size(),"route_from_first_stroke_to_branch":route,"vehicle_count":game.traffic.simulation.vehicles.size(),"parcel_count":game.city.zoning_grid.count(),"viewport":str(root.get_visible_rect())},"  ")+"\n");file.close()
 quit(0 if root.get_texture().get_image().save_png(path)==OK else 1)
