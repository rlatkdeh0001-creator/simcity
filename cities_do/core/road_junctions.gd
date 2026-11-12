extends RefCounted
## Shared centreline topology in city cells. Curves retain their authored geometry.
const EPS := .0001
const Profile=preload("res://core/road_profile.gd")
const CROSSWALK_HALF_LENGTH := .22
const CROSSWALK_EDGE_GAP := .03
static func key(point: Vector2) -> Vector2i:
 return Vector2i(roundi(point.x/EPS),roundi(point.y/EPS))
static func merged_key(point: Vector2, nodes: Dictionary) -> Vector2i:
 var base := key(point)
 for x in range(-1,2):
  for y in range(-1,2):
   var candidate := base+Vector2i(x,y)
   if nodes.has(candidate) and nodes[candidate].position.distance_to(point)<=EPS*2:return candidate
 return base
static func snap_point(point: Vector2,roads: Array,distance: float=1.0) -> Vector2:
 if not point.is_finite():return point
 var best:=point;var nearest:=distance+.000001;var found:=false
 # Prefer an authored endpoint over a nearby interior projection.
 for road in roads:
  for candidate in [road.points[0],road.points[-1]]:
   var gap: float=point.distance_to(candidate)
   if gap<nearest:nearest=gap;best=candidate;found=true
 if found:return best
 for road in roads:
  for index in range(road.points.size()-1):
   var candidate:=Geometry2D.get_closest_point_to_segment(point,road.points[index],road.points[index+1])
   var gap:=point.distance_to(candidate)
   if gap<nearest:nearest=gap;best=candidate
 return best
static func snap_path(points: PackedVector2Array,roads: Array) -> PackedVector2Array:
 var result:=points.duplicate()
 if result.size()>=2:
  result[0]=snap_point(result[0],roads);result[-1]=snap_point(result[-1],roads)
 return result
static func length_of(points: PackedVector2Array) -> float:
 var result := 0.0
 for i in range(1,points.size()): result+=points[i-1].distance_to(points[i])
 return result
static func sample(points: PackedVector2Array, distance: float) -> Vector2:
 for i in range(1,points.size()):
  var length := points[i-1].distance_to(points[i])
  if length>EPS and distance<=length: return points[i-1].lerp(points[i],clampf(distance/length,0,1))
  distance-=length
 return points[-1]
static func slice(points: PackedVector2Array, first: float, last: float) -> PackedVector2Array:
 var result := PackedVector2Array([sample(points,first)])
 var travelled := 0.0
 for i in range(1,points.size()):
  travelled+=points[i-1].distance_to(points[i])
  if travelled>first+EPS and travelled<last-EPS:result.append(points[i])
 var end := sample(points,last)
 if result[-1].distance_to(end)>EPS: result.append(end)
 return result
static func analyze(roads: Array) -> Dictionary:
 var cuts := []
 var offsets := []
 var errors: Array[String] = []
 for road in roads:
  var cumulative := [0.0]
  for i in range(1,road.points.size()): cumulative.append(cumulative[-1]+road.points[i-1].distance_to(road.points[i]))
  offsets.append(cumulative)
  cuts.append([0.0,cumulative[-1]])
 for a in range(roads.size()):
  for b in range(a,roads.size()):
   var pa: PackedVector2Array=roads[a].points
   var pb: PackedVector2Array=roads[b].points
   for i in range(pa.size()-1):
    for j in range(pb.size()-1):
     if a==b and j<=i+1:continue
     if a==b and i==0 and j==pb.size()-2 and pa[0].is_equal_approx(pa[-1]):continue
     var ea := pa[i+1]-pa[i]
     var eb := pb[j+1]-pb[j]
     if ea.length()<EPS or eb.length()<EPS:continue
     if absf(ea.cross(pb[j]-pa[i]))/ea.length()<EPS and absf(ea.cross(pb[j+1]-pa[i]))/ea.length()<EPS:
      var t0 := (pb[j]-pa[i]).dot(ea)/ea.length_squared()
      var t1 := (pb[j+1]-pa[i]).dot(ea)/ea.length_squared()
      if minf(1,maxf(t0,t1))-maxf(0,minf(t0,t1))>EPS:
       if not "겹치는 도로는 주행할 수 없습니다" in errors: errors.append("겹치는 도로는 주행할 수 없습니다")
       continue
     var hit=Geometry2D.segment_intersects_segment(pa[i],pa[i+1],pb[j],pb[j+1])
     if hit==null:continue
     cuts[a].append(float(offsets[a][i])+pa[i].distance_to(hit))
     cuts[b].append(float(offsets[b][j])+pb[j].distance_to(hit))
 var nodes := {}
 var sections := []
 for road_id in range(roads.size()):
  cuts[road_id].sort()
  var unique := []
  for distance in cuts[road_id]:
   if unique.is_empty() or distance-unique[-1]>EPS:unique.append(distance)
  for i in range(1,unique.size()):
   var points := slice(roads[road_id].points,unique[i-1],unique[i])
   if points.size()<2:continue
   var start := merged_key(points[0],nodes)
   var end := merged_key(points[-1],nodes)
   var section := {"id":sections.size(),"road":road_id,"points":points,"start_node":start,"end_node":end}
   sections.append(section)
   for pair in [[start,points[0],(points[1]-points[0]).normalized()],[end,points[-1],(points[-2]-points[-1]).normalized()]]:
    if not nodes.has(pair[0]):nodes[pair[0]]={"key":pair[0],"position":pair[1],"arms":[],"road_ids":[],"junction":-1}
    var node: Dictionary=nodes[pair[0]]
    if not road_id in node.road_ids:node.road_ids.append(road_id)
    var duplicate := false
    for arm in node.arms:
     if arm.direction.dot(pair[2])>.9999: duplicate=true
    if not duplicate:node.arms.append({"direction":pair[2],"width":float(roads[road_id].width),"lanes":int(roads[road_id].lanes)})
 var junctions := []
 var joins := []
 for node in nodes.values():
  node.join=-1
  if node.arms.size()<2:continue
  var transition: bool=node.arms.size()==2
  # A single closed stroke already has continuous offset lanes at its seam.
  if transition and node.road_ids.size()==1:continue
  if transition and node.arms[0].direction.dot(node.arms[1].direction)<-.99999 and node.arms[0].lanes==node.arms[1].lanes and is_equal_approx(node.arms[0].width,node.arms[1].width):continue
  if transition:node.join=joins.size()
  else:node.junction=junctions.size()
  var radius := 0.0
  for arm in node.arms:radius=maxf(radius,arm.width/2+1.0)
  var junction := {"id":node.junction,"key":node.key,"position":node.position,"arms":node.arms,"radius":radius}
  junction.transition=transition
  junction.footprint=patch(junction)
  junction.asphalt=patch(junction,true)
  if transition:joins.append(junction)
  else:junctions.append(junction)
 return {"nodes":nodes,"sections":sections,"junctions":junctions,"joins":joins,"errors":errors}

static func connection(node: Dictionary, topology: Dictionary) -> Dictionary:
 if node.junction>=0:return topology.junctions[node.junction]
 if node.join>=0:return topology.joins[node.join]
 return {}

static func crosswalk_distance(junction: Dictionary, arm: Dictionary) -> float:
 # Measure the far edge of the crossing road, not a shared maximum road radius.
 var direction: Vector2=arm.direction
 var half: float=Profile.asphalt_width(arm)/2
 var edge := 0.0
 for other in junction.arms:
  var crossing: float=absf(direction.cross(other.direction))
  if crossing<.001:continue
  # Project the whole zebra width beyond the intersecting strip at oblique angles.
  var skew: float=absf(direction.dot(other.direction))
  edge=maxf(edge,(other.width/2+half*skew)/crossing)
 return edge+CROSSWALK_HALF_LENGTH+CROSSWALK_EDGE_GAP

static func patch(junction: Dictionary, asphalt: bool = false) -> PackedVector2Array:
 var cache_key := "asphalt" if asphalt else "footprint"
 if junction.has(cache_key):return junction[cache_key]
 # Union of road-width strips, preserving square block corners. A convex hull
 # would fill the diagonal wedges outside the roads and consume valid parcels.
 var result := PackedVector2Array()
 for arm in junction.arms:
  var direction: Vector2=arm.direction
  var normal := Vector2(-direction.y,direction.x)
  var factor: float=Profile.asphalt_width(arm)/arm.width if asphalt else 1.0
  var distance: float=junction.radius+(.02 if asphalt else 0)
  var side: Vector2=normal*arm.width/2*factor
  var start: Vector2=junction.position-direction*EPS*2
  var finish: Vector2=junction.position+direction*distance
  var strip := PackedVector2Array([start-side,finish-side,finish+side,start+side])
  if result.is_empty():result=strip
  else:
   var merged := Geometry2D.merge_polygons(result,strip)
   if not merged.is_empty():result=merged[0]
 return result
