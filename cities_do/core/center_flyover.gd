extends RefCounted
## E4c authored three-road cross section. Horizontal distances are in city cells.
const Height=preload("res://core/road_height.gd")
const Paths=preload("res://core/road_junctions.gd")
const Construction=preload("res://core/road_construction.gd")
const Profile=preload("res://core/road_profile.gd")
const Portals=preload("res://core/center_flyover_portals.gd")
const SPLIT_CELLS:=4.0
const LEVEL_M:=10.0
const EPS:=.0001

static func failure(reason:String)->Dictionary:
 return {"ok":false,"reason":reason}

## The median is reserved ground space, not a second parallel road layer.
## A full-width, transverse road may cross the reserved ground at +10m.
static func ground_error(deck:Dictionary,road:Dictionary)->String:
 if not Profile.is_center_deck(deck) or Height.off_ground(road):return ""
 if Construction.intersections(deck,road).is_empty():return ""
 for hit in Construction.contact_hits(deck,road):
  var crossing:Vector2=Paths.sample(deck.points,hit.a)
  if Height.height_at(deck,crossing)<LEVEL_M-EPS:continue
  var before:=Paths.sample(deck.points,maxf(0,hit.a-.01))
  var after:=Paths.sample(deck.points,hit.a+.01)
  var axis:Vector2=(after-before).normalized()
  var distance:float=deck.width/2.0
  var left:=false;var right:=false
  for point in road.points:
   var lateral:float=axis.cross(point-crossing)
   left=left or lateral<=-distance+EPS
   right=right or lateral>=distance-EPS
  if left and right and Construction.overlap_allowed(deck,road):return ""
 return "중앙 분리대와 겹칩니다"

## Distances from each longitudinal seam to the nearest already built station.
## Pass only matching, opposite-facing centre deck endpoints to the E1 solver;
## a crossing, side branch or unrelated elevated road is not a continuation.
static func support_neighbors(roads:Array,deck:Dictionary,count:int)->Vector2:
 var result:=Vector2(INF,INF)
 for end:int in [0,1]:
  var at:=0 if end==0 else -1
  var point:Vector2=deck.points[at]
  if absf(Height.height_at(deck,point)-LEVEL_M)>EPS:continue
  var inward:Vector2=(deck.points[1 if end==0 else -2]-point).normalized()
  for other:Dictionary in roads:
   if not Profile.is_center_deck(other) or other.get("center_lanes",0)!=count or other.points.size()<2:continue
   for other_end:int in [0,1]:
    var other_at:=0 if other_end==0 else -1
    if other.points[other_at].distance_to(point)>EPS or absf(Height.height_at(other,point)-LEVEL_M)>EPS:continue
    var away:Vector2=(other.points[1 if other_end==0 else -2]-point).normalized()
    if inward.dot(away)>-.99999 or absf(inward.cross(away))>EPS:continue
    var length:float=Height.length_cells(other.points)
    for station:Dictionary in other.get("piers",[]):
     var distance:float=station.distance if other_end==0 else length-station.distance
     result[end]=minf(result[end],maxf(0.0,distance))
 return result

static func plan(city,points:PackedVector2Array,levels:PackedFloat64Array,count:int,major_side:int,grid_frame:Dictionary)->Dictionary:
 var section:Dictionary=Profile.CENTER_SECTIONS.get(count,{})
 if section.is_empty() or points.size()<2 or points.size()!=levels.size() or major_side not in [-1,1]:return failure("도로 높이 경로가 필요합니다")
 var distances:=PackedFloat64Array([0.0])
 for i in range(points.size()):
  if not points[i].is_finite() or not points[i].is_equal_approx(points[i].clamp(Vector2.ZERO,Vector2(city.width,city.height))):return failure("지도 경계 밖입니다")
  if levels[i] not in [0.0,LEVEL_M]:return failure("지원하지 않는 도로 높이입니다")
  if i==0:continue
  var length:=points[i-1].distance_to(points[i])
  if length<EPS:return failure("도로가 너무 짧습니다")
  distances.append(distances[-1]+length)
 var stations:=distances.duplicate()
 var runs:Array[Vector4]=[] # ramp start/end chainage, then start/end elevation
 var minimum:=Height.minimum_ramp_m(LEVEL_M,"local")/4.0
 # Interior geometry samples at one of the two elevations do not restart a
 # ramp. A change of target creates a new run only when the direction changes.
 var first:=0
 while first<levels.size()-1:
  var last:=first+1
  while last<levels.size()-1 and levels[last]==levels[first]:last+=1
  if levels[last]==levels[first]:break
  var stop:=last
  while stop+1<levels.size() and levels[stop+1]==levels[last]:stop+=1
  var rising:=levels[first]==0.0
  var start:=distances[first]+SPLIT_CELLS if rising else maxf(distances[first],distances[stop]-SPLIT_CELLS-minimum)
  var end:=start+minimum
  if end>distances[stop]-(0.0 if rising else SPLIT_CELLS)+EPS:return failure("경사로 길이가 부족합니다")
  stations.append(start);stations.append((start+end)*.5);stations.append(end)
  if not rising and distances[stop]>end+SPLIT_CELLS+EPS:return failure("합류점 뒤는 일반 도로로 이어 그립니다")
  runs.append(Vector4(start,end,levels[first],levels[last]))
  first=stop
 # A surface split/merge lives only at the actual outside endpoints.
 if runs.size()>2 or (runs.size()==2 and (levels[0]!=0.0 or levels[-1]!=0.0)):return failure("고가 구간을 나눠 그립니다")
 stations.sort()
 var spine:=PackedVector2Array();var heights:=PackedFloat64Array();var previous:=-INF
 for d:float in stations:
  if d-previous<EPS:continue
  spine.append(Paths.sample(points,d));previous=d
  var level:=levels[0]
  for ramp in runs:
   if d<ramp.x:break
   level=lerpf(ramp.z,ramp.w,clampf((d-ramp.x)/(ramp.y-ramp.x),0,1))
  heights.append(level)
 var family:int=city.next_road_id
 var deck:Dictionary={"points":spine,"heights_m":heights,"kind":"local","lanes":section.deck_lanes,"width":section.deck_width,"road_variant":"center-flyover-deck","major_side":major_side}
 var members:Array[Dictionary]=[deck]
 var branch:Dictionary=Profile.BRANCH_PROFILES[section.branch_variant]
 var boundary:=float(section.offset)+float(branch.width)/2.0
 for side in [-1,1]:
  var edge:=Profile.offset_path(spine,side*boundary)
  for j in range(1,edge.size()):
   if (edge[j]-edge[j-1]).dot(spine[j]-spine[j-1])<=0.0:return failure("도로가 스스로 겹칩니다")
 for side:int in [1,-1]:
  var offset:=Profile.offset_path(spine,side*float(section.offset))
  if side<0:offset.reverse()
  members.append({"points":offset,"kind":"local","lanes":branch.lanes,"width":branch.width,"travel_dir":1,"road_variant":section.branch_variant})
 for i in range(members.size()):
  var member:=members[i]
  member.center_family=family
  member.center_role=i
  member.center_lanes=count
  var basis:=spine.duplicate()
  if i==2:basis.reverse()
  member.center_ribbon={"axis":member.points,"basis":basis,"offset":0.0 if i==0 else float(section.offset)}
  member.flat_start=true;member.flat_end=true
  if not grid_frame.is_empty():member.grid_frame=grid_frame.duplicate(true)
  if i>0:
   member.heights_m=PackedFloat64Array();member.heights_m.resize(member.points.size())
  Portals.author(member,spine,heights,count,i,int(section.deck_lanes)/2)
  var error:=Height.validate(member,Vector2(city.width,city.height))
  if error!="":return failure(error)
  if not Construction.self_clear(member):return failure("도로가 스스로 겹칩니다")
  if city._hits_existing_support(member):return failure("교각과 겹침")
  var layers:Dictionary=city._road_layer_context(member)
  if not layers.ok:return layers
  var built:=Construction.plan(layers.roads,member)
  if not built.ok:return built
  if built.new_roads.size()!=1 or built.new_roads[0].points!=member.points:return failure("기존 도로와 겹칩니다")
  for route:Dictionary in city.transit_routes:
   if route.kind!="rail":continue
   error=preload("res://core/transit_routes.gd").road_rail_error(route,member)
   if error!="":return failure(error)
 var topology:=Paths.analyze(city.roads+members)
 if not topology.errors.is_empty():return failure(topology.errors[0])
 if not Construction.spacing_ok(topology,city.roads.size(),city.roads.size()+3):return failure("교차로 사이 간격은 14m 이상이어야 합니다")
 var supports:=Height.supports(city,deck,support_neighbors(city.roads,deck,count))
 if not supports.ok:return supports
 deck.piers=supports.piers
 return {"ok":true,"reason":"","new_roads":members,"piers":supports.piers}
