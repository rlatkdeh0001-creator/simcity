extends RefCounted
## Angle assist is a drawing policy, not a rewrite of stored road geometry.
const ANGLE_DEGREES:=10.0
const EPS:=.0001
static func connection(point: Vector2,roads: Array) -> Dictionary:
 var ordered:=roads.duplicate();ordered.reverse()
 for road in ordered:
  var points: PackedVector2Array=road.points
  for end in [0,points.size()-1]:
   if point.distance_to(points[end])>EPS:continue
   var neighbor: int=1 if end==0 else points.size()-2
   var outward: Vector2=(point-points[neighbor]).normalized()
   return {"a":points[end],"b":points[neighbor],"tangent":outward,"outward":outward,"point":point,"endpoint":true}
 for road in ordered:
  for i in range(road.points.size()-1):
   var a: Vector2=road.points[i];var b: Vector2=road.points[i+1]
   if point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b))<=EPS:
    return {"a":a,"b":b,"tangent":(b-a).normalized(),"outward":Vector2.ZERO,"point":point,"endpoint":false}
 return {}
static func axis(delta: Vector2,host: Dictionary,allow_overlay: bool=false) -> Vector2:
 if host.is_empty() or delta.length()<EPS:return Vector2.ZERO
 var tangent: Vector2=host.tangent
 var normal:=Vector2(-tangent.y,tangent.x)
 var candidates: Array[Vector2]=[normal,-normal]
 # Straight-mode overdraw may snap onto an occupied axis; the construction
 # transaction retains that surface and adds only exact same-profile tails.
 if allow_overlay:candidates.append_array([tangent,-tangent])
 elif host.endpoint:candidates.append(host.outward)
 var best:=Vector2.ZERO;var alignment: float=cos(deg_to_rad(ANGLE_DEGREES))-.000001
 for candidate in candidates:
  var dot: float=delta.normalized().dot(candidate)
  if dot>=alignment:alignment=dot;best=candidate
 return best
static func constrain_point(contact: Vector2,point: Vector2,roads: Array) -> Vector2:
 var direction:=axis(point-contact,connection(contact,roads))
 return point if direction==Vector2.ZERO else contact+direction*(point-contact).dot(direction)
static func intersect_host(origin: Vector2,direction: Vector2,host: Dictionary):
 var a: Vector2=host.a;var segment: Vector2=host.b-a
 var denominator:=direction.cross(segment)
 if absf(denominator)<EPS:
  return host.point if absf(direction.cross(Vector2(host.point)-origin))<EPS else null
 var u: float=(a-origin).cross(direction)/denominator
 if u < -EPS or u > 1+EPS:return null
 return a+segment*clampf(u,0,1)
static func apply(points: PackedVector2Array,roads: Array,allow_overlay: bool=false) -> PackedVector2Array:
 var result:=points.duplicate()
 if result.size()<2:return result
 if result.size()>2:
  result[1]=constrain_point(result[0],result[1],roads)
  result[-2]=constrain_point(result[-1],result[-2],roads)
  return result
 var first: Vector2=result[0];var last: Vector2=result[-1]
 var start_host:=connection(first,roads);var end_host:=connection(last,roads)
 if not start_host.is_empty() and not end_host.is_empty() and end_host.endpoint:
  # Authored endpoints outrank angle assistance. A middle contact may slide,
  # but two incompatible fixed endpoints cannot both move and remain pinned.
  if start_host.endpoint:return result
  var pinned_axis:=axis(first-last,end_host,allow_overlay)
  if pinned_axis!=Vector2.ZERO:
   var pinned_hit=intersect_host(last,pinned_axis,start_host)
   if pinned_hit!=null and (Vector2(pinned_hit)-last).dot(pinned_axis)>EPS:result[0]=pinned_hit
  return result
 var start_axis:=axis(last-first,start_host,allow_overlay)
 if start_axis!=Vector2.ZERO:
  if end_host.is_empty():result[-1]=first+start_axis*(last-first).dot(start_axis);return result
  var intersection=intersect_host(first,start_axis,end_host)
  if intersection!=null and (Vector2(intersection)-first).dot(start_axis)>EPS:result[-1]=intersection;return result
 if not start_host.is_empty() and start_host.endpoint:return result
 var end_axis:=axis(first-last,end_host,allow_overlay)
 if end_axis!=Vector2.ZERO:
  if start_host.is_empty():result[0]=last+end_axis*(first-last).dot(end_axis);return result
  var intersection=intersect_host(last,end_axis,start_host)
  if intersection!=null and (Vector2(intersection)-last).dot(end_axis)>EPS:result[0]=intersection
 return result
