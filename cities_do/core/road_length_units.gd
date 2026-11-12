extends RefCounted
## City cells: one cell is four metres. Authored existing roads are never rewritten.
const Paths=preload("res://core/road_junctions.gd")
const Angles=preload("res://core/road_angle_snap.gd")
const BUILD:=2.0
const CONNECT:=1.0
const REMOVE:=1.0
const EPS:=.0005
static func is_build_length(length: float,step: float=BUILD) -> bool:
 return length>=step-EPS and absf(length-roundf(length/step)*step)<=EPS
static func build_step(points: PackedVector2Array,roads: Array) -> float:
 if points.size()>=2 and (not Angles.connection(points[0],roads).is_empty() or not Angles.connection(points[-1],roads).is_empty()):return CONNECT
 return BUILD
static func fit(points: PackedVector2Array,roads: Array,step_override: float=0.0,lock_contacts: bool=false) -> Dictionary:
 var result:={"ok":false,"points":points.duplicate(),"reason":"도로는 8m 단위로 건설해야 합니다"}
 if points.size()<2:return result
 var step:=step_override if step_override>0 else build_step(points,roads)
 if step==CONNECT:result.reason="기존 도로 연결은 4m 단위로 건설해야 합니다"
 var length:=Paths.length_of(points)
 if length<EPS:return result
 if is_build_length(length,step):result.ok=true;return result
 var start_fixed:=lock_contacts or not Angles.connection(points[0],roads).is_empty()
 var end_fixed:=lock_contacts or not Angles.connection(points[-1],roads).is_empty()
 if start_fixed and end_fixed:
  if points.size()<5:return result # Approved: incompatible fixed straight contacts stay red.
  var target:=maxf(step,ceilf((length-EPS)/step)*step)
  var chord: Vector2=(points[-1]-points[0]).normalized()
  if chord==Vector2.ZERO:return result
  var normal:=Vector2(-chord.y,chord.x)
  var sign_value:=0.0
  for point in points:sign_value+=(point-points[0]).dot(normal)
  if sign_value<0:normal=-normal
  var low:=0.0;var high:=1.0
  for attempt in range(16):
   if Paths.length_of(bend(points,normal,high))>=target:break
   high*=2
  if Paths.length_of(bend(points,normal,high))<target:return result
  for attempt in range(42):
   var middle: float=(low+high)/2
   if Paths.length_of(bend(points,normal,middle))<target:low=middle
   else:high=middle
  result.points=bend(points,normal,(low+high)/2)
 else:
  var ordered:=points.duplicate()
  # A free start may move when the destination is an existing contact; never detach it.
  if end_fixed:ordered.reverse()
  var target:=maxf(step,roundf(length/step)*step)
  if target<length:ordered=Paths.slice(ordered,0,target)
  else:
   var prior:=ordered.size()-2
   while prior>=0 and ordered[prior].distance_to(ordered[-1])<EPS:prior-=1
   if prior<0:return result
   ordered[-1]+=(ordered[-1]-ordered[prior]).normalized()*(target-length)
  if end_fixed:ordered.reverse()
  result.points=ordered
 result.ok=is_build_length(Paths.length_of(result.points),step)
 return result
static func bend(points: PackedVector2Array,normal: Vector2,amount: float) -> PackedVector2Array:
 var result:=points.duplicate()
 # Keep both contacts AND their first/last sampled tangents exactly unchanged.
 for i in range(2,points.size()-2):
  var t:=float(i-1)/(points.size()-3)
  result[i]+=normal*amount*pow(sin(PI*t),2)
 return result
static func projection(points: PackedVector2Array,point: Vector2) -> Dictionary:
 var best:=INF;var progress:=0.0;var travelled:=0.0
 for i in range(1,points.size()):
  var a: Vector2=points[i-1];var b: Vector2=points[i]
  var near:=Geometry2D.get_closest_point_to_segment(point,a,b)
  var distance:=near.distance_to(point)
  if distance<best:best=distance;progress=travelled+a.distance_to(near)
  travelled+=a.distance_to(b)
 return {"distance":best,"progress":progress}
static func cut_target(road: Dictionary,point: Vector2) -> Dictionary:
 var hit:=projection(road.points,point)
 var offset: float=road.get("source_start",0.0)
 var finish: float=offset+Paths.length_of(road.points)
 var cursor:=clampf(offset+float(hit.progress),offset,maxf(offset,finish-EPS*2))
 var unit:=floorf((cursor+EPS)/REMOVE)*REMOVE
 var first:=maxf(offset,unit);var last:=minf(finish,unit+REMOVE)
 var selected:=road.duplicate()
 selected.points=Paths.slice(road.points,first-offset,last-offset)
 selected.flat_start=true;selected.flat_end=true
 return {"road":selected,"first":first,"last":last,"distance":hit.distance}
static func fragment(road: Dictionary,first: float,last: float) -> Dictionary:
 var result:=road.duplicate(true)
 var length:=Paths.length_of(road.points)
 var offset: float=road.get("source_start",0.0)
 result.points=Paths.slice(road.points,first,last)
 result.zoning_source_points=road.get("zoning_source_points",road.points).duplicate()
 result.zoning_source_id=road.get("zoning_source_id",road.parcel_id)
 result.source_start=offset+first;result.source_end=offset+last
 result.flat_start=bool(road.get("flat_start",false)) or first>EPS
 result.flat_end=bool(road.get("flat_end",false)) or last<length-EPS
 return result
static func supports_column(road: Dictionary,frame: Dictionary,u: int) -> bool:
 if not road.has("zoning_source_points"):return true
 var a: Vector2=frame.origin-frame.outward*road.width/2+frame.along*u
 var b: Vector2=a+frame.along
 var first: float=frame.arc_start+float(projection(frame.centerline,a).progress)
 var last: float=frame.arc_start+float(projection(frame.centerline,b).progress)
 return minf(first,last)>=float(road.source_start)-EPS and maxf(first,last)<=float(road.source_end)+EPS
