extends "res://bottom_ui_preview.gd"
var record_dir := ""
var record_index := -1
var recording := false
var record_time := 0.0
func make_town():
 city.add_road(PackedVector2Array([Vector2(10,40),Vector2(70,40)]),"local",true,4)
 city.add_road(PackedVector2Array([Vector2(40,10),Vector2(40,70)]))
 city.add_road(PackedVector2Array([Vector2(60,40),Vector2(60,68)]))
 for entry in [["small-4x4-a",22,34],["mansion-a-4x4-4f",30,34],["small-4x4-b",45,34],["mansion-b-4x4-4f",64,34],["small-4x4-b",34,22],["small-2x2-a",43,26],["small-4x4-a",34,50],["small-4x4-b",43,50],["small-2x2-b",63,52],["small-4x4-a",54,60]]:
  var result: Dictionary=city.place_catalog_building(entry[0],entry[1],entry[2])
  if not result.ok:push_error("Invalid junction demo lot: "+str(entry))
func _ready():
 super._ready()
 var tab_choice := "transport"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--bottom-tab="):tab_choice=argument.trim_prefix("--bottom-tab=")
 select_category(tab_choice)
 categories[NAMES.keys().find(chosen)].grab_focus.call_deferred()
 if chosen=="transport":drawer.hide()
 if traffic.rebuild(city.roads):traffic.seed_traffic()
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--record-junction="):
   record_dir=argument.trim_prefix("--record-junction=")
   DirAccess.make_dir_recursive_absolute(record_dir)
func _process(delta: float):
 super._process(delta)
 record_time+=delta
 if record_dir!="" and not recording and int(record_time*5)>record_index:
  record_index=int(record_time*5)
  recording=true
  record_frame.call_deferred()
func record_frame():
 await RenderingServer.frame_post_draw
 var error := get_viewport().get_texture().get_image().save_png(record_dir.path_join("%04d.png"%record_index))
 recording=false
 if error!=OK or record_time>=18:get_tree().quit(0 if error==OK else 1)
