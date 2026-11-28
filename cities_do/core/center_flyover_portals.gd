extends RefCounted
## Primitive, member-owned split descriptors. Runtime array/lane indices are
## resolved afresh from the surviving records, never written to a checkpoint.
const Profile=preload("res://core/road_profile.gd")
const Height=preload("res://core/road_height.gd")
const EPS:=.0001
const SHIFT_CELLS:=4.0

static func author(member:Dictionary,spine:PackedVector2Array,heights:PackedFloat64Array,count:int,role:int,inner:int)->void:
 var portals:Array[Dictionary]=[]
 for end in [0,1]:
  var at:=0 if end==0 else -1
  if absf(heights[at])>EPS:continue
  var member_end:int=1-end if role==2 else end
  var anchor:=spine[at]
  var inward:Vector2=(spine[1 if end==0 else -2]-anchor).normalized()
  var endpoint:Vector2=member.points[0 if member_end==0 else -1]
  var right:=Vector2(-inward.y,inward.x)*(1 if end==0 else -1)
  var lateral:float=(endpoint-anchor).dot(right)*4.0
  var links:Array[Dictionary]=[]
  for direction in [1,-1] if role==0 else [1]:
   var heading:int=direction if role!=2 else -direction
   for lane in range(Profile.direction_count(member,direction)):
    var trunk_lane:int=lane+(0 if role==0 else inner)
    var target:float=(trunk_lane+.5)*3.5
    var local:float=Profile.lane_center_metres(member,direction,lane)
    links.append({"direction":direction,"index":lane,"trunk_index":trunk_lane,"shift_m":target-heading*lateral-local})
  portals.append({"version":1,"end":member_end,"point":endpoint,"source":0.0 if member_end==0 else Height.length_cells(member.points),"anchor":anchor,"inward":inward,"lanes":count,"links":links})
 member.center_portals=portals

static func active(road:Dictionary)->Array[Dictionary]:
 var result:Array[Dictionary]=[]
 var portals:Variant=road.get("center_portals")
 if not portals is Array or not road.get("center_family") is int or road.points.size()<2:return result
 var role:Variant=road.get("center_role")
 var count:Variant=road.get("center_lanes")
 if not role is int or role not in [0,1,2] or not count is int or not Profile.CENTER_SECTIONS.has(count):return result
 if (role==0 and not Profile.is_center_structure(road)) or (role!=0 and Profile.branch_profile(road).is_empty()):return result
 var start:float=road.get("source_start",0.0)
 var end_distance:=start+Height.length_cells(road.points)
 for value in portals:
  if not value is Dictionary:continue
  var p:Dictionary=value
  if not p.get("version") is int or p.version!=1 or not p.get("end") is int or p.end not in [0,1] or not p.get("point") is Vector2 or not p.get("anchor") is Vector2 or not p.get("inward") is Vector2 or not p.get("source") is float or not p.get("links") is Array or not p.get("lanes") is int or p.lanes!=count:continue
  if not p.point.is_finite() or not p.anchor.is_finite() or not p.inward.is_normalized() or not is_finite(p.source):continue
  var at:int=0 if p.end==0 else -1
  if absf(p.source-(start if p.end==0 else end_distance))>EPS or road.points[at].distance_to(p.point)>EPS or absf(Height.height_at(road,p.point))>EPS:continue
  var interior:Vector2=(road.points[1 if p.end==0 else -2]-p.point).normalized()
  if interior.dot(p.inward)<.95:continue
  var inner:int=Profile.CENTER_SECTIONS[count].deck_lanes/2
  var expected:=0
  var valid:=true
  var seen:Dictionary={}
  for link in p.links:
   if not link is Dictionary or not link.get("direction") is int or link.direction not in [-1,1] or not link.get("index") is int or not link.get("trunk_index") is int or not link.get("shift_m") is float:
    valid=false;break
   var handle:=Vector2i(link.direction,link.index)
   if seen.has(handle) or link.index<0 or link.index>=Profile.direction_count(road,link.direction) or link.trunk_index!=link.index+(0 if role==0 else inner) or not is_finite(link.shift_m) or absf(link.shift_m)>1.01:
    valid=false;break
   seen[handle]=true;expected+=1
  if valid and expected==int(road.lanes):result.append(p)
 return result

## Returns the matching authored end, or -1. Interior crossings, lookalike
## profiles, reversed flow and mismatched heights do not become trunk links.
static func trunk_end(road:Dictionary,p:Dictionary)->int:
 if road.has("center_family") or road.has("road_variant") or road.get("kind")!="local" or road.get("lanes")!=p.lanes or Profile.travel_direction(road)!=0:return -1
 if road.points.size()<2:return -1
 for end in [0,1]:
  var at:=0 if end==0 else -1
  var endpoint:Vector2=road.points[at]
  if endpoint.distance_to(p.anchor)>EPS or absf(Height.height_at(road,endpoint))>EPS:continue
  var outward:Vector2=(road.points[1 if end==0 else -2]-endpoint).normalized()
  if outward.dot(p.inward)<-.99999 and absf(outward.cross(p.inward))<.0001:return end
 return -1

static func matching_center_contact(a:Dictionary,b:Dictionary)->bool:
 if not Profile.is_center_structure(a):
  if not Profile.is_center_structure(b):return false
  return matching_center_contact(b,a)
 return matching_trunk(a,b)

static func matching_trunk(a:Dictionary,b:Dictionary)->bool:
 for p in active(a):
  if trunk_end(b,p)>=0:return true
 return false

static func is_deck_extension(a:Dictionary,b:Dictionary)->bool:
 # The only extra width transition is a same-lane narrow deck to normal
 # +10m continuation, not another width grade or a ground portal bypass.
 if not Profile.is_center_deck(a):
  if not Profile.is_center_deck(b):return false
  return is_deck_extension(b,a)
 if b.has("center_family") or b.has("road_variant") or b.get("kind")!="local" or a.lanes!=b.lanes or Profile.travel_direction(b)!=0:return false
 for first in [a.points[0],a.points[-1]]:
  if absf(Height.height_at(a,first)-10.0)>EPS:continue
  for second in [b.points[0],b.points[-1]]:
   if first.distance_to(second)<=EPS and absf(Height.height_at(b,second)-10.0)<=EPS:return true
 return false

static func lane_points(road:Dictionary,section:Dictionary,first:float,last:float,direction:int,index:int,offset:float)->PackedVector2Array:
 var portals:=active(road)
 if portals.is_empty():return PackedVector2Array()
 var relevant:Array[Dictionary]=[]
 for p in portals:
  for link in p.links:
   if link.direction==direction and link.index==index and absf(link.shift_m)>EPS:
    relevant.append({"source":p.source-float(road.get("source_start",0.0)),"shift":link.shift_m,"end":p.end})
 if relevant.is_empty():return PackedVector2Array()
 var samples:Array[float]=[first,last]
 var base:float=section.first
 for i in range(1,section.points.size()):
  base+=section.points[i-1].distance_to(section.points[i])
  if base>first+EPS and base<last-EPS:samples.append(base)
 for p in relevant:
  for step in range(1,17): # exact 1m profile stations, not a second editor snap
   var d:float=p.source+float(step)*.25*(1 if p.end==0 else -1)
   if d>first+EPS and d<last-EPS:samples.append(d)
 samples.sort()
 var centers:=PackedVector2Array();var stations:=PackedFloat64Array()
 for d in samples:
  if not stations.is_empty() and absf(d-stations[-1])<EPS:continue
  stations.append(d);centers.append(Height.point_at(road.points,d))
 var miter:=Profile.offset_path(centers,float(direction))
 var result:=PackedVector2Array()
 for i in range(centers.size()):
  var distance:=offset
  for p in relevant:
   distance+=p.shift*(1.0-smoothstep(0.0,SHIFT_CELLS,absf(stations[i]-p.source)))
  result.append(centers[i]*4.0+(miter[i]-centers[i])*distance)
 if direction<0:result.reverse()
 return result
