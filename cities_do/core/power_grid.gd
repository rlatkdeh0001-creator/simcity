extends RefCounted
## World metres. Delivery/energy accounting never reads animation state.
const SPACING := 32.0
const RANGE := 64.0
const EPS := 0.001
const RATES := {"highly_developed":[.0024,.0010],"developed":[.0027,.0012],"peer":[.0030,.0015]}
var bounds: Vector2
var plants: Array[Dictionary] = []
var wires: Array[Dictionary] = []
var ports: Array[Dictionary] = []
var next_id := 1
var nodes: Array[Dictionary] = []
var adjacency := {}
var revision := 0
var graph_revision := -1
var imported_kwh := 0.0
var exported_kwh := 0.0
var pending_doth := 0.0
var last_state := {}

func _init(size_m: Vector2 = Vector2(400,400)):
 bounds = size_m
 var defs = JSON.parse_string(FileAccess.get_file_as_string("res://maps/region_neighbors.json"))
 for town in defs.neighbors:
  var p := Vector2.ZERO
  match town.edge:
   "x_min": p=Vector2(0,bounds.y/2)
   "x_max": p=Vector2(bounds.x,bounds.y/2)
   "y_min": p=Vector2(bounds.x/2,0)
   "y_max": p=Vector2(bounds.x/2,bounds.y)
  ports.append({"id":town.id,"edge":town.edge,"position":p,"development":town.development,"name":town.development_name})

func valid(p: Vector2) -> bool:
 return p.is_finite() and p.x>=0 and p.y>=0 and p.x<=bounds.x and p.y<=bounds.y

func add_plant(p: Vector2, output_kw: float = 300.0) -> int:
 if not valid(p) or not is_finite(output_kw) or output_kw<0: return -1
 for plant in plants:
  if plant.position.distance_to(p)<8: return -1
 var id := next_id
 next_id += 1
 plants.append({"id":id,"position":p,"output_kw":output_kw,"enabled":true})
 revision += 1
 return id

func remove_plant(id: int) -> bool:
 for i in range(plants.size()):
  if plants[i].id==id:
   plants.remove_at(i)
   revision += 1
   return true
 return false

func set_output(id: int, output: float) -> bool:
 if not is_finite(output) or output<0: return false
 for plant in plants:
  if plant.id==id:
   plant.output_kw=output
   revision += 1
   return true
 return false

func _key(p: Vector2) -> Vector2i:
 return Vector2i(roundi(p.x/EPS),roundi(p.y/EPS))

func snap(p: Vector2, distance: float = 8.0) -> Dictionary:
 rebuild()
 var best := distance
 var result := {}
 for node in nodes:
  var d: float=node.position.distance_to(p)
  if d<=best:
   best=d
   result={"position":node.position,"node":node.id}
 return result

func add_wire(points: PackedVector2Array, commit: bool = true) -> Dictionary:
 if points.size()<2: return {"ok":false,"reason":"선을 드래그해 주세요"}
 for p in points:
  if not valid(p): return {"ok":false,"reason":"지도 경계 밖입니다"}
 var start := snap(points[0])
 if start.is_empty(): return {"ok":false,"reason":"발전소·이웃 접속점·기존 접속점에서 시작하세요"}
 var clean := PackedVector2Array([start.position])
 for i in range(1,points.size()):
  if points[i].distance_to(clean[-1])>.01: clean.append(points[i])
 if clean.size()<2: return {"ok":false,"reason":"전력선이 너무 짧습니다"}
 var end := snap(clean[-1])
 if not end.is_empty(): clean[-1]=end.position
 var length := path_length(clean)
 if length<1.0: return {"ok":false,"reason":"전력선이 너무 짧습니다"}
 var samples := []
 var d := 0.0
 while d<=length+EPS:
  samples.append({"position":sample(clean,minf(d,length)),"service":true,"distance":d})
  d += SPACING
 # A short final stub is a graph terminal, not an extra 32m supply point.
 if samples[-1].position.distance_to(clean[-1])>EPS:
  samples.append({"position":clean[-1],"service":false,"distance":length})
 var travelled := 0.0
 for i in range(1,clean.size()-1):
  travelled += clean[i-1].distance_to(clean[i])
  if absf(travelled/SPACING-roundf(travelled/SPACING))>.00001:
   samples.append({"position":clean[i],"service":false,"distance":travelled})
 samples.sort_custom(func(a,b):return a.distance<b.distance)
 var wire := {"id":next_id,"points":clean,"samples":samples,"length":length}
 if commit:
  next_id += 1
  wires.append(wire)
  revision += 1
 return {"ok":true,"wire":wire}

func remove_wire(id: int) -> bool:
 for i in range(wires.size()):
  if wires[i].id==id:
   wires.remove_at(i)
   revision += 1
   return true
 return false

static func path_length(points: PackedVector2Array) -> float:
 var length := 0.0
 for i in range(1,points.size()): length += points[i-1].distance_to(points[i])
 return length

static func sample(points: PackedVector2Array, distance: float) -> Vector2:
 for i in range(1,points.size()):
  var length := points[i-1].distance_to(points[i])
  if length>EPS and distance<=length: return points[i-1].lerp(points[i],distance/length)
  distance -= length
 return points[-1]

func rebuild():
 if graph_revision==revision: return
 nodes.clear()
 adjacency.clear()
 var lookup := {}
 for wire in wires:
  var prior := -1
  for point in wire.samples:
   var id := _node(point.position,point.service,lookup)
   if prior!=-1 and prior!=id:
    if not id in adjacency[prior]: adjacency[prior].append(id)
    if not prior in adjacency[id]: adjacency[id].append(prior)
   prior=id
 for plant in plants: _node(plant.position,true,lookup)
 for port in ports: _node(port.position,false,lookup)
 graph_revision=revision

func _node(p: Vector2, service: bool, lookup: Dictionary) -> int:
 var key := _key(p)
 if lookup.has(key):
  var id: int=lookup[key]
  nodes[id].service=nodes[id].service or service
  return id
 var id := nodes.size()
 nodes.append({"id":id,"position":p,"service":service})
 adjacency[id]=[]
 lookup[key]=id
 return id

func solve(consumers: Array, import_budget: float = INF, hours: float = 0.0) -> Dictionary:
 rebuild()
 var groups := []
 var membership := {}
 for node in nodes:
  if membership.has(node.id): continue
  var group := {"id":groups.size(),"nodes":[],"plants":[],"ports":[],"consumers":[],"generation_kw":0.0,"demand_kw":0.0,"import_kw":0.0,"export_kw":0.0,"supplied_kw":0.0,"ratio":0.0,"trade_port":{},"active_sources":[]}
  var queue := [node.id]
  while not queue.is_empty():
   var id: int=queue.pop_back()
   if membership.has(id): continue
   membership[id]=group.id
   group.nodes.append(id)
   for other in adjacency[id]: queue.append(other)
  groups.append(group)
 for plant in plants:
  var id := _find_node(plant.position)
  var group: Dictionary=groups[membership[id]]
  if adjacency[id].is_empty(): continue
  group.plants.append(plant)
  if plant.enabled:
   group.generation_kw += plant.output_kw
   if plant.output_kw>0: group.active_sources.append(id)
 for port in ports:
  var id := _find_node(port.position)
  if not adjacency[id].is_empty(): groups[membership[id]].ports.append(port)
 var states := {}
 for consumer in consumers:
  var selected := -1
  var attachment := -1
  var nearest := INF
  for node in nodes:
   var group: Dictionary=groups[membership[node.id]]
   if not node.service or adjacency[node.id].is_empty() or (group.generation_kw<=0 and group.ports.is_empty()): continue
   var distance: float=node.position.distance_squared_to(consumer.position)
   if distance<=RANGE*RANGE and distance<nearest:
    nearest=distance
    selected=group.id
    attachment=node.id
  var demand: float=maxf(0,consumer.demand_kw)
  states[consumer.id]={"connected":selected!=-1,"powered":false,"ratio":0.0,"demand_kw":demand,"supplied_kw":0.0,"group":selected,"node":attachment}
  if selected!=-1:
   groups[selected].consumers.append(consumer.id)
   groups[selected].demand_kw += demand
 var total_import := 0.0
 var total_export := 0.0
 var cost := 0.0
 var revenue := 0.0
 var routes := []
 for group in groups:
  var balance: float=group.generation_kw-group.demand_kw
  if not group.ports.is_empty():
   group.ports.sort_custom(func(a,b):
    var ra: Array=RATES[a.development]
    var rb: Array=RATES[b.development]
    return ra[0]<rb[0] if balance<0 else ra[1]>rb[1])
   var port: Dictionary=group.ports[0]
   var rate: Array=RATES[port.development]
   group.trade_port=port
   if balance<0:
    var required: float=-balance
    if import_budget<=0.000000001: required=0.0
    if hours>0 and import_budget<INF: required=minf(required,maxf(0,import_budget)/(rate[0]*hours))
    group.import_kw=required
    var charge: float=required*hours*rate[0]
    cost += charge
    import_budget=maxf(0,import_budget-charge)
    if required>0: group.active_sources.append(_find_node(port.position))
   elif balance>0:
    group.export_kw=balance
    revenue += balance*hours*rate[1]
  group.supplied_kw=minf(group.demand_kw,group.generation_kw+group.import_kw)
  group.ratio=group.supplied_kw/group.demand_kw if group.demand_kw>0 else 1.0
  for id in group.consumers:
   states[id].ratio=group.ratio
   states[id].supplied_kw=states[id].demand_kw*group.ratio
   states[id].powered=group.ratio>=1.0-.000001
  total_import += group.import_kw
  total_export += group.export_kw
  if group.supplied_kw>0 or group.export_kw>0:
   var targets := []
   for id in group.nodes:
    var external := false
    for port in group.ports:
     if _find_node(port.position)==id: external=true
    if adjacency[id].size()==1 and not id in group.active_sources and not external: targets.append(id)
   if group.export_kw>0:
    var id := _find_node(group.trade_port.position)
    if not id in targets: targets.append(id)
   if targets.is_empty():
    for id in group.consumers:
     if not states[id].node in targets: targets.append(states[id].node)
   for source in group.active_sources:
    for target in targets:
     if source==target or routes.size()>=128: continue
     var path := route(source,target)
     if path.size()>1: routes.append({"points":path,"length":path_length(path)})
 last_state={"consumers":states,"groups":groups,"import_kw":total_import,"export_kw":total_export,"cost_doth":cost,"revenue_doth":revenue,"routes":routes,"billing_active":hours>0}
 return last_state

func _find_node(p: Vector2) -> int:
 for node in nodes:
  if _key(node.position)==_key(p): return node.id
 return -1

func route(start: int, goal: int) -> PackedVector2Array:
 var queue := [start]
 var seen := {start:-1}
 var cursor := 0
 while cursor<queue.size():
  var id: int=queue[cursor]
  cursor += 1
  if id==goal: break
  for other in adjacency[id]:
   if not seen.has(other):
    seen[other]=id
    queue.append(other)
 if not seen.has(goal): return PackedVector2Array()
 var result := PackedVector2Array()
 var id := goal
 while id!=-1:
  result.append(nodes[id].position)
  id=seen[id]
 result.reverse()
 return result
