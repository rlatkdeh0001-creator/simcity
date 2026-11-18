extends RefCounted
## Structural routing only. No clock, dispatch, fares, scene or mutable operational state.
const Network=preload("res://core/traffic_network.gd")
const Paths=preload("res://core/road_junctions.gd")
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
func rail_plan(city,line:Dictionary)->Dictionary:
 nodes.clear();edges.clear();outgoing.clear()
 var kind:String="metro" if line.kind=="metro" else "rail"
 var targets:Array[int]=[]
 for id:Variant in line.stops:
  var found:=false
  for lot:Dictionary in city.public_facilities.lots:
   if lot.id!=id or lot.get("internal_kind","")!=kind:continue
   var p:PackedVector2Array=lot.internal_points
   targets.append(node((p[0]+p[-1])*2));found=true;break
  if not found:return failure()
 var segments:Array=[]
 for route:Dictionary in city.transit_routes:
  if route.kind!=kind:continue
  for i in range(1,route.points.size()):
   var a:Vector2=route.points[i-1]*4;var b:Vector2=route.points[i]*4
   segments.append({"a":a,"b":b,"host":route.id});node(a);node(b)
 # True endpoint/interior contacts and geometric crossings use the same graph in either insertion order.
 for i in range(segments.size()):
  for j in range(i):
   var hit:Variant=Geometry2D.segment_intersects_segment(segments[i].a,segments[i].b,segments[j].a,segments[j].b)
   if hit!=null:node(hit)
 for segment:Dictionary in segments:
  var ids:Array[int]=[]
  for i in range(nodes.size()):
   if Geometry2D.get_closest_point_to_segment(nodes[i],segment.a,segment.b).distance_to(nodes[i])<EPS:ids.append(i)
  ids.sort_custom(func(a,b):return nodes[a].distance_squared_to(segment.a)<nodes[b].distance_squared_to(segment.a))
  for i in range(1,ids.size()):edge(ids[i-1],ids[i],segment.host);edge(ids[i],ids[i-1],segment.host)
 if targets.size()<2:return failure()
 var best:Dictionary={}
 for start:int in outgoing.get(targets[0],[]):
  var candidate:=cycle(start,targets)
  if not candidate.is_empty() and (best.is_empty() or candidate.length<best.length):best=candidate
 if best.is_empty():return failure()
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
func cycle(start:int,targets:Array[int])->Dictionary:
 var first:Dictionary=edges[start]
 var stage:int=2 if first.b==targets[1] else 1
 var key:String="%d:%d"%[start,stage]
 var pending:Array[String]=[key];var costs:Dictionary={key:first.length};var states:Dictionary={key:[start,stage]};var previous:Dictionary={}
 while not pending.is_empty():
  pending.sort_custom(func(a,b):return float(costs[a])<float(costs[b]))
  var current:String=pending.pop_front();var state:Array=states[current];var incoming:Dictionary=edges[state[0]]
  if state[1]==targets.size() and incoming.b==targets[0] and incoming.heading.dot(first.heading)>.965:
   var result:Array[int]=[];var cursor:String=current
   while true:
    result.push_front(states[cursor][0])
    if not previous.has(cursor):break
    cursor=previous[cursor]
   return {"edges":result,"length":costs[current]}
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
 distance=fposmod(distance,float(plan.length))
 var points:PackedVector2Array=plan.points;var distances:PackedFloat64Array=plan.distances
 for i in range(1,points.size()):
  if distance<=distances[i]:
   var heading:Vector2=(points[i]-points[i-1]).normalized()
   return {"position":points[i-1]+heading*(distance-distances[i-1]),"heading":heading}
 return {"position":points[0],"heading":(points[1]-points[0]).normalized()}
