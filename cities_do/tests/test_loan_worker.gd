extends SceneTree
const Model=preload("res://core/city_model.gd")
const Adapter=preload("res://core/city_simulation_worker.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func step(c):
 c.simulation.resume();c.advance_society(2);check(c.simulation.validation_publish(),"actual native publication")
func _initialize():run.call_deferred()
func run():
 var c=Model.new();c.population_enabled=false;c.happiness_enabled=false;c.enable_taxation()
 c.set_loan_amount(12000);c.clock.game_seconds=86400-48
 c.enable_simulation_worker();c.simulation.worker.Suspend()
 var old:Dictionary=c.loan_status()
 c.simulation.worker.SetValidationGate(true);c.advance_society(2)
 var accepted:Dictionary=c.set_loan_amount(18000)
 check(accepted.get("queued",false),"loan intent queues behind genuine closed native gate")
 if not accepted.get("queued",false):c.simulation.shutdown();finish();return
 c.set_loan_amount(6000);c.funds-=7
 check(c.loan_status()==old and c.funds==61993,"queued debt is not visible and concurrent spending stays main-owned")
 check(c.simulation.validation_publish(),"first day publishes")
 check(c.funds==61893 and c.loan_status().principal==12000,"interest charged once and concurrent seven preserved")
 check(old.principal==12000 and old.interest_total==0,"old immutable publication remains unchanged")
 step(c)
 check(c.loan_status().principal==6000 and c.funds==55893,"queued targets replay FIFO on actual worker funds")
 var status:Dictionary=c.loan_status()
 check(status.is_read_only(),"loan read facade immutable")
 check(status.interest_total==100,"second tick never rebills interest")
 check(not c.simulation.validation_publish() and c.funds==55893,"duplicate publication never transfers money twice")
 c.simulation.resume();c.set_loan_amount(9000);step(c)
 check(c.funds==58893 and c.loan_status().principal==9000,"idle command reaches actual worker")
 var cp:Dictionary=Adapter.capture(c)
 c.simulation.shutdown()
 var restored=Adapter.new();restored.boot(cp)
 check(restored.city.loan_status().principal==9000 and restored.city.loans.interest_total==100,"checkpoint keeps principal and accrued interest")
 var money:int=restored.city.funds;restored.city.advance_society(2)
 check(restored.city.funds==money,"restored same-day debt watermark prevents duplicate interest")
 cp.model.values.erase("loans");cp.model.values.clock.values.game_seconds=10*86400.0
 var legacy=Adapter.new();legacy.boot(cp)
 check(legacy.city.loan_status().principal==0 and legacy.city.loans.last_day==10,"old checkpoint establishes zero-debt watermark without retrospective billing")
 legacy.city.enable_simulation_worker();legacy.city.simulation.worker.Suspend()
 check(legacy.city.loan_status().is_read_only() and legacy.city.loan_status().principal==0,"old save boots actual native immutable zero-debt view")
 var legacy_money:int=legacy.city.funds
 step(legacy.city)
 check(legacy.city.funds==legacy_money and legacy.city.loan_status().interest_total==0,"old-save native boot and publication never retrospectively bill debt")
 legacy.city.simulation.shutdown()
 c=Model.new(100,100);c.happiness_enabled=false;c.population_enabled=false
 c.buildings.append({"id":1,"x":20,"y":48,"size":2,"level":1,"zone":"residential","power_demand_kw":800.0})
 c.next_id=2
 c.power.add_wire(PackedVector2Array([c.power.ports[0].position,Vector2(96,200)]))
 c.set_loan_amount(12000);c.funds=10;c.clock.game_seconds=96;c.utilities.elapsed=48
 c.enable_simulation_worker();c.simulation.worker.Suspend();c.set_loan_amount(11990)
 c.simulation.worker.SetValidationGate(true);c.advance_society(2)
 c.advance_utilities(2)
 check(is_equal_approx(c.treasury_balance(),10),"accepted repayment reserves available funds against concurrent utility purchases")
 c.simulation.validation_publish()
 check(c.loan_status().principal==11990 and is_zero_approx(c.treasury_balance()),"repayment cannot double spend the same money as main metering")
 c.simulation.shutdown()
 check_finance_placement_fifo()
 check_finance_utility_fifo()
 check_idle_finance_fifo()
 finish()
func check_finance_placement_fifo():
 # Real worker gate: no synthetic busy flags or fabricated publication.
 for scenario in ["borrow", "repay", "rejected_borrow", "rejected_repay", "repay_then_short"]:
  var c=Model.new(100,100);c.population_enabled=false;c.happiness_enabled=false
  c.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
  if scenario in ["repay","rejected_repay","repay_then_short"]:c.set_loan_amount(30000)
  c.funds=0 if scenario in ["borrow","rejected_borrow"] else (20000 if scenario=="rejected_repay" else 30000)
  c.enable_simulation_worker();c.simulation.worker.Suspend()
  c.simulation.worker.SetValidationGate(true);c.advance_society(2)
  var results:Array=[]
  c.simulation.edit_completed.connect(func(result):results.append(result))
  var target:=30000.0
  if scenario=="rejected_borrow":target=50001.0
  elif scenario in ["repay","repay_then_short"]:target=20000.0 if scenario=="repay" else 10000.0
  elif scenario=="rejected_repay":target=0.0
  check(c.set_loan_amount(target).get("queued",false),scenario+" financing queues behind gate")
  check(c.public_facilities.place("fire-station",Vector2(12,35),0).get("queued",false),scenario+" valid paid placement queues behind financing")
  check(c.simulation.validation_publish(),scenario+" initial gated job publishes")
  # Drain the actual coordinator, including any financing publication barrier.
  for i in range(4):
   c.simulation.resume();c.advance_society(0)
   if c.simulation.has_pending():check(c.simulation.validation_publish(),scenario+" financing publication")
  var built:bool=scenario in ["borrow","repay","rejected_repay"]
  check(c.public_facilities.lots.size()==(1 if built else 0),scenario+" FIFO placement outcome")
  var expected_funds:int={"borrow":10000,"repay":0,"rejected_borrow":0,"rejected_repay":0,"repay_then_short":10000}[scenario]
  var expected_debt:int={"borrow":30000,"repay":20000,"rejected_borrow":0,"rejected_repay":30000,"repay_then_short":10000}[scenario]
  check(c.funds==expected_funds and c.loan_status().principal==expected_debt,scenario+" authoritative funds and debt exactly once")
  check(results.size()==2 and (results[1].get("ok",false) if built else results[1].get("code","")=="insufficient_funds"),scenario+" placement result emitted once after financing")
  var worker_state:Dictionary=c.simulation.export_validation_state()
  check(worker_state.funds==expected_funds and c.simulation._revision==c.simulation._submitted_revision,scenario+" final paused prefix reaches authoritative worker")
  check(not c.simulation.validation_publish() and c.funds==expected_funds,scenario+" duplicate publication cannot transfer again")
  c.simulation.shutdown()
func check_finance_utility_fifo():
 for repay:bool in [false,true]:
  var c=Model.new(100,100);c.population_enabled=false;c.happiness_enabled=false
  c.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
  c.buildings.append({"id":1,"x":20,"y":48,"size":2,"level":1,"zone":"residential","power_demand_kw":800.0});c.next_id=2
  c.power.add_wire(PackedVector2Array([c.power.ports[0].position,Vector2(96,200)]))
  if repay:c.set_loan_amount(30000)
  c.funds=30000 if repay else 20000;c.clock.game_seconds=96;c.utilities.elapsed=48
  c.enable_simulation_worker();c.simulation.worker.Suspend()
  c.simulation.worker.SetValidationGate(true);c.advance_society(2)
  c.set_loan_amount(20000 if repay else 10000)
  c.public_facilities.place("fire-station",Vector2(12,35),0)
  check(c.simulation.validation_publish(),"utility FIFO initial publication")
  var old:Dictionary=c.loan_status();var before:float=c.treasury_balance()
  c.simulation.resume();c.simulation.worker.SetValidationGate(true);c.advance_society(0)
  check(c.public_facilities.lots.is_empty() and c.treasury_balance()==before and c.loan_status()==old,"unpublished financing never grants cash or allows paid placement")
  check(c.simulation.loan_reservation==(10000.0 if repay else 0.0),"financing prefix retains exact repayment reservation")
  c.advance_utilities(2)
  var debit:float=before-c.treasury_balance()
  check(debit>0 and c.power.imported_kwh>0 and not is_zero_approx(c.power.pending_doth),"real concurrent utility debit includes fractional carry")
  check(c.simulation.validation_publish(),"utility FIFO finance publication")
  check(is_equal_approx(c.treasury_balance(),before-debit+(-10000 if repay else 10000)),"authoritative financing delta preserves concurrent utility debit")
  check(old.principal==(30000.0 if repay else 0.0) and old.is_read_only(),"earlier immutable debt publication unchanged")
  c.simulation.resume();c.advance_society(0)
  if c.simulation.has_pending():check(c.simulation.validation_publish(),"utility FIFO placement publication")
  check(c.public_facilities.lots.size()==(0 if repay else 1),"placement validates actual post-finance post-utility cash")
  var expected:float=before-debit-10000.0
  check(is_equal_approx(c.treasury_balance(),expected) and c.simulation.loan_reservation==0,"utility and construction charged exactly once; reservation released")
  check(not c.simulation.validation_publish() and is_equal_approx(c.treasury_balance(),expected),"repeated publication never duplicates concurrent ledger transfers")
  c.simulation.shutdown()
func check_idle_finance_fifo():
 for finance_first:bool in [true,false]:
  var c=Model.new(100,100);c.population_enabled=false;c.happiness_enabled=false
  c.add_road(PackedVector2Array([Vector2(2,40),Vector2(90,40)]),"local",true,4)
  c.funds=0;c.enable_simulation_worker();c.simulation.worker.Suspend()
  check(c.simulation.is_ready(),"idle FIFO worker ready")
  if finance_first:
   c.set_loan_amount(30000)
   check(c.public_facilities.place("fire-station",Vector2(12,35),0).get("queued",false),"idle unsubmitted financing fences subsequent placement")
  else:
   check(c.public_facilities.place("fire-station",Vector2(12,35),0).get("code","")=="insufficient_funds","earlier placement cannot consume later borrowing")
   c.set_loan_amount(30000)
  for i in range(3):
   c.simulation.resume();c.advance_society(0)
   if c.simulation.has_pending():check(c.simulation.validation_publish(),"idle FIFO publication")
  check(c.loan_status().principal==30000 and c.funds==(10000 if finance_first else 30000) and c.public_facilities.lots.size()==(1 if finance_first else 0),"idle ordering preserves construction before/after financing")
  c.simulation.shutdown()
func finish():
 print("LOAN_WORKER checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
