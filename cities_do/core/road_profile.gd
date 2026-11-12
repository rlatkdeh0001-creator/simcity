extends RefCounted
## Total lane counts; major_side is relative to authored point order, never screen axes.
const LOCAL_LANES:=[2,3,4,5,8]
static func direction_count(road: Dictionary,direction: int) -> int:
 return ceili(float(road.lanes)/2) if direction==int(road.get("major_side",1)) else floori(float(road.lanes)/2)
static func asphalt_width(road: Dictionary) -> float:
 return float(road.width)*(.75 if road.lanes==2 else (.8125 if road.lanes==4 else .875))
static func lane_width_metres(road: Dictionary) -> float:
 return minf(3.5,(float(road.width)*4-2)/road.lanes) if road.lanes in [2,4] else minf(3.5,asphalt_width(road)*4/road.lanes)
static func median_offset(road: Dictionary) -> float:
 return -int(road.get("major_side",1))*asphalt_width(road)/road.lanes/2 if int(road.lanes)%2 else 0.0
static func separators(road: Dictionary) -> Array[float]:
 var result: Array[float]=[]
 for i in range(1,int(road.lanes)):
  if i==direction_count(road,-1):continue
  result.append((i-float(road.lanes)/2)*asphalt_width(road)/road.lanes)
 return result
static func offset_path(points: PackedVector2Array,distance: float) -> PackedVector2Array:
 if is_zero_approx(distance):return points.duplicate()
 var result:=PackedVector2Array()
 for i in range(points.size()):
  var a: Vector2=(points[i]-points[maxi(0,i-1)]).normalized()
  var b: Vector2=(points[mini(points.size()-1,i+1)]-points[i]).normalized()
  if a==Vector2.ZERO:a=b
  if b==Vector2.ZERO:b=a
  var first:=Vector2(-a.y,a.x);var last:=Vector2(-b.y,b.x)
  var normal: Vector2=(first+last).normalized()
  if normal==Vector2.ZERO:normal=last
  result.append(points[i]+normal*distance/maxf(.5,normal.dot(last)))
 return result
