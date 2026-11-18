extends RefCounted
## Structural routing only. No clock, dispatch, fares, scene or mutable operational state.
const Network=preload("res://core/traffic_network.gd")
const Paths=preload("res://core/road_junctions.gd")
const Crossover=preload("res://core/terminal_crossover.gd")
const EPS:=0.002
var nodes:Array[Vector2]=[]
var edges:Array[Dictionary]=[]
var outgoing:Dictionary={}
func failure()->Dictionary:return {"ok":false,"code":"unreachable_line","reason":"정류장 순서와 이어진 회차 경로를 확인하세요"}
func node(point:Vector2)->int:
 for i in range(nodes.size()):
  if nodes[i].distance_to(point)<EPS:return i
 nodes.append(point);return nodes.size()-1
func edge(a:int,b:int,host:int):
 if a==b:return
 var id:int=edges.size()
 edges.append({"a":a,"b":b,"host":host,"length":nodes[a].distance_to(nodes[b]),"heading":(nodes[b]-nodes[a]).normalized()})
 if not outgoing.has(a):outgoing[a]=[]
 outgoing[a].append(id)
## E3a: a track only meets another where both are at the same height; a viaduct
## passing over a ground track adds no node (no switch). Station targets match any level.
var node_heights:Dictionary={}
func height_node(point:Vector2,height:float)->int:
 var id:=node(point)
 if not node_heights.has(id):node_heights[id]=height
 return id
static func segment_height(segment:Dictionary,point:Vector2)->float:
 var length:float=segment.a.distance_to(segment.b)
 return lerpf(segment.ha,segment.hb,clampf(segment.a.distance_to(point)/maxf(.000001,length),0,1))
func build_graph(city,kind:String):
 var Height=preload("res://core/road_height.gd")
 var segments:Array=[]
 for route:Dictionary in city.transit_routes:
  if route.kind!=kind:continue
  for i in range(1,route.points.size()):
   var a:Vector2=route.points[i-1]*4;var b:Vector2=route.points[i]*4
   var segment:={"a":a,"b":b,"host":route.id,"ha":Height.height_at(route,route.points[i-1]),"hb":Height.height_at(route,route.points[i])}
   segments.append(segment);height_node(a,segment.ha);height_node(b,segment.hb)
 # True endpoint/interior contacts and geometric crossings use the same graph in either insertion order.
 for i in range(segments.size()):
  for j in range(i):
   var hit:Variant=Geometry2D.segment_intersects_segment(segments[i].a,segments[i].b,segments[j].a,segments[j].b)
   if hit!=null and absf(segment_height(segments[i],hit)-segment_height(segments[j],hit))<=Height.EPS:height_node(hit,segment_height(segments[i],hit))
 for segment:Dictionary in segments:
  var ids:Array[int]=[]
  for i in range(nodes.size()):
   if Geometry2D.get_closest_point_to_segment(nodes[i],segment.a,segment.b).distance_to(nodes[i])>=EPS:continue
   if node_heights.has(i) and absf(float(node_heights[i])-segment_height(segment,nodes[i]))>Height.EPS:continue
   ids.append(i)
  ids.sort_custom(func(a,b):return nodes[a].distance_squared_to(segment.a)<nodes[b].distance_squared_to(segment.a))
  for i in range(1,ids.size()):edge(ids[i-1],ids[i],segment.host);edge(ids[i],ids[i-1],segment.host)
func rail_plan(city,line:Dictionary)->Dictionary:
 nodes.clear();edges.clear();outgoing.clear();node_heights.clear()
 var kind:String="metro" if line.kind=="metro" else "rail"
 var targets:Array[int]=[]
 var stations:Array[Dictionary]=[]
 for id:Variant in line.stops:
  var found:=false
  for lot:Dictionary in city.public_facilities.lots:
   if lot.id!=id or lot.get("internal_kind","")!=kind:continue
   var p:PackedVector2Array=lot.internal_points
   targets.append(node((p[0]+p[-1])*2));stations.append(lot);found=true;break
  if not found:return failure()
 build_graph(city,kind)
 if targets.size()<2:return failure()
 var best:Dictionary={}
 if not line.get("turnback",false):
  for start:int in outgoing.get(targets[0],[]):
   var candidate:=cycle(start,targets)
   if not candidate.is_empty() and (best.is_empty() or candidate.length<best.length):best=candidate
 if best.is_empty():
  if not line.get("turnback",false) and not line.get("allow_turnback",false):return failure()
  var open := _open_path(targets, stations, city, line)
  return open if not open.is_empty() else Crossover.failure()
 var center:=PackedVector2Array([nodes[targets[0]]]);var hosts:Array=[]
 var stop_vertices:Array[int]=[0];var next_stop:=1
 for id:int in best.edges:
  center.append(nodes[edges[id].b])
  if not edges[id].host in hosts:hosts.append(edges[id].host)
  if next_stop<targets.size() and edges[id].b==targets[next_stop]:stop_vertices.append(center.size()-1);next_stop+=1
 var network=Network.new()
 var points:PackedVector2Array=network._offset(center,4.15 if kind=="metro" else 2.0,true)
 var distances:=PackedFloat64Array([0.0])
 for i in range(1,points.size()):distances.append(distances[-1]+points[i-1].distance_to(points[i]))
 var stops:Array=[]
 for i in range(stop_vertices.size()):stops.append({"id":line.stops[i],"distance":distances[stop_vertices[i]]})
 return {"ok":true,"points":points,"distances":distances,"length":distances[-1],"stops":stops,"hosts":hosts,"kind":kind}

func _open_path(targets: Array[int], stations: Array[Dictionary], city, line: Dictionary) -> Dictionary:
 var best: Dictionary = {}
 var chosen: Array = []
 for start: int in outgoing.get(targets[0], []):
  var first := _switch_at(stations[0], edges[start].heading)
  if first.is_empty() or not Crossover.available(city, first):continue
  var fixed: Array = line.get("terminal_ports", [])
  if not fixed.is_empty() and first.port != fixed[0][1]:continue
  var finishes: Dictionary = {}
  for port: int in range(stations[-1].station_ports.size()):
   if not fixed.is_empty() and port != fixed[1][1]:continue
   var last := Crossover.geometry(stations[-1], port)
   if Crossover.available(city, last):finishes[port] = last
  if finishes.is_empty():continue
  var candidate := cycle(start, targets, finishes)
  if candidate.is_empty():continue
  var last: Dictionary = finishes[candidate.port]
  if best.is_empty() or candidate.length < best.length:
   best = candidate
   chosen = [first, last]
 if best.is_empty():return {}
 var center := PackedVector2Array([nodes[targets[0]]])
 var vertices: Array[int] = [0]
 var hosts: Array = []
 for id: int in best.edges:
  center.append(nodes[edges[id].b])
  if not edges[id].host in hosts:hosts.append(edges[id].host)
  if vertices.size() < targets.size() and edges[id].b == targets[vertices.size()]:vertices.append(center.size()-1)
 var forward := _turnback_leg(center, vertices, line.stops, chosen[0])
 var backwards := PackedVector2Array(center);backwards.reverse()
 var reversed_stops: Array = line.stops.duplicate();reversed_stops.reverse()
 vertices.reverse()
 for i: int in range(vertices.size()):vertices[i] = center.size()-1-vertices[i]
 var back := _turnback_leg(backwards, vertices, reversed_stops, chosen[1])
 if forward.stops.size()!=vertices.size() or back.stops.size()!=vertices.size():return {}
 var stops: Array = forward.stops.duplicate()
 for i: int in range(1, back.stops.size()-1):
  stops.append({"id":back.stops[i].id,"distance":forward.length+back.stops[i].distance})
 return {"ok":true,"turnback":true,"legs":[forward,back],"length":forward.length+back.length,
  "stops":stops,"hosts":hosts,"kind":chosen[0].kind,"terminal_ports":[[chosen[0].station_id,chosen[0].port],[chosen[1].station_id,chosen[1].port]]}

func _switch_at(lot: Dictionary, axis: Vector2) -> Dictionary:
 for i: int in range(lot.station_ports.size()):
  var x := Crossover.geometry(lot, i)
  if Vector2(x.axis).dot(axis) > 0.99999:return x
 return {}

func _turnback_leg(center: PackedVector2Array, vertices: Array[int], ids: Array, x: Dictionary) -> Dictionary:
 # Path 1 starts on the inbound rail and joins the right-hand outbound rail.
 var half: float = x.lateral_m/2.0
 var axis: Vector2 = x.axis
 var side := Vector2(-axis.y, axis.x)
 var points := PackedVector2Array([center[0]-side*half])
 points.append_array(x.paths[1])
 var last: Vector2 = x.end
 var track: PackedVector2Array = Network.new()._offset(center, half, false)
 var distances := PackedFloat64Array([0.0])
 for i: int in range(1, points.size()):distances.append(distances[-1]+points[i-1].distance_to(points[i]))
 var stops: Array = [{"id":ids[0],"distance":0.0}]
 for i: int in range(1, center.size()):
  if (center[i]-last).dot(axis) < -EPS and Geometry2D.get_closest_point_to_segment(center[i],center[0],last).distance_to(center[i]) < EPS:continue
  if points[-1].distance_to(track[i]) > EPS:
   distances.append(distances[-1]+points[-1].distance_to(track[i]));points.append(track[i])
  if stops.size() < vertices.size() and vertices[stops.size()] == i:
   stops.append({"id":ids[stops.size()],"distance":distances[-1]})
 return {"points":points,"distances":distances,"length":distances[-1],"stops":stops}

func cycle(start:int,targets:Array[int],finishes:Dictionary={ })->Dictionary:
 var first:Dictionary=edges[start]
 var stage:int=2 if first.b==targets[1] else 1
 var key:String="%d:%d"%[start,stage]
 var pending:Array[String]=[key];var costs:Dictionary={key:first.length};var states:Dictionary={key:[start,stage]};var previous:Dictionary={}
 while not pending.is_empty():
  pending.sort_custom(func(a,b):return float(costs[a])<float(costs[b]))
  var current:String=pending.pop_front();var state:Array=states[current];var incoming:Dictionary=edges[state[0]]
  var port := -1
  if not finishes.is_empty() and state[1]==targets.size() and incoming.b==targets[-1]:
   for finish_port: int in finishes:
    if Vector2(finishes[finish_port].axis).dot(incoming.heading)<-0.99999:port=finish_port;break
  if port>=0 or (finishes.is_empty() and state[1]==targets.size() and incoming.b==targets[0] and incoming.heading.dot(first.heading)>.965):
   var result:Array[int]=[];var cursor:String=current
   while true:
    result.push_front(states[cursor][0])
    if not previous.has(cursor):break
    cursor=previous[cursor]
   return {"edges":result,"length":costs[current],"port":port}
  for next:int in outgoing.get(incoming.b,[]):
   var following:Dictionary=edges[next]
   if incoming.heading.dot(following.heading)<.965:continue
   var progress:int=state[1]
   if progress<targets.size() and following.b==targets[progress]:progress+=1
   var next_key:String="%d:%d"%[next,progress]
   var cost:float=costs[current]+following.length
   if costs.has(next_key) and float(costs[next_key])<=cost:continue
   costs[next_key]=cost;states[next_key]=[next,progress];previous[next_key]=current
   if not next_key in pending:pending.append(next_key)
 return {}
static func sample(plan:Dictionary,distance:float)->Dictionary:
 return sample_leg(plan,fposmod(distance,float(plan.length)))
static func sample_leg(plan:Dictionary,distance:float)->Dictionary:
 var points:PackedVector2Array=plan.points;var distances:PackedFloat64Array=plan.distances
 for i in range(1,points.size()):
  if distance<=distances[i] or i==points.size()-1:
   var heading:Vector2=(points[i]-points[i-1]).normalized()
   return {"position":points[i-1]+heading*(distance-distances[i-1]),"heading":heading}
 return {"position":points[0],"heading":(points[1]-points[0]).normalized()}
