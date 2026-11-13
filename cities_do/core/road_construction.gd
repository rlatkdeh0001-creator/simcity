extends RefCounted
## Player-only construction transaction: keep retained roads, validate and append only new pieces.
const Paths=preload("res://core/road_junctions.gd")
const Units=preload("res://core/road_length_units.gd")
const Geometry=preload("res://core/road_geometry.gd")
const Parcels=preload("res://core/road_parcels.gd")
const EPS:=.00001
const MIN_JUNCTION_DISTANCE:=4.0
static func segments(points: PackedVector2Array) -> Array[Dictionary]:
 var result: Array[Dictionary]=[];var travelled:=0.0
 for i in range(1,points.size()):
  var length:=points[i-1].distance_to(points[i])
  if length>EPS:result.append({"a":points[i-1],"b":points[i],"direction":(points[i]-points[i-1])/length,"length":length,"first":travelled})
  travelled+=length
 return result
static func same_line(a: Dictionary,b: Dictionary) -> bool:
 return absf(a.direction.cross(b.direction))<.000001 and absf((b.a-Vector2(a.a)).cross(a.direction))<EPS and absf((b.b-Vector2(a.a)).cross(a.direction))<EPS
static func same_profile(a: Dictionary,b: Dictionary) -> bool:
 return a.kind==b.kind and a.lanes==b.lanes and is_equal_approx(a.width,b.width) and int(a.get("major_side",1))==int(b.get("major_side",1))
static func collinear_contact(a: Dictionary,b: Dictionary) -> bool:
 for first in segments(a.points):
  for second in segments(b.points):
   if absf(first.direction.cross(second.direction))>=.000001:continue
   for point in [first.a,first.b]:
    if point.distance_to(Geometry2D.get_closest_point_to_segment(point,second.a,second.b))<=Paths.EPS:return true
   for point in [second.a,second.b]:
    if point.distance_to(Geometry2D.get_closest_point_to_segment(point,first.a,first.b))<=Paths.EPS:return true
 return false
static func coverage(roads: Array,road: Dictionary) -> Dictionary:
 var intervals: Array[Vector2]=[]
 for a in segments(road.points):
  for old in roads:
   for b in segments(old.points):
    if not same_line(a,b):continue
    var p: float=(b.a-Vector2(a.a)).dot(a.direction);var q: float=(b.b-Vector2(a.a)).dot(a.direction)
    var first:=maxf(0,minf(p,q));var last:=minf(a.length,maxf(p,q))
    if last-first<=EPS:continue
    if not same_profile(road,old) or a.direction.dot(b.direction)<=0:return {"ok":false,"reason":"다른 종류·차로·방향의 도로와 겹칩니다"}
    intervals.append(Vector2(a.first+first,a.first+last))
 intervals.sort_custom(func(a,b):return a.x<b.x)
 var merged: Array[Vector2]=[]
 for interval in intervals:
  if merged.is_empty() or interval.x>merged[-1].y+EPS:merged.append(interval)
  else:merged[-1].y=maxf(merged[-1].y,interval.y)
 return {"ok":true,"intervals":merged}
static func uncovered(points: PackedVector2Array,intervals: Array) -> Array[PackedVector2Array]:
 var result: Array[PackedVector2Array]=[];var cursor:=0.0
 for interval in intervals:
  if interval.x-cursor>EPS:result.append(Paths.slice(points,cursor,interval.x))
  cursor=maxf(cursor,interval.y)
 var length:=Paths.length_of(points)
 if length-cursor>EPS:result.append(Paths.slice(points,cursor,length))
 return result
static func fit_overlay(points: PackedVector2Array,roads: Array,profile: Dictionary) -> Dictionary:
 if points.size()!=2:return {}
 var road:=profile.duplicate();road.points=points
 var retained:=coverage(roads,road)
 if not retained.ok or retained.intervals.is_empty():return {}
 var pieces:=uncovered(points,retained.intervals);var result:=points.duplicate()
 if pieces.is_empty():return {"ok":false,"points":points,"reason":"이미 있는 도로입니다"}
 for piece in pieces:
  var fitted:=Units.fit(piece,roads)
  if not fitted.ok:return {"ok":false,"points":points,"reason":fitted.reason}
  if piece[0].distance_to(points[0])<EPS:result[0]=fitted.points[0]
  if piece[-1].distance_to(points[-1])<EPS:result[-1]=fitted.points[-1]
 return {"ok":true,"points":result,"reason":""}
static func outlines(road: Dictionary) -> Array[PackedVector2Array]:return Geometry.ribbons(road.points,road.width,true,true)
static func intersections(a: Dictionary,b: Dictionary) -> Array[PackedVector2Array]:
 var result: Array[PackedVector2Array]=[]
 for first in outlines(a):
  for second in outlines(b):
   for shape in Geometry2D.intersect_polygons(first,second):
    if Parcels.area(shape)>EPS:result.append(shape)
 return result
static func inside(point: Vector2,road: Dictionary) -> bool:
 var distance: float=Units.projection(road.points,point).distance
 if distance<EPS or distance>=float(road.width)/2-EPS:return false
 for shape in outlines(road):
  if Geometry2D.is_point_in_polygon(point,shape):return true
 return false
static func escapes(road: Dictionary,other: Dictionary,at: float,reach: float) -> bool:
 var length:=Paths.length_of(road.points)
 for sign_value in [-1,1]:
  var distance:=clampf(at+sign_value*reach,0,length)
  if absf(distance-at)>EPS and inside(Paths.sample(road.points,distance),other):return false
 return true
static func contact_hits(a: Dictionary,b: Dictionary) -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 for first in segments(a.points):
  for second in segments(b.points):
   var cross_value: float=absf(first.direction.cross(second.direction))
   if cross_value<.000001:continue
   var point=Paths.intersection(first.a,first.b,second.a,second.b)
   if point==null:continue
   result.append({"a":first.first+first.a.distance_to(point),"b":second.first+second.a.distance_to(point),"reach":(float(a.width)+float(b.width))/cross_value})
 return result
static func overlap_allowed(a: Dictionary,b: Dictionary) -> bool:
 var remaining:=intersections(a,b)
 if remaining.is_empty():return true
 var length_a:=Paths.length_of(a.points);var length_b:=Paths.length_of(b.points)
 for hit in contact_hits(a,b):
  if not escapes(a,b,hit.a,hit.reach) or not escapes(b,a,hit.b,hit.reach):continue
  var first:={"points":Paths.slice(a.points,maxf(0,hit.a-hit.reach),minf(length_a,hit.a+hit.reach)),"width":a.width}
  var second:={"points":Paths.slice(b.points,maxf(0,hit.b-hit.reach),minf(length_b,hit.b+hit.reach)),"width":b.width}
  for allowed in intersections(first,second):
   # Re-offsetting sliced paths can leave float/Clipper slivers at a valid junction.
   # Use the existing topology tolerance only after contact and escape checks pass.
   var border:=Geometry2D.offset_polygon(allowed,Paths.EPS,Geometry2D.JOIN_MITER)
   var contact_area: PackedVector2Array=allowed if border.is_empty() else border[0]
   var next: Array[PackedVector2Array]=[]
   for shape in remaining:
    for rest in Geometry2D.clip_polygons(shape,contact_area):
     if Parcels.area(rest)>EPS:next.append(rest)
   remaining=next
  if remaining.is_empty():return true
 return false
static func self_clear(road: Dictionary) -> bool:
 var parts:=segments(road.points);var hits: Array[Dictionary]=[];var hits_ready:=false
 for i in range(parts.size()):
  for j in range(i+1,parts.size()):
   var a: Dictionary=parts[i];var b: Dictionary=parts[j]
   if same_line(a,b):
    var p: float=(b.a-Vector2(a.a)).dot(a.direction);var q: float=(b.b-Vector2(a.a)).dot(a.direction)
    if minf(a.length,maxf(p,q))-maxf(0,minf(p,q))>EPS:return false
   if j==i+1 or b.first+b.length/2-a.first-a.length/2<=float(road.width)*2:continue
   if not Rect2(a.a,a.b-a.a).abs().grow(road.width/2).intersects(Rect2(b.a,b.b-b.a).abs().grow(road.width/2)):continue
   var first:={"points":PackedVector2Array([a.a,a.b]),"width":road.width}
   var second:={"points":PackedVector2Array([b.a,b.b]),"width":road.width}
   if intersections(first,second).is_empty():continue
   if not hits_ready:hits=contact_hits(road,road);hits_ready=true
   var supported:=false
   for hit in hits:
    if absf(hit.a-hit.b)<EPS:continue
    if absf((a.first+a.length/2)-hit.a)<=hit.reach and absf((b.first+b.length/2)-hit.b)<=hit.reach:supported=true;break
   if not supported:return false
 return true
static func spacing_ok(topology: Dictionary,old_count: int,total: int) -> bool:
 var affected: Dictionary={};var offsets: Dictionary={};var positions: Array=[]
 for i in range(total):positions.append([])
 for node in topology.nodes.values():
  if node.junction<0:continue
  for id in node.road_ids:
   if id>=old_count:affected[node.key]=true
 for section in topology.sections:
  var first: float=offsets.get(section.road,0.0);var length:=Paths.length_of(section.points)
  for pair in [[section.start_node,first],[section.end_node,first+length]]:
   var node: Dictionary=topology.nodes[pair[0]]
   if node.junction<0:continue
   var list: Array=positions[section.road]
   var item:={"distance":pair[1],"changed":affected.has(node.key)}
   if not list.is_empty() and absf(list[-1].distance-item.distance)<EPS:list[-1].changed=list[-1].changed or item.changed
   else:list.append(item)
  offsets[section.road]=first+length
 for list in positions:
  for i in range(1,list.size()):
   if (list[i-1].changed or list[i].changed) and list[i].distance-list[i-1].distance<MIN_JUNCTION_DISTANCE-.0005:return false
 return true
static func plan(roads: Array,road: Dictionary) -> Dictionary:
 var retained:=coverage(roads,road)
 if not retained.ok:return retained
 var pieces:=uncovered(road.points,retained.intervals)
 if pieces.is_empty():return {"ok":false,"reason":"이미 있는 도로입니다"}
 var additions: Array[Dictionary]=[];var length:=0.0
 for points in pieces:
  var candidate:=road.duplicate(true);candidate.points=points
  if not self_clear(candidate):return {"ok":false,"reason":"도로가 스스로 겹칩니다"}
  for old in roads+additions:
   if not same_profile(candidate,old) and collinear_contact(candidate,old):return {"ok":false,"reason":"직선 연장은 같은 종류·차로의 도로만 가능합니다"}
   if not overlap_allowed(candidate,old):return {"ok":false,"reason":"기존 도로와 겹칩니다"}
  additions.append(candidate);length+=Paths.length_of(points)
 var topology:=Paths.analyze(roads+additions)
 if not topology.errors.is_empty():return {"ok":false,"reason":topology.errors[0]}
 if not spacing_ok(topology,roads.size(),roads.size()+additions.size()):return {"ok":false,"reason":"교차로 사이 간격은 4칸 이상이어야 합니다"}
 return {"ok":true,"new_roads":additions,"new_length_m":length*4,"retained_length_m":(Paths.length_of(road.points)-length)*4,"construction_cost":0,"reason":""}
