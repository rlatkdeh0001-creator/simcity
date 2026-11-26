extends SceneTree
## Native main-scene fixture. File output is opt-in and uses an untouched framebuffer.
const City = preload("res://core/city_model.gd")
var game
var checks := 0
var failed := 0

func _initialize():
 run.call_deferred()

func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS ",label)
 else:failed+=1;printerr("FAIL ",label)

func settle():
 for i in range(4):await process_frame

func move(position:Vector2):
 var event:=InputEventMouseMotion.new()
 event.position=position;event.global_position=position
 root.push_input(event,true)
 await settle()

func click(position:Vector2):
 await move(position)
 for pressed:bool in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
  event.position=position;event.global_position=position
  root.push_input(event,true)
  await process_frame

func run():
 Engine.max_fps=30
 root.size=Vector2i(1920,1080)
 var city=City.new(100,100,20261126)
 city.population_enabled=false;city.happiness_enabled=false;city.funds=100000000
 var track:=PackedVector2Array([Vector2(20,50),Vector2(84,50)])
 var levels:=PackedFloat64Array([15,15])
 var deck:Dictionary=city.add_transit_route(track,"rail",false,levels)
 check(deck.ok and deck.get("piers",[]).size()>=6,"the authored rail viaduct plans a row of supports")
 if failed:finish();return
 var pivot:Vector2=deck.piers[5].positions[0]
 var clear_x:float=(pivot.x+deck.piers[4].positions[0].x)/2
 var clear_path:=PackedVector2Array([Vector2(clear_x,29),Vector2(clear_x,71)])
 check(city.add_road(clear_path).ok,"the road fits through the adjacent future pier span")
 game=load("res://main.tscn").instantiate();game.city=city;game.paused=true
 root.add_child(game);current_scene=game
 await settle()
 game.map_zoom=.95
 game.origin=Vector2(950,440)-game.world_renderer.iso(pivot)*game.map_zoom
 game.refresh();game.select_category("road");game.activate_tool("road")
 game.road_grid_enabled=false
 game.road_drawer.set_height(0)
 await settle()
 var start:Vector2=game.screen(pivot-Vector2(0,21))
 var end:Vector2=game.screen(pivot+Vector2(0,21))
 await click(start)
 await move(end)
 check(game.road_drawer.preview().get("ok",false),"drawing through that point is green before a shaft exists")
 var placed:Dictionary=city.add_transit_route(track,"rail",true,levels)
 check(placed.ok and placed.piers.any(func(p):return pivot in p.positions),"the viaduct actually builds a shaft on that point, with the adjacent crossing road kept")
 game.refresh();await settle()
 var preview:Dictionary=game.road_drawer.preview()
 check(not preview.get("ok",false) and preview.get("reason","")=="교각과 겹침","the real drawing preview refuses the new shaft without moving the cursor")
 var before:=var_to_bytes(city.roads)
 await click(end)
 await settle()
 check(var_to_bytes(city.roads)==before and not game.road_drawer.last_result.get("ok",false),"the endpoint click does not build through the pier")
 for arg:String in OS.get_cmdline_user_args():
  if not arg.begins_with("--pier-capture="):continue
  var file:=arg.trim_prefix("--pier-capture=")
  if failed:break
  if DisplayServer.get_name()=="headless" or FileAccess.file_exists(file):
   check(false,"capture requires a native window and a new destination");break
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image()
  check(image.get_size()==Vector2i(1920,1080),"the uncropped framebuffer is 1920×1080")
  if not failed:check(image.save_png(file)==OK,"saved "+file)
 finish()

func finish():
 if is_instance_valid(game) and game.city.simulation!=null:game.city.simulation.shutdown()
 print("SECOND_FIX_PIER_VIEW checks=%d failed=%d"%[checks,failed])
 quit(1 if failed else 0)
