extends RefCounted
## Boundary lattice is inherited from real road parcels, never a screen-space grid.
const Parcels=preload("res://core/road_parcels.gd")
const Paths=preload("res://core/road_junctions.gd")
const Units=preload("res://core/road_length_units.gd")
const Angles=preload("res://core/road_angle_snap.gd")
const EPS:=.0005
static func frame_near(city,point: Vector2) -> Dictionary:
 var best:=INF;var selected: Dictionary={}
 for i in range(city.roads.size()-1,-1,-1):
  var road: Dictionary=city.roads[i]
  var distance: float=Units.projection(road.points,point).distance
  if distance>=best:continue
  best=distance;selected=road
 if selected.is_empty():return {"origin":Vector2.ZERO,"along":Vector2.RIGHT,"outward":Vector2.DOWN}
 var frames:=Parcels.blocks(selected.get("zoning_source_points",selected.points),selected.width/2,0)
 var result: Dictionary={};var closest: Dictionary={};best=INF
 for frame in frames:
  if frame.side!=1:continue
  var distance: float=Units.projection(frame.centerline,point).distance
  if distance<best:best=distance;closest=frame;result={"origin":frame.origin,"along":frame.along,"outward":frame.outward}
 if selected.has("grid_frame") and not closest.is_empty() and straight(closest):
  var inherited: Dictionary=selected.grid_frame
  if maxf(absf(closest.along.dot(inherited.along)),absf(closest.along.dot(inherited.outward)))>.99999:return inherited.duplicate(true)
 if result.is_empty():
  var along: Vector2=(selected.points[-1]-selected.points[0]).normalized()
  var outward:=Vector2(-along.y,along.x)
  return {"origin":selected.points[0]+outward*selected.width/2,"along":along,"outward":outward}
 return result
static func coordinates(point: Vector2,frame: Dictionary) -> Vector2:
 var delta: Vector2=point-frame.origin
 return Vector2(delta.dot(frame.along),delta.dot(frame.outward))
static func world(point: Vector2,frame: Dictionary) -> Vector2:return frame.origin+frame.along*point.x+frame.outward*point.y
static func tick(value: float,phase: float=0.0) -> float:return roundf(value-phase)+phase
static func contact(city,point: Vector2,frame: Dictionary,width: float,ignore: Vector2=Vector2.INF) -> Dictionary:
 var near:=Paths.snap_point(point,city.roads)
 if near.distance_to(ignore)<EPS and point.distance_to(ignore)>=.5:return {}
 var host:=Angles.connection(near,city.roads)
 if host.is_empty():return {}
 if host.endpoint:return {"point":near}
 var axis: Vector2=frame.along if absf(frame.along.dot(host.tangent))>=absf(frame.outward.dot(host.tangent)) else frame.outward
 var target:=tick((near-Vector2(frame.origin)).dot(axis),width/2)
 var best:=INF;var result:=near
 for road in city.roads:
  if float(Units.projection(road.points,near).distance)>EPS:continue
  for i in range(1,road.points.size()):
   var a: Vector2=road.points[i-1];var b: Vector2=road.points[i]
   var first: float=(a-Vector2(frame.origin)).dot(axis);var span: float=(b-a).dot(axis)
   if absf(span)<EPS:continue
   var t: float=(target-first)/span
   if t<0 or t>1:continue
   var q:=a.lerp(b,t);var gap:=q.distance_to(near)
   if gap<best:best=gap;result=q
 return {"point":result}
static func start(city,point: Vector2,width: float,frame: Dictionary) -> Vector2:
 var hit:=contact(city,point,frame,width)
 if not hit.is_empty():return hit.point
 var local:=coordinates(point,frame)
 return world(Vector2(tick(local.x),tick(local.y,width/2)),frame)
static func ends(city,first: Vector2,last: Vector2,width: float,frame: Dictionary) -> PackedVector2Array:
 var a:=coordinates(first,frame);var b:=coordinates(last,frame)
 var parallel:=absf(b.x-a.x)>=absf(b.y-a.y)
 var cross_axis:=1 if parallel else 0;var along_axis:=1-cross_axis
 var start_hit:=contact(city,first,frame,width)
 var end_hit:=contact(city,last,frame,width,first)
 if start_hit.is_empty():
  a[cross_axis]=tick(a[cross_axis],width/2);a[along_axis]=tick(a[along_axis])
 else:a=coordinates(start_hit.point,frame)
 if end_hit.is_empty():
  b[cross_axis]=tick(b[cross_axis],a[cross_axis])
  b[along_axis]=tick(b[along_axis],width/2 if not start_hit.is_empty() else 0)
 else:
  b=coordinates(end_hit.point,frame)
  if start_hit.is_empty():a[cross_axis]=tick(a[cross_axis],b[cross_axis])
 return PackedVector2Array([world(a,frame),world(b,frame)])
static func straight(frame: Dictionary) -> bool:
 for p in frame.centerline:
  if absf((p-Vector2(frame.centerline[0])).cross(frame.along))>EPS:return false
 return true
static func aligned_blocks(frames: Array[Dictionary],grid: Dictionary) -> Array[Dictionary]:
 if grid.is_empty():return frames
 for i in range(frames.size()):
  var frame: Dictionary=frames[i]
  if maxf(absf(frame.along.dot(grid.along)),absf(frame.along.dot(grid.outward)))<.99999:continue
  if not straight(frame):continue
  var phase: float=(frame.origin-Vector2(grid.origin)).dot(frame.along)
  var shift:=ceilf(phase-EPS)-phase
  var length: float=frame.centerline[0].distance_to(frame.centerline[-1])
  var continues: bool=i+2<frames.size() and frame.along.dot(frames[i+2].along)>.99999 and frame.centerline[-1].distance_to(frames[i+2].centerline[0])<EPS
  frame.origin+=frame.along*shift
  frame.columns=ceili(length-shift-EPS) if continues else floori(length-shift+EPS)
  var extension: float=shift+frame.columns-length
  if extension>EPS:frame.centerline.append(frame.centerline[-1]+frame.along*extension)
 return frames
static func valid_length(points: PackedVector2Array,roads: Array) -> bool:
 if points.size()<2:return false
 var minimum:=Units.build_step(points,roads)
 var length:=Paths.length_of(points)
 return length>=minimum-EPS and (points.size()==2 or Units.is_build_length(length,1))
static func fit(points: PackedVector2Array,roads: Array) -> Dictionary:
 # Straight lattice connections retain exact endpoints, including approved width-phase exceptions.
 if points.size()==2:return {"ok":valid_length(points,roads),"points":points,"reason":"도로가 너무 짧습니다"}
 var result:=Units.fit(points,roads,1,true)
 result.ok=result.ok and valid_length(result.points,roads)
 return result
