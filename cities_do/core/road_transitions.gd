extends RefCounted
## Derived, uncontrolled two-arm transitions. Authored centreline records stay fixed.
const Profile=preload("res://core/road_profile.gd")
const GRADES:=[3,5,7,8]
static func allowed(a:Dictionary,b:Dictionary)->bool:
 if a.kind!=b.kind:return false
 if a.kind!="local":return a.lanes==b.lanes and is_equal_approx(a.width,b.width)
 var first:=GRADES.find(Profile.width_grade(a.lanes));var last:=GRADES.find(Profile.width_grade(b.lanes))
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
 if not allowed(a,b) or is_equal_approx(a.width,b.width):return false
 var first:=extent(a);var last:=extent(b)
 if minf(first,last)<.0001:return false
 var p:Vector2=junction.position+a.direction*first;var q:Vector2=junction.position+b.direction*last;var normal:=Vector2(-b.direction.y,b.direction.x)
 var half:float=maxf(a.width,b.width)/2
 junction.taper=true;junction.taper_extents=[first,last];junction.box_axis=b.direction;junction.box_half=half
 junction.box_width=half*2;junction.box_border=half-maxf(Profile.asphalt_width(a),Profile.asphalt_width(b))/2;junction.radius=maxf(first,last)
 junction.box=quad(p,q,normal,half,half)
 junction.taper_pavement=quad(p,q,normal,a.width/2,b.width/2)
 junction.taper_asphalt=quad(p,q,normal,Profile.asphalt_width(a)/2,Profile.asphalt_width(b)/2)
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
 var a:Dictionary=junction.arms[0];var b:Dictionary=junction.arms[1];var normal:=Vector2(-b.direction.y,b.direction.x)
 if not allowed(a,b):return {}
 var ma:float=-Profile.median_offset(a);var mb:=Profile.median_offset(b)
 if a.lanes==b.lanes and is_equal_approx(a.width,b.width) and is_equal_approx(ma,mb):return {}
 var first:=extent(a);var last:=extent(b)
 if minf(first,last)<.0001:return {}
 var p:Vector2=junction.position+a.direction*first;var q:Vector2=junction.position+b.direction*last
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
