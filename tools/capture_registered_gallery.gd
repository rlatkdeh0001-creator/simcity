extends SceneTree
## Reuse the existing exhibition and its capture function; no new game UI.
func _initialize():run.call_deferred()
func run():
 var path:=""
 var bottom:=false
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--evidence-path="):path=argument.trim_prefix("--evidence-path=")
  if argument=="--scroll-bottom":bottom=true
 if path.is_empty():push_error("Missing --evidence-path");quit(2);return
 var gallery=load("res://vehicle_showcase.tscn").instantiate()
 gallery.facility_group="commercial_industrial"
 root.add_child(gallery)
 current_scene=gallery
 for frame in range(5):await process_frame
 if bottom:
  var scroll: ScrollContainer=gallery.find_children("*","ScrollContainer",true,false)[0]
  scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
 var file:=FileAccess.open(path.trim_suffix(".png")+".state.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"entries":gallery.entries.map(func(entry):return entry.id),"count":gallery.entries.size(),"viewport":str(root.get_visible_rect()),"scroll_bottom":bottom,"same_scale":gallery.same_scale},"  ")+"\n")
 file.close()
 gallery.capture(path)
