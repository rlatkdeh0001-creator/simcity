extends RefCounted
## Metre-cost graph on actual, same-level segments. No proximity-only graph joins.
const EPS:=0.00001
var nodes:Array[Vector2]=[]
var levels:Array[float]=[]
var edges:Dictionary={}
var anchors:Dictionary={}
func node(point:Vector2,height:float)->int:
 for i in range(nodes.size()):
  if levels[i]==height and nodes[i].distance_to(point)<EPS:return i
 nodes.append(point);levels.append(height);return nodes.size()-1
func build(paths:Array,requests:Array):
 nodes.clear();levels.clear();edges.clear();anchors.clear()
 var segments:Array=[]
 var ordered:Array=paths.duplicate();ordered.sort_custom(func(a,b):return int(a.id)<int(b.id))
 for path:Dictionary in ordered:
  for i in range(1,path.points.size()):
   var a:Vector2=path.points[i-1];var b:Vector2=path.points[i]
   if a.distance_to(b)<EPS:continue
   var height:float=path.get("height",0.0)
   segments.append({"a":a,"b":b,"host":path.id,"height":height});node(a,height);node(b,height)
 for i in range(segments.size()):
  for j in range(i):
   if segments[i].height!=segments[j].height:continue
   var hit:Variant=Geometry2D.segment_intersects_segment(segments[i].a,segments[i].b,segments[j].a,segments[j].b)
   if hit!=null:node(hit,segments[i].height)
 for request:Dictionary in requests:
  var best:Dictionary={}
  for segment:Dictionary in segments:
   if segment.host!=request.host:continue
   var p:Vector2=Geometry2D.get_closest_point_to_segment(request.point,segment.a,segment.b)
   var offset:float=p.distance_to(request.point)*4.0
   if offset>float(request.get("max_offset_m",INF)):continue
   if best.is_empty() or offset<best.offset:best={"point":p,"offset":offset,"height":segment.height}
  if not best.is_empty():anchors[request.key]={"node":node(best.point,best.height),"offset":best.offset}
 for segment:Dictionary in segments:
  var ids:Array=[]
  for i in range(nodes.size()):
   if levels[i]==segment.height and Geometry2D.get_closest_point_to_segment(nodes[i],segment.a,segment.b).distance_to(nodes[i])<EPS:ids.append(i)
  ids.sort_custom(func(a,b):return nodes[a].distance_squared_to(segment.a)<nodes[b].distance_squared_to(segment.a))
  for i in range(1,ids.size()):
   var a:int=ids[i-1];var b:int=ids[i];var metres:float=nodes[a].distance_to(nodes[b])*4.0
   if not edges.has(a):edges[a]={}
   if not edges.has(b):edges[b]={}
   edges[a][b]=metres;edges[b][a]=metres
func rail_distances(key:String)->Dictionary:
 if not anchors.has(key):return {}
 var start:int=anchors[key].node
 var initial:=Vector2i(-1,start)
 var costs:Dictionary={initial:0.0};var pending:Array=[initial];var best:Dictionary={start:0.0};var done:Dictionary={}
 while not pending.is_empty():
  pending.sort_custom(func(a,b):return costs[a]<costs[b] if costs[a]!=costs[b] else (a.x<b.x if a.x!=b.x else a.y<b.y))
  var state:Vector2i=pending.pop_front()
  if done.has(state):continue
  done[state]=true
  for next:int in edges.get(state.y,{}):
   if state.x>=0 and (nodes[state.y]-nodes[state.x]).normalized().dot((nodes[next]-nodes[state.y]).normalized())<.965:continue
   var following:=Vector2i(state.y,next)
   var cost:float=costs[state]+edges[state.y][next]
   if cost>=float(costs.get(following,INF)):continue
   costs[following]=cost;pending.append(following)
   best[next]=minf(float(best.get(next,INF)),cost)
 var result:Dictionary={}
 for target:String in anchors:
  var anchor:Dictionary=anchors[target]
  if best.has(anchor.node):result[target]=best[anchor.node]
 return result
func distances(key:String)->Dictionary:
 if not anchors.has(key):return {}
 var start:int=anchors[key].node
 var costs:Dictionary={start:float(anchors[key].offset)};var pending:Array=[start];var closed:Dictionary={}
 while not pending.is_empty():
  pending.sort_custom(func(a,b):return costs[a]<costs[b] if costs[a]!=costs[b] else a<b)
  var current:int=pending.pop_front()
  if closed.has(current):continue
  closed[current]=true
  for next:int in edges.get(current,{}):
   var cost:float=costs[current]+edges[current][next]
   if cost>=float(costs.get(next,INF)):continue
   costs[next]=cost;pending.append(next)
 var result:Dictionary={}
 for target:String in anchors:
  var anchor:Dictionary=anchors[target]
  if costs.has(anchor.node):result[target]=costs[anchor.node]+anchor.offset
 return result
