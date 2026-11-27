extends RefCounted
## Derived, uncontrolled two-arm transitions. Authored centreline records stay fixed.
const Profile=preload("res://core/road_profile.gd")
const GRADES:=[1.5,3.0,5.0,7.0,8.0]
static func allowed(a:Dictionary,b:Dictionary)->bool:
 if a.kind!=b.kind:return false
 if a.kind!="local":return a.lanes==b.lanes and is_equal_approx(a.width,b.width)
 var first:=GRADES.find(Profile.grade_for_record(a));var last:=GRADES.find(Profile.grade_for_record(b))
 return first>=0 and last>=0 and absi(first-last)<=1
static func straight(junction:Dictionary)->bool:
 return junction.arms.size()==2 and junction.arms[0].direction.dot(junction.arms[1].direction)<-.99999
static func extent(arm:Dictionary)->float:
 var length:=0.0
 for i in range(1,arm.points.size()):
  var delta:Vector2=arm.points[i]-arm.points[i-1]
  if delta.normalized().dot(arm.direction)<.99999:break
  length+=delta.length()
 return minf(2.0,length*.45)
static func quad(a:Vector2,b:Vector2,normal:Vector2,first:float,last:float)->PackedVector2Array:
 return PackedVector2Array([a+normal*first,b+normal*last,b-normal*last,a-normal*first])
static func setup(junction:Dictionary)->bool:
 if not straight(junction):return false
 var a:Dictionary=junction.arms[0];var b:Dictionary=junction.arms[1]
 if not allowed(a,b) or (is_equal_approx(a.width,b.width) and Profile.travel_direction(a)==-Profile.travel_direction(b)):return false
 var first:=extent(a);var last:=extent(b)
 if minf(first,last)<.0001:return false
 var p:Vector2=junction.position+a.direction*first;var q:Vector2=junction.position+b.direction*last;var normal:=Vector2(-b.direction.y,b.direction.x)
 var half:float=maxf(a.width,b.width)/2
 junction.taper=true;junction.taper_extents=[first,last];junction.box_axis=b.direction;junction.box_half=half
 junction.box_width=half*2;junction.box_border=half-maxf(Profile.asphalt_width(a),Profile.asphalt_width(b))/2;junction.radius=maxf(first,last)
 junction.box=quad(p,q,normal,half,half)
 junction.taper_pavement=quad(p,q,normal,a.width/2,b.width/2)
 var start_edges:=Profile.asphalt_edges(a);var end_edges:=Profile.asphalt_edges(b)
 junction.taper_asphalt=PackedVector2Array([p-normal*start_edges.x,q+normal*end_edges.y,q+normal*end_edges.x,p-normal*start_edges.y])
 return true
static func curve(a:Vector2,b:Vector2,forward:Vector2)->PackedVector2Array:
 var result:=PackedVector2Array();var length:=a.distance_to(b);var c:=a+forward*length/3;var d:=b-forward*length/3
 for i in range(25):
  var t:=i/24.0;var u:=1-t;result.append(a*u*u*u+c*3*u*u*t+d*3*u*t*t+b*t*t*t)
 return result
static func dashes(points:PackedVector2Array)->Array[PackedVector2Array]:
 var result:Array[PackedVector2Array]=[];var phase:=0.0
 for i in range(1,points.size()):
  var delta:=points[i]-points[i-1];var length:=delta.length()
  if length<.00001:continue
  var cursor:=0.0
  while cursor<length:
   var cycle:=fposmod(phase+cursor,1.25);var last:=minf(length,cursor+(.75-cycle if cycle<.75 else 1.25-cycle))
   if cycle<.75:result.append(PackedVector2Array([points[i-1]+delta*cursor/length,points[i-1]+delta*last/length]))
   cursor=last+.00001
  phase+=length
 return result
static func paint(junction:Dictionary)->Dictionary:
 if not straight(junction) or junction.arms[0].get("kind","local")!="local" or junction.arms[1].get("kind","local")!="local":return {}
 var a:Dictionary=junction.arms[0];var b:Dictionary=junction.arms[1]
 # Arm headings face out of the seam. Pair separators left-to-right and start
 # the dash phase in physical travel order, not road insertion order.
 if Profile.travel_direction(a)==1 and Profile.travel_direction(b)==-1:
  a=junction.arms[1];b=junction.arms[0]
 var normal:=Vector2(-b.direction.y,b.direction.x)
 if not allowed(a,b):return {}
 var ma:float=-Profile.median_offset(a);var mb:=Profile.median_offset(b)
 if a.lanes==b.lanes and is_equal_approx(a.width,b.width) and is_equal_approx(ma,mb) and Profile.has_median(a)==Profile.has_median(b):return {}
 var first:=extent(a);var last:=extent(b)
 if minf(first,last)<.0001:return {}
 var p:Vector2=junction.position+a.direction*first;var q:Vector2=junction.position+b.direction*last
 if not Profile.has_median(a) or not Profile.has_median(b):return directional_paint(a,b,p,q,normal,junction.position)
 var result:={"region":quad(p,q,normal,maxf(a.width,b.width)/2,maxf(a.width,b.width)/2),"median":curve(p+normal*ma,q+normal*mb,b.direction),"white":[]}
 var left:Array[float]=[];var right:Array[float]=[]
 for offset in Profile.separators(a):left.append(-offset)
 for offset in Profile.separators(b):right.append(offset)
 for side in [-1,1]:
  var starts:=left.filter(func(offset):return (offset-ma)*side>0);var ends:=right.filter(func(offset):return (offset-mb)*side>0)
  starts.sort_custom(func(x,y):return absf(x-ma)<absf(y-ma));ends.sort_custom(func(x,y):return absf(x-mb)<absf(y-mb))
  for i in range(maxi(starts.size(),ends.size())):
   var begin:float=starts[i] if i<starts.size() else side*(Profile.travel_width(a)/2-.04);var finish:float=ends[i] if i<ends.size() else side*(Profile.travel_width(b)/2-.04)
   result.white.append_array(dashes(curve(p+normal*begin,q+normal*finish,b.direction)))
  if not Profile.shoulder_offsets(a).is_empty() or not Profile.shoulder_offsets(b).is_empty():
   var begin:float=side*(Profile.travel_width(a)/2 if not Profile.shoulder_offsets(a).is_empty() else Profile.asphalt_width(a)/2-.04)
   var finish:float=side*(Profile.travel_width(b)/2 if not Profile.shoulder_offsets(b).is_empty() else Profile.asphalt_width(b)/2-.04)
   result.white.append(curve(p+normal*begin,q+normal*finish,b.direction))
 return result

static func directional_paint(a:Dictionary,b:Dictionary,p:Vector2,q:Vector2,normal:Vector2,seam:Vector2)->Dictionary:
 var result:={"region":quad(p,q,normal,maxf(a.width,b.width)/2,maxf(a.width,b.width)/2),"median":PackedVector2Array(),"white":[]}
 if Profile.has_median(a):result.median=PackedVector2Array([p-normal*Profile.median_offset(a),seam-normal*Profile.median_offset(a)])
 if Profile.has_median(b):result.median=PackedVector2Array([seam+normal*Profile.median_offset(b),q+normal*Profile.median_offset(b)])
 var a_edges:=Profile.asphalt_edges(a);var b_edges:=Profile.asphalt_edges(b)
 var centre_edges:=(Vector2(-a_edges.y,-a_edges.x)+b_edges)/2
 var start:=Profile.separators(a);start.reverse()
 var end:=Profile.separators(b)
 for i in range(maxi(start.size(),end.size())):
  result.white.append_array(dashes(taper_mark(p,q,normal,centre_edges,-start[i] if i<start.size() else null,end[i] if i<end.size() else null)))
 var shoulders_a:=Profile.shoulder_offsets(a);var shoulders_b:=Profile.shoulder_offsets(b)
 for side in [-1,1]:
  var before:=shoulders_a.filter(func(offset):return -offset*side>0)
  var after:=shoulders_b.filter(func(offset):return offset*side>0)
  if not before.is_empty() or not after.is_empty():
   result.white.append(taper_mark(p,q,normal,centre_edges,-before[0] if not before.is_empty() else null,after[0] if not after.is_empty() else null))
 return result

static func taper_mark(p:Vector2,q:Vector2,normal:Vector2,centre_edges:Vector2,first:Variant,last:Variant)->PackedVector2Array:
 # An unmatched marking terminates inside the taper instead of crossing to the opposite curb.
 var offset:float=last if first==null else first
 var midpoint:=p.lerp(q,.5)+normal*clampf(offset,centre_edges.x+.04,centre_edges.y-.04)
 return PackedVector2Array([midpoint if first==null else p+normal*first,midpoint if last==null else q+normal*last])
