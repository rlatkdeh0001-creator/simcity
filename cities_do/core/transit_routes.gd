extends RefCounted
## P1 physical routes, NOT operating passenger lines. Coordinates are city cells (4m).
## No road/parcel IDs, frontage, municipal prices, vehicle routing or asset dependency.
const Paths=preload("res://core/road_junctions.gd")
const Units=preload("res://core/road_length_units.gd")
const Region=preload("res://core/regional_exchange.gd")
const METRES_PER_CELL:=4.0
const EPS:=0.0005
static func profile(kind:String)->Dictionary:
 if kind=="rail":return {"kind":kind,"width":7.6/4.0,"track_offsets_m":PackedFloat64Array([-2.0,2.0]),"rail_top_z_m":0.0,"min_center_radius_m":34.0}
 if kind=="metro":return {"kind":kind,"width":12.0/4.0,"track_offsets_m":PackedFloat64Array([-4.15,4.15]),"rail_top_z_m":-12.7,"min_center_radius_m":0.0}
 return {}
static func index_of(routes:Array,id:int)->int:
 for i in range(routes.size()):
  if int(routes[i].id)==id:return i
 return -1
## P2 seam only: caller loads the approved v2 spec and supplies actual lot placement.
## Does not place a station, exempt its whole footprint, or install its internal track.
## Blender +X follows side, -Y follows front; values in spec are metres, world is cells.
static func station_ports(spec:Dictionary,center:Vector2,front:Vector2)->Dictionary:
 var invalid:=failure("invalid_station_spec","기차역 v2 접속 규격이 필요합니다")
 if not spec.get("version") is String or not (spec.get("track_count") is int or spec.get("track_count") is float) or not spec.get("track_included") is bool:return invalid
 if spec.version!="v2" or spec.track_count!=2 or spec.track_included:return invalid
 if not center.is_finite() or not front.is_finite() or front.length()<EPS:return invalid
 for key:String in ["trackway_width_m","track_midline_blender_y_m","platform_length_m","max_consist_length_m"]:
  if not spec.get(key) is float and not spec.get(key) is int:return invalid
  if not is_finite(float(spec[key])):return invalid
 if spec.trackway_width_m<=0 or spec.platform_length_m<=0 or spec.max_consist_length_m<=0:return invalid
 var ends:Variant=spec.get("track_end_points_blender")
 var centres:Variant=spec.get("track_centres_blender_y_m")
 if not ends is Array or ends.size()!=2 or not centres is Array or centres.size()!=2:return invalid
 for point:Variant in ends:
  if not point is Array or point.size()!=3:return invalid
  for coordinate:Variant in point:
   if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)):return invalid
  if absf(float(point[1])-float(spec.track_midline_blender_y_m))>EPS:return invalid
 for value:Variant in centres:
  if not (value is float or value is int) or not is_finite(float(value)):return invalid
 if float(ends[0][0])>=float(ends[1][0]) or absf(float(ends[0][2])-float(ends[1][2]))>EPS:return invalid
 if float(centres[0])>=float(centres[1]):return invalid
 var offsets:=PackedFloat64Array([float(centres[0])-float(spec.track_midline_blender_y_m),float(centres[1])-float(spec.track_midline_blender_y_m)])
 if absf(offsets[0]+offsets[1])>EPS or maxf(absf(offsets[0]),absf(offsets[1]))>=float(spec.trackway_width_m)/2:return invalid
 front=front.normalized()
 var side:=Vector2(front.y,-front.x)
 var points:=PackedVector2Array();var ports:Array[Dictionary]=[]
 for i in range(2):
  var point:Vector2=center+(side*float(ends[i][0])-front*float(ends[i][1]))/METRES_PER_CELL
  points.append(point)
  ports.append({"kind":"rail","point":point,"outward":side*(-1 if i==0 else 1),"rail_top_z_m":float(ends[i][2])})
 return {"ok":true,"points":points,"ports":ports,"width_m":float(spec.trackway_width_m),"track_offsets_m":offsets,"platform_length_m":float(spec.platform_length_m),"max_consist_length_m":float(spec.max_consist_length_m)}

## Validate detached transport before changing any worker state.
static func snapshot_error(rows:Variant,width:int,height:int)->String:
 if not rows is Array:return "transit routes must be an array"
 var seen:Dictionary={}
 for row:Variant in rows:
  if not row is Dictionary:return "invalid transit record"
  if not row.get("id") is int or row.id<1 or seen.has(row.id):return "invalid/duplicate transit ID"
  seen[row.id]=true
  if not row.get("kind") is String:return "invalid transit kind"
  var expected:=profile(row.kind)
  if expected.is_empty():return "invalid transit kind"
  if not row.get("points") is PackedVector2Array:return "invalid transit points"
  if not Region.path_error(row.points,width,height).is_empty() or not curve_error(row.points,float(expected.min_center_radius_m)).is_empty():return "invalid transit geometry"
  for key:String in ["width","rail_top_z_m","min_center_radius_m"]:
   if not (row.get(key) is float or row.get(key) is int):return "invalid transit profile"
   if not is_finite(float(row[key])) or not is_equal_approx(float(row[key]),float(expected[key])):return "invalid transit profile"
  if not row.get("track_offsets_m") is PackedFloat64Array or row.track_offsets_m!=expected.track_offsets_m:return "invalid transit track offsets"
 return ""

static func is_external(points:PackedVector2Array,width:int,height:int)->bool:
 if points.size()<2:return false
 return not Region.endpoint_edge(points[0],points[1],width,height).is_empty() or not Region.endpoint_edge(points[-1],points[-2],width,height).is_empty()

static func failure(code:String,reason:String)->Dictionary:return {"ok":false,"code":code,"reason":reason}
static func plan(city,points:PackedVector2Array,kind:String,ignore_id:int=-1)->Dictionary:
 var route:=profile(kind)
 if route.is_empty():return failure("invalid_kind","철도 또는 지하철 경로가 필요합니다")
 var error:=Region.path_error(points,city.width,city.height)
 if not error.is_empty():return failure("invalid_path",error)
 error=curve_error(points,float(route.min_center_radius_m))
 if not error.is_empty():return failure("curve",error)
 route.points=points.duplicate()
 var occupied:Array=[]
 for building:Dictionary in city.buildings:occupied.append(city.footprint(building))
 for lot:Dictionary in city.public_facilities.lots:
  if kind=="rail" and lot.get("internal_kind","")=="rail" and lot.has("internal_points"):
   var corridor:=profile("rail");corridor.points=lot.internal_points
   var pieces:Array[PackedVector2Array]=[lot.polygon]
   for strip:PackedVector2Array in ribbons(corridor):
    var remaining:Array[PackedVector2Array]=[]
    for piece:PackedVector2Array in pieces:remaining.append_array(Geometry2D.clip_polygons(piece,strip))
    pieces=remaining
   occupied.append_array(pieces)
  else:occupied.append(lot.polygon)
 for facility:Dictionary in city.power.plants+city.water.facilities:occupied.append(city.power_plant_footprint(facility))
 for polygon:PackedVector2Array in occupied:
  if city._polygon_road_distance(polygon,route)<-EPS:return failure("occupied","건물 또는 시설과 충돌합니다")
 if kind=="rail":
  for road:Dictionary in city.roads:
   if not crossing_allowed(route,road):return failure("road_overlap","도로를 가로지르는 건널목만 허용합니다")
 for existing:Dictionary in city.transit_routes:
  if int(existing.id)==ignore_id or existing.kind!=kind:continue
  if existing.points==points:return failure("duplicate_route","이미 설치된 경로입니다")
  if collinear_overlap(points,existing.points):return failure("duplicate_route","이미 설치된 선로 구간과 겹칩니다")
  error=joint_error(points,existing.points,float(route.min_center_radius_m))
  if not error.is_empty():return failure("curve",error)
 return {"ok":true,"route":route,"points":points.duplicate(),"reason":""}

static func station_contact_only(route:Dictionary,polygon:PackedVector2Array,ports:PackedVector2Array)->bool:
 if route.kind!="rail" or ports.size()!=2:return false
 var contact:=false
 for end:Vector2 in [route.points[0],route.points[-1]]:
  for port:Vector2 in ports:
   if end.distance_to(port)<EPS:contact=true
 if not contact:return false
 for strip:PackedVector2Array in ribbons(route):
  for overlap:PackedVector2Array in Geometry2D.intersect_polygons(strip,polygon):
   if not Geometry2D.triangulate_polygon(overlap).is_empty():return false
 return true

static func collinear_overlap(first:PackedVector2Array,second:PackedVector2Array)->bool:
 for i in range(1,first.size()):
  var a:=first[i-1];var axis:=(first[i]-a).normalized();var length:=a.distance_to(first[i])
  for j in range(1,second.size()):
   var c:=second[j-1];var d:=second[j]
   if absf(axis.cross((d-c).normalized()))>0.00001 or absf(axis.cross(c-a))>EPS:continue
   var low:=minf((c-a).dot(axis),(d-a).dot(axis));var high:=maxf((c-a).dot(axis),(d-a).dot(axis))
   if minf(length,high)-maxf(0,low)>EPS:return true
 return false

static func joint_error(first:PackedVector2Array,second:PackedVector2Array,minimum_m:float)->String:
 # Either route may supply the endpoint, regardless of construction/update order.
 var error:=endpoint_joint_error(first,second,minimum_m)
 if not error.is_empty():return error
 return endpoint_joint_error(second,first,minimum_m)

static func endpoint_joint_error(first:PackedVector2Array,second:PackedVector2Array,minimum_m:float)->String:
 for i:int in [0,first.size()-1]:
  for j:int in [0,second.size()-1]:
   if first[i].distance_to(second[j])>EPS:continue
   var before:=second[1 if j==0 else j-1]
   var after:=first[1 if i==0 else i-1]
   var error:=curve_error(PackedVector2Array([before,first[i],after]),minimum_m)
   if not error.is_empty():return error
  for j in range(1,second.size()-1):
   if first[i].distance_to(second[j])>EPS:continue
   var after:=first[1 if i==0 else i-1]
   var from_a:=curve_error(PackedVector2Array([second[j-1],first[i],after]),minimum_m)
   var from_b:=curve_error(PackedVector2Array([second[j+1],first[i],after]),minimum_m)
   if not from_a.is_empty() and not from_b.is_empty():return from_a
  for j in range(1,second.size()):
   var a:=second[j-1];var b:=second[j]
   if first[i].distance_to(a)<EPS or first[i].distance_to(b)<EPS:continue
   if Geometry2D.get_closest_point_to_segment(first[i],a,b).distance_to(first[i])>EPS:continue
   var after:=first[1 if i==0 else i-1]
   # A branch may join either running direction, but never make a sharp T-turn.
   var from_a:=curve_error(PackedVector2Array([a,first[i],after]),minimum_m)
   var from_b:=curve_error(PackedVector2Array([b,first[i],after]),minimum_m)
   if not from_a.is_empty() and not from_b.is_empty():return from_a
 return ""

static func curve_error(points:PackedVector2Array,minimum_m:float)->String:
 for i in range(1,points.size()):
  if points[i].distance_to(points[i-1])<EPS:return "중복 경로 점은 사용할 수 없습니다"
 for i in range(1,points.size()-1):
  var a:=points[i]-points[i-1];var b:=points[i+1]-points[i]
  var angle:=absf(a.angle_to(b))
  # The polyline is a sampled smooth curve, not a corner to be rounded by rendering.
  # At most 15 degrees per sample; resolve() samples at <=2m, much finer than this.
  if angle>PI/12+EPS:return "급격한 모서리 대신 부드러운 곡선을 그려 주세요"
  var twice_area:=absf(a.cross(b))
  if twice_area>0.0000001:
   var radius_m:=a.length()*b.length()*(a+b).length()/(2*twice_area)*METRES_PER_CELL
   if radius_m+0.02<minimum_m:return "철도 중심선 곡선 반경은 34m 이상이어야 합니다"
 return ""

static func ribbons(route:Dictionary)->Array[PackedVector2Array]:
 return Geometry2D.offset_polyline(route.points,float(route.width)/2,Geometry2D.JOIN_ROUND,Geometry2D.END_BUTT)

static func crossing_allowed(route:Dictionary,road:Dictionary)->bool:
 var crossings:=PackedVector2Array()
 for i in range(1,route.points.size()):
  var a:Vector2=route.points[i-1];var b:Vector2=route.points[i]
  for j in range(1,road.points.size()):
   var c:Vector2=road.points[j-1];var d:Vector2=road.points[j]
   if absf((b-a).normalized().cross((d-c).normalized()))<0.00001:continue
   var hit:Variant=Geometry2D.segment_intersects_segment(a,b,c,d)
   if hit!=null:crossings.append(hit)
 for strip:PackedVector2Array in ribbons(route):
  for pavement:PackedVector2Array in ribbons(road):
   for overlap:PackedVector2Array in Geometry2D.intersect_polygons(strip,pavement):
    var crossed:=false
    for point:Vector2 in crossings:
     if Geometry2D.is_point_in_polygon(point,overlap):crossed=true;break
     for i in range(overlap.size()):
      if Geometry2D.get_closest_point_to_segment(point,overlap[i],overlap[(i+1)%overlap.size()]).distance_to(point)<EPS:crossed=true;break
    if not crossed:return false
 return true

## Snaps ONLY to same-mode transit. Existing points/IDs are never moved or split.
## tangent points outward at a terminal, or follows the host at an interior branch.
static func snap(city,point:Vector2,kind:String,radius:float=1.0)->Dictionary:
 var result:={"point":point,"snapped":false,"tangent":Vector2.ZERO,"route_id":-1}
 if not point.is_finite() or not is_finite(radius) or radius<0:return result
 var best:=radius+EPS
 for route:Dictionary in city.transit_routes:
  if route.kind!=kind:continue
  var points:PackedVector2Array=route.points
  for end:int in [0,points.size()-1]:
   var distance:=point.distance_to(points[end])
   if distance<best:
    best=distance
    result={"point":points[end],"snapped":true,"tangent":(points[end]-points[1 if end==0 else end-1]).normalized(),"route_id":route.id}
 # Prefer a terminal over a nearby mid-segment projection.
 if result.snapped:return result
 for route:Dictionary in city.transit_routes:
  if route.kind!=kind:continue
  for i in range(1,route.points.size()):
   var a:Vector2=route.points[i-1];var b:Vector2=route.points[i]
   var near:=Geometry2D.get_closest_point_to_segment(point,a,b)
   var distance:=point.distance_to(near)
   if distance<best:
    best=distance;result={"point":near,"snapped":true,"tangent":(b-a).normalized(),"route_id":route.id}
 return result

## Pure drawing adapter: feed these exact points to add_transit_route().
## Independent and connected transit strokes use the approved 8m build step.
static func resolve(city,kind:String,mode:String,anchors:PackedVector2Array,cursor:Vector2,start_tangent:Vector2=Vector2.ZERO)->Dictionary:
 if mode not in ["straight","curve","free"] or anchors.is_empty() or (mode=="curve" and anchors.size()!=2):return failure("incomplete","경로 제어점이 필요합니다")
 if not cursor.is_finite() or not start_tangent.is_finite():return failure("invalid_path","유효하지 않은 경로입니다")
 for point:Vector2 in anchors:
  if not point.is_finite():return failure("invalid_path","유효하지 않은 경로입니다")
 var start:=snap(city,anchors[0],kind);var end:=snap(city,cursor,kind)
 var first:Vector2=start.point;var last:Vector2=end.point
 if last.distance_to(first)<EPS and cursor.distance_to(first)>=1.0:last=cursor;end.snapped=false
 var tangent:=start_tangent.normalized()
 if tangent==Vector2.ZERO and start.snapped:tangent=start.tangent
 var points:=PackedVector2Array([first,last])
 if mode=="curve" or (mode=="free" and tangent!=Vector2.ZERO):
  var control:Vector2=anchors[1] if mode=="curve" else first+tangent*first.distance_to(last)/2
  var steps:=maxi(8,ceili((first.distance_to(control)+control.distance_to(last))*2))
  points.clear()
  for i in range(steps+1):
   var t:=float(i)/steps;var u:=1-t
   points.append(first*u*u+control*2*u*t+last*t*t)
 var hosts:Array=[]
 for route:Dictionary in city.transit_routes:
  if route.kind==kind:hosts.append(route)
 var fit:=Units.fit(points,hosts,Units.BUILD)
 if not fit.ok:return fit
 var result:=plan(city,fit.points,kind)
 result.points=fit.points
 return result
