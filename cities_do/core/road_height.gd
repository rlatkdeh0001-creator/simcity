extends RefCounted
## E1/E2 height geometry. Units: horizontal city cells (4m), vertical metres.
const EPS := .0001
## E2 portal: road surface = -(4.5m clearance + 1.0m cover slab + 0.5m portal beam).
const PORTAL_CLEARANCE_M := 4.5
const COVER_SLAB_M := 1.0
const PORTAL_BEAM_M := 0.5
const PORTAL_M := -(PORTAL_CLEARANCE_M+COVER_SLAB_M+PORTAL_BEAM_M)
## E3b rail portal: rail top = -(5.5m clearance + 1.0m cover slab + 0.5m portal beam) = -7.0m.
const RAIL_PORTAL_CLEARANCE_M := 5.5
const RAIL_PORTAL_M := -(RAIL_PORTAL_CLEARANCE_M+COVER_SLAB_M+PORTAL_BEAM_M)
static var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://core/elevated_road_config.json"))
static func height_at(road:Dictionary,point:Vector2)->float:
 var points:PackedVector2Array=road.points
 var heights:PackedFloat64Array=road.get("heights_m",PackedFloat64Array())
 if heights.size()!=points.size():return 0.0
 var best:=INF;var result:=0.0
 for i in range(1,points.size()):
  var axis:=points[i]-points[i-1]
  var t:=clampf((point-points[i-1]).dot(axis)/maxf(EPS,axis.length_squared()),0,1)
  var distance:=point.distance_squared_to(points[i-1]+axis*t)
  if distance<best:best=distance;result=lerpf(heights[i-1],heights[i],t)
 return result
static func raised(road:Dictionary)->bool:
 for value in road.get("heights_m",[]):
  if value>EPS:return true
 return false
static func sunken(road:Dictionary)->bool:
 for value in road.get("heights_m",[]):
  if value< -EPS:return true
 return false
static func off_ground(road:Dictionary)->bool:return raised(road) or sunken(road)
static func level(road:Dictionary)->int:return 1 if raised(road) else (-1 if sunken(road) else 0)
## The portal line and everything deeper is covered; the open trench is above it.
static func covered_at(height:float,portal:float=PORTAL_M)->bool:return height<=portal+EPS
## Rail structures (E3b) open into a 5.5m portal; roads keep the 4.5m one.
static func portal_for(road:Dictionary)->float:return RAIL_PORTAL_M if road.has("rail_route_id") or road.get("kind","")=="rail" else PORTAL_M
## Sub-paths whose interpolated height lies in [low, high], cut exactly where a
## ramp crosses a bound. Each piece keeps per-point heights.
static func pieces_between(road:Dictionary,low:float,high:float)->Array:
 var points:PackedVector2Array=road.points
 var heights:PackedFloat64Array=road.get("heights_m",PackedFloat64Array())
 if heights.size()!=points.size():
  heights=PackedFloat64Array();heights.resize(points.size());heights.fill(0.0)
 var result:Array=[]
 var current:={"points":PackedVector2Array(),"heights_m":PackedFloat64Array()}
 for i in range(1,points.size()):
  var a:=heights[i-1];var b:=heights[i]
  var t0:=0.0;var t1:=1.0
  if absf(b-a)<=EPS:
   if a<low-EPS or a>high+EPS:t0=1.0;t1=0.0
  else:
   var tl:=(low-a)/(b-a);var th:=(high-a)/(b-a)
   t0=maxf(0.0,minf(tl,th));t1=minf(1.0,maxf(tl,th))
  var span:=points[i-1].distance_to(points[i])
  if (t1-t0)*span<=EPS:
   _close_piece(result,current);continue
  if t0>EPS or current.points.is_empty():
   _close_piece(result,current)
   current.points.append(points[i-1].lerp(points[i],t0));current.heights_m.append(lerpf(a,b,t0))
  current.points.append(points[i-1].lerp(points[i],t1));current.heights_m.append(lerpf(a,b,t1))
  if t1<1.0-EPS:_close_piece(result,current)
 _close_piece(result,current)
 return result
static func _close_piece(result:Array,current:Dictionary):
 if current.points.size()>=2 and length_cells(current.points)>EPS:result.append({"points":current.points.duplicate(),"heights_m":current.heights_m.duplicate()})
 current.points=PackedVector2Array();current.heights_m=PackedFloat64Array()
static func covered_pieces(road:Dictionary,portal:float=NAN)->Array:return pieces_between(road,-INF,portal_for(road) if is_nan(portal) else portal) if sunken(road) else []
static func open_pieces(road:Dictionary)->Array:
 if not sunken(road):return [{"points":road.points,"heights_m":road.get("heights_m",PackedFloat64Array())}]
 return pieces_between(road,portal_for(road),INF)
## Ground-rule footprint: the whole ribbon, except covered underground parts.
static func surface_ribbons(road:Dictionary)->Array[PackedVector2Array]:
 var geometry=preload("res://core/road_geometry.gd")
 var result:Array[PackedVector2Array]=[]
 for piece:Dictionary in open_pieces(road):
  for ribbon:PackedVector2Array in geometry.ribbons(piece.points,float(road.width),true,true):result.append(ribbon)
 return result
## Reversible placeholder relation only (config depth_cost is disabled and unpriced).
static func depth_cost_factor(road:Dictionary)->float:
 var settings:Dictionary=config.get("depth_cost",{})
 var reference:float=maxf(EPS,float(settings.get("reference_depth_m",10.0)))
 var exponent:float=float(settings.get("exponent",2.0))
 var heights:PackedFloat64Array=road.get("heights_m",PackedFloat64Array())
 if heights.size()!=road.points.size():return 1.0
 var total:=0.0;var weighted:=0.0
 for i in range(1,heights.size()):
  var length:float=road.points[i-1].distance_to(road.points[i])
  var depth:=maxf(0.0,-(heights[i-1]+heights[i])/2)
  weighted+=length*(1.0+pow(depth/reference,exponent));total+=length
 return weighted/total if total>EPS else 1.0
static func usable_under_deck(road:Dictionary,polygon:PackedVector2Array)->bool:
 # Parks may use open space, never the earth-filled part below the +5m abutment.
 var points:PackedVector2Array=road.points
 var heights:PackedFloat64Array=road.get("heights_m",PackedFloat64Array())
 var parcels=preload("res://core/road_parcels.gd")
 if heights.size()!=points.size() or not raised(road):
  # Covered underground parts never block parks; open trench parts do.
  for ribbon in surface_ribbons(road):
   if parcels.overlap(ribbon,polygon):return false
  return true
 var profile=preload("res://core/road_profile.gd")
 var left:PackedVector2Array=profile.offset_path(points,float(road.width)/2)
 var right:PackedVector2Array=profile.offset_path(points,-float(road.width)/2)
 # Clip each deck cross-section at the exact interpolated threshold before intersecting.
 # Checking only vertices of the full-ribbon intersection misses interior height minima.
 for i in range(1,points.size()):
  var a:=heights[i-1];var b:=heights[i]
  if minf(a,b)>=5:continue
  var first:=0.0 if a<5 else (5-a)/(b-a)
  var last:=1.0 if b<5 else (5-a)/(b-a)
  var l0:=left[i-1];var l1:=left[i];var r0:=right[i-1];var r1:=right[i]
  # A threshold inside a segment uses the segment's perpendicular cross-section.
  var normal:Vector2=(points[i]-points[i-1]).normalized().orthogonal()*float(road.width)/2
  if a>5:
   var boundary:=points[i-1].lerp(points[i],first)
   l0=boundary+normal;r0=boundary-normal
  if b>5:
   var boundary:=points[i-1].lerp(points[i],last)
   l1=boundary+normal;r1=boundary-normal
  if parcels.overlap(PackedVector2Array([l0,l1,r1,r0]),polygon):return false
 return true
## E3a: rail ramps use the approved 3.5% limit (10m -> 288m, 5m -> 144m).
static func grade_for(kind:String)->float:return 0.05 if kind=="highway" else (0.035 if kind=="rail" else 0.08)
static func minimum_ramp_m(rise:float,kind:String)->float:
 return ceilf(absf(rise)/grade_for(kind)/8.0-EPS)*8.0
## Reversible placeholder relation only (config rail_height_cost / rail_depth_cost are disabled and unpriced).
static func height_cost_factor(road:Dictionary)->float:
 var settings:Dictionary=config.get("rail_height_cost",{})
 # E3b: a tunnel uses its own disabled rail_depth_cost placeholder (never mixed with a viaduct).
 var deep:=sunken(road)
 if deep:settings=config.get("rail_depth_cost",settings)
 var reference:float=maxf(EPS,float(settings.get("reference_depth_m" if deep else "reference_height_m",10.0)))
 var exponent:float=float(settings.get("exponent",2.0))
 var heights:PackedFloat64Array=road.get("heights_m",PackedFloat64Array())
 if heights.size()!=road.points.size():return 1.0
 var total:=0.0;var weighted:=0.0
 for i in range(1,heights.size()):
  var length:float=road.points[i-1].distance_to(road.points[i])
  var lift:=maxf(0.0,(-1.0 if deep else 1.0)*(heights[i-1]+heights[i])/2)
  weighted+=length*(1.0+pow(lift/reference,exponent));total+=length
 return weighted/total if total>EPS else 1.0
static func same_level_contact(a:Dictionary,b:Dictionary)->bool:
 var plane:=height_at(a,a.points[0]);var flat:=true
 for road:Dictionary in [a,b]:
  for point:Vector2 in road.points:
   if absf(height_at(road,point)-plane)>EPS:flat=false;break
 if flat:return true # Keep all existing 2D surface/curb/box guards on one plane.
 for i in range(1,a.points.size()):
  for j in range(1,b.points.size()):
   var hits:Array=[]
   var hit:Variant=Geometry2D.segment_intersects_segment(a.points[i-1],a.points[i],b.points[j-1],b.points[j])
   if hit!=null:hits.append(hit)
   for point:Vector2 in [a.points[i-1],a.points[i]]:
    if point.distance_to(Geometry2D.get_closest_point_to_segment(point,b.points[j-1],b.points[j]))<EPS:hits.append(point)
   for point:Vector2 in [b.points[j-1],b.points[j]]:
    if point.distance_to(Geometry2D.get_closest_point_to_segment(point,a.points[i-1],a.points[i]))<EPS:hits.append(point)
   for point:Vector2 in hits:
    if absf(height_at(a,point)-height_at(b,point))<EPS:return true
 return false
static func validate(road:Dictionary,bounds:Vector2)->String:
 if road.kind not in ["local","highway"] or road.lanes not in ([2,3,4,5,6,7,8] if road.kind=="local" else [2,4]) or road.major_side not in [-1,1]:return "도로 경로가 필요합니다"
 if raised(road) and sunken(road):return "고가와 지하는 지상에서 나눠 그립니다"
 return profile_error(road.points,road.heights_m,road.kind,bounds)
## Whole-run grade check shared by roads and rail: a run is every consecutive
## piece rising (or falling) the same way, never only its last piece.
static func profile_error(points:PackedVector2Array,heights:PackedFloat64Array,kind:String,bounds:Vector2=Vector2(INF,INF))->String:
 var grade:=grade_for(kind)
 var run_length:=0.0;var run_rise:=0.0;var previous_sign:=0.0
 for i in range(points.size()):
  if not points[i].is_finite() or points[i].x<0 or points[i].y<0 or points[i].x>bounds.x or points[i].y>bounds.y:return "지도 경계 밖입니다"
  if i==0:continue
  var length:=points[i].distance_to(points[i-1])*4
  if length<EPS:return "도로가 너무 짧습니다"
  var rise:=absf(heights[i]-heights[i-1])
  var sign_value:=signf(heights[i]-heights[i-1])
  if sign_value!=previous_sign:
   if run_length+EPS<minimum_ramp_m(run_rise,kind):return "경사로 길이가 부족합니다"
   run_length=0;run_rise=0
  if sign_value!=0:run_length+=length;run_rise+=rise
  previous_sign=sign_value
  if rise<=EPS and absf(heights[i]/5-roundf(heights[i]/5))>EPS:return "높이는 5m 단위입니다"
  if rise/length>grade+EPS:return "경사가 너무 급합니다"
 if run_length+EPS<minimum_ramp_m(run_rise,kind):return "경사로 길이가 부족합니다"
 return ""
static func segment(road:Dictionary,index:int)->Dictionary:
 return {"points":PackedVector2Array([road.points[index-1],road.points[index]]),"heights_m":PackedFloat64Array([height_at(road,road.points[index-1]),height_at(road,road.points[index])]),"width":road.width}
static func overlap_error(a:Dictionary,b:Dictionary,same_level_ok:bool=true)->String:
 # Linear height fields reach their extrema at vertices of each full-width overlap.
 # Segment rectangles preserve the complete ribbon width, not centreline-only clearance.
 for i in range(1,a.points.size()):
  var first:=segment(a,i)
  for j in range(1,b.points.size()):
   var second:=segment(b,j)
   for pa in Geometry2D.offset_polyline(first.points,float(a.width)/2,Geometry2D.JOIN_MITER,Geometry2D.END_BUTT):
    for pb in Geometry2D.offset_polyline(second.points,float(b.width)/2,Geometry2D.JOIN_MITER,Geometry2D.END_BUTT):
     for overlap in Geometry2D.intersect_polygons(pa,pb):
      var low:=INF;var high:=-INF
      for point:Vector2 in overlap:
       var delta:=height_at(first,point)-height_at(second,point)
       low=minf(low,delta);high=maxf(high,delta)
      if same_level_ok and absf(low)<=EPS and absf(high)<=EPS:continue # Same-level topology handles ordinary junctions.
      if low<10-EPS and high>-10+EPS:return "수직 간격 부족"
 return ""
static func length_cells(points:PackedVector2Array)->float:
 var result:=0.0
 for i in range(1,points.size()):result+=points[i-1].distance_to(points[i])
 return result
static func point_at(points:PackedVector2Array,distance:float)->Vector2:
 for i in range(1,points.size()):
  var length:=points[i-1].distance_to(points[i])
  if length>EPS and distance<=length:return points[i-1].lerp(points[i],clampf(distance/length,0,1))
  distance-=length
 return points[-1]
static func support_positions(road:Dictionary,distance:float)->Array[Vector2]:
 var point:=point_at(road.points,distance)
 var direction:Vector2=(point_at(road.points,minf(length_cells(road.points),distance+.01))-point_at(road.points,maxf(0,distance-.01))).normalized()
 var half_offset:float=float(road.width)/4
 if float(road.width)*4>=14:return [point+direction.orthogonal()*half_offset,point-direction.orthogonal()*half_offset]
 return [point]
static func support_clear(city,road:Dictionary,distance:float)->bool:
 var height:=height_at(road,point_at(road.points,distance))
 for point in support_positions(road,distance):
  for other:Dictionary in city.roads:
   if height_at(other,point)>=height-EPS:continue
   for i in range(1,other.points.size()):
    if point.distance_to(Geometry2D.get_closest_point_to_segment(point,other.points[i-1],other.points[i]))<float(other.width)/2+.5:return false
  for route:Dictionary in city.transit_routes:
   if route.kind!="rail" or int(route.id)==int(road.get("rail_route_id",-2)):continue
   for i in range(1,route.points.size()):
    if point.distance_to(Geometry2D.get_closest_point_to_segment(point,route.points[i-1],route.points[i]))<1.75:return false
 return true
static func supports(city,road:Dictionary)->Dictionary:
 var travelled:=0.0
 var heights:PackedFloat64Array=road.get("heights_m",PackedFloat64Array())
 if heights.size()!=road.points.size():return {"ok":true,"piers":[],"reason":""}
 var first_boundary:=INF
 var piers:Array=[]
 for i in range(1,heights.size()):
  var span:float=road.points[i-1].distance_to(road.points[i])
  var a:=heights[i-1];var b:=heights[i]
  if maxf(a,b)>=5:
   if first_boundary==INF:first_boundary=travelled if a>=5 else travelled+span*(5-a)/(b-a)
   if b<5 or i==heights.size()-1:
    var last_boundary:=travelled+span if b>=5 else travelled+span*(5-a)/(b-a)
    var stations:=support_run(city,road,first_boundary,last_boundary)
    if stations.is_empty():return {"ok":false,"piers":[],"reason":"교각을 세울 자리가 없습니다"}
    for d in stations:piers.append({"distance":d,"height_m":height_at(road,point_at(road.points,d)),"positions":support_positions(road,d)})
    first_boundary=INF
  travelled+=span
 return {"ok":true,"piers":piers,"reason":""}
static func support_run(city,road:Dictionary,first_boundary:float,last_boundary:float)->Array[float]:
 var stations:Array[float]=[];var candidates:Array[float]=[]
 # Quarter-cell search resolution is a reversible geometric placement default.
 var step:float=maxf(.01,float(config.support_search_step_m)/4)
 if support_clear(city,road,first_boundary):candidates.append(first_boundary)
 for i in range(floori(first_boundary/step)+1,ceili(last_boundary/step)):
  var d:=float(i)*step
  if support_clear(city,road,d):candidates.append(d)
 if last_boundary>first_boundary and support_clear(city,road,last_boundary):candidates.append(last_boundary)
 if candidates.is_empty():return []
 if candidates[0]-first_boundary>12+EPS or last_boundary-candidates[-1]>12+EPS:
  return []
 var can_reach:Dictionary={candidates[-1]:true};var next_station:Dictionary={}
 for i in range(candidates.size()-2,-1,-1):
  var best:=-1.0;var score:=INF
  for j in range(i+1,candidates.size()):
   var gap:=candidates[j]-candidates[i]
   if gap>12+EPS:break
   if gap<4-EPS or not can_reach.has(candidates[j]):continue
   if absf(gap-8)<score:best=candidates[j];score=absf(gap-8)
  if best>=0:can_reach[candidates[i]]=true;next_station[candidates[i]]=best
 var start:=candidates[0]
 if not can_reach.has(start):
  if candidates[-1]-start>=4:return []
  # A short cluster can emit only one station. Its actual position must
  # satisfy both end spans, not borrow clearance from an unplaced candidate.
  for candidate in candidates:
   if candidate-first_boundary<=12+EPS and last_boundary-candidate<=12+EPS:
    stations.append(candidate)
    break
 else:
  stations.append(start)
  while next_station.has(stations[-1]):stations.append(next_station[stations[-1]])
 return stations
