extends RefCounted
## Pure preview. Cuts use stable parcel IDs and ORIGINAL RECORD-LOCAL arc distances,
## never source_start offsets. Points follow the record's original sampling direction.
const Paths=preload("res://core/road_junctions.gd")
const Units=preload("res://core/road_length_units.gd")
static func selection(roads: Array,id: int,point: Vector2,drag_to: Variant=null) -> Dictionary:
 if not point.is_finite():return {"ok":false,"cuts":[]}
 if drag_to!=null and (not drag_to is Vector2 or not drag_to.is_finite()):return {"ok":false,"cuts":[]}
 var selected:=-1
 for index in range(roads.size()):
  if int(roads[index].get("parcel_id",index))==id:selected=index;break
 if selected<0:return {"ok":false,"cuts":[]}
 if roads[selected].points.size()<2:return {"ok":false,"cuts":[]}
 var hit:=Units.projection(roads[selected].points,point)
 if float(hit.distance)>float(roads[selected].width)/2+Units.EPS:return {"ok":false,"cuts":[]}
 var topology:=Paths.analyze(roads)
 var offsets:={}
 var start: Dictionary={}
 var candidates: Array=[]
 var progress: float=hit.progress
 for section: Dictionary in topology.sections:
  var index: int=section.road
  section.first=float(offsets.get(index,0.0))
  section.last=section.first+Paths.length_of(section.points)
  offsets[index]=section.last
  if index==selected and progress>=section.first-Paths.EPS and progress<=section.last+Paths.EPS:
   candidates.append(section)
   start=section # An exact junction click deterministically chooses the forward span.
 if start.is_empty():return {"ok":false,"cuts":[]}
 if drag_to==null:return _result(roads,_walk(topology,start,progress,1)+_walk(topology,start,progress,-1))
 var route: Array=[]
 var target:={"distance":INF,"progress":0.0}
 for candidate: Dictionary in candidates:
  for direction in [1,-1]:
   var possible:=_walk(topology,candidate,clampf(progress,candidate.first,candidate.last),direction)
   var aim:=_aim(roads,possible,drag_to)
   if float(aim.progress)>Paths.EPS and float(aim.distance)<float(target.distance):
    route=possible
    target=aim
 if route.is_empty():return {"ok":false,"cuts":[]}
 var budget:=maxf(Units.BUILD,ceilf((float(target.progress)-Units.EPS)/Units.BUILD)*Units.BUILD)
 var chosen: Array=[]
 for part: Dictionary in route:
  var length: float=part.last-part.first
  var take:=minf(length,budget)
  var piece:=part.duplicate()
  if int(part.direction)>0:piece.last=part.first+take
  else:piece.first=part.last-take
  chosen.append(piece)
  budget-=take
  if budget<=Paths.EPS:break
 return _result(roads,chosen)

static func _aim(roads: Array,route: Array,point: Vector2) -> Dictionary:
 var best:={"distance":INF,"progress":0.0}
 var travelled:=0.0
 for part: Dictionary in route:
  var points:=Paths.slice(roads[part.road].points,part.first,part.last)
  if int(part.direction)<0:points.reverse()
  var hit:=Units.projection(points,point)
  if float(hit.distance)<float(best.distance):
   best={"distance":hit.distance,"progress":travelled+float(hit.progress)}
  travelled+=part.last-part.first
 return best

static func _walk(topology: Dictionary,start: Dictionary,progress: float,direction: int) -> Array:
 var route: Array=[]
 var section:=start
 var visited:={}
 while not visited.has(section.id):
  visited[section.id]=true
  var finish: float=section.last if direction>0 else section.first
  if absf(finish-progress)>Paths.EPS:
   route.append({"road":section.road,"first":minf(progress,finish),"last":maxf(progress,finish),"direction":direction})
  var node_key: Vector2i=section.end_node if direction>0 else section.start_node
  if topology.nodes[node_key].arms.size()!=2:break
  var next: Dictionary={}
  for candidate: Dictionary in topology.sections:
   if candidate.id==section.id:continue
   if candidate.start_node==node_key or candidate.end_node==node_key:next=candidate;break
  if next.is_empty():break
  section=next
  direction=1 if section.start_node==node_key else -1
  progress=section.first if direction>0 else section.last
 return route

static func _result(roads: Array,route: Array) -> Dictionary:
 var cuts: Array=[]
 for part: Dictionary in route:
  var road: Dictionary=roads[part.road]
  var id: int=road.get("parcel_id",part.road)
  var merged:=false
  for existing: Dictionary in cuts:
   if existing.id==id and part.first<=existing.last+Paths.EPS and part.last>=existing.first-Paths.EPS:
    existing.first=minf(existing.first,part.first)
    existing.last=maxf(existing.last,part.last)
    existing.points=Paths.slice(road.points,existing.first,existing.last)
    merged=true
    break
  if not merged:cuts.append({"id":id,"first":part.first,"last":part.last,"points":Paths.slice(road.points,part.first,part.last)})
 return {"ok":not cuts.is_empty(),"cuts":cuts}
