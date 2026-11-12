extends SceneTree
const Links=preload("res://core/boundary_links.gd")
var game
func _initialize():run.call_deferred()
func click(point: Vector2):
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
func settle():
 for i in range(6):await process_frame
 await RenderingServer.frame_post_draw
func shaft_probe(link: Dictionary) -> Vector2i:
 var polygon: PackedVector2Array=Links.arrow_shapes(link)[0]
 return Vector2i(game.screen((polygon[0]+polygon[1]+polygon[5]+polygon[6])/4))
func white_pixels(image: Image,point: Vector2i) -> int:
 var result:=0
 for x in range(-1,2):
  for y in range(-1,2):
   var p:=image.get_pixelv(point+Vector2i(x,y))
   if p.r>.75 and p.g>.75 and p.b>.75:result+=1
 return result
func run():
 var path:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
 root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();game.city=preload("res://core/city_model.gd").new(100,100);game.paused=true;root.add_child(game);current_scene=game
 assert(game.city.add_road(PackedVector2Array([Vector2(40,75),Vector2(40,100)]),"local",true,4).ok)
 assert(game.city.add_building(36,80).ok)
 var port: Dictionary=game.city.power.ports.filter(func(p):return p.edge=="y_max")[0]
 var line:=PackedVector2Array([port.position,port.position+Vector2.UP*88])
 assert(game.city.power.add_wire(line).ok and game.city.water.add_pipe(line).ok)
 game.map_zoom=2.2;game.origin=Vector2.ZERO;game.origin=Vector2(1030,420)-game.screen(Vector2(43,92));game.queue_redraw()
 var road_probe:=shaft_probe(Links.road_links(game.city)[0])
 var utility_probe:=shaft_probe(Links.utility_links(game.city.power,true)[0])
 var power: Dictionary=game.city.power_state();var water: Dictionary=game.city.water_state()
 assert(power.import_kw>0 and water.water_supplied_m3_day>0)
 await settle()
 var base:=root.get_texture().get_image()
 assert(white_pixels(base,road_probe)>0 and white_pixels(base,utility_probe)==0)
 var outside:=base.get_pixelv(Vector2i(game.screen(Vector2(40,100.7))))
 var background:=base.get_pixelv(Vector2i(game.screen(Vector2(43,100.7))))
 assert(Vector3(outside.r,outside.g,outside.b).distance_to(Vector3(background.r,background.g,background.b))<.02)
 var state:={"viewport":str(base.get_size()),"road_arrow_always_visible":true,"flat_boundary_no_pavement_outside":true,"road_probe":road_probe,"utility_probe":utility_probe,"tabs":[],"utility_supply_unchanged":true,"input":"actual utility category mouse press/release, then actual tray closure"}
 for tab in ["power","water"]:
  await click(game.categories[game.NAMES.keys().find(tab)].get_global_rect().get_center())
  game.power_overlay.show_ranges=false;game.water_overlay.show_ranges=false;game.power_overlay.show_flow=false;game.water_overlay.show_flow=false;game.power_overlay.queue_redraw();game.water_overlay.queue_redraw()
  await settle()
  assert(game.power_overlay.tab_open==(tab=="power") and game.water_overlay.tab_open==(tab=="water"))
  assert(game.city.power_state()==power and game.city.water_state()==water)
  var image:=root.get_texture().get_image()
  assert(white_pixels(image,road_probe)>0 and white_pixels(image,utility_probe)>0)
  state.tabs.append({"tab":tab,"power_arrow":Links.utility_links(game.city.power,game.power_overlay.tab_open).size(),"water_arrow":Links.utility_links(game.city.water.geometry,game.water_overlay.tab_open).size(),"white_utility_pixels":white_pixels(image,utility_probe)})
  if tab=="power":assert(image.get_size()==Vector2i(1920,1080) and image.save_png(path)==OK)
 game.drawer.hide();await settle()
 var closed:=root.get_texture().get_image();assert(white_pixels(closed,utility_probe)==0 and white_pixels(closed,road_probe)>0)
 state.closed_utility_arrow_white_pixels=white_pixels(closed,utility_probe)
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
 print("NATIVE_BOUNDARY_LINKS_PASS road/flat edge; power/water real tab arrows; close removes cached arrow; positive supply unchanged");quit()
