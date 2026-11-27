extends RefCounted
## Realized receipts/payments only. Main owns utilities, worker owns fiscal publication.
## Separate channel clocks preserve power-before-water billing and never rerun a solver.
var seconds:Dictionary={"power":0.0,"water":0.0}
var days:Dictionary={}
func record_utility(channel:String,duration:float,revenue:float,expense:float,absolute_start:float=-1):
 if duration<=0:return
 var start:float=seconds[channel] if absolute_start<0 else absolute_start
 var finish:float=start+duration
 var cursor:=start
 while cursor<finish-.000000001:
  var day:=floori((cursor+.000000001)/86400)+1
  var stop:=minf(finish,float(day)*86400)
  var fraction:float=(stop-cursor)/duration
  if not days.has(day):days[day]={"power_revenue":0.0,"power_expense":0.0,"water_revenue":0.0,"water_expense":0.0,"power_seconds":0.0,"water_seconds":0.0}
  days[day][channel+"_seconds"]+=stop-cursor
  days[day][channel+"_revenue"]+=revenue*fraction
  days[day][channel+"_expense"]+=expense*fraction
  cursor=stop
 seconds[channel]=finish
 var oldest:=floori(minf(seconds.power,seconds.water)/86400)-2
 for day in days.keys():
  if int(day)<oldest:days.erase(day)
func status(fiscal:Dictionary)->Dictionary:
 var result:Dictionary={"available":false,"daily_net":null}
 if fiscal.is_empty():return result
 var day:int=fiscal.day
 if day<=0 or not days.has(day) or minf(seconds.power,seconds.water)+.0000001<float(day)*86400:return result
 if minf(days[day].power_seconds,days[day].water_seconds)<86400-.000001:return result
 result=fiscal.duplicate(true);result.merge(days[day],true)
 result.available=true
 result.daily_net=result.tax_collected+result.power_revenue+result.water_revenue-result.power_expense-result.water_expense-result.facility_upkeep-result.interest
 result.make_read_only()
 return result
