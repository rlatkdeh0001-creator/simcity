extends SceneTree
var checks:=0
var failures:=0
func verify(value: bool,label: String):
 checks+=1
 if value:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1920,1080)
 var scene=load("res://main.tscn").instantiate();scene.paused=true
 scene.city.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
 root.add_child(scene)
 await process_frame
 verify(scene.get("public_controller")!=null,"existing game owns public world placement interaction, without a new panel")
 if scene.get("public_controller")!=null:
  await check_input(scene)
 scene.queue_free();await process_frame
 print("RESULT %d/%d public UI checks passed" % [checks-failures,checks])
 quit(1 if failures else 0)
func mouse(position: Vector2,button: int=MOUSE_BUTTON_LEFT):
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=position;event.button_index=button;event.pressed=down;root.push_input(event,true)
 await process_frame
func move(position: Vector2):
 var event:=InputEventMouseMotion.new();event.position=position;root.push_input(event,true)
 await process_frame
func key(code: int):
 var event:=InputEventKey.new();event.keycode=code;event.pressed=true;root.push_input(event,true)
 await process_frame
func check_input(scene):
 var controller=scene.public_controller
 scene.select_category("fire");await process_frame;await process_frame
 var panels: int=scene.find_children("*","PanelContainer",true,false).filter(func(n):return n.name not in ["AssetMoneyInfo","InsufficientFundsBubble"]).size()
 var button: Button=scene.drawer_box.get_node("Slot_fire_standard")
 await mouse(button.get_global_rect().get_center())
 verify(scene.mode=="public_placement" and controller.asset_id=="fire-station","actual C-card mouse click starts the selected world ghost")
 verify(scene.find_children("*","PanelContainer",true,false).filter(func(n):return n.name not in ["AssetMoneyInfo","InsufficientFundsBubble"]).size()==panels and scene.get_node_or_null("ServiceAssetPreview")==null,"no extra construction panel/modal beyond approved hover and cash bubbles")
 var position: Vector2=scene.screen(Vector2(12,35))
 await move(position)
 verify(controller.preview().ok and controller.ghost_color().g>controller.ghost_color().r,"valid frontage and cash produce green translucent ghost")
 await key(KEY_R)
 verify(controller.turns==1 and not controller.preview().ok and controller.ghost_color().r>controller.ghost_color().g,"R rotates 90 degrees and wrong front becomes red")
 await key(KEY_ESCAPE)
 verify(scene.mode=="select" and scene.city.public_facilities.lots.is_empty() and scene.city.funds==50000,"ESC cancels without placing or charging")
 controller.begin("fire-station");await mouse(position,MOUSE_BUTTON_RIGHT)
 verify(scene.mode=="select" and controller.asset_id.is_empty(),"right click cancels world placement")
 controller.begin("fire-station");await move(position);await mouse(position)
 verify(scene.city.public_facilities.lots.size()==1 and scene.city.funds==30000,"actual world click places and charges once")
 scene.toggle_demolition();await mouse(position)
 verify(scene.city.public_facilities.lots.is_empty() and scene.city.funds==30000,"existing bulldozer removes public building without invented refund")
 scene.city.funds=0;controller.begin("fire-station");await move(position)
 var previous_message: String=scene.message
 verify(not controller.preview().ok and controller.preview().code=="insufficient_funds","cash shortage is recorded in validation, not a new HUD explanation")
 await mouse(position)
 verify(scene.city.funds==0 and scene.city.public_facilities.lots.is_empty() and scene.message==previous_message,"cash rejection creates no building, debit or explanatory HUD text")
 for tool: String in scene.SERVICE_TOOLS:
  scene.activate_tool(tool)
  if scene.city.public_facilities.price(scene.SERVICE_TOOLS[tool])>scene.city.utility_balance():
   verify(scene.mode!="public_placement" and controller.asset_id.is_empty(),tool+" approved insufficient-funds gate prevents ghost")
  else:
   verify(scene.mode=="public_placement" and controller.asset_id==scene.SERVICE_TOOLS[tool],tool+" affordable existing medical/education/crematorium card selects actual placement")
 controller.cancel()
