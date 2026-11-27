extends RefCounted
## Total lane counts; major_side is relative to authored point order, never screen axes.
const LOCAL_LANES:=[2,3,4,5,6,7,8]
const ONE_WAY_WIDTHS:=[1.5,3.0,3.0,5.0] # City cells, independent of the legacy width scale.
const ONE_WAY_SIDEWALK_RIGHT:=[.75,.75,.75,1.25] # Metres
const ONE_WAY_SHOULDER_RIGHT:=[1.75,1.75,0.0,1.75]
enum BranchVariant { SIX_METRE, EIGHT_METRE }
# Width and transition grade are in cells; sidewalk and shoulder in metres.
const BRANCH_IDS:=["branch-one-way-6m","branch-one-way-8m"]
const BRANCH_PROFILES:={
 "branch-one-way-6m":{"lanes":1,"width":1.5,"grade":1.5,"walk":.75,"shoulder":1.75},
 "branch-one-way-8m":{"lanes":2,"width":2.0,"grade":3.0,"walk":1.0,"shoulder":0.0},
}
static func branch_profile(road: Dictionary) -> Dictionary:
 var key:Variant=road.get("road_variant")
 if not key is String or road.get("kind")!="local" or travel_direction(road)==0:return {}
 var section:Dictionary=BRANCH_PROFILES.get(key,{})
 return section if not section.is_empty() and road.get("lanes")==section.lanes else {}
static func travel_direction(road: Dictionary) -> int:
 var value:Variant=road.get("travel_dir",0)
 return int(value) if value is int and value in [-1,1] else 0
static func width_grade(lanes: int) -> int:return lanes+1 if lanes in [2,4,6] else lanes
static func width_for(kind: String,lanes: int,base_width: float=2.0,travel_dir: int=0) -> float:
 if kind=="local" and travel_dir!=0 and lanes>=1 and lanes<=ONE_WAY_WIDTHS.size():return ONE_WAY_WIDTHS[lanes-1]
 return base_width*(width_grade(lanes) if kind=="local" else lanes)/2.0
static func width_for_record(road: Dictionary,base_width: float=2.0) -> float:
 var branch:=branch_profile(road)
 if not branch.is_empty():return branch.width
 return width_for(road.kind,road.lanes,base_width,travel_direction(road))
static func grade_for_record(road: Dictionary) -> float:
 var branch:=branch_profile(road)
 if not branch.is_empty():return branch.grade
 return width_for_record(road) if travel_direction(road)!=0 else float(width_grade(road.lanes))
static func valid_selection(kind: String,lanes: int,major_side: int,travel_dir: int) -> bool:
 if travel_dir!=0:return travel_dir==1 and kind=="local" and lanes>=1 and lanes<=ONE_WAY_WIDTHS.size()
 if major_side not in [-1,1]:return false
 return (lanes in LOCAL_LANES if kind=="local" else kind=="highway" and lanes in [2,4])
static func direction_count(road: Dictionary,direction: int) -> int:
 var travel:=travel_direction(road)
 if travel!=0:return int(road.lanes) if direction==travel else 0
 return ceili(float(road.lanes)/2) if direction==int(road.get("major_side",1)) else floori(float(road.lanes)/2)
static func sidewalk_width(road: Dictionary,side: int) -> float:
 var travel:=travel_direction(road)
 if travel==0:return (float(road.width)-asphalt_width(road))/2
 var branch:=branch_profile(road)
 if not branch.is_empty():return branch.walk/4.0 if side==travel else 0.0
 return ONE_WAY_SIDEWALK_RIGHT[road.lanes-1]/4.0 if side==travel or road.lanes>1 else 0.0
static func shoulder_width(road: Dictionary,side: int) -> float:
 var travel:=travel_direction(road)
 if travel==0:
  return (asphalt_width(road)-travel_width(road))/2 if road.get("kind","local")=="local" and road.lanes in [2,4,6] else 0.0
 var branch:=branch_profile(road)
 if not branch.is_empty():return branch.shoulder/4.0 if side==travel else 0.0
 return ONE_WAY_SHOULDER_RIGHT[road.lanes-1]/4.0 if side==travel or road.lanes>1 else 0.0
## Policy only; bus berth admission uses the physical shoulder independently.
static func allows_roadside_parking(road: Dictionary,side: int) -> bool:
 return branch_profile(road).is_empty() and shoulder_width(road,side)>0
## Signed edges along the right normal of authored point order, in cells.
static func asphalt_edges(road: Dictionary) -> Vector2:
 var half:=float(road.width)/2
 return Vector2(-half+sidewalk_width(road,-1),half-sidewalk_width(road,1))
static func asphalt_width(road: Dictionary) -> float:
 if travel_direction(road)!=0:
  var edges:=asphalt_edges(road)
  return edges.y-edges.x
 return float(road.width)*(.875 if road.get("kind","local")=="local" else (.75 if road.lanes==2 else (.8125 if road.lanes==4 else .875)))
static func lane_width_metres(road: Dictionary) -> float:
 if travel_direction(road)!=0:return 3.5
 return minf(3.5,(float(road.width)*4-2)/road.lanes) if road.get("kind","local")!="local" else minf(3.5,asphalt_width(road)*4/road.lanes)
static func travel_width(road: Dictionary) -> float:return lane_width_metres(road)*road.lanes/4.0
## Lane index increases left-to-right relative to travel; distances are signed in that frame.
static func lane_center_metres(road: Dictionary,direction: int,index: int) -> float:
 if travel_direction(road)!=0:
  return (-float(road.width)/2+sidewalk_width(road,-direction)+shoulder_width(road,-direction))*4+(index+.5)*lane_width_metres(road)
 return (index+.5)*lane_width_metres(road)+median_offset(road)*4*direction
static func shoulder_offsets(road: Dictionary) -> Array[float]:
 var result: Array[float]=[]
 if travel_direction(road)!=0:
  var edges:=asphalt_edges(road)
  var left:=shoulder_width(road,-1);var right:=shoulder_width(road,1)
  if left>0:result.append(edges.x+left)
  if right>0:result.append(edges.y-right)
  return result
 if road.get("kind","local")=="local" and road.lanes in [2,4,6]:result.assign([-travel_width(road)/2,travel_width(road)/2])
 return result
static func has_median(road: Dictionary) -> bool:return travel_direction(road)==0
static func median_offset(road: Dictionary) -> float:
 if not has_median(road):return 0.0
 return -int(road.get("major_side",1))*lane_width_metres(road)/8 if int(road.lanes)%2 else 0.0
static func separators(road: Dictionary) -> Array[float]:
 var result: Array[float]=[]
 var travel:=travel_direction(road)
 if travel!=0:
  var left:=asphalt_edges(road).x+shoulder_width(road,-1)
  for i in range(1,int(road.lanes)):result.append(left+i*lane_width_metres(road)/4)
  return result
 for i in range(1,int(road.lanes)):
  if i==direction_count(road,-1):continue
  result.append((i-float(road.lanes)/2)*(lane_width_metres(road)/4 if road.get("kind","local")=="local" else asphalt_width(road)/road.lanes))
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
