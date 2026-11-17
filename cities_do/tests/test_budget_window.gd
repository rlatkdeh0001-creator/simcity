extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,text:String):
 checks+=1
 if not ok:failures+=1;push_error(text)
func key(code:int,shift:bool=false):
 for pressed in [true,false]:
  var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;event.shift_pressed=shift;root.push_input(event);await process_frame
func click(point:Vector2,button:int=MOUSE_BUTTON_LEFT):
 var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion);await process_frame
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=button;event.position=point;event.pressed=pressed;root.push_input(event);await process_frame
func reverted_rate_publication(close_between:bool):
 # Real mailbox barriers, never sleeps or fabricated tax_status publications.
 var city=preload("res://core/city_model.gd").new()
 city.enable_simulation_worker()
 var sim=city.simulation
 sim.worker.Suspend() # Join boot without advancing/publishing a tick.
 var budget=preload("res://core/budget_window.gd").new();root.add_child(budget);budget.open(city)
 var initial_tick:int=sim.get_published_tick()
 check(city.tax_status().policy.rates[0]==9,"revert repro starts at published A9")
 budget.sliders[0].value=10
 sim.worker.SetValidationGate(true);city.advance_society(2)
 check(sim.has_pending(),"A10 is genuinely in flight")
 budget.sliders[0].value=9
 check(sim.queued_edit_count()==1,"restore A9 is queued behind A10")
 check(budget.pending_rates.size()==9 and budget.pending_rates[0]==9,"equal old publication cannot acknowledge queued restore")
 budget.refresh()
 check(budget.pending_rates.size()==9,"unchanged refresh retains queued intent")
 if close_between:budget.close()
 check(sim.validation_publish(),"older A10 publication completes")
 check(sim.get_published_tick()==initial_tick+1 and city.tax_status().policy.rates[0]==10,"real published read view now contains older A10")
 if close_between:budget.open(city)
 check(budget.sliders[0].value==9 and budget.rate_labels[0].text=="10%","latest thumb survives older publication and reopen")
 budget.sliders[3].value=12
 sim.resume();city.advance_society(2)
 check(sim.queued_edit_count()==0 and sim.has_pending(),"restore and B replay into next actual worker submission")
 budget.close() # Corresponding publication must also acknowledge across hidden UI.
 check(sim.validation_publish(),"latest policy publication completes while closed")
 budget.open(city)
 var rates:Array=city.tax_status().policy.rates
 check(rates[0]==9 and rates[3]==12,"editing B must not overwrite restored A9")
 check(budget.pending_rates.is_empty(),"corresponding publication acknowledges on reopen")
 check(budget.sliders[0].value==9 and budget.sliders[3].value==12,"reopen shows acknowledged latest policy")
 # A still older job can publish the SAME vector as the latest queued intent.
 sim.resume();sim.worker.SetValidationGate(true);city.advance_society(2)
 budget.sliders[0].value=10;budget.sliders[0].value=9
 check(sim.has_pending() and sim.queued_edit_count()==2,"two reverted edits wait behind unchanged job")
 check(sim.validation_publish(),"unchanged older worker publication completes")
 check(budget.pending_rates.size()==9,"matching older publication is not the corresponding acknowledgment")
 sim.resume();city.advance_society(2)
 check(budget.pending_rates.size()==9,"edit completion alone does not acknowledge worker publication")
 check(sim.validation_publish(),"matching corresponding worker publication completes")
 check(budget.pending_rates.is_empty(),"new matching tick acknowledges even when cached scalar values are unchanged")
 sim.shutdown();budget.free()
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1280,820)
 reverted_rate_publication(false);reverted_rate_publication(true)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game)
 await process_frame
 check(game.has_method("open_budget"),"HUD exposes actual economy entrypoint")
 if game.has_method("open_budget"):
  game.open_budget();await process_frame
  check(game.budget_window.visible,"entrypoint opens approved budget")
  check(game.budget_window.sliders.size()==9,"nine tax cells")
  var budget=game.budget_window
  check(budget.net.text==game.balance_label.text and budget.net.text=="—","unclosed ledger shares HUD em dash")
  check(budget.loan.editable==false and budget.values.loan.text=="—","loan disabled and unavailable until T4")
  check(budget.tabs.slice(1).all(func(b):return b.disabled),"future tabs disabled")
  for slider in budget.sliders:check(slider.min_value==0 and slider.max_value==20 and slider.step==1,"integral zero to twenty range")
  check(budget.amounts.all(func(l):return l.text=="—" and l.icon_ready()),"unavailable amounts use actual currency renderer")
  var refreshes:int=budget.refresh_count
  budget.refresh();budget.refresh()
  check(budget.refresh_count==refreshes,"unchanged publication does not repaint")
  var origin:Vector2=game.origin;var zoom:float=game.map_zoom
  budget.sliders[0].grab_focus()
  await key(KEY_RIGHT)
  check(game.origin==origin and game.keyboard_camera.held.is_empty(),"slider keyboard input never pans world")
  check(budget.pending_rates.size()==9 and budget.pending_rates[0]==10,"keyboard sends real tax edit")
  game.city.simulation.worker.Suspend();game.city.simulation.worker.SetValidationGate(true)
  game.city.advance_society(2)
  budget.sliders[3].value=12;budget.sliders[8].value=17
  check(budget.pending_rates[0]==10 and budget.pending_rates[3]==12 and budget.pending_rates[8]==17,"queued multiple cells preserve latest complete policy")
  check(budget.rate_labels[3].text=="9%","displayed rate remains authoritative during queue latency")
  check(game.city.simulation.validation_publish(),"native gate released and published")
  game.city.simulation.resume();game.city.advance_society(2);game.city.simulation.validation_publish()
  var policy:Dictionary=game.city.simulation.export_validation_state().population.tax_policy.policy
  check(policy.rates[0]==10 and policy.rates[3]==12 and policy.rates[8]==17,"all rapid edits reach genuine worker checkpoint")
  await key(KEY_ESCAPE)
  check(not budget.visible and root.gui_get_focus_owner()==game.economy_button,"Escape closes and restores entrypoint focus")
  await click(game.economy_button.get_global_rect().get_center())
  check(budget.visible,"actual viewport economy button mouse opens window")
  var slider_rect:Rect2=budget.sliders[0].get_global_rect()
  await click(Vector2(slider_rect.end.x-2,slider_rect.get_center().y))
  check(budget.sliders[0].value==20,"actual mouse slider reaches 20 percent")
  for viewport in [Vector2i(1920,1080),Vector2i(1280,820),Vector2i(960,640)]:
   root.size=viewport
   for i in range(4):await process_frame
   check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(budget.panel.get_global_rect()),"budget panel stays inside "+str(viewport))
   check(not budget.net.get_global_rect().intersects(budget.close_button.get_global_rect()),"header does not overlap close "+str(viewport))
   check(budget.scroll.size.x>0 and budget.scroll.size.y>0,"small layout scroll viewport available "+str(viewport))
  await click(Vector2(5,5))
  await click(Vector2(5,5),MOUSE_BUTTON_WHEEL_UP)
  check(game.origin==origin and game.map_zoom==zoom and game.selected==-1,"modal background blocks world mouse and wheel")
  await click(budget.close_button.get_global_rect().get_center())
  check(not budget.visible,"actual close mouse works")
  game.open_budget()
  budget.tabs[0].grab_focus();await key(KEY_TAB,true)
  check(budget.is_ancestor_of(root.gui_get_focus_owner()),"reverse tab wraps within modal")
  budget.sliders[8].grab_focus()
  for i in range(15):await key(KEY_DOWN)
  check(budget.is_ancestor_of(root.gui_get_focus_owner()),"directional focus cannot escape modal to HUD")
  # Real closed-day ledger fixture, not UI-injected values.
  var closed=preload("res://tests/budget_fixture.gd").create()
  budget.bind_model(closed)
  var status:Dictionary=closed.economic_status()
  var tax:Dictionary=closed.tax_status()
  check(tax.collected>0,"capture fixture has real employed tax receipts")
  for i in range(9):
   check(budget.amounts[i].text==budget.amount(float(tax.cells[i].collected)/int(tax.days)),"cell shows collected daily amount "+str(i))
  for viewport in [Vector2i(1920,1080),Vector2i(1280,820),Vector2i(960,640)]:
   root.size=viewport
   for i in range(4):await process_frame
   check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(budget.panel.get_global_rect()),"closed values fit panel "+str(viewport))
   for i in range(9):
    check(not budget.rate_labels[i].get_global_rect().intersects(budget.amounts[i].get_global_rect()),"rate and actual amount do not overlap "+str(i)+" "+str(viewport))
  check(budget.find_children("*","Label",true,false).all(func(l):return l.get_theme_font_size("font_size")>=18),"all budget text at least 18px")
  check(status.available and budget.values.utility_income.text==budget.amount(status.power_revenue+status.water_revenue),"actual utility receipts feed composition values")
  check(budget.net.text==("−" if roundi(status.daily_net)<0 else "+")+closed.Economy.format_amount(absi(roundi(status.daily_net)))+"/월","closed daily net uses HUD rounding and units")
  check(budget.values.utility_expense.text==budget.amount(status.power_expense+status.water_expense),"utility costs included rather than hiding expenses")
  check(not game.city.is_connected("economic_changed",budget.refresh) and closed.is_connected("economic_changed",budget.refresh),"model replacement disconnects old lifecycle signals")
  budget.bind_model(game.city)
  check(not closed.is_connected("economic_changed",budget.refresh),"replacement detaches previous model")
 game.queue_free();await process_frame
 var fixture=load("res://tests/budget_capture.tscn").instantiate();root.add_child(fixture)
 for i in range(4):await process_frame
 check(fixture.budget_window.visible and fixture.paused,"capture scene opens the real budget and remains paused without capturing")
 check(fixture.budget_window.net.text==fixture.balance_label.text and fixture.balance_label.text!="—","capture header exactly matches authoritative bottom HUD")
 check(fixture.city.tax_status().collected>0,"capture scene retains actual settled tax receipts")
 fixture.queue_free();await process_frame
 print("BUDGET_WINDOW checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
