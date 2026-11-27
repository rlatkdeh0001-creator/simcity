extends SceneTree

const City=preload("res://core/city_model.gd")
const Junctions=preload("res://core/road_junctions.gd")
const Profile=preload("res://core/road_profile.gd")
const START:=Vector2(40,40)
var checks:=0
var failures:=0

func _initialize():run.call_deferred()

func verify(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error("FAIL "+label)

func area(polygon:PackedVector2Array)->float:
 var result:=0.0
 for i in range(1,polygon.size()-1):result+=(polygon[i]-polygon[0]).cross(polygon[i+1]-polygon[0])
 return absf(result)*.5

func overlap(a:PackedVector2Array,b:PackedVector2Array)->float:
 var result:=0.0
 for patch in Geometry2D.intersect_polygons(a,b):result+=area(patch)
 return result

func no_overdraw(polygons:Array[PackedVector2Array])->bool:
 for i in range(polygons.size()):
  for j in range(i):
   if overlap(polygons[i],polygons[j])>.00001:return false
 return true

func rectangle(x0:float,x1:float,y0:float,y1:float)->PackedVector2Array:
 return PackedVector2Array([Vector2(x0,y0),Vector2(x1,y0),Vector2(x1,y1),Vector2(x0,y1)])

func fixture(gap:float,side:int,reverse:bool,seam:bool,lanes:int=2,through:bool=false):
 var end:=START+Vector2(gap,0)
 var strokes:=[PackedVector2Array([Vector2(10,40),Vector2(80,40)])]
 if seam:
  # Two passive seams; neither individual junction arm spans the midpoint.
  var left:=START+Vector2.RIGHT*1.625;var right:=end-Vector2.RIGHT*1.625
  strokes=[PackedVector2Array([Vector2(10,40),left]),PackedVector2Array([left,right]),PackedVector2Array([right,Vector2(80,40)])]
 var branch_a:=PackedVector2Array([START+Vector2.UP*18 if through else START,START+Vector2.DOWN*18])
 var branch_b:=PackedVector2Array([end+Vector2.UP*18*side if through else end,end+Vector2.DOWN*18*side])
 var city:=City.new(100,100)
 for road in strokes:
  if reverse:road.reverse()
  verify(city.add_road(road,"local",true,lanes).ok,"authored host placement")
 var branch_bytes:=var_to_bytes(city.roads)
 var branches:=[branch_a,branch_b] if not reverse else [branch_b,branch_a]
 for branch in branches:
  if reverse:branch.reverse()
  # Wide X render boxes overlap at this spacing; exercise their paint on authored
  # records separately from player placement, which has its own footprint checks.
  var placement:=city.add_road(branch,"local",true,2,false,lanes==2)
  verify(placement.ok,"branch placement at %.2fm: %s"%[gap*4,placement.get("reason","")])
 verify(city.junctions.size()==2 and var_to_bytes(city.roads.slice(0,strokes.size()))==branch_bytes,"two independent junctions and unchanged authored host records")
 return city

func check_paint(city,gap:float,merged:bool,label:String):
 var edge:=START.x+gap
 var half:=Profile.asphalt_width(city.roads[0])*.5
 var mask:=rectangle(START.x+1.5,edge-1.5,START.y-half,START.y+half)
 var faces:Array[PackedVector2Array]=[]
 for stripe in city.road_crosswalks:
  if overlap(stripe,mask)>.00001:faces.append(stripe)
 var count:=0
 var y:=START.y-half+.12
 while y<START.y+half-.12:count+=1;y+=.28
 verify(faces.size()==count*(1 if merged else 2),label+": one complete zebra if overlapping, otherwise two")
 var centres:={}
 for stripe in faces:
  var x0:=INF;var x1:=-INF
  for p in stripe:x0=minf(x0,p.x);x1=maxf(x1,p.x)
  var centre:=(x0+x1)*.5
  centres[snappedf(centre,.001)]=true
  verify(absf(x1-x0-.44)<.001 and (absf(centre-(START.x+gap*.5))<.001 if merged else (absf(centre-START.x-1.75)<.001 or absf(centre-edge+1.75)<.001)),label+": full-length stripe at midpoint or original actual edge")
 verify(centres.size()==(1 if merged else 2),label+": exact number of painted transverse rows")
 verify(no_overdraw(city.road_crosswalks),label+": no positive-area zebra pairs (including duplicates within the final crossing)")
 var surfaces:Array[PackedVector2Array]=city.road_asphalt+city.junction_asphalt
 var clipped_ok:=true
 for stripe in faces:
  var covered:=0.0
  for surface in surfaces:covered+=overlap(stripe,surface)
  if covered<area(stripe)-.0001 or overlap(stripe,mask)<area(stripe)-.0001:clipped_ok=false
 verify(clipped_ok,label+": retained shared paint is inside asphalt and between actual branch edges")
 var clear:=true
 for zebra in city.road_crosswalks:
  for stop in city.road_stop_lines:
   if overlap(zebra,stop)>.00001:clear=false
 if merged:verify(clear and no_overdraw(city.road_stop_lines),label+": no positive-area zebra/stop or stop/stop pairs")
 var outside: Array[PackedVector2Array]=[]
 for node in city.junctions:
  for stripe in Junctions.crosswalk_polygons(node,surfaces):
   if overlap(stripe,mask)<=.00001:outside.append(stripe)
 verify(city.road_crosswalks.size()-faces.size()==outside.size() and outside.all(func(stripe):return city.road_crosswalks.has(stripe)),label+": all unrelated approach stripes stay unchanged")

func run():
 for gap in [3.5,3.75,4.0]:
  for side in [1,-1]:
   for reverse in [false,true]:
    var city=fixture(gap,side,reverse,false)
    if city.junctions.size()==2:check_paint(city,gap,gap<4,"%.2fm side=%d reverse=%s"%[gap*4,side,reverse])
 for gap in [3.5,3.75]:
  for reverse in [false,true]:
   var split=fixture(gap,-1,reverse,true)
   if split.junctions.size()==2:check_paint(split,gap,true,"%.2fm split host reverse=%s"%[gap*4,reverse])
   var wide=fixture(gap,1,reverse,false,8,true)
   if wide.junctions.size()==2:check_paint(wide,gap,true,"%.2fm mixed-width cross reverse=%s"%[gap*4,reverse])
 print("RESULT %d/%d close-junction paint checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
