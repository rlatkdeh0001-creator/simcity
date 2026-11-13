extends SceneTree
var checks:=0
var failed:=0
func _initialize():run.call_deferred()
func verify(ok: bool,description: String):
 checks+=1
 if ok:print("PASS "+description)
 else:failed+=1;push_error("FAIL "+description)
func run():
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game)
 await process_frame;await process_frame
 var forbidden:=["power_plant","power_settings","power_demo","water_supply","water_treatment","water_demo","score","residential_gallery","parcel_demo","facilities_gallery","vehicles_gallery","traffic_demo","water_settings","traffic","upgrade","reset","power_select","select","water_select","road"]
 var retained:={"power":["power_wire"],"water":["water_pipe"],"build":["build","build_commercial","build_industrial","build_erase"],"road":[],"park":[],"transport":[],"health":["hospital","clinic","large_hospital","crematorium"],"education":["elementary","high_school","college","university"],"environment":[],"fire":[],"police":[]}
 var inventory:={}
 if game.developer_tools_enabled():
  forbidden.erase("upgrade");retained.build.append("upgrade")
 for tab in game.NAMES:
  game.select_category(tab);await process_frame
  var tools: Array=game.drawer_box.get_children().filter(func(n):return n is Button and n.name.begins_with("Tool_"))
  var ids: Array=tools.map(func(n):return str(n.name).trim_prefix("Tool_"));ids.sort()
  var expected: Array=retained[tab].duplicate();expected.sort()
  verify(ids==expected,tab+" contains only retained play tools: "+str(ids))
  verify(ids.all(func(id):return not id in forbidden),tab+" removes free prototypes and demonstration UI connections")
  var cards:Array=game.road_lane_cards if tab=="road" else game.drawer_box.get_children().filter(func(n):return n is Button and n.has_meta("thumbnail_asset_id"))
  inventory[tab]={"tools":ids,"cards":cards.map(func(n):return n.get_meta("thumbnail_asset_id"))}
  for tool in ["power_wire","water_pipe","select"]:
   var button=game.drawer_box.get_node_or_null("Tool_"+tool)
   if button!=null:button.pressed.emit();verify(game.mode==tool,"retained "+tool+" still activates real mode")
 game.city.add_road(PackedVector2Array([Vector2(10,30),Vector2(40,30)]));game.activate_tool("traffic")
 verify(game.traffic.running and game.message.is_empty() and not game.hud.visible,"road simulation starts without mechanics explanation text")
 game.select_category("road")
 verify(game.road_mode_buttons.size()==3 and game.road_lane_cards.size()==7 and game.bulldozer!=null,"three road modes, seven lane cards and bulldozer preserved")
 print("PLAY_TOOL_INVENTORY "+JSON.stringify(inventory))
 game.queue_free();await process_frame
 print("RESULT %d/%d play tool checks passed"%[checks-failed,checks]);quit(1 if failed else 0)
