extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func click(point:Vector2):
 var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion);await process_frame
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event);await process_frame
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.paused=true;root.add_child(game)
 await process_frame
 game.city.simulation.worker.Suspend()
 await click(game.economy_button.get_global_rect().get_center())
 var budget=game.budget_window;var c=game.city;var sim=c.simulation
 check(budget.visible and budget.loan.editable,"existing approved loan gauge is active through real HUD entry")
 if not budget.loan.editable:game.queue_free();await process_frame;finish();return
 var opening:int=c.funds;var start:float=c.clock.game_seconds
 var rect:Rect2=budget.loan.get_global_rect()
 await click(Vector2(rect.end.x-2,rect.get_center().y))
 sim.worker.Suspend();game._process(0);sim.worker.Suspend();game._process(0)
 check(c.loan_status().principal==50000 and c.funds==opening+50000,"actual mouse borrows credit limit even while paused: debt=%s funds=%s gauge=%s"%[c.loan_status().principal,c.funds,budget.loan.get_global_rect()])
 check(c.clock.game_seconds==start and c.tax_status().collected_total==0,"paused financing does not advance time or assess tax")
 check(budget.values.loan.text==budget.amount(50000),"gauge amount is genuine published debt")
 budget.loan.grab_focus()
 for code:int in [KEY_LEFT,KEY_RIGHT]:
  for pressed in [true,false]:
   var arrow:=InputEventKey.new();arrow.keycode=code;arrow.physical_keycode=code;arrow.pressed=pressed;root.push_input(arrow);await process_frame
  sim.worker.Suspend();game._process(0);sim.worker.Suspend();game._process(0)
  var expected:=49000 if code==KEY_LEFT else 50000
  check(c.loan_status().principal==expected and c.funds==opening+expected,"real arrow keys adjust the approved 1000-unit intent step")
 for pressed in [true,false]:
  var key:=InputEventKey.new();key.keycode=KEY_HOME;key.physical_keycode=KEY_HOME;key.pressed=pressed;root.push_input(key);await process_frame
 sim.worker.Suspend();game._process(0);sim.worker.Suspend();game._process(0)
 check(c.loan_status().principal==0 and c.funds==opening,"real keyboard gauge repays full principal")
 # Hold a real older identical-value publication; ABA cannot acknowledge the pending intent.
 game.set_process(false);sim.resume();sim.worker.SetValidationGate(true);c.advance_society(2)
 budget.loan.value=10000;budget.loan.value=0
 sim.validation_publish()
 check(budget.pending_loan!=null and budget.loan.value==0,"older identical publication cannot clear rapid reverted loan intent")
 budget.close();budget.open(c)
 check(budget.pending_loan!=null,"close reopen retains pending loan intent")
 sim.resume();c.advance_society(2);sim.validation_publish()
 check(budget.pending_loan==null and c.loan_status().principal==0,"corresponding publication acknowledges FIFO borrow and repay")
 sim.resume();c.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
 c.funds=0;sim.worker.SetValidationGate(true);c.advance_society(2)
 budget.loan.value=30000
 c.public_facilities.place("fire-station",Vector2(12,35),0)
 budget.loan.value=20000
 sim.validation_publish();sim.resume();c.advance_society(0);sim.validation_publish()
 check(c.loan_status().principal==30000 and c.public_facilities.lots.is_empty(),"first finance publication precedes interleaved paid placement")
 check(budget.pending_loan==20000 and budget.loan.value==20000,"earlier financing publication cannot acknowledge target beyond construction barrier")
 budget.close();budget.open(c)
 check(budget.pending_loan==20000,"close reopen retains target beyond construction barrier")
 sim.resume();c.advance_society(0);sim.validation_publish()
 check(c.public_facilities.lots.size()==1 and c.loan_status().principal==20000 and c.funds==0 and budget.pending_loan==null,"later finance publication acknowledges exact FIFO target once")
 sim.resume();sim.worker.SetValidationGate(true);c.advance_society(2)
 budget.loan.value=30000
 var old_rate:int=c.tax_status().policy.rates[0]
 budget.change_rate(old_rate+1,0);budget.change_rate(old_rate,0)
 sim.validation_publish();sim.resume();c.advance_society(0);sim.validation_publish()
 check(not budget.pending_rates.is_empty(),"identical tax rates behind finance barrier stay pending")
 sim.resume();c.advance_society(0)
 var tax_published:bool=sim.validation_publish()
 check(tax_published and budget.pending_rates.is_empty(),"paused financing drain also publishes following tax commands: published=%s tick=%s fence=%s pending=%s rates=%s queued=%s fault=%s"%[tax_published,sim.get_published_tick(),budget.pending_publication_tick,budget.pending_rates,c.tax_status().policy.rates,sim.queued_edit_count(),sim.get_fault()])
 c.funds=0;sim.resume();budget.loan.value=30000;c.advance_society(2);sim.validation_publish()
 c.funds=0;sim.resume();budget.loan.value=0;c.advance_society(2);sim.validation_publish()
 check(c.loan_status().principal==30000 and budget.loan.value==30000 and budget.pending_loan==null,"unaffordable worker repayment restores actual gauge without sticky pending")
 check("부족" in budget.loan.tooltip_text,"rejected repayment feedback shown in existing control")
 var fractional=load("res://core/city_model.gd").new();fractional.set_loan_amount(10550.25)
 budget.bind_model(fractional)
 check(is_equal_approx(budget.loan.value,10550.25) and fractional.loan_status().principal==10550.25,"fractional forced debt can be displayed without rounding or emitting a treasury command")
 budget.bind_model(c)
 sim.shutdown()
 var warning_city=load("res://core/city_model.gd").new();warning_city.happiness_enabled=false;warning_city.population_enabled=false
 warning_city.funds=-1;warning_city.loans.negative_days=2;warning_city.loans.evaluated_day=2;warning_city.loans.last_day=2
 warning_city.clock.game_seconds=3*86400.0-48;warning_city.utilities.elapsed=3*86400.0-48
 warning_city.enable_simulation_worker();warning_city.simulation.worker.Suspend()
 game.city=warning_city;game.bind_status_events();budget.bind_model(warning_city)
 warning_city.advance_society(2);warning_city.simulation.validation_publish()
 check(warning_city.loan_status().negative_days==2,"negative verdict waits for final main utility interval")
 warning_city.advance_utilities(2);warning_city.simulation.resume();warning_city.advance_society(2);warning_city.simulation.validation_publish()
 check(warning_city.loan_status().warning and "경고" in game.hud.text,"actual published third deficit appears in existing HUD feedback")
 warning_city.simulation.shutdown()
 var failed=load("res://core/city_model.gd").new();failed.happiness_enabled=false;failed.population_enabled=false
 failed.funds=-1;failed.loans.negative_days=5;failed.loans.evaluated_day=5;failed.loans.last_day=5
 failed.clock.game_seconds=6*86400.0-48;failed.utilities.elapsed=6*86400.0-48
 failed.enable_simulation_worker();failed.simulation.worker.Suspend()
 game.city=failed;game.bind_status_events();budget.bind_model(failed)
 failed.advance_society(2);failed.simulation.validation_publish();failed.advance_utilities(2)
 failed.simulation.resume();failed.advance_society(2);failed.simulation.validation_publish()
 check(failed.loan_status().bankrupt and "게임 오버" in game.hud.text,"actual sixth deficit publishes game over through existing feedback")
 check(not budget.loan.editable and budget.sliders.all(func(s):return not s.editable),"gameover blocks finance controls")
 var frozen:float=failed.clock.game_seconds;var money:int=failed.funds
 failed.simulation.resume();game.paused=false;game._process(100)
 check(failed.clock.game_seconds==frozen and failed.funds==money and not failed.simulation.has_pending(),"native gameover never submits more ticks or bills utility")
 game.power_overlay.drawing=true;game.power_overlay.stroke=PackedVector2Array([failed.power.ports[0].position,Vector2(80,80)])
 check(failed.power.add_wire(game.power_overlay.stroke,false).ok,"gameover wire fixture is geometrically valid")
 game.power_overlay.finish_wire()
 check(failed.power.wires.is_empty(),"a deferred wire release cannot mutate the bankrupt city")
 game.water_overlay.drawing=true;game.water_overlay.stroke=PackedVector2Array([failed.water.geometry.ports[0].position,Vector2(80,80)])
 check(failed.water.geometry.add_wire(game.water_overlay.stroke,false).ok,"gameover pipe fixture is geometrically valid")
 game.water_overlay.finish_pipe()
 check(failed.water.geometry.wires.is_empty(),"a deferred paired pipe release cannot mutate the bankrupt city")
 game.queue_free();await process_frame
 finish()
func finish():
 print("LOAN_UI checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
