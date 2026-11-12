extends SceneTree
var checks:=0
var failed:=0
func _initialize():run.call_deferred()
func verify(ok: bool,description: String):
 checks+=1
 if ok:print("PASS "+description)
 else:failed+=1;push_error("FAIL "+description)
func run():
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame
 verify(game.has_method("developer_tools_enabled"),"explicit opt-in developer UI policy exists")
 if game.has_method("developer_tools_enabled"):
  verify(not game.developer_tools_allowed(false,PackedStringArray(["--developer-tools"])),"release builds reject developer UI even with opt-in flag")
  verify(not game.developer_tools_allowed(true,PackedStringArray()),"ordinary debug play hides developer tools by default")
  verify(game.developer_tools_allowed(true,PackedStringArray(["--developer-tools"])),"debug engine with exact opt-in flag enables developer tools")
  verify(not game.developer_tools_allowed(true,PackedStringArray(["--developer-tools=false"])),"nonmatching flag never enables developer UI")
 game.select_category("build")
 var buttons: Array=game.drawer_box.find_children("Tool_upgrade","Button",true,false)
 var enabled:=OS.is_debug_build() and "--developer-tools" in OS.get_cmdline_user_args()
 verify(buttons.size()==(1 if enabled else 0),"growth button follows actual process developer opt-in: "+str(enabled))
 if enabled and buttons.size()==1:
  game.city.add_road(PackedVector2Array([Vector2(1,20),Vector2(39,20)]))
  var result: Dictionary=game.city.add_building(10,17,"residential",120)
  verify(result.ok,"real growth fixture has valid frontage")
  if result.ok:
   game.selected=result.building.id;buttons[0].pressed.emit()
   verify(game.city.find_building(game.selected).level==2,"developer-only button still executes existing growth simulation")
 for tab in game.NAMES:
  game.select_category(tab)
  verify(game.drawer_box.find_children("Tool_reset","Button",true,false).is_empty() and game.drawer_box.find_children("Tool_traffic","Button",true,false).is_empty() and game.drawer_box.find_children("Tool_water_settings","Button",true,false).is_empty() and game.drawer_box.find_children("Tool_power_select","Button",true,false).is_empty(),tab+" keeps the other four removed buttons absent")
 game.queue_free();await process_frame
 print("RESULT %d/%d developer UI checks passed"%[checks-failed,checks]);quit(1 if failed else 0)
