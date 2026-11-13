extends SceneTree
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func click(point: Vector2):
 for down in [true,false]:
  var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=point;root.push_input(e,true);await process_frame
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame;await process_frame
 for category in game.NAMES:
  game.select_category(category);await process_frame
  var obsolete: Array=game.drawer_box.find_children("Tool_select","Button",true,false)+game.drawer_box.find_children("Tool_water_select","Button",true,false)+game.drawer_box.find_children("Tool_road","Button",true,false)
  verify(obsolete.is_empty(),category+" has no redundant draw/building/facility-select action")
 verify(game.find_children("Water_select","Button",true,false).is_empty(),"legacy water-panel facility-select button is also removed")
 verify(game.water_overlay.has_method("handle_input") and game.has_method("pick_rendered_building"),"internal facility and building inspection entry points remain available")
 game.select_category("road");await process_frame;await process_frame
 var folds: Array=game.drawer_box.get_children().filter(func(n):return n is Button and n.text=="⌄")
 verify(folds.size()==1 and not folds[0] is OptionButton,"small v is the preserved drawer-collapse button, not a lane dropdown")
 var grid: bool=game.road_grid_enabled
 if not folds.is_empty():folds[0].pressed.emit()
 verify(not game.drawer.visible and game.road_grid_enabled==grid,"v folds the tool drawer without changing the grid choice")
 game.select_category("road");await process_frame;await process_frame
 game.road_drawer.set_kind("curve")
 await click(game.road_grid_button.get_global_rect().get_center());verify(not game.road_grid_enabled,"fixture uses the player's real grid OFF click")
 for card in game.road_lane_cards:
  game.activate_tool("select")
  await click(card.get_global_rect().get_center())
  verify(game.mode=="road" and game.road_lanes==int(card.get_meta("lanes")) and game.road_drawer.cursor_armed,"real card click starts its exact road width from selection mode")
  verify(game.road_drawer.kind=="curve" and not game.road_grid_enabled,"card activation retains selected drawing method and grid setting")
 game.road_drawer.click(Vector2(20,20));verify(game.road_drawer.anchors.size()==1,"pending curve exists before width-card restart")
 await click(game.road_lane_cards[1].get_global_rect().get_center())
 verify(game.road_drawer.anchors.is_empty() and game.road_drawer.cursor_armed and game.road_lanes==3,"width card starts a fresh stroke instead of changing an unfinished stroke's width")
 game.road_drawer.click(Vector2(20,20))
 for down in [true,false]:
  var e:=InputEventKey.new();e.keycode=KEY_ESCAPE;e.pressed=down;root.push_input(e,true);await process_frame
 verify(game.mode=="select" and game.road_drawer.anchors.is_empty() and not game.road_drawer.cursor_armed,"real Escape exits drawing mode and clears its preview")
 game.select_category("road");await process_frame;await process_frame
 await click(game.road_lane_cards[1].get_global_rect().get_center())
 verify(game.mode=="road" and game.road_drawer.cursor_armed and game.road_drawer.kind=="curve" and not game.road_grid_enabled,"clicking the already selected lane card re-arms drawing after Escape")
 game.road_drawer.click(Vector2(20,20));game.map_zoom=.75;game.origin=Vector2(850,20)
 for down in [true,false]:
  var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=down;e.position=game.screen(Vector2(50,50));root.push_input(e,true);await process_frame
 verify(game.mode=="select" and game.road_drawer.anchors.is_empty() and not game.road_drawer.cursor_armed,"real right click exits drawing without constructing a road")
 verify(game.city.roads.is_empty() and game.city.buildings.is_empty(),"toolbar navigation and cancellations never mutate the city")
 game.queue_free();await process_frame
 print("RESULT %d/%d road toolbar cleanup checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
