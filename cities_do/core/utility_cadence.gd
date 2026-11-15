extends RefCounted
## Heavy topology/demand/service calculations use game seconds; metering integrates every frame.
const PERIOD:=48.0
const EPS:=.000000001
var owner:WeakRef
var started:=false
var elapsed:=0.0
var next_power:=PERIOD
var next_water:=PERIOD/2
var power_dirty:=true
var water_dirty:=true
var power_generation:=0
var water_generation:=0
var power_snapshot:Dictionary={}
var water_snapshot:Dictionary={}
var returned_demand:Dictionary={}
func _init(city):owner=weakref(city)
func mark_power_dirty():power_dirty=true
func mark_water_dirty():water_dirty=true
func mark_dirty():mark_power_dirty();mark_water_dirty()
func start():
 if started:return
 started=true;_power();_water()
func _power():
 var city=owner.get_ref()
 power_snapshot=city.power_state();power_generation+=1;power_dirty=false
 power_snapshot.display={"imported_kwh":city.power.imported_kwh,"exported_kwh":city.power.exported_kwh,"pending_doth":city.power.pending_doth}
func _water():
 var city=owner.get_ref()
 water_snapshot=city.water_state();water_generation+=1;water_dirty=false;returned_demand.clear()
 for consumer:Dictionary in water_snapshot.consumers.values():
  var id:int=consumer.group
  returned_demand[id]=float(returned_demand.get(id,0))+float(consumer.demand_m3_day)*float(consumer.return_ratio)
 water_snapshot.display={"supplied_m3":city.water.supplied_m3,"treated_m3":city.water.treated_m3,"pending_doth":city.water.pending_doth}
func advance(seconds:float)->Dictionary:
 start()
 if is_finite(seconds) and seconds>0:
  var city=owner.get_ref();var game_seconds:float=seconds*city.Clock.SCALE
  # Preserve the original power-then-water budget priority and fractional carry per frame.
  _meter_power(city,game_seconds/3600);_meter_water(city,game_seconds/86400)
  elapsed+=game_seconds
  if elapsed+EPS>=next_power:
   _power();next_power+=PERIOD*maxi(1,floori((elapsed-next_power+EPS)/PERIOD)+1)
  if elapsed+EPS>=next_water:
   _water();next_water+=PERIOD*maxi(1,floori((elapsed-next_water+EPS)/PERIOD)+1)
 return {"power":power_snapshot,"water":water_snapshot}
func _settle(city,grid,amount:float):
 grid.pending_doth+=amount
 var nearest:float=roundf(grid.pending_doth)
 if absf(grid.pending_doth-nearest)<EPS:grid.pending_doth=nearest
 var whole:=int(grid.pending_doth)
 city.funds+=whole;grid.pending_doth-=whole
func _meter_power(city,hours:float):
 var grid=city.power;var budget:float=city.utility_balance();var cost:=0.0;var revenue:=0.0
 for group:Dictionary in power_snapshot.groups:
  if group.ports.is_empty():continue
  var balance:float=group.generation_kw-group.demand_kw;var rates:Array=grid.RATES[group.trade_port.development]
  if balance<0:
   var imported:float=0 if budget<=EPS else minf(-balance,budget/(float(rates[0])*hours))
   var charge:float=imported*hours*float(rates[0]);budget=maxf(0,budget-charge);cost+=charge;grid.imported_kwh+=imported*hours
  elif balance>0:
   grid.exported_kwh+=balance*hours;revenue+=balance*hours*float(rates[1])
 _settle(city,grid,revenue-cost)
func _meter_water(city,days:float):
 var grid=city.water;var budget:float=city.utility_balance();var total_cost:=0.0;var total_revenue:=0.0
 for group:Dictionary in water_snapshot.groups:
  var external:bool=group.has("water_import_port")
  var import_rate:float=grid.tariffs[group.water_import_port.development].water_import if external else 0.0
  var export_rate:float=grid.tariffs[group.water_export_port.development].water_export if external else 0.0
  var sewage_rate:float=grid.tariffs[group.sewage_export_port.development].sewage_disposal if external else 0.0
  var exported:float=maxf(0,group.water_capacity-group.demand) if external else 0.0
  var revenue:float=exported*export_rate*days;budget+=revenue
  var imported:float=grid.affordable(maxf(0,group.demand-group.water_capacity),import_rate,days,budget) if external else 0.0
  var purchase:float=imported*import_rate*days;budget=maxf(0,budget-purchase)
  var supplied:float=minf(group.demand,group.water_capacity+imported)
  var ratio:float=supplied/group.demand if group.demand>0 else 1.0
  var sewage:float=float(returned_demand.get(group.id,0))*ratio
  var treated:float=minf(sewage,group.sewage_capacity)
  var exported_sewage:float=grid.affordable(maxf(0,sewage-treated),sewage_rate,days,budget) if external else 0.0
  var disposal:float=exported_sewage*sewage_rate*days;budget=maxf(0,budget-disposal)
  grid.water_purchase_doth+=purchase;grid.sewage_disposal_doth+=disposal;grid.water_sales_doth+=revenue
  grid.supplied_m3+=supplied*days;grid.treated_m3+=treated*days;grid.imported_water_m3+=imported*days;grid.exported_water_m3+=exported*days;grid.exported_sewage_m3+=exported_sewage*days
  total_cost+=purchase+disposal;total_revenue+=revenue
 _settle(city,grid,total_revenue-total_cost)
