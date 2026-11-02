extends RefCounted
## Paired underground pipes share geometry, never drinking/waste water state.
## Reuse only PowerGrid's tested metre geometry, graph and routing, not its solver/rates.
const Geometry = preload("res://core/power_grid.gd")
const RANGE := 64.0
const SPACING := 32.0
var geometry
var tariffs := {}
var pending_doth := 0.0
var water_purchase_doth := 0.0
var sewage_disposal_doth := 0.0
var water_sales_doth := 0.0
var facilities: Array[Dictionary] = []
var supplied_m3 := 0.0
var treated_m3 := 0.0
var imported_water_m3 := 0.0
var exported_water_m3 := 0.0
var exported_sewage_m3 := 0.0

func _init(bounds: Vector2 = Vector2(400,400)):
 geometry=Geometry.new(bounds)
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://core/water_tariffs.json"))
 if data is Dictionary and valid_tariffs(data.get("neighbors",{})):
  tariffs=data.neighbors.duplicate(true)
 else:
  push_error("Invalid water_tariffs.json: external water/sewage trade disabled")

static func valid_tariffs(value) -> bool:
 if not value is Dictionary: return false
 for development in ["highly_developed","developed","peer"]:
  if not value.get(development) is Dictionary: return false
  for key in ["water_import","water_export","sewage_disposal"]:
   var rate=value[development].get(key)
   if not (rate is float or rate is int) or not is_finite(float(rate)) or rate<0: return false
 return true

func best_port(ports: Array, key: String, highest: bool = false) -> Dictionary:
 var best: Dictionary=ports[0]
 for port in ports:
  var candidate: float=tariffs[port.development][key]
  var prior: float=tariffs[best.development][key]
  if (highest and candidate>prior) or (not highest and candidate<prior): best=port
 return best

func affordable(required: float, rate: float, days: float, budget: float) -> float:
 if rate==0: return required
 if budget<=.000000001: return 0
 if days>0: return minf(required,maxf(0,budget)/(rate*days))
 return required

func add_facility(position: Vector2, kind: String, capacity: float = 300.0) -> int:
 if kind not in ["water","sewage"] or not is_finite(capacity) or capacity<0: return -1
 var id: int=geometry.add_plant(position,0)
 if id!=-1: facilities.append({"id":id,"position":position,"kind":kind,"capacity_m3_day":capacity})
 return id

func remove_facility(id: int) -> bool:
 for i in range(facilities.size()):
  if facilities[i].id==id:
   facilities.remove_at(i)
   geometry.remove_plant(id)
   return true
 return false

func set_capacity(id: int, capacity: float) -> bool:
 if not is_finite(capacity) or capacity<0: return false
 for facility in facilities:
  if facility.id==id:
   facility.capacity_m3_day=capacity
   return true
 return false

func add_pipe(points: PackedVector2Array, commit: bool = true) -> Dictionary:
 return geometry.add_wire(points,commit)

func remove_pipe(id: int) -> bool:
 return geometry.remove_wire(id)

func solve(consumers: Array, budget: float = INF, days: float = 0.0) -> Dictionary:
 if not is_finite(days) or days<0: days=0
 budget=maxf(0,budget)
 geometry.rebuild()
 var groups := []
 var membership := {}
 for node in geometry.nodes:
  if membership.has(node.id): continue
  var group := {"id":groups.size(),"nodes":[],"ports":[],"consumers":[],"water_sources":[],"sewage_sinks":[],"water_capacity":0.0,"sewage_capacity":0.0,"demand":0.0,"water_supplied":0.0,"sewage_generated":0.0,"sewage_treated":0.0,"water_import":0.0,"water_export":0.0,"sewage_export":0.0}
  var queue := [node.id]
  while not queue.is_empty():
   var id: int=queue.pop_back()
   if membership.has(id): continue
   membership[id]=group.id
   group.nodes.append(id)
   for adjacent in geometry.adjacency[id]: queue.append(adjacent)
  groups.append(group)
 for facility in facilities:
  var id: int=geometry._find_node(facility.position)
  if geometry.adjacency[id].is_empty(): continue
  var group: Dictionary=groups[membership[id]]
  if facility.kind=="water":
   group.water_capacity+=facility.capacity_m3_day
   if facility.capacity_m3_day>0: group.water_sources.append(id)
  else:
   group.sewage_capacity+=facility.capacity_m3_day
   if facility.capacity_m3_day>0: group.sewage_sinks.append(id)
 for port in geometry.ports:
  var id: int=geometry._find_node(port.position)
  if not geometry.adjacency[id].is_empty(): groups[membership[id]].ports.append(port)
 var states := {}
 for consumer in consumers:
  var attachment := -1
  var selected := -1
  var nearest := INF
  for node in geometry.nodes:
   if not node.service or geometry.adjacency[node.id].is_empty(): continue
   var distance: float=node.position.distance_squared_to(consumer.position)
   if distance<=RANGE*RANGE and distance<nearest:
    nearest=distance
    attachment=node.id
    selected=membership[node.id]
  var demand: float=consumer.demand_m3_day
  if not is_finite(demand): demand=0
  demand=maxf(0,demand)
  var return_ratio: float=consumer.get("return_ratio",.8)
  if not is_finite(return_ratio): return_ratio=.8
  states[consumer.id]={"node":attachment,"group":selected,"connected":selected!=-1,"demand_m3_day":demand,"return_ratio":clampf(return_ratio,0,1),"water_supplied_m3_day":0.0,"sewage_generated_m3_day":0.0,"sewage_handled_m3_day":0.0,"water_ratio":0.0,"sewage_ratio":0.0,"has_water":false,"has_sewage":false}
  if selected!=-1:
   groups[selected].consumers.append(consumer.id)
   groups[selected].demand+=demand
 var water_routes := []
 var sewage_routes := []
 var total := {"water_purchase_doth":0.0,"sewage_disposal_doth":0.0,"water_sales_doth":0.0,"cost_doth":0.0,"revenue_doth":0.0,"expense_doth_day":0.0,"revenue_doth_day":0.0,"demand_m3_day":0.0,"water_supplied_m3_day":0.0,"sewage_generated_m3_day":0.0,"sewage_treated_m3_day":0.0,"water_import_m3_day":0.0,"water_export_m3_day":0.0,"sewage_export_m3_day":0.0,"unhandled_sewage_m3_day":0.0}
 for state in states.values(): total.demand_m3_day+=state.demand_m3_day
 for group in groups:
  var external: bool=not group.ports.is_empty() and not tariffs.is_empty()
  var import_node := -1
  var export_node := -1
  var sewage_node := -1
  var import_rate := 0.0
  var export_rate := 0.0
  var sewage_rate := 0.0
  if external:
   group.water_import_port=best_port(group.ports,"water_import")
   group.water_export_port=best_port(group.ports,"water_export",true)
   group.sewage_export_port=best_port(group.ports,"sewage_disposal")
   import_node=geometry._find_node(group.water_import_port.position)
   export_node=geometry._find_node(group.water_export_port.position)
   sewage_node=geometry._find_node(group.sewage_export_port.position)
   import_rate=tariffs[group.water_import_port.development].water_import
   export_rate=tariffs[group.water_export_port.development].water_export
   sewage_rate=tariffs[group.sewage_export_port.development].sewage_disposal
  group.water_export=maxf(0,group.water_capacity-group.demand) if external else 0.0
  var revenue: float=group.water_export*export_rate*days
  budget+=revenue
  group.water_import=affordable(maxf(0,group.demand-group.water_capacity),import_rate,days,budget) if external else 0.0
  var purchase: float=group.water_import*import_rate*days
  budget=maxf(0,budget-purchase)
  group.water_supplied=minf(group.demand,group.water_capacity+group.water_import)
  var water_ratio: float=group.water_supplied/group.demand if group.demand>0 else 1.0
  for id in group.consumers:
   var state: Dictionary=states[id]
   state.water_ratio=water_ratio
   state.has_water=(group.water_capacity>0 or external) and water_ratio>=1-.000001
   state.water_supplied_m3_day=state.demand_m3_day*water_ratio
   state.sewage_generated_m3_day=state.water_supplied_m3_day*state.return_ratio
   group.sewage_generated+=state.sewage_generated_m3_day
  group.sewage_treated=minf(group.sewage_generated,group.sewage_capacity)
  group.sewage_export=affordable(maxf(0,group.sewage_generated-group.sewage_treated),sewage_rate,days,budget) if external else 0.0
  var disposal: float=group.sewage_export*sewage_rate*days
  budget=maxf(0,budget-disposal)
  total.water_purchase_doth+=purchase
  total.sewage_disposal_doth+=disposal
  total.water_sales_doth+=revenue
  total.expense_doth_day+=group.water_import*import_rate+group.sewage_export*sewage_rate
  total.revenue_doth_day+=group.water_export*export_rate
  var handled: float=group.sewage_treated+group.sewage_export
  var sewage_ratio: float=handled/group.sewage_generated if group.sewage_generated>0 else 1.0
  for id in group.consumers:
   var state: Dictionary=states[id]
   state.sewage_ratio=sewage_ratio
   state.sewage_handled_m3_day=state.sewage_generated_m3_day*sewage_ratio
   state.has_sewage=(group.sewage_capacity>0 or external) and sewage_ratio>=1-.000001
   if state.water_supplied_m3_day>0:
    for source in group.water_sources: append_route(water_routes,source,state.node)
    if group.water_import>0: append_route(water_routes,import_node,state.node)
   if state.sewage_handled_m3_day>0:
    for sink in group.sewage_sinks: append_route(sewage_routes,state.node,sink)
    if group.sewage_export>0: append_route(sewage_routes,state.node,sewage_node)
  if group.water_export>0:
   for source in group.water_sources: append_route(water_routes,source,export_node)
  total.water_supplied_m3_day+=group.water_supplied
  total.sewage_generated_m3_day+=group.sewage_generated
  total.sewage_treated_m3_day+=group.sewage_treated
  total.water_import_m3_day+=group.water_import
  total.water_export_m3_day+=group.water_export
  total.sewage_export_m3_day+=group.sewage_export
 total.unhandled_sewage_m3_day=total.sewage_generated_m3_day-total.sewage_treated_m3_day-total.sewage_export_m3_day
 total.cost_doth=total.water_purchase_doth+total.sewage_disposal_doth
 total.revenue_doth=total.water_sales_doth
 total.consumers=states
 total.groups=groups
 total.water_routes=water_routes
 total.sewage_routes=sewage_routes
 return total

func append_route(routes: Array, start: int, finish: int):
 if start==finish or routes.size()>=128: return
 var points: PackedVector2Array=geometry.route(start,finish)
 if points.size()<2: return
 for route in routes:
  if route.points==points: return
 routes.append({"points":points,"length":Geometry.path_length(points)})

func advance(consumers: Array, days: float, budget: float = INF) -> Dictionary:
 var state := solve(consumers,budget,days)
 if is_finite(days) and days>0:
  water_purchase_doth+=state.water_purchase_doth
  sewage_disposal_doth+=state.sewage_disposal_doth
  water_sales_doth+=state.water_sales_doth
  supplied_m3+=state.water_supplied_m3_day*days
  treated_m3+=state.sewage_treated_m3_day*days
  imported_water_m3+=state.water_import_m3_day*days
  exported_water_m3+=state.water_export_m3_day*days
  exported_sewage_m3+=state.sewage_export_m3_day*days
 return state
