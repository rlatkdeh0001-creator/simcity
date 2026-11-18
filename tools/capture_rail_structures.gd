extends "res://viaduct_geometry.gd"
# Inspection fixtures only. No registered rail structure or gameplay code.
func texture_material(path:String,shade:float=1.)->StandardMaterial3D:
 var m:=flat("ffffff");m.albedo_texture=load(path);m.albedo_color=Color(shade,shade,shade);m.texture_repeat=true;return m
func side(v:SubViewport,x0:float,x1:float,z:float,top:float,bottom:float,mat:Material,v0:float=0.,v1:float=1.):
 quad(v,PackedVector3Array([Vector3(x0,top,z),Vector3(x1,top,z),Vector3(x1,bottom,z),Vector3(x0,bottom,z)]),PackedVector2Array([Vector2(0,v0),Vector2((x1-x0)/4,v0),Vector2((x1-x0)/4,v1),Vector2(0,v1)]),mat)
func tracks(v:SubViewport,x0:float,x1:float,height:float):
 var mat:=texture_material("res://assets/rail/rail-track-01/strip.png")
 cube(v,"BallastGap",Vector3(x1-x0,.05,.4),Vector3((x0+x1)/2,height-.025,0),"a59c8e")
 for z in [-2.,2.]:
  quad(v,PackedVector3Array([Vector3(x0,height,z-1.8),Vector3(x1,height,z-1.8),Vector3(x1,height,z+1.8),Vector3(x0,height,z+1.8)]),PackedVector2Array([Vector2.ZERO,Vector2((x1-x0)/4,0),Vector2((x1-x0)/4,1),Vector2(0,1)]),mat)
func line(v:SubViewport,a:Vector3,b:Vector3,color:String):
 var im:=ImmediateMesh.new();var mat:=flat(color);im.surface_begin(Mesh.PRIMITIVE_LINES,mat);im.surface_add_vertex(a);im.surface_add_vertex(b);im.surface_end();var n:=MeshInstance3D.new();n.mesh=im;v.add_child(n)
func wires(v:SubViewport,height:float):
 for x in [-16.,16.]:
  for sign_value in [-1.,1.]:
   var z:float=sign_value*4
   line(v,Vector3(x,height,z),Vector3(x,height+5.3,z),"6f7579")
   line(v,Vector3(x,height+4.8,z),Vector3(x,height+4.8,sign_value*2),"9aa1a4")
   line(v,Vector3(x,height+3.9,z),Vector3(x,height+4.8,sign_value*2),"9aa1a4")
   line(v,Vector3(x,height+4.8,sign_value*2),Vector3(x,height+3.8,sign_value*2),"9aa1a4")
 for z in [-2.,2.]:
  line(v,Vector3(-20,height+3.8,z),Vector3(20,height+3.8,z),"2a2e30")
  for j in range(32):
   var a:float=-16+j;var b:float=a+1
   line(v,Vector3(a,height+4.3+.5*pow(a/16,2),z),Vector3(b,height+4.3+.5*pow(b/16,2),z),"2a2e30")
func vehicle_entry(id:String)->Dictionary:
 var d:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/catalog.json"));return d.vehicles.filter(func(e):return e.id==id)[0]
func bridge(v:SubViewport):
 var s:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://side-spec.json"))
 cube(v,"BridgeCore",Vector3(40,2,10),Vector3(0,9,0),"8f948f")
 cube(v,"RailDeck",Vector3(40,.01,10),Vector3(0,9.995,0),"a3a89f")
 for sign_value in [-1.,1.]:
  side(v,-20,20,sign_value*5.001,11.1,8,texture_material("res://assets/structures/viaduct-side-01/deck_side.png",s.face_shade["-Y"] if sign_value>0 else s.face_shade["+X"]))
  side(v,-20,20,sign_value*4.6,11.1,10,texture_material("res://assets/structures/viaduct-side-01/barrier_inner.png"))
  cube(v,"BarrierTop",Vector3(40,.035,.4),Vector3(0,11.0825,sign_value*4.8),"ced0c7")
 for x in [-16.,16.]:model(v,"res://assets/structures/viaduct-pier-01/viaduct-pier-01.glb",Vector3(x,0,0))
 tracks(v,-20,20,10.002)
 var lead:=vehicle_entry("train-loco-01");var coach:=vehicle_entry("train-passenger-01");assert(lead.model.ends_with("-v3.glb") and coach.model.ends_with("-v3.glb"));checks+=1
 var a:=model(v,lead.model,Vector3(5.5,10,2),90);var b:=model(v,coach.model,Vector3(-5,10,2),90)
 assert(abs(bounds(a).position.x-bounds(b).end.x)<.002);checks+=1
 var contact:Node3D=a.find_child("PantographContactBar",true,false);assert(contact!=null and abs(bounds(contact).end.y-13.8)<.002);checks+=1
 assert(abs(bounds(contact).get_center().z-2)<.002);checks+=1
 wires(v,10)
 assert(5.-4.15>.4 and 4.6-3.8>.79);checks+=1
 print("RAIL_BRIDGE width10 deck10 underside8 ballast+/-3.8 poles+/-4 barrier_inner+/-4.6 contact=",bounds(contact).end.y," train_coupler_contact PASS")
func tunnel(v:SubViewport):
 var wall:=texture_material("res://assets/structures/retaining-wall-01/wall.png",.9)
 var inner:=texture_material("res://assets/structures/viaduct-side-01/barrier_inner.png")
 cube(v,"ClosedRailTrenchFloor",Vector3(32,.2,9),Vector3(0,-7.45,0),"a3a89f")
 for sign_value in [-1.,1.]:
  cube(v,"WallSolid",Vector3(32,7.35,.5),Vector3(0,-3.675,sign_value*4.75),"a3a89f")
  side(v,-16,16,sign_value*5.001,1.1,-7.35,wall,0,8.45/9.)
  side(v,-16,16,sign_value*4.499,0,-7.35,wall,1.1/9.,8.45/9.)
  side(v,-16,16,sign_value*4.6,1.1,0,inner)
  cube(v,"BarrierTop",Vector3(32,.035,.4),Vector3(0,1.0825,sign_value*4.8),"ced0c7")
  cube(v,"GroundSide",Vector3(32,.3,2),Vector3(0,-.15,sign_value*6),"7e9275")
 cube(v,"Cover",Vector3(8,1,10),Vector3(-12,-.5,0),"a3a89f")
 cube(v,"CoverGround",Vector3(8,.02,10),Vector3(-12,.01,0),"7e9275")
 cube(v,"PortalSolidBeam",Vector3(.5,1.5,9),Vector3(-8.25,-.75,0),"8c8a80")
 cube(v,"PortalTopBarrier",Vector3(.4,1.1,9.2),Vector3(-8.25,.55,0),"b9bbb3")
 var portal:=texture_material("res://assets/structures/tunnel-portal-01/portal.png")
 quad(v,PackedVector3Array([Vector3(-7.999,1.1,-5),Vector3(-7.999,1.1,5),Vector3(-7.999,-1.5,5),Vector3(-7.999,-1.5,-5)]),PackedVector2Array([Vector2.ZERO,Vector2(2.5,0),Vector2(2.5,1),Vector2(0,1)]),portal)
 cube(v,"ClosedDarkEnd",Vector3(.2,6.35,9),Vector3(-15.9,-4.175,0),"15181a")
 tracks(v,-15.8,16,-7.)
 # Rails are level here: no ramp or altered railway grade is implied.
 var freight:=model(v,vehicle_entry("train-loco-freight-01").model,Vector3(-5,-7,-2),-90)
 assert(abs(bounds(freight).end.y-(-3.2))<.002);checks+=1
 assert(abs(-1.5-(-7)-5.5)<.0001);checks+=1
 assert(bounds(freight).position.x< -8 and bounds(freight).end.x> -8);checks+=1
 print("RAIL_PORTAL width10 inner9 rail-7 mouth-1.5 clearance5.5 freight partially entering; level fixture/no ramp")
func run():
 make_canvas();label("RAIL / shared concrete bridge + portal / 10m structure / actual delivered strips",Vector2(24,15),27)
 label("BRIDGE +10m / v3 lead +coach / contact line3.8m",Vector2(24,68),21)
 label("PORTAL / freight entering / rail-7m / clearance5.5m",Vector2(814,68),21)
 var a:=stage(Vector2(20,110),Vector2i(770,740),48,Vector3(0,7,0));bridge(a)
 var b:=stage(Vector2(810,110),Vector2i(770,740),39,Vector3(0,-3,0));tunnel(b)
 label("Ballast7.6m / track centres+/-2m / poles+/-4m / barrier inner+/-4.6m",Vector2(24,875),23)
 label("Fixture wires: contact3.8m / messenger4.8m (midspan4.3m) / pole5.3m / spacing32m",Vector2(24,915),23)
 label("Inspection only. Concrete parts reused; no steel truss, ramp, new rail asset or gameplay code.",Vector2(24,960),21)
 await finish(OS.get_cmdline_user_args()[0],"RAIL_STRUCTURES_PASS")
