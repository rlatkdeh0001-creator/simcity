extends "res://common.gd"
var entry:Dictionary
var underground:bool
func road_height(x:float)->float:return clampf((144-abs(x))*10/128,0,10)*(-1 if underground else 1)
func fixture(v:SubViewport):
 var n:=model(v,entry.model)
 # Crossing four-lane road is fixture-only, not widened asset geometry.
 cube(v,"CrossingRoad",Vector3(20,.08,92),Vector3(0,-.025,0),"c8cbc3")
 cube(v,"CrossingAsphalt",Vector3(17.5,.012,92),Vector3(0,.021,0),"4c5659")
 for z in range(-44,45,8):
  if abs(z)<entry.metres[1]/2+4:continue
  cube(v,"CrossCentre",Vector3(.12,.004,3),Vector3(0,.03,z),"d6b65c")
  for x in [-3.5,3.5]:cube(v,"CrossLane",Vector3(.12,.004,3),Vector3(x,.03,z),"e5dfc8")
 # Ground intersections marked without implied live traffic/junction operation.
 for sign in [-1,1]:
  var z:float=sign*(entry.metres[1]/2+1.5)
  cube(v,"CrossStop",Vector3(7,.004,.25),Vector3(sign*-4.375,.031,z),"e5dfc8")
  for i in range(8):cube(v,"Crosswalk",Vector3(.65,.004,2),Vector3(-7.6+i*2.1,.032,sign*(entry.metres[1]/2+3.5)),"e5dfc8")
 for side in [-1,1]:
  model(v,"res://assets/vehicles/car-sedan-03.glb",Vector3(side*129,0,side*(8.75 if entry.center_width_m==14 else 5.25)),side*90)
  model(v,"res://assets/vehicles/car-sedan-03.glb",Vector3(side*124,road_height(124),side*1.5),side*90)
  model(v,"res://assets/vehicles/car-sedan-03.glb",Vector3(side*4.8,.03,side*22),0 if side==1 else 180)
  person(v,Vector3(side*135,0,side*(entry.metres[1]/2-.5)))
 if underground:model(v,"res://assets/vehicles/car-sedan-03.glb",Vector3(72,road_height(72),1.5),90)
 else:model(v,"res://assets/vehicles/car-sedan-03.glb",Vector3(1,10,1.5),90)
 person(v,Vector3(10,0,entry.metres[1]/2+7))
 return n
func verify(n:Node3D):
 var bb:=bounds(n)
 assert(abs(bb.size.x-304)<.002 and abs(bb.size.z-entry.metres[1])<.002);checks+=1
 assert(entry.kind=="structure_sample" and entry.status=="inspection_only");checks+=1
 var surfaces:=n.find_children("CentreAsphalt*","MeshInstance3D",true,false)
 var b:=AABB();var first:=true
 for s in surfaces:
  if first:b=bounds(s);first=false
  else:b=b.merge(bounds(s))
 assert(abs(b.size.x-288)<.002 and abs((b.position.y if underground else b.end.y)-(-10.01 if underground else 10))<.003);checks+=1
 # Actual endpoints of the ramp surface: 0m at144, ±10m at16.
 for x in [16.,144.]:
  var found:=false
  for s in surfaces:
   var a:=bounds(s)
   if abs(a.position.x-x)<.002 or abs(a.end.x-x)<.002:
    if abs(a.end.y-road_height(x))<.002 or abs(a.position.y+.01-road_height(x))<.002:found=true
  assert(found)
 checks+=1
 var outers:=n.find_children("GroundOuterAsphalt*","MeshInstance3D",true,false)
 assert(outers.size()==2)
 for s in outers:
  var a:=bounds(s);assert(abs(a.end.y)<.002 and abs(a.size.z-(entry.metres[1]*.875-entry.center_width_m)/2)<.002)
 checks+=1
 if underground:
  var portals:=n.find_children("Portal_LowerMember*","MeshInstance3D",true,false);assert(portals.size()==4)
  for p in portals:assert(abs(bounds(p).position.y+1.5)<.002)
  assert(n.find_children("ClosedTrenchFloor*","MeshInstance3D",true,false).size()==72 and n.find_child("CoverSlab",true,false)!=null)
  checks+=1
 else:
  var caps:=n.find_children("Support_PierCap*","MeshInstance3D",true,false)
  assert(caps.size()==(12 if entry.center_width_m==14 else 6))
  for p in caps:
   var a:=bounds(p);assert(abs(a.get_center().x)>=15.99)
   assert(abs(abs(a.get_center().z)-(3.5 if entry.center_width_m==14 else 0))<.002)
  checks+=1
  var cores:=n.find_children("ClosedDeckCore*","MeshInstance3D",true,false)
  for p in cores:
   var a:=bounds(p)
   if abs(a.get_center().x)<16:assert(abs(a.position.y-8)<.002)
  checks+=1
 print("NO_FOCUS project=",ProjectSettings.get_setting("display/window/size/no_focus")," native=",DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)," root=",root.unfocusable," focused=",root.has_focus())
 assert(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS));checks+=1
func run():
 var args:=OS.get_cmdline_user_args()
 var cat:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/facilities/catalog.json"))
 entry=cat.facilities.filter(func(e):return e.id==args[1])[0];underground="underpass" in args[1]
 make_canvas()
 label(args[1]+" / INSPECTION ONLY",Vector2(20,12),27)
 label("304m real length = 8 +128 +32 +128 +8 / unchanged width "+str(entry.metres[1])+"m",Vector2(20,49),22)
 label("WHOLE / game zoom0.65 / ramp7.8125%",Vector2(20,90),21)
 # Horizontal screen density 14/4/cos45 *0.65 =3.2173 px/m.
 var v:=stage(Vector2(20,125),Vector2i(780,455),780.0/(14.0/4.0/cos(PI/4)*.65),Vector3(0,1,0),Vector3(300,244.949,300))
 verify(fixture(v))
 label("SPLIT / outer lanes stay at ground / person1.75m",Vector2(20,592),20)
 var split:=stage(Vector2(20,628),Vector2i(780,317),50,Vector3(135,1,0),Vector3(90,73.4847,90));fixture(split)
 label("PORTAL + CROSSING / mouth4.5m" if underground else "CROSSING / deck+10m / clearance8m",Vector2(820,90),21)
 var target:=Vector3(39,-1,0) if underground else Vector3(0,3,0)
 var close:=stage(Vector2(820,125),Vector2i(760,820),113 if underground else 67,target,Vector3(100,81.6497,100) if underground else Vector3(55,65.888,100));fixture(close)
 label("Centre "+str(entry.center_width_m)+"m / inner lanes3m / outer lanes3.5m / no placement or traffic code",Vector2(20,961),21)
 await finish(args[0],"CENTER_SAMPLE_PASS "+args[1])
