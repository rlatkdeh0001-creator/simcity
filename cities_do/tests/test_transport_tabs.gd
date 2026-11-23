extends SceneTree

var checks := 0
var failures := 0

func _initialize():
 run.call_deferred()

func check(ok:bool, title:String):
 checks+=1
 if not ok:
  failures+=1
  push_error("FAIL "+title)

func click(button:Control):
 var p:=button.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new()
 motion.position=p
 root.push_input(motion,true)
 for down in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT
  event.pressed=down
  event.position=p
  root.push_input(event,true)

func run():
 root.size=Vector2i(1280,720)
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 game.paused=true
 game.select_category("transport")
 await process_frame
 var tabs:Control=game.get_node_or_null("HUD/TransportTabs")
 if tabs==null:
  var matches:Array=game.find_children("TransportTabs","HBoxContainer",true,false)
  if not matches.is_empty():tabs=matches[0]
 check(tabs!=null,"transport has a dedicated tab row")
 if tabs!=null:
  var expected:=[
   ["Facility_bus-stop-01","Facility_bus-station-01","Tool_transit_line"],
   ["Tool_metro","Facility_subway-entrance-01","Tool_transit_line"],
   ["Tool_rail","RailHeightControls","Facility_train-station-01","Tool_transit_line"]]
  check(game.transport_tab==0,"first transport tab is bus")
  for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
   root.size=resolution
   await process_frame
   await process_frame
   var width:float=game.drawer.size.x
   var tab_pos:=tabs.global_position
   for i in range(3):
    game.activate_tool("rail")
    click(tabs.get_child(i))
    await process_frame
    await process_frame
    check(game.transport_tab==i and game.mode=="select","viewport click selects tab and clears tool: %s %d"%[resolution,i])
    var names:Array=[]
    for child in game.drawer_box.get_children().slice(1,-1):names.append(str(child.name))
    check(names==expected[i],"exact card order: %s %d: %s"%[resolution,i,names])
    var route:Control=game.drawer_box.get_node("Tool_transit_line")
    check(route.get_global_rect().end.x<=game.drawer.get_global_rect().end.x-12,"last card is fully inside the tray: %s %d"%[resolution,i])
    check(game.drawer.size.x==width and tabs.global_position==tab_pos,"tray and tabs stay fixed: %s %d"%[resolution,i])
    check(root.get_visible_rect().encloses(tabs.get_global_rect()) and not tabs.get_global_rect().intersects(game.drawer.get_global_rect()) and not game.drawer.get_global_rect().intersects(game.dock.get_global_rect()),"HUD regions do not overlap: %s %d"%[resolution,i])
  game.select_category("road")
  check(not tabs.visible,"other categories hide the transport tab row")
  game.select_category("transport")
  check(game.transport_tab==2,"transport remembers the last viewed tab")
 print("Transport tabs: %d passed, %d failed"%[checks-failures,failures])
 quit(1 if failures else 0)
