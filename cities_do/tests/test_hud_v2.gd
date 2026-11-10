extends SceneTree
var checks := 0
var failed := 0
func _initialize(): run.call_deferred()
func verify(value: bool, detail: String):
 checks+=1
 if value: print("PASS "+detail)
 else:
  failed+=1
  push_error("FAIL "+detail)
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 current_scene=game
 await process_frame
 game.paused=true
 verify(game.categories.size()==11 and not game.NAMES.has("corrections"),"v2 has eleven categories, no correction tab")
 verify(game.NAMES.water=="수도","water compatibility key has approved short caption")
 game.select_category("police")
 var ids: Array=game.drawer_box.get_children().filter(func(n):return n is Button and n.has_meta("slot_id")).map(func(n):return n.get_meta("slot_id"))
 verify(ids==["police.small","police.standard","police.headquarters","police.prison"],"police contains all four real inspector slots including prison")
 if game.has_method("begin_city_name_edit"):
  await check_status(game)
 else: verify(false,"approved status row and editable city name are implemented")
 game.queue_free()
 await process_frame
 print("RESULT %d/%d HUD v2 checks passed" % [checks-failed,checks])
 quit(1 if failed else 0)

func check_status(game):
 verify(game.city.city_name=="CITIESDO" and game.city_name_button.text=="CITIESDO","default city identity matches A2")
 verify(game.happiness_label.text=="—" and game.balance_label.text=="—","unimplemented happiness and cash flow stay unknown")
 verify(game.money.text=="50,000 doth" and game.population_label.text=="0","real initial funds and population, no made-up mockup values")
 verify(game.demand_bars.size()==3 and game.demand_bars[0].value>0 and game.demand_bars[1].value==0 and game.demand_bars[2].value==0,"RCI reflects existing empty-city residential-only demand")
 game.city_name_button.pressed.emit()
 await process_frame
 verify(game.city_name_edit.visible and root.gui_get_focus_owner()==game.city_name_edit,"city title is keyboard-editable after activation")
 game.city_name_edit.text="  새 도시  "
 var enter:=InputEventKey.new()
 enter.keycode=KEY_ENTER;enter.pressed=true
 root.push_input(enter)
 enter.pressed=false;root.push_input(enter)
 await process_frame
 verify(game.city.city_name=="새 도시" and game.city_name_button.text=="새 도시","Enter commits trimmed Unicode name to city model")
 game.begin_city_name_edit()
 game.city_name_edit.text="   "
 game.city_name_edit.text_submitted.emit(game.city_name_edit.text)
 verify(game.city.city_name=="새 도시","empty name is rejected without losing previous name")
 game.begin_city_name_edit()
 game.city_name_edit.text="취소 이름"
 var escape:=InputEventKey.new()
 escape.keycode=KEY_ESCAPE;escape.pressed=true
 root.push_input(escape)
 await process_frame
 verify(game.city.city_name=="새 도시" and not game.city_name_edit.visible,"real Escape key cancels editing")
 var before: int=game.hud_refresh_count
 for i in range(10):game._process(0)
 verify(game.hud_refresh_count==before,"idle frames do not poll/rewrite status HUD")
 game.city.funds=48730
 verify(game.money.text=="48,730 doth" and game.hud_refresh_count>before,"funds-change event updates formatted money immediately")
 before=game.hud_refresh_count
 game.city.funds=48730
 verify(game.hud_refresh_count==before,"identical funds assignment emits no HUD update")
 var time_before: String=game.date_label.text
 game.city.clock.advance_real(3)
 verify(game.date_label.text!=time_before,"clock minute event updates date without polling")
 var closed: Array=[]
 game.game_month_closed.connect(func(index):closed.append(index))
 game.city.clock.advance_real(3600)
 verify(closed==[0] and game.balance_label.text=="—","one game day closes one game month, no fake cash flow")
 game.set_monthly_balance(1200)
 verify(game.balance_label.text=="+1,200/월" and game.balance_label.get_theme_color("font_color")==Color("5fd38a"),"future positive monthly value includes sign, unit and green")
 game.set_monthly_balance(-350)
 verify(game.balance_label.text=="−350/월" and game.balance_label.get_theme_color("font_color")==Color("ff6b6b"),"future negative monthly value includes minus and red")
 game.set_monthly_balance(null)
 verify(game.balance_label.text=="—","unknown monthly data restores dash")
 game.speed_button.pressed.emit()
 verify(game.simulation_speed==3 and game.speed_button.text=="3×","speed button changes real multiplier and caption")
 game.speed_button.pressed.emit()
 verify(game.simulation_speed==1 and game.speed_button.text=="1×","speed button cycles back to one")
 game.pause_button.pressed.emit()
 verify(not game.paused,"pause button resumes actual model clock")
 game.pause_button.pressed.emit()
 verify(game.paused,"pause button pauses actual model clock")
 game.city.add_road(PackedVector2Array([Vector2(10,30),Vector2(50,30)]))
 var frame: Dictionary=game.city.zoning_grid.frames.values()[0]
 game.city.paint_zones(game.city.Parcels.polygon(frame,0,0,2),"residential")
 game.city.advance_society(4)
 var live: Dictionary=game.city.population.demand(game.city.buildings)
 verify(game.population_label.text=="2" and game.demand_bars[1].value==live.commercial and game.demand_bars[2].value==live.industrial and live.commercial>0,"real immigration event updates population and both job demand bars")
 for size_value in [Vector2i(1920,1080),Vector2i(1280,820),Vector2i(960,640)]:
  root.size=size_value
  await process_frame
  await process_frame
  var view:=root.get_visible_rect()
  var date_rect: Rect2=game.date_label.get_global_rect()
  var control_rect: Rect2=game.playback_controls.get_global_rect()
  verify(absf(date_rect.position.x-control_rect.position.x)<1 and absf(date_rect.size.x-control_rect.size.x)<1,"playback pair matches actual date text width at "+str(size_value))
  verify(absf(game.pause_button.size.y-32)<1 and absf(game.speed_button.size.y-32)<1,"both playback buttons are 32px tall at "+str(size_value))
  verify(absf(game.city_name_button.get_global_rect().get_center().x-view.get_center().x)<1,"city title stays at exact viewport center at "+str(size_value))
  var nodes: Array=[game.date_label,game.happiness_label,game.population_label,game.money,game.balance_label,game.city_name_button,game.pause_button,game.speed_button]
  for node in nodes:verify(view.encloses(node.get_global_rect()),str(node.name)+" fits "+str(size_value))
  verify(game.status_left.get_global_rect().end.x<=game.city_name_button.get_global_rect().position.x,"left instruments never overlap center at "+str(size_value))
  verify(game.money.get_theme_font_size("font_size")>game.balance_label.get_theme_font_size("font_size"),"money is larger than cash flow at "+str(size_value))
  for node in game.demand_bars:verify(not node.show_percentage and node.fill_mode==ProgressBar.FILL_BOTTOM_TO_TOP,"demand bars have no written percentage/label")
