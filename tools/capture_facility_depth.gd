extends SceneTree
func _initialize():run.call_deferred()
func run():
 var path:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);current_scene=game
 # Renderer-only fixture: disjoint authored lots, intentionally no economy/placement changes.
 var specs:=[["park-garden-2x2",Vector2(33,35)],["power-solar",Vector2(30,36)]]
 for spec in specs:
  var result: Dictionary=game.city.public_facilities.preview(spec[0],spec[1]);var record: Dictionary=result.record
  record.id=game.city.next_id;game.city.next_id+=1;game.city.public_facilities.lots.append(record)
  game.public_controller.visual(record)
 game.map_zoom=4;game.origin=Vector2(960,400)-Vector2((31-36)*game.tile.x,(31+36)*game.tile.y)*game.map_zoom
 for frame in range(200):
  game.queue_redraw();await process_frame
  if not game.building_views.busy and game.building_views.queue.is_empty() and game.building_views.cache.size()>=2:break
 for frame in range(5):game.queue_redraw();await process_frame
 await RenderingServer.frame_post_draw
 var state:={"lots":game.city.public_facilities.lots,"depths":game.city.public_facilities.lots.map(func(n):return game.building_depth(n)),"rendered":game.building_views.cache.size()}
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  "));file.close()
 print("RENDER_FIXTURE ",state.depths," cached=",state.rendered)
 quit(0 if root.get_texture().get_image().save_png(path)==OK else 1)
