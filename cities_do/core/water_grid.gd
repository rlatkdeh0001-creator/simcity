extends RefCounted
## Paired underground pipes share geometry, never drinking/waste water state.
## Reuse only PowerGrid's tested metre geometry, graph and routing, not its solver/rates.
const Geometry = preload("res://core/power_grid.gd")
const RANGE := 64.0
const SPACING := 32.0
var geometry
var facilities: Array[Dictionary] = []
var supplied_m3 := 0.0
var treated_m3 := 0.0
var imported_water_m3 := 0.0
var exported_water_m3 := 0.0
var exported_sewage_m3 := 0.0

func _init(bounds: Vector2 = Vector2(400,400)):
 geometry=Geometry.new(bounds)

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

func solve(consumers: Array) -> Dictionary:
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
 var total := {"demand_m3_day":0.0,"water_supplied_m3_day":0.0,"sewage_generated_m3_day":0.0,"sewage_treated_m3_day":0.0,"water_import_m3_day":0.0,"water_export_m3_day":0.0,"sewage_export_m3_day":0.0,"unhandled_sewage_m3_day":0.0}
 for state in states.values(): total.demand_m3_day+=state.demand_m3_day
 for group in groups:
  var external: bool=not group.ports.is_empty()
  var port_id := -1
  if external: port_id=geometry._find_node(group.ports[0].position)
  group.water_import=maxf(0,group.demand-group.water_capacity) if external else 0.0
  group.water_export=maxf(0,group.water_capacity-group.demand) if external else 0.0
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
  group.sewage_export=maxf(0,group.sewage_generated-group.sewage_treated) if external else 0.0
  var handled: float=group.sewage_treated+group.sewage_export
  var sewage_ratio: float=handled/group.sewage_generated if group.sewage_generated>0 else 1.0
  for id in group.consumers:
   var state: Dictionary=states[id]
   state.sewage_ratio=sewage_ratio
   state.sewage_handled_m3_day=state.sewage_generated_m3_day*sewage_ratio
   state.has_sewage=(group.sewage_capacity>0 or external) and sewage_ratio>=1-.000001
   if state.water_supplied_m3_day>0:
    for source in group.water_sources: append_route(water_routes,source,state.node)
    if group.water_import>0: append_route(water_routes,port_id,state.node)
   if state.sewage_handled_m3_day>0:
    for sink in group.sewage_sinks: append_route(sewage_routes,state.node,sink)
    if group.sewage_export>0: append_route(sewage_routes,state.node,port_id)
  if group.water_export>0:
   for source in group.water_sources: append_route(water_routes,source,port_id)
  total.water_supplied_m3_day+=group.water_supplied
  total.sewage_generated_m3_day+=group.sewage_generated
  total.sewage_treated_m3_day+=group.sewage_treated
  total.water_import_m3_day+=group.water_import
  total.water_export_m3_day+=group.water_export
  total.sewage_export_m3_day+=group.sewage_export
 total.unhandled_sewage_m3_day=total.sewage_generated_m3_day-total.sewage_treated_m3_day-total.sewage_export_m3_day
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

func advance(consumers: Array, days: float) -> Dictionary:
 var state := solve(consumers)
 if is_finite(days) and days>0:
  supplied_m3+=state.water_supplied_m3_day*days
  treated_m3+=state.sewage_treated_m3_day*days
  imported_water_m3+=state.water_import_m3_day*days
  exported_water_m3+=state.water_export_m3_day*days
  exported_sewage_m3+=state.sewage_export_m3_day*days
 return state
