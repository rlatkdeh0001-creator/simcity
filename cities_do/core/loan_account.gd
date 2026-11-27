extends RefCounted
## Worker-owned municipal debt. Never touches household savings or tax policy.
var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://core/loan_config.json"))
var principal:=0.0
var carry:=0.0
var last_command_result:Dictionary={}
var last_day:=0
var negative_days:=0
var evaluated_day:=0
var bankrupt:=false
func observe_balance(balance:float):
 if not bankrupt and balance>=0:negative_days=0
func evaluate_day(day:int,balance:float):
 observe_balance(balance)
 if bankrupt:return
 while evaluated_day<day:
  evaluated_day+=1
  if balance<0:negative_days+=1
  if negative_days>=int(config.bankruptcy_days):bankrupt=true;break
var interest_total:=0.0
var forced_repayment_total:=0.0
func monthly_interest(residents:int)->float:
 var rate:float=config.base_annual_rate
 for i in range(config.preferred_population.size()):
  if residents>=int(config.preferred_population[i]):rate=float(config.preferred_annual_rates[i])
 var preferred:=minf(principal,credit_limit(residents)*float(config.preferred_fraction))
 return (preferred*rate+(principal-preferred)*float(config.base_annual_rate))/float(config.months_per_year)
func settle_day(day:int,residents:int)->Dictionary:
 var result:Dictionary={"posted":0,"interest":0.0,"forced_repayment":0.0,"days":0}
 while last_day<day:
  var interest:=monthly_interest(residents)
  var repayment:=maxf(0,principal-credit_limit(residents))*float(config.excess_repayment_fraction)
  principal-=repayment
  interest_total+=interest;forced_repayment_total+=repayment
  result.interest+=interest;result.forced_repayment+=repayment;result.posted+=post(-interest-repayment);result.days+=1
  last_day+=1
 return result
func credit_limit(residents:int)->float:return float(config.base_limit)+maxi(0,residents)*float(config.limit_per_resident)
func post(amount:float)->int:
 carry+=amount
 var whole:=int(carry)
 carry-=whole
 return whole
func change(target:float,residents:int,available:float)->Dictionary:
 if bankrupt:return {"ok":false,"code":"bankrupt","reason":"파산 · 게임 오버"}
 var difference:=target-principal
 if difference>0 and target>credit_limit(residents):return {"ok":false,"code":"credit_limit","reason":"대출 한도 초과"}
 if difference<0 and -difference>maxf(0,available)+.00000001:return {"ok":false,"code":"insufficient_funds","reason":"상환 자금 부족"}
 principal=target
 return {"ok":true,"posted":post(difference)}
func status(residents:int)->Dictionary:
 var command:Dictionary=last_command_result.duplicate(true);command.make_read_only()
 var result:Dictionary={"negative_days":negative_days,"evaluated_day":evaluated_day,"bankrupt":bankrupt,"warning":negative_days>=int(config.warning_days),"principal":principal,"limit":credit_limit(residents),"carry":carry,"slider_step":config.slider_step,"interest_total":interest_total,"forced_repayment_total":forced_repayment_total,"last_day":last_day,"monthly_interest":monthly_interest(residents),"last_command_result":command}
 result.make_read_only()
 return result
