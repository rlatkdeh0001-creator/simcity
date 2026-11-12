extends SceneTree
var game
func _initialize():run.call_deferred()
func click(point: Vector2):
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
func run():
 var folder:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence-dir="):folder=arg.trim_prefix("--evidence-dir=")
 if folder.is_empty():quit(1);return
 game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);current_scene=game
 assert(game.city.add_road(PackedVector2Array([Vector2(10,44),Vector2(90,44)])).ok)
 assert(game.city.add_building(40,41).ok)
 assert(game.city.add_power_plant(Vector2(20,41),300).ok)
 assert(game.city.add_water_facility(Vector2(26,41),"water",1000).ok)
 assert(game.city.add_water_facility(Vector2(70,41),"sewage",1000).ok)
 assert(game.city.power.add_wire(PackedVector2Array([Vector2(84,168),Vector2(300,168)])).ok)
 assert(game.city.water.add_pipe(PackedVector2Array([Vector2(108,168),Vector2(284,168)])).ok)
 game.map_zoom=.65;game.origin=Vector2(960,360)-Vector2(8*game.tile.x,92*game.tile.y)*game.map_zoom;game.queue_redraw()
 for i in range(8):await process_frame
 var p0: Dictionary=game.city.power_state();var w0: Dictionary=game.city.water_state()
 assert(w0.water_supplied_m3_day>0)
 var base_image: Image
 var probe_power: Vector2i=Vector2i(game.screen(Vector2(37,42)))
 var probe_water: Vector2i=probe_power+Vector2i(0,-4)
 for tab in ["normal","power","water"]:
  if tab!="normal":await click(game.categories[game.NAMES.keys().find(tab)].get_global_rect().get_center())
  for i in range(8):await process_frame
  await RenderingServer.frame_post_draw
  assert(game.power_overlay.tab_open==(tab=="power") and game.water_overlay.tab_open==(tab=="water"))
  assert(game.city.power_state()==p0 and game.city.water_state()==w0)
  var image:=root.get_texture().get_image()
  if tab=="normal":base_image=image
  else:
   var pixel:=probe_power if tab=="power" else probe_water
   assert(Vector3(image.get_pixelv(pixel).r,image.get_pixelv(pixel).g,image.get_pixelv(pixel).b).distance_to(Vector3(base_image.get_pixelv(pixel).r,base_image.get_pixelv(pixel).g,base_image.get_pixelv(pixel).b))>.05)
  var state:={"tab":tab,"viewport":str(root.get_visible_rect()),"power_visible":game.power_overlay.tab_open,"water_visible":game.water_overlay.tab_open,"power_ranges":game.power_overlay.show_ranges,"water_ranges":game.water_overlay.show_ranges,"power_state":p0,"water_state":w0,"above_ground_utility_structures_retained":true,"power_probe_rgb":str(image.get_pixelv(probe_power)),"water_probe_rgb":str(image.get_pixelv(probe_water)),"input":"actual category mouse press/release; fixed same-city test fixture"}
  var path: String=folder+"/"+tab+"-1920.png";var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  ")+"\n");file.close()
  assert(image.save_png(path)==OK);print("NATIVE_NETWORK_CAPTURE "+tab)
 game.drawer.hide()
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
 var closed_image:=root.get_texture().get_image()
 for pixel in [probe_power,probe_water]:
  var a:=closed_image.get_pixelv(pixel);var b:=base_image.get_pixelv(pixel)
  assert(Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b))<.01)
 print("NATIVE_CLOSED_NETWORK_CACHE_CLEARED")
 quit()
