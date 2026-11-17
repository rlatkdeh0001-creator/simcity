extends SceneTree
const Model=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():run.call_deferred()
func run():
 var c=Model.new()
 check(c.has_method("set_loan_amount"),"loan gauge has an actual treasury command")
 if not c.has_method("set_loan_amount"):finish();return
 check(c.loan_status().principal==0 and c.loan_status().limit==50000,"initial zero debt and documented credit limit")
 check(c.set_loan_amount(12000).ok and c.funds==62000,"raising gauge disburses the difference")
 check(c.set_loan_amount(5000).ok and c.funds==55000,"lowering gauge repays the difference")
 check(c.set_loan_amount(5000).ok and c.funds==55000,"identical target never disburses twice")
 c.funds=100
 check(not c.set_loan_amount(0).ok and c.funds==100 and c.loan_status().principal==5000,"unaffordable repayment is atomic")
 check(not c.set_loan_amount(50001).ok and c.funds==100,"cannot borrow beyond credit limit")
 for invalid in [-1,NAN,INF,"1000"]:check(not c.set_loan_amount(invalid).ok,"invalid loan target rejected")
 var account=c.loans
 check(account.has_method("settle_day"),"monthly interest and excess repayment use actual debt")
 if not account.has_method("settle_day"):finish();return
 for population in [0,999,1000,9999,10000,99999,100000]:
  var a=load("res://core/loan_account.gd").new()
  var limit:float=50000+population*20
  check(a.credit_limit(population)==limit,"population based credit limit "+str(population))
  a.change(limit,population,0)
  var rate:float=.10 if population<1000 else (.08 if population<10000 else (.06 if population<100000 else .04))
  var expected:float=(limit*.3*rate+limit*.7*.1)/12
  var result:Dictionary=a.settle_day(1,population)
  check(is_equal_approx(result.interest,expected),"tiered interest only discounts first thirty percent "+str(population))
  check(a.principal==limit and result.forced_repayment==0,"no automatic amortization within limit")
  check(a.settle_day(1,population).posted==0,"same day idempotent")
 var a=load("res://core/loan_account.gd").new()
 a.change(70000,1000,0)
 var result:Dictionary=a.settle_day(1,0)
 check(result.forced_repayment==2000 and a.principal==68000,"population drop forces ten percent of excess only")
 check(is_equal_approx(result.interest,70000*.1/12),"interest uses opening principal before forced repayment")
 check(is_equal_approx(float(result.posted)+a.carry,-result.interest-result.forced_repayment),"fractional debt charges reconcile exactly")
 c=Model.new();c.happiness_enabled=false;c.population_enabled=false;c.enable_taxation();c.set_loan_amount(12000)
 c.clock.game_seconds=86400-48;c.advance_society(2)
 check(c.funds==61900 and c.loan_status().principal==12000,"model charges one month interest from actual funds")
 check(c._tax_day_economy.interest==100,"fiscal publication contains realized loan interest")
 c.advance_society(2);check(c.funds==61900,"same day tick does not double charge")
 check(c.loan_status().has("bankrupt"),"bankruptcy status is part of actual loan model")
 if not c.loan_status().has("bankrupt"):finish();return
 c=Model.new();c.happiness_enabled=false;c.population_enabled=false;c.enable_taxation();c.funds=-1
 for day in range(1,7):
  c.clock.game_seconds=day*86400.0-48;c.utilities.elapsed=c.clock.game_seconds;c.advance_society(2)
  check(c.loan_status().negative_days==day-1,"synchronous deficit waits for the final utility interval")
  c.advance_utilities(2)
  check(c.loan_status().negative_days==day,"completed negative month counted exactly once "+str(day))
  check(c.loan_status().warning==(day>=3),"warning begins at three completed negative months")
  check(c.loan_status().bankrupt==(day>=6),"game over begins at six completed negative months")
 var frozen:float=c.clock.game_seconds;var before:int=c.funds
 c.advance_society(100);c.advance_utilities(100)
 check(c.clock.game_seconds==frozen and c.funds==before,"bankruptcy freezes simulation and all metering")
 check(not c.set_loan_amount(1000).ok,"bankruptcy cannot be undone by late borrowing")
 c=Model.new();c.happiness_enabled=false;c.population_enabled=false;c.funds=-1
 for day in range(1,4):
  c.clock.game_seconds=day*86400.0-48;c.utilities.elapsed=c.clock.game_seconds;c.advance_society(2);c.advance_utilities(2)
 check(c.loan_status().warning,"warning reached before recovery")
 c.set_loan_amount(1000)
 check(c.loan_status().negative_days==0 and not c.loan_status().warning,"actual borrowing recovery immediately resets streak")
 c.funds=-1;c.clock.game_seconds=4*86400.0-48;c.utilities.elapsed=c.clock.game_seconds;c.advance_society(2);c.advance_utilities(2)
 check(c.loan_status().negative_days==1,"new deficit starts a new consecutive streak")
 c.loans.bankrupt=true
 check(not c.add_road(PackedVector2Array([Vector2(2,10),Vector2(20,10)])).ok,"gameover prevents new road edits")
 check(not c.configure_tax_policy({"rates":[0,0,0,0,0,0,0,0,0]}).ok,"gameover rejects forced tax signals")
 c=Model.new();c.funds=-1;c.power.pending_doth=.9;c.water.pending_doth=-.9;c.loans.negative_days=3
 c.utilities._settle(c,c.power,.2)
 check(c.treasury_balance()<0 and c.loans.negative_days==3,"fractional posting cannot fabricate a temporary treasury recovery")
 c.funds=1
 check(c.loans.negative_days==0,"genuine nonnegative treasury recovers immediately")
 c=Model.new();c.funds=-100
 check(c.add_road(PackedVector2Array([Vector2(2,10),Vector2(20,10)])).ok,"negative cash retains free road construction")
 var asset:String=c.public_facilities.entries.keys()[0]
 check(c.public_facilities.preview(asset,Vector2(10,10)).code=="insufficient_funds","negative treasury rejects paid actions before mutation")
 var rounding=load("res://core/loan_account.gd").new();rounding.change(1000,0,0)
 var paid:=0
 for day in range(1,13):paid+=int(rounding.settle_day(day,0).posted)
 check(paid==-100 and absf(rounding.carry)<.000000001,"twelve fractional interest postings reconcile to annual interest")
 c=Model.new();c.happiness_enabled=false;c.population_enabled=false;c.enable_taxation()
 c.loans.change(70000,1000,0);c.funds=0 # Valid historical debt, followed by population loss.
 c.clock.game_seconds=86400-48;c.advance_society(2)
 check(c.loan_status().principal==68000,"population loss forces only ten percent of excess principal")
 check(is_equal_approx(c.treasury_balance(),-2000.0-70000.0*.1/12),"mandatory repayment and interest debit actual treasury even without spare cash")
 check(c._tax_day_economy.forced_repayment==2000 and is_equal_approx(c._tax_day_economy.interest,70000.0*.1/12),"published fiscal breakdown retains both realized charges")
 finish()
func finish():
 print("LOANS checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
