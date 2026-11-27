extends RefCounted
## Player-only construction transaction: keep retained roads, validate and append only new pieces.
const Paths=preload("res://core/road_junctions.gd")
const Units=preload("res://core/road_length_units.gd")
const Geometry=preload("res://core/road_geometry.gd")
const Parcels=preload("res://core/road_parcels.gd")
const Profile=preload("res://core/road_profile.gd")
const Height=preload("res://core/road_height.gd")
const EPS:=.00001
const MIN_JUNCTION_DISTANCE:=3.5 # 14m of centreline chainage.
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
 var travel:=Profile.travel_direction(a)
 return a.kind==b.kind and a.lanes==b.lanes and a.get("road_variant")==b.get("road_variant") and is_equal_approx(a.width,b.width) and travel==Profile.travel_direction(b) and (travel!=0 or int(a.get("major_side",1))==int(b.get("major_side",1)))
static func collinear_contact(a: Dictionary,b: Dictionary,ground:bool=false) -> bool:
 for first in segments(a.points):
  for second in segments(b.points):
   if absf(first.direction.cross(second.direction))>=.000001:continue
   for point in [first.a,first.b]:
    if point.distance_to(Geometry2D.get_closest_point_to_segment(point,second.a,second.b))<=Paths.EPS and (not ground or absf(Height.height_at(b,point))<=Height.EPS):return true
   for point in [second.a,second.b]:
    if point.distance_to(Geometry2D.get_closest_point_to_segment(point,first.a,first.b))<=Paths.EPS and (not ground or absf(Height.height_at(b,point))<=Height.EPS):return true
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
static func surface_contact(shapes: Array[PackedVector2Array],polygon: PackedVector2Array) -> bool:
 for shape in shapes:
  if not Parcels.bounds(shape).grow(Paths.EPS).intersects(Parcels.bounds(polygon)):continue
  # Include boundary-only contact, which an area-only intersection test drops.
  for expanded in Geometry2D.offset_polygon(shape,Paths.EPS,Geometry2D.JOIN_MITER):
   if not Geometry2D.intersect_polygons(expanded,polygon).is_empty():return true
 return false
static func centre_contact_in_patch(road: Dictionary,junction: Dictionary) -> bool:
 for first in segments(road.points):
  for arm in junction.arms:
   for second in segments(arm.points):
    var point=Paths.intersection(first.a,first.b,second.a,second.b)
    if point==null:continue
    if Geometry2D.is_point_in_polygon(point,junction.footprint):return true
    for i in range(junction.footprint.size()):
     if point.distance_to(Geometry2D.get_closest_point_to_segment(point,junction.footprint[i],junction.footprint[(i+1)%junction.footprint.size()]))<=Paths.EPS:return true
 return false

static func joins_crossing(candidate:Dictionary,old:Dictionary,roads:Array,ground:bool)->bool:
 var found:=false
 for first in segments(candidate.points):
  for second in segments(old.points):
   if absf(first.direction.cross(second.direction))>=.000001:continue
   var point=Paths.intersection(first.a,first.b,second.a,second.b)
   if point==null or (ground and absf(Height.height_at(old,point))>Height.EPS):continue
   found=true
   var crossing:=false
   for other in roads:
    if ground and absf(Height.height_at(other,point))>Height.EPS:continue
    for hit in contact_hits(candidate,other):
     if Paths.sample(candidate.points,hit.a).distance_to(point)<=Paths.EPS:crossing=true
   if not crossing:return false
 return found
static func endpoint_remainder(shapes:Array[PackedVector2Array],a:Dictionary,b:Dictionary)->Array[PackedVector2Array]:
 var result:Array[PackedVector2Array]=shapes.duplicate()
 for first in [0,-1]:
  for last in [0,-1]:
   var p:Vector2=a.points[first];var q:Vector2=b.points[last]
   if p.distance_to(q)>Paths.EPS:continue
   var da:Vector2=(a.points[1 if first==0 else -2]-p).normalized();var db:Vector2=(b.points[1 if last==0 else -2]-q).normalized()
   if da.dot(db)>=0 or absf(da.cross(db))>=.000001:continue
   var normal:=Vector2(-da.y,da.x);var half:float=maxf(a.width,b.width)/2+Paths.EPS;var reach:Vector2=da*Paths.EPS*2
   var regions:Array[PackedVector2Array]=[PackedVector2Array([p-reach-normal*half,p+reach-normal*half,p+reach+normal*half,p-reach+normal*half])]
   result=Geometry.outside_regions(result,regions)
 var filtered:Array[PackedVector2Array]=[]
 for shape in result:
  if absf(Parcels.area(shape))>EPS:filtered.append(shape)
 return filtered
static func overlap_allowed(a: Dictionary,b: Dictionary) -> bool:
 var remaining:=endpoint_remainder(intersections(a,b),a,b)
 if remaining.is_empty():
  var touching:=false
  for polygon in outlines(b):
   if surface_contact(outlines(a),polygon):touching=true;break
  if not touching:return true
  if collinear_contact(a,b):return true # Profile compatibility is checked by plan.
  for hit in contact_hits(a,b):
   if escapes(a,b,hit.a,hit.reach) and escapes(b,a,hit.b,hit.reach):return true
  return false
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
static func continuation_overlap_allowed(candidate:Dictionary,other_id:int,surface:Dictionary,roads:Array,surfaces:Array,topology:Dictionary,ground:bool)->bool:
 # An uncovered tail may start inside an EXISTING junction's footprint. Validate its
 # unchanged entry arm plus the tail, without storing that combined road or bypassing spacing.
 if other_id>=roads.size():return false
 var parts:=segments(candidate.points)
 if parts.is_empty():return false
 for host_id in range(roads.size()):
  if host_id==other_id or not same_profile(candidate,roads[host_id]):continue
  var existing_contact:=false
  for node in topology.nodes.values():
   if ground and absf(node.height_m)>Height.EPS:continue
   if (node.junction>=0 or node.join>=0) and host_id in node.road_ids and other_id in node.road_ids:existing_contact=true;break
  if not existing_contact:continue
  for host:Dictionary in surfaces[host_id]:
   var host_parts:=segments(host.points)
   if host_parts.is_empty():continue
   var points:=PackedVector2Array()
   if candidate.points[0].distance_to(host.points[-1])<EPS and same_line(host_parts[-1],parts[0]) and host_parts[-1].direction.dot(parts[0].direction)>0:
    points=host.points.duplicate();points.append_array(candidate.points.slice(1))
   elif candidate.points[-1].distance_to(host.points[0])<EPS and same_line(parts[-1],host_parts[0]) and parts[-1].direction.dot(host_parts[0].direction)>0:
    points=candidate.points.duplicate();points.append_array(host.points.slice(1))
   if points.is_empty():continue
   var joined:=candidate.duplicate();joined.points=points
   if overlap_allowed(joined,surface):return true
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
static func spacing_ok(topology: Dictionary,old_count: int,_total: int) -> bool:
 # Follow centreline sections across authored record boundaries, not record-local offsets.
 var anchors: Dictionary={};var adjacent: Dictionary={}
 for node in topology.nodes.values():
  adjacent[node.key]=[]
  # Uncontrolled bends are spacing boundaries too; straight joins/width changes are not.
  var bent: bool=node.arms.size()==2 and (node.arms[0].direction.dot(node.arms[1].direction)>=0 or absf(node.arms[0].direction.cross(node.arms[1].direction))>=.000001)
  if node.junction<0 and not bent:continue
  var changed:=false
  for id in node.road_ids:
   if id>=old_count:changed=true
  anchors[node.key]=changed
 for section in topology.sections:
  var distance:=Paths.length_of(section.points)
  for pair in [[section.start_node,section.end_node],[section.end_node,section.start_node]]:
   adjacent[pair[0]].append({"key":pair[1],"distance":distance,"changed":section.road>=old_count})
 for origin in anchors:
  var frontier: Array=[{"key":origin,"distance":0.0,"changed":anchors[origin]}]
  var best: Array[Dictionary]=[{},{}];best[int(anchors[origin])][origin]=0.0
  while not frontier.is_empty():
   var step: Dictionary=frontier.pop_back()
   for edge in adjacent[step.key]:
    var distance: float=step.distance+edge.distance
    if edge.key==origin or distance>=MIN_JUNCTION_DISTANCE-.0005:continue
    var changed: bool=step.changed or edge.changed or anchors.get(edge.key,false)
    if anchors.has(edge.key):
     if changed:return false
     continue # Leave unrelated legacy short gaps intact.
    if distance>=best[int(changed)].get(edge.key,INF):continue
    best[int(changed)][edge.key]=distance
    frontier.append({"key":edge.key,"distance":distance,"changed":changed})
 return true
static func plan(roads: Array,road: Dictionary) -> Dictionary:
 var ground:=not Height.off_ground(road)
 var surfaces:Array=[];var coverage_roads:Array=[]
 # A real 0m contact does not put the whole mixed-height record on the plane.
 # Keep original records/indices for topology, spacing, and ramp endpoint joins.
 for old:Dictionary in roads:
  var spans:Array=Height.ground_spans(old) if ground else [old]
  surfaces.append(spans);coverage_roads.append_array(spans)
 var retained:=coverage(coverage_roads,road)
 if not retained.ok:return retained
 var pieces:=uncovered(road.points,retained.intervals)
 if pieces.is_empty():return {"ok":false,"reason":"이미 있는 도로입니다"}
 var additions: Array[Dictionary]=[];var length:=0.0
 for points in pieces:
  var candidate:=road.duplicate(true);candidate.points=points
  if not self_clear(candidate):return {"ok":false,"reason":"도로가 스스로 겹칩니다"}
  additions.append(candidate);length+=Paths.length_of(points)
 var topology:=Paths.analyze(roads+additions)
 if not topology.errors.is_empty():return {"ok":false,"reason":topology.errors[0]}
 for node in topology.nodes.values():
  if node.arms.size()!=2 or not node.road_ids.any(func(id):return id>=roads.size()):continue
  var a:=Profile.travel_direction(node.arms[0]);var b:=Profile.travel_direction(node.arms[1])
  # Both arm profiles point AWAY from the node; matching signs mean no through movement.
  if a!=0 and a==b:return {"ok":false,"reason":"통행 방향이 맞지 않습니다"}
 if not spacing_ok(topology,roads.size(),roads.size()+additions.size()):return {"ok":false,"reason":"교차로 사이 간격은 14m 이상이어야 합니다"}
 var existing:=Paths.analyze(roads)
 for i in range(additions.size()):
  var candidate: Dictionary=additions[i]
  var prior:=roads+additions.slice(0,i)
  for old_id in range(prior.size()):
   var old:Dictionary=prior[old_id]
   if collinear_contact(candidate,old,ground and Height.off_ground(old)) and not preload("res://core/road_transitions.gd").allowed(candidate,old) and not joins_crossing(candidate,old,prior,ground):return {"ok":false,"reason":"직선 연장은 같은 폭 또는 바로 옆 폭 등급만 가능합니다"}
   for surface:Dictionary in surfaces[old_id]:
    if not overlap_allowed(candidate,surface) and not continuation_overlap_allowed(candidate,old_id,surface,roads,surfaces,existing,ground):return {"ok":false,"reason":"기존 도로와 겹칩니다"}
  for junction in existing.junctions+existing.joins:
   if ground and absf(junction.height_m)>Height.EPS:continue
   if junction.has("box") and surface_contact(outlines(candidate),junction.footprint) and not centre_contact_in_patch(candidate,junction):return {"ok":false,"reason":"도로 측면에만 닿는 연결은 허용되지 않습니다"}
  surfaces.append([candidate])
 return {"ok":true,"new_roads":additions,"new_length_m":length*4,"retained_length_m":(Paths.length_of(road.points)-length)*4,"construction_cost":0,"reason":""}
