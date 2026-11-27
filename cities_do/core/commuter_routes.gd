extends RefCounted
## Worker-only derived directed graph. Base road curves are copied, not modified.
const Network = preload("res://core/traffic_network.gd")
var network = Network.new()
var world := {}
var buildings := {}
var access := {}
var boundary := {}
var cache := {}
var errors := []

func prepare(source: Dictionary) -> bool:
 world = source.duplicate(true)
 buildings.clear(); access.clear(); boundary.clear(); cache.clear(); errors.clear()
 var base = Network.new()
 if not base.build(world.roads):
  errors = base.errors.duplicate()
  return false
 network = Network.new()
 var anchors := {}
 for row in world.buildings:
  buildings[str(row.id)] = row
  var road_index := -1
  for i in range(world.roads.size()):
   if int(world.roads[i].get("parcel_id",-1)) == int(row.get("front_road_id",-2)) and world.roads[i].kind == "local": road_index = i
  if road_index < 0: continue
  var polygon: PackedVector2Array = row.get("polygon",PackedVector2Array([Vector2(row.get("x",0),row.get("y",0)),Vector2(row.get("x",0)+row.size,row.get("y",0)),Vector2(row.get("x",0)+row.size,row.get("y",0)+row.size),Vector2(row.get("x",0),row.get("y",0)+row.size)]))
  var center := Vector2.ZERO
  for p in polygon: center += p
  center /= polygon.size()
  var front: Vector2 = row.get("front_direction",Vector2.ZERO)
  if front.length_squared() < .99: continue
  var door := center
  var score := -INF
  for i in range(polygon.size()):
   var midpoint := (polygon[i]+polygon[(i+1)%polygon.size()])*.5
   var candidate := (midpoint-center).dot(front.normalized())
   if candidate > score: score = candidate; door = midpoint
  var road: Dictionary = world.roads[road_index]
  var foot := Vector2.ZERO
  var gap := INF
  for i in range(road.points.size()-1):
   var projected := Geometry2D.get_closest_point_to_segment(door,road.points[i],road.points[i+1])
   if projected.distance_to(door) < gap: foot = projected; gap = projected.distance_to(door)
  if gap-float(road.width)*.5 > .3751: continue
  var curb := (foot+(door-foot).normalized()*float(road.width)*.5)*4.0
  var record := {"door":door*4.0,"curb":curb,"walk_m":curb.distance_to(door*4.0),"sources":[],"sinks":[],"road":road_index}
  var gate := 100000+access.size()
  for lane in base.lanes:
   if lane.road != road_index or lane.get("junction",-1)>=0: continue
   # Only the outermost lane in each direction may access a frontage.
   var count := 0
   for other in base.lanes:
    if other.road == lane.road and other.section == lane.section and other.direction == lane.direction: count += 1
   if lane.index != count-1: continue
   var projected := project(lane,curb)
   if projected.s < 6 or projected.s > lane.length-6: continue
   if not anchors.has(lane.id): anchors[lane.id] = []
   anchors[lane.id].append({"s":projected.s,"building":str(row.id),"gate":gate,"point":projected.point})
  access[str(row.id)] = record
 var heads := {}; var tails := {}; var cut_links := []
 for lane in base.lanes:
  var cuts: Array = anchors.get(lane.id,[])
  cuts.sort_custom(func(a,b):return a.s < b.s if a.s != b.s else a.building < b.building)
  # Coincident frontages share one road gate, not mutually oblivious crossings.
  var unique := []
  for cut in cuts:
   if not unique.is_empty() and absf(unique[-1].s-cut.s)<.001:
    cut.gate = unique[-1].gate
    unique[-1].members.append(cut)
   else:
    cut["members"] = [cut.duplicate()]
    unique.append(cut)
  var at := 0.0
  var previous := -1
  for cut in unique:
   var part := copy_lane(lane,slice_lane(lane,at,cut.s-.05))
   if not heads.has(lane.id): heads[lane.id] = part.id
   if previous >= 0: network.lanes[previous].next.append(part.id)
   var gate_lane := copy_lane(lane,slice_lane(lane,cut.s-.05,cut.s+.05))
   gate_lane.merge({"road":-1,"junction":cut.gate,"from":part.id,"to":-1,"speed_limit":4.0})
   part.next.append(gate_lane.id)
   cut_links.append({"head":part.id,"gate":gate_lane.id,"members":cut.members,"tail":network.lanes.size()})
   previous = gate_lane.id
   at = cut.s+.05
  var last := copy_lane(lane,slice_lane(lane,at,lane.length))
  if not heads.has(lane.id): heads[lane.id] = last.id
  if previous >= 0:
   network.lanes[previous].next.append(last.id)
  tails[lane.id] = last.id
 for lane in base.lanes:
  var last: Dictionary = network.lanes[tails[lane.id]]
  for next in lane.next: last.next.append(heads[next])
 # Remap existing road-junction connector receiving lanes.
 for lane in network.lanes:
  if lane.get("junction",-1)>=0 and lane.get("to",-1)>=0:
   lane.from = tails[lane.from]
   lane.to = heads[lane.to]
 for link in cut_links:
  var main_gate: Dictionary = network.lanes[link.gate]
  var tail: int = int(main_gate.next[0])
  main_gate.to = tail
  for cut in link.members:
   var record: Dictionary = access[cut.building]
   var midpoint: Vector2 = record.curb.lerp(cut.point,.35)
   # Explicit local driveway/roadside crossing only; never substitutes for a road route.
   var source_lane := append_lane(PackedVector2Array([record.curb,midpoint]),{"road":-1,"junction":-1,"speed_limit":3.0,"access":cut.building,"role":"source"})
   var enter := append_lane(PackedVector2Array([midpoint,network.sample(tail,0)]),{"road":-1,"junction":main_gate.junction,"speed_limit":3.0,"from":source_lane.id,"to":tail,"access":cut.building,"role":"enter"})
   source_lane.next.append(enter.id); enter.next.append(tail)
   var sink := append_lane(PackedVector2Array([midpoint,record.curb]),{"road":-1,"junction":-1,"speed_limit":3.0,"access":cut.building,"role":"sink"})
   var leave := append_lane(PackedVector2Array([network.sample(link.head,network.lanes[link.head].length),midpoint]),{"road":-1,"junction":main_gate.junction,"speed_limit":3.0,"from":link.head,"to":sink.id,"access":cut.building,"role":"leave"})
   network.lanes[link.head].next.append(leave.id); leave.next.append(sink.id)
   record.sources.append(source_lane.id); record.sinks.append(sink.id)
 # Boundary seeds use an actual authored map-edge endpoint and inward/outward lane.
 for lane in base.lanes:
  if lane.get("road",-1)<0 or lane.get("junction",-1)>=0: continue
  var stable: int = int(world.roads[lane.road].get("parcel_id",-1))
  for incoming in [true,false]:
   var endpoint: Vector2 = lane.start if incoming else lane.end
   var cell := endpoint/4.0
   if not on_edge(cell): continue
   var key := token(stable,cell)
   if not boundary.has(key): boundary[key] = {"entry":[],"exit":[]}
   boundary[key]["entry" if incoming else "exit"].append(heads[lane.id] if incoming else tails[lane.id])
 network.search.clear(); network.search.lengths.clear()
 for lane in network.lanes:
  network.search.add_point(lane.id,network.sample(lane.id,0)); network.search.lengths[lane.id] = lane.length
 for lane in network.lanes:
  for next in lane.next:
   if lane.id != next: network.search.connect_points(lane.id,next,false)
 return true

func append_lane(points: PackedVector2Array, data: Dictionary) -> Dictionary:
 var lane: Dictionary = network._add_lane(points)
 lane.merge(data,true)
 return lane
func copy_lane(original: Dictionary, points: PackedVector2Array) -> Dictionary:
 var data: Dictionary = original.duplicate()
 for key in ["id","curve","length","next"]: data.erase(key)
 return append_lane(points,data)
func project(lane: Dictionary, point: Vector2) -> Dictionary:
 var baked: PackedVector3Array = lane.curve.get_baked_points()
 var best := {"s":0.0,"point":Vector2.ZERO,"gap":INF}
 var at := 0.0
 for i in range(1,baked.size()):
  var a := Vector2(baked[i-1].x,baked[i-1].z)
  var b := Vector2(baked[i].x,baked[i].z)
  var hit := Geometry2D.get_closest_point_to_segment(point,a,b)
  var gap := point.distance_squared_to(hit)
  if gap < best.gap: best = {"s":at+a.distance_to(hit),"point":hit,"gap":gap}
  at += a.distance_to(b)
 return best
func slice_lane(lane: Dictionary, start: float, finish: float) -> PackedVector2Array:
 var points := PackedVector2Array()
 var first: Vector3 = lane.curve.sample_baked(start)
 points.append(Vector2(first.x,first.z))
 var at := 0.0
 var baked: PackedVector3Array = lane.curve.get_baked_points()
 for i in range(1,baked.size()):
  at += baked[i-1].distance_to(baked[i])
  if at>start+.00001 and at<finish-.00001: points.append(Vector2(baked[i].x,baked[i].z))
 var last: Vector3 = lane.curve.sample_baked(finish)
 points.append(Vector2(last.x,last.z))
 return points
func on_edge(cell: Vector2) -> bool:
 return absf(cell.x)<.001 or absf(cell.y)<.001 or absf(cell.x-float(world.width))<.001 or absf(cell.y-float(world.height))<.001
func token(road_id: int, point: Vector2) -> String:
 return "%d:%.4f:%.4f" % [road_id,point.x,point.y]
func prove(spec: Dictionary) -> Dictionary:
 var id := str(spec.get("local_id",""))
 var point = spec.get("boundary",spec.get("endpoint",null))
 if not point is Vector2 or not access.has(id): return {"reachable":false,"reason":"missing_actual_boundary_or_frontage"}
 var key := token(int(spec.get("road_id",-1)),point)
 if not boundary.has(key): return {"reachable":false,"reason":"not_an_actual_boundary_endpoint"}
 var cache_key := key+":"+id+":"+str(spec.get("direction","inbound"))
 if cache.has(cache_key): return cache[cache_key].duplicate(true)
 var inbound := best_route(boundary[key].entry,access[id].sinks,id)
 var outward := best_route(access[id].sources,boundary[key].exit,id)
 if inbound.is_empty() or outward.is_empty(): return {"reachable":false,"reason":"directed_roundtrip_unreachable"}
 var result := spec.duplicate(true)
 result.merge({"reachable":true,"mode":"road","route_id":cache_key,"distance_m":inbound.distance_m if spec.get("direction","inbound")=="inbound" else outward.distance_m,"outbound":inbound if spec.get("direction","inbound")=="inbound" else outward,"return_route":outward if spec.get("direction","inbound")=="inbound" else inbound,"frontage":access[id].duplicate(true)},true)
 cache[cache_key] = result
 return result.duplicate(true)
func best_route(starts: Array, ends: Array, building: String) -> Dictionary:
 var result := {}
 # AStar graph must not permit shortcut/U-turn through any other building.
 var disabled := []
 for lane in network.lanes:
  if lane.has("access") and str(lane.access)!=building:
   network.search.set_point_disabled(lane.id,true); disabled.append(lane.id)
 for start in starts:
  for finish in ends:
   var route: Array = network.route(start,finish)
   if route.is_empty(): continue
   var valid := true
   for lane_id in route.slice(1,-1):
    if network.lanes[lane_id].get("role","") in ["source","sink"]: valid = false
   if not valid: continue
   var length := 0.0
   for lane_id in route: length += float(network.lanes[lane_id].length)
   if result.is_empty() or length < result.distance_m: result = {"lanes":route,"distance_m":length,"start_m":network.sample(route[0],0),"end_m":network.sample(route[-1],network.lanes[route[-1]].length)}
 for lane in disabled: network.search.set_point_disabled(lane,false)
 return result
func validate(route: Dictionary) -> bool:
 var ids: Array = route.get("lanes",[])
 if ids.is_empty(): return false
 var length := 0.0
 for i in range(ids.size()):
  if ids[i]<0 or ids[i]>=network.lanes.size():return false
  length += float(network.lanes[ids[i]].length)
  if i+1<ids.size():
   if not ids[i+1] in network.lanes[ids[i]].next:return false
   if network.sample(ids[i],network.lanes[ids[i]].length).distance_to(network.sample(ids[i+1],0))>.01:return false
 return absf(length-float(route.distance_m))<.01
