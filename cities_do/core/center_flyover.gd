extends RefCounted
## Authored three-road cross section. Horizontal distances are in city cells.
const Height=preload("res://core/road_height.gd")
const Paths=preload("res://core/road_junctions.gd")
const Construction=preload("res://core/road_construction.gd")
const Geometry=preload("res://core/road_geometry.gd")
const Profile=preload("res://core/road_profile.gd")
const Portals=preload("res://core/center_flyover_portals.gd")
const SPLIT_CELLS:=4.0
const LEVEL_M:=10.0
const EPS:=.0001

static func failure(reason:String)->Dictionary:
 return {"ok":false,"reason":reason}

## The median is reserved ground space, not a second parallel road layer.
## Only a full-width transverse road may cross the reserved ground, where
## the central profile has the required 10m of clearance in either direction.
static func ground_error(deck:Dictionary,road:Dictionary)->String:
 if not Profile.is_center_structure(deck):return ""
 # The grade of a remote ramp does not exempt the road's actual ground span.
 for span:Dictionary in Height.ground_spans(road):
  var error:=ground_span_error(deck,span)
  if error!="":return error
 return retaining_error(deck,road)

## The retaining fill can obstruct the median even with legal road-surface clearance.
static func retaining_error(deck:Dictionary,road:Dictionary)->String:
 if Height.sunken(deck) and Height.raised(road) and not Profile.is_center_deck(road):
  if adds_fill([],median_fill([road],Construction.outlines(deck))):return "중앙 분리대와 겹칩니다"
 return ""

static func retaining_visuals(visuals:Array)->Dictionary:
 var result:Dictionary={}
 for visual:Dictionary in visuals:
  if not Height.raised(visual) or Profile.is_center_deck(visual):continue
  if not Array(visual.heights_m).any(func(level):return Height.retaining_section(level,level)):continue
  var key:=var_to_bytes([visual.points,visual.heights_m,visual.width])
  result[key]=visual
 return result

## Compare occupied ground inside each reservation, never whole-path identity.
## A remote edit may repartition the wall into different 4m sections.
static func median_fill(visuals:Array,outlines:Array[PackedVector2Array])->Array[PackedVector2Array]:
 var clips:Array[PackedVector2Array]=[]
 for visual:Dictionary in visuals:
  var stations:=Height.elevated_sections(visual)
  for i in range(1,stations.points.size()):
   if not Height.retaining_section(stations.heights[i-1],stations.heights[i]):continue
   var footprint:=Height.elevated_section_footprint(stations,i)
   for outline in outlines:clips.append_array(Geometry2D.intersect_polygons(footprint,outline))
 return clips

## Subtract one CCW triangle from a convex polygon without introducing a hole.
## Each rejected half-plane contributes a disjoint convex remainder.
static func outside_triangle(subject:PackedVector2Array,cut:PackedVector2Array)->Array[PackedVector2Array]:
 var pieces:Array[PackedVector2Array]=[]
 var rest:=subject
 for i in range(3):
  if rest.size()<3:break
  var a:=cut[i];var edge:=cut[(i+1)%3]-a
  var inside:=PackedVector2Array();var outside:=PackedVector2Array()
  var prev:=rest[-1];var last:=edge.cross(prev-a)
  for point:Vector2 in rest:
   var side:=edge.cross(point-a)
   if (side>=0)!=(last>=0):
    var cross:=prev.lerp(point,last/(last-side));inside.append(cross);outside.append(cross)
   if side>=0:inside.append(point)
   else:outside.append(point)
   prev=point;last=side
  if outside.size()>=3:pieces.append(outside)
  rest=inside
 return pieces

static func fill_triangles(regions:Array[PackedVector2Array])->Array[PackedVector2Array]:
 var result:Array[PackedVector2Array]=[]
 for clip in regions:
  var indices:=Geometry2D.triangulate_polygon(clip)
  for i in range(0,indices.size(),3):
   var a:=clip[indices[i]];var b:=clip[indices[i+1]];var d:=clip[indices[i+2]]
   result.append(PackedVector2Array([a,b,d] if (b-a).cross(d-a)>=0 else [a,d,b]))
 return result

## Each new triangle contributes only its uncovered portion. Keep previously
## counted triangles in the same coverage set as old fill, so neither overlap
## between sections nor the location of a 4m station changes the area verdict.
static func adds_fill(previous:Array[PackedVector2Array],next:Array[PackedVector2Array])->bool:
 if next.is_empty():return false
 var parcels=preload("res://core/road_parcels.gd")
 var covered:=fill_triangles(previous)
 var bounds:Array[Rect2]=[]
 for triangle in covered:bounds.append(fill_bounds(triangle))
 var area:=0.0
 for clip in next:
  if parcels.area(clip)<=0.0:continue
  var triangles:=fill_triangles([clip])
  if triangles.is_empty():return true
  for triangle in triangles:
   var work:Array[PackedVector2Array]=[triangle]
   var extent:=fill_bounds(triangle)
   for i in range(covered.size()):
    if not extent.intersects(bounds[i]):continue
    var rest:Array[PackedVector2Array]=[]
    for piece in work:
     if fill_bounds(piece).intersects(bounds[i]):rest.append_array(outside_triangle(piece,covered[i]))
     else:rest.append(piece)
    work=rest
    if work.is_empty():break
   if work.is_empty():continue
   for piece in work:area+=parcels.area(piece)
   if area>.0005:return true
   covered.append(triangle);bounds.append(extent)
 return false

static func fill_bounds(polygon:PackedVector2Array)->Rect2:
 var bounds:=Rect2(polygon[0],Vector2.ZERO)
 for point in polygon:bounds=bounds.expand(point)
 return bounds

static func visual_retaining_error(before:Array,after:Array,existing:Array,added:Array)->String:
 var previous:=retaining_visuals(before)
 var final:=retaining_visuals(after)
 var changed:Array=[]
 for key:PackedByteArray in final:
  if not previous.has(key):changed.append(final[key])
 for deck:Dictionary in existing:
  if not Profile.is_center_structure(deck) or not Height.sunken(deck):continue
  var outlines:=Construction.outlines(deck)
  var next:=median_fill(changed,outlines)
  if next.is_empty():continue
  if adds_fill(median_fill(previous.values(),outlines),next):return "중앙 분리대와 겹칩니다"
 for deck:Dictionary in added:
  if not Profile.is_center_structure(deck) or not Height.sunken(deck):continue
  if adds_fill([],median_fill(final.values(),Construction.outlines(deck))):return "중앙 분리대와 겹칩니다"
 return ""

## D21: demolition never depends on artwork. Re-evaluate each blocked build:
## breaking a loop can expose a different, previously undrawn closing seam.
static func protected_road_visuals(roads:Array,topology:Dictionary)->Array:
 var covers:Array=[]
 for road:Dictionary in roads:
  if Profile.is_center_structure(road) and Height.sunken(road):covers.append(road)
 if covers.is_empty():return Geometry.continuous_roads(roads,topology)
 var blocked:Dictionary={}
 var safe:Array=[]
 while true:
  var joins:Dictionary={}
  safe=Geometry.continuous_roads(roads,topology,blocked,joins)
  var changed:=false
  for deck:Dictionary in covers:
   # Detect the total new fill, including multiple small joined portions. Only
   # consult chains that actually touch this reservation when proposing blocks.
   if visual_retaining_error(roads,safe,[deck],[]).is_empty():continue
   var outlines:=Construction.outlines(deck)
   for index:int in joins:
    if median_fill([safe[index]],outlines).is_empty():continue
    for key:String in joins[index]:
     if not blocked.has(key):blocked[key]=true;changed=true
  if not changed:break
 if blocked.is_empty():return safe
 # Re-enable harmless neighbors in deterministic order. Reconsider earlier
 # keys when a later accepted merge makes a different chain geometry possible.
 while true:
  var keys:=blocked.keys();keys.sort()
  var restored:=false
  for key:String in keys:
   blocked.erase(key)
   var proposed:=Geometry.continuous_roads(roads,topology,blocked)
   if visual_retaining_error(roads,proposed,covers,[]).is_empty():safe=proposed;restored=true
   else:blocked[key]=true
  if not restored:break
 return safe

static func ground_span_error(deck:Dictionary,road:Dictionary)->String:
 if Construction.intersections(deck,road).is_empty():return ""
 var central_level:=LEVEL_M if Profile.is_center_deck(deck) else -LEVEL_M
 for hit in Construction.contact_hits(deck,road):
  var crossing:Vector2=Paths.sample(deck.points,hit.a)
  if absf(Height.height_at(deck,crossing)-central_level)>EPS:continue
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
 var structural_level:=0.0
 for i in range(points.size()):
  if not points[i].is_finite() or not points[i].is_equal_approx(points[i].clamp(Vector2.ZERO,Vector2(city.width,city.height))):return failure("지도 경계 밖입니다")
  if levels[i] not in [0.0,LEVEL_M,-LEVEL_M]:return failure("지원하지 않는 도로 높이입니다")
  if levels[i]!=0.0:
   if structural_level!=0.0 and levels[i]!=structural_level:return failure("고가와 지하는 지상에서 나눠 그립니다")
   structural_level=levels[i]
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
  var leaves_ground:=levels[first]==0.0
  var start:=distances[first]+SPLIT_CELLS if leaves_ground else maxf(distances[first],distances[stop]-SPLIT_CELLS-minimum)
  var end:=start+minimum
  if end>distances[stop]-(0.0 if leaves_ground else SPLIT_CELLS)+EPS:return failure("경사로 길이가 부족합니다")
  stations.append(start);stations.append((start+end)*.5);stations.append(end)
  if not leaves_ground and distances[stop]>end+SPLIT_CELLS+EPS:return failure("합류점 뒤는 일반 도로로 이어 그립니다")
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
 var variant:="center-underpass" if structural_level<0.0 else "center-flyover-deck"
 var deck:Dictionary={"points":spine,"heights_m":heights,"kind":"local","lanes":section.deck_lanes,"width":section.deck_width,"road_variant":variant,"major_side":major_side}
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
