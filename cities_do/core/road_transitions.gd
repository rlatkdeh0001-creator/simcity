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
