extends SceneTree
func _initialize():run.call_deferred()
func run():
 var path:="";var tab:="power"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence="):path=arg.trim_prefix("--evidence=")
  if arg.begins_with("--tab="):tab=arg.trim_prefix("--tab=")
 if path.is_empty() or tab not in ["power","road"]:quit(1);return
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);current_scene=game
 game.city.add_road(PackedVector2Array([Vector2(10,30),Vector2(70,30)]));game.activate_tool("traffic")
 for frame in range(5):await process_frame
 var button=game.categories[game.NAMES.keys().find(tab)]
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=button.get_global_rect().get_center();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
 for frame in range(8):await process_frame
 if game.chosen!=tab or not game.drawer.visible or not game.traffic.running or not game.message.is_empty():quit(1);return
 await RenderingServer.frame_post_draw
 var state:={"tab":tab,"input":"actual category mouse press/release","viewport":str(root.get_visible_rect()),"traffic_running":game.traffic.running,"hud_text":game.message,"tools":game.drawer_box.get_children().filter(func(n):return n is Button and n.name.begins_with("Tool_")).map(func(n):return str(n.name)),"cards":game.drawer_box.get_children().filter(func(n):return n is Button and n.has_meta("thumbnail_asset_id")).map(func(n):return n.get_meta("thumbnail_asset_id")),"road_modes":game.road_mode_buttons.size(),"road_modes_visible":game.road_modes.visible}
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(state,"  ")+"\n");file.close()
 quit(0 if root.get_texture().get_image().save_png(path)==OK else 1)
