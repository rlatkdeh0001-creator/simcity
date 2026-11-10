extends SceneTree
var checks := 0
var failed := 0
func _initialize(): run.call_deferred()
func verify(value: bool, description: String):
 checks+=1
 if value: print("PASS "+description)
 else:
  failed+=1
  push_error("FAIL "+description)
func run():
 var preview=load("res://bottom_ui_preview.tscn").instantiate()
 root.add_child(preview)
 current_scene=preview
 await process_frame
 await process_frame
 verify(preview.city.buildings.size()==34,"preview uses 34 validated catalog buildings")
 verify(preview.city.buildings.all(func(b):return not b.asset_id.is_empty()),"every preview building comes from actual game catalog")
 verify(preview.city.roads.size()==6,"preview uses six actual model roads")
 verify(preview.city.power.plants.size()==1 and preview.city.water.facilities.size()==2,"preview contains actual utility sources")
 verify(preview.categories.size()==12,"twelve real category buttons created")
 var no_instructions := true
 for node in preview.find_children("*","Label",true,false):
  for phrase in ["64m","32m","도착과 무관","1실제초","시험용","배치 검토용"]:
   no_instructions=no_instructions and not phrase in node.text
 verify(no_instructions,"HUD omits range explanations and development instructions")
 verify(not preview.controls_panel.visible and not preview.hud.visible,"shared HUD does not create legacy side tools")
 verify(preview.chosen=="power" and preview.power_overlay.tab_open and not preview.power_overlay.panel.visible,"power view uses real network overlay with bottom controls")
 for size_value in [Vector2i(1920,1080),Vector2i(1280,820),Vector2i(960,640)]:
  root.size=size_value
  await process_frame
  await process_frame
  var bottom: float=preview.dock.get_global_rect().end.y
  verify(absf(bottom-root.get_visible_rect().size.y)<2,"dock stays anchored to bottom at "+str(size_value))
  verify(preview.drawer.get_global_rect().position.x>=0 and preview.drawer.get_global_rect().end.x<=root.get_visible_rect().size.x+1,"context tray remains within screen at "+str(size_value))
 verify(preview.categories.all(func(b):return b.get_global_rect().position.y>root.get_visible_rect().size.y*.65),"all primary category icons remain in bottom region")
 verify(not preview.NAMES.has("other"),"unused other category removed")
 var saved_city=preview.city
 var slots: Array=preview.service_slots()
 verify(slots.size()==7,"preview shares all seven data-driven service slots with main")
 for key in ["fire","police","corrections"]:
  preview.select_category(key)
  var slot_buttons: Array=preview.drawer_box.get_children().filter(func(n):return n is Button and n.name.begins_with("Slot_"))
  verify(slot_buttons.size()==slots.filter(func(s):return s.category==key).size(),key+" preview shows exact configured slots")
  verify(slot_buttons.all(func(b):return b.disabled and b.get_child_count()==0),key+" preview slots have names only and remain disabled")
  var funds: int=preview.city.funds
  var buildings: int=preview.city.buildings.size()
  for button in slot_buttons: button.pressed.emit()
  verify(preview.city==saved_city and preview.city.funds==funds and preview.city.buildings.size()==buildings,key+" forced clicks cannot construct or charge")
 for key in ["health","education"]:
  preview.select_category(key)
  verify(not preview.show_zoning_tiles(),key+" hides placement grid")
  verify(not preview.power_overlay.tab_open and not preview.water_overlay.tab_open,key+" disables utility overlays")
  var tools := []
  for child in preview.drawer_box.get_children():
   if child is Button and child.name.begins_with("Tool_"): tools.append(child)
  verify(tools.size()==4,key+" has expected facility entries")
  verify(tools.all(func(b):return not b.disabled),"registered service assets can be inspected")
  if key=="health":
   tools[3].pressed.emit()
   await process_frame
   var windows=preview.find_children("ServiceAssetPreview","Window",true,false)
   verify(windows.size()==1,"crematorium opens actual model inspector")
   if not windows.is_empty(): windows[0].close_requested.emit()
   await process_frame
   verify(preview.city==saved_city and preview.city.buildings.size()==34,"inspector preserves city")
 preview.select_category("education")
 preview.categories[-1].grab_focus()
 verify(preview.categories[-1].focus_neighbor_right==preview.categories[0].get_path(),"keyboard navigation wraps across new category count")
 preview.categories[3].pressed.emit()
 verify(preview.chosen=="water" and preview.water_overlay.tab_open and not preview.power_overlay.tab_open,"category switch enables actual water overlay")
 verify(not preview.water_overlay.panel.visible,"water side panel stays hidden with bottom controls")
 var button: Button
 for child in preview.drawer_box.get_children():
  if child is Button and child.name=="Tool_water_pipe": button=child
 if button!=null: button.pressed.emit()
 verify(button!=null and preview.mode=="water_pipe","bottom water tool selects existing paired-pipe construction mode")
 preview.categories[2].grab_focus()
 verify(root.gui_get_focus_owner()==preview.categories[2] and preview.categories[2].focus_neighbor_right==preview.categories[3].get_path(),"keyboard focus has explicit category neighbor")
 var escape := InputEventKey.new()
 escape.keycode=KEY_ESCAPE
 escape.pressed=true
 preview._unhandled_key_input(escape)
 verify(not preview.drawer.visible,"escape closes bottom context tray")
 preview.select_category("power")
 preview.paused=true
 var before: float=preview.city.water.supplied_m3
 preview._process(1)
 verify(preview.city.water.supplied_m3==before,"preview pause actually stops water simulation time")
 preview.paused=false
 preview.simulation_speed=3
 var rate: float=preview.city.water_state().water_supplied_m3_day
 preview._process(1)
 verify(is_equal_approx(preview.city.water.supplied_m3-before,rate*3*24/86400),"3x control advances the actual model 72 game seconds")
 verify("50,000 doth" in preview.money.text and "34" in preview.counts.text,"status uses actual funds and building count")
 var added: Dictionary=preview.city.add_building(28,67)
 preview.fit_preview()
 verify(added.ok and is_finite(preview.map_zoom),"camera fitting supports newly built procedural lots too")
 preview.queue_free()
 await process_frame
 print("RESULT %d/%d bottom UI checks passed" % [checks-failed,checks])
 quit(1 if failed else 0)
