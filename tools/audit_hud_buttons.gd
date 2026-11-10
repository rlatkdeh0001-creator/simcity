extends SceneTree
## Snapshot actual drawer bindings for the delivery report; never construct assets.
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1280,820)
 var game=load("res://main.tscn").instantiate()
 root.add_child(game);current_scene=game
 await process_frame
 game.paused=true
 var rows: Array=[]
 for category in game.NAMES:
  game.select_category(category)
  for node in game.drawer_box.get_children():
   if not node is Button:continue
   if node.has_meta("thumbnail_asset_id"):
    rows.append({"category":category,"button":str(node.name),"name":node.get_meta("asset_name"),"asset":node.get_meta("thumbnail_asset_id"),"source_png":node.get_meta("source_preview"),"presentation":"thumbnail_C","disabled":node.disabled})
   elif str(node.name).begins_with("Tool_"):
    rows.append({"category":category,"button":str(node.name),"name":node.tooltip_text,"presentation":"existing_icon_tool","reason":"action/network tool or gallery launcher; no individual registered asset PNG"})
 var path: String=""
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--output="):path=argument.trim_prefix("--output=")
 if path.is_empty():quit(1);return
 var stream:=FileAccess.open(path,FileAccess.WRITE)
 if stream==null:quit(1);return
 stream.store_string(JSON.stringify(rows,"  ")+"\n");stream.close()
 print("BUTTON_INVENTORY ",rows.size()," THUMBNAILS ",rows.filter(func(row):return row.presentation=="thumbnail_C").size())
 game.queue_free();await process_frame;quit()
