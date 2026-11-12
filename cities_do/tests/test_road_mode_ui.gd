extends SceneTree
var checks:=0
var failures:=0
func verify(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game);await process_frame
 verify(game.get("road_modes")!=null,"approved 1-B floating road mode palette exists")
 if game.get("road_modes")!=null:
  verify(not game.road_modes.visible,"palette is hidden outside road category")
  game.select_category("road");await process_frame;await process_frame
  var buttons: Array=game.road_mode_buttons
  verify(game.road_modes.visible and buttons.size()==3 and game.mode=="road","road tab shows exactly three mode buttons and activates drawing")
  verify(buttons.all(func(b):return b.text.is_empty() and b.icon!=null and b.get_theme_font_size("font_size")>=18),"three real icons only, no explanatory labels")
  verify(buttons.all(func(b):return b.get_meta("road_kind")!="legacy"),"old freehand drag is retained internally but has no player-facing button")
  verify(buttons[0].button_pressed and buttons[0].get_theme_stylebox("pressed").bg_color==Color("36b7ff"),"straight default has exact approved blue selection")
  for size_value in [Vector2i(1920,1080),Vector2i(1280,820),Vector2i(960,640)]:
   root.size=size_value;await process_frame;await process_frame
   verify(root.get_visible_rect().encloses(game.road_modes.get_global_rect()),"anchored palette stays onscreen at "+str(size_value))
   verify(not game.road_modes.get_global_rect().intersects(game.drawer.get_global_rect()) and not game.road_modes.get_global_rect().intersects(game.dock.get_global_rect()),"palette never overlaps drawer/dock at "+str(size_value))
  buttons[1].grab_focus()
  for down in [true,false]:
   var event:=InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=down;root.push_input(event,true);await process_frame
  verify(game.road_drawer.kind=="curve" and buttons[1].button_pressed,"keyboard focus and Enter select quadratic mode")
  game.select_category("fire");verify(not game.road_modes.visible and game.road_drawer.anchors.is_empty(),"tab change hides palette and cancels pending construction")
 game.queue_free();await process_frame
 print("RESULT %d/%d road mode UI checks passed" % [checks-failures,checks]);quit(1 if failures else 0)
