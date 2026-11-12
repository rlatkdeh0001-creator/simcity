extends SceneTree
var checks:=0
var failed:=0
func _initialize():run.call_deferred()
func verify(ok: bool,description: String):
 checks+=1
 if ok:print("PASS "+description)
 else:failed+=1;push_error("FAIL "+description)
func hidden(game) -> bool:return not game.power_overlay.tab_open and not game.water_overlay.tab_open
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://bottom_ui_preview.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame;await process_frame
 var power: Dictionary=game.city.power_state();var water: Dictionary=game.city.water_state()
 verify(water.water_supplied_m3_day>0 and not power.consumers.is_empty(),"real authored city has connected consumers for display-independent supply checks")
 game.drawer.hide()
 verify(hidden(game),"closing initially open utility tray hides both networks")
 for tab in game.NAMES:
  game.select_category(tab)
  verify(game.power_overlay.tab_open==(tab=="power") and game.water_overlay.tab_open==(tab=="water"),tab+" displays only its own network")
  verify(game.power_overlay.show_ranges==(tab=="power") and game.water_overlay.show_ranges==(tab=="water"),tab+" supply ranges follow utility tab")
  verify(game.city.power_state()==power and game.city.water_state()==water,tab+" visual switching leaves actual service and connectivity unchanged")
 for tab in ["power","water"]:
  game.select_category(tab)
  var overlay=game.power_overlay if tab=="power" else game.water_overlay
  var anchor: Vector2=game.city.power.plants[0].position if tab=="power" else game.city.water.facilities[0].position
  var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=game.screen(anchor/4)
  overlay.handle_input(press)
  verify(overlay.drawing and overlay.tab_open and overlay.show_ranges,tab+" real connection placement keeps its network and range visible")
  game.drawer.hide()
  verify(hidden(game) and not overlay.drawing and overlay.stroke.is_empty(),tab+" direct tray close clears hidden connection preview and both networks")
  game.drawer.show()
  verify(overlay.tab_open,tab+" toolbar reopen restores only chosen network")
  var escape:=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE;game._unhandled_key_input(escape)
  verify(hidden(game),tab+" Escape hides networks")
  game.select_category(tab);game.drawer_box.get_child(game.drawer_box.get_child_count()-1).pressed.emit()
  verify(hidden(game),tab+" tray close button hides networks")
  game.select_category(tab);game.toggle_demolition()
  verify(hidden(game),tab+" bulldozer hides both networks")
  game.select_category(tab);verify(game.public_controller.begin("power-wind"),"facility placement starts")
  verify(hidden(game) and game.mode=="public_placement",tab+" facility-card tray closure hides networks without cancelling facility ghost")
  game.public_controller.cancel()
 game.drawer.hide()
 var a: float=game.city.water.supplied_m3;game.city.advance_water(.01);var hidden_volume: float=game.city.water.supplied_m3-a
 game.select_category("water");a=game.city.water.supplied_m3;game.city.advance_water(.01)
 verify(hidden_volume>0 and is_equal_approx(game.city.water.supplied_m3-a,hidden_volume),"equal elapsed time meters identical nonzero water volume hidden and shown")
 game.queue_free();await process_frame
 var main=load("res://main.tscn").instantiate();main.paused=true;root.add_child(main);await process_frame
 verify(hidden(main) and not main.drawer.visible,"normal initial main screen hides both networks")
 main.queue_free();await process_frame
 print("RESULT %d/%d utility tab visibility checks passed"%[checks-failed,checks]);quit(1 if failed else 0)
