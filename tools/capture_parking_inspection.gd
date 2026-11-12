extends SceneTree
## Capture current blocked state, not an empty-parking implementation.
func _initialize():run.call_deferred()
func run():
 var path:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);current_scene=game
 assert(game.city.add_road(PackedVector2Array([Vector2(10,40),Vector2(90,40)])).ok)
 var ids:=["parking-small-2x4","parking-medium-4x4","parking-large-4x8","parking-tower-4x4-4f"]
 var cost:=0.0
 for id in ids:cost+=game.city.public_facilities.price(id)
 game.city.funds=ceili(cost)+1000
 var records:=[]
 for i in range(ids.size()):
  var placed: Dictionary=game.city.public_facilities.place(ids[i],Vector2([20,35,55,74][i],45),0,true)
  assert(placed.ok);records.append({"id":ids[i],"position":placed.record.position,"model":game.public_controller.asset(ids[i]).model})
 game.map_zoom=1.3;game.origin=Vector2.ZERO;game.origin=Vector2(960,420)-game.screen(Vector2(48,44));game.refresh();game.queue_redraw()
 var ready:=false
 for i in range(160):
  ready=true
  for record in game.city.public_facilities.lots:
   if game.public_controller.visual(record).is_empty():ready=false
  if ready:break
  await process_frame
 assert(ready)
 for i in range(5):await process_frame
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image();assert(image.get_size()==Vector2i(1920,1080));assert(image.save_png(path)==OK)
 var state:={"status":"BLOCKED: vehicles are in the single combined facility mesh; no removal applied","capture":"current unchanged parking models, NOT empty-parking result","viewport":str(image.get_size()),"placement":"four actual successful public_facilities.place calls; fixture funds equal summed real construction prices plus 1000","facilities":records,"original_assets_modified":false}
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
 print("NATIVE_PARKING_INSPECTION_PASS four current models captured; VEHICLE_REMOVAL_NOT_APPLIED");quit()
