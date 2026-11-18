extends SceneTree
var canvas:SubViewport
var checks:=0
func _initialize():run.call_deferred()
func label(t:String,p:Vector2,s:int=22):
 var l:=Label.new();l.text=t;l.position=p;l.add_theme_font_size_override("font_size",s);canvas.add_child(l)
func bounds(n:Node3D)->AABB:
 if n is MeshInstance3D:return n.global_transform*n.get_aabb()
 var b:=AABB();var first:=true
 for m in n.find_children("*","MeshInstance3D",true,false):
  var v:AABB=m.global_transform*m.get_aabb()
  if first:b=v;first=false
  else:b=b.merge(v)
 return b
func model(v:SubViewport,path:String)->Node3D:
 var packed=load(path);assert(packed is PackedScene);var n:Node3D=packed.instantiate();v.add_child(n);return n
func stage(pos:Vector2,reverse:bool)->SubViewport:
 var holder:=SubViewportContainer.new();holder.position=pos;canvas.add_child(holder)
 var v:=SubViewport.new();v.size=Vector2i(770,750);v.own_world_3d=true;v.msaa_3d=Viewport.MSAA_4X;holder.add_child(v)
 var e:=WorldEnvironment.new();e.environment=Environment.new();e.environment.background_mode=Environment.BG_COLOR;e.environment.background_color=Color("334851");e.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.environment.ambient_light_color=Color("d9e4f0");e.environment.ambient_light_energy=.75;v.add_child(e)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);light.light_energy=1.1;light.shadow_enabled=true;v.add_child(light)
 var c:=Camera3D.new();c.projection=Camera3D.PROJECTION_ORTHOGONAL;c.keep_aspect=Camera3D.KEEP_WIDTH;c.size=39;v.add_child(c)
 var target:=Vector3(0,-2.5,0);var sign_value:float=-1 if reverse else 1
 c.position=target+Vector3(30*sign_value,24.4949,30*sign_value);c.look_at(target);c.current=true
 return v
func populate(v:SubViewport,verify:bool):
 var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/facilities/catalog.json"))
 var entries:Array=doc.facilities.filter(func(e):return e.id=="tunnel-sample-01");assert(entries.size()==1)
 var entry:Dictionary=entries[0];var n:=model(v,entry.model)
 var car:=model(v,"res://assets/vehicles/car-sedan-03.glb");car.position=Vector3(-6,-5.84,-2.5);car.basis=Basis(Vector3.BACK,atan(.08))*Basis(Vector3.UP,deg_to_rad(-90))
 var person:=MeshInstance3D.new();var capsule:=CapsuleMesh.new();capsule.radius=.19;capsule.height=1.75;person.mesh=capsule
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color("dcaa72");person.material_override=mat;v.add_child(person);person.position=Vector3(-6,.875,7)
 if not verify:return
 assert(entry.kind=="structure_sample" and entry.status=="inspection_only" and entry.width==8 and entry.depth==4);checks+=1
 var bb:=bounds(n);assert(abs(bb.size.x-32)<.002 and abs(bb.size.z-16)<.002 and abs(bb.position.y+6.84)<.002 and abs(bb.end.y-1.1)<.002);checks+=1
 var asphalt:Node3D=n.find_child("Asphalt",true,false);var ab:=bounds(asphalt);assert(abs(ab.end.y+4.08)<.002 and abs(ab.position.y+6.65)<.002 and abs(ab.size.z-10.5)<.002);checks+=1
 var beams:=n.find_children("Portal_LowerMember*","MeshInstance3D",true,false);assert(beams.size()==3)
 for beam in beams:assert(abs(bounds(beam).position.y+1.5)<.002 and bounds(beam).end.x<=-8+.002)
 assert(abs(entry.portal_mouth_top_z_m-entry.portal_road_z_m-4.5)<.0001);checks+=1
 var floor:Node3D=n.find_child("ClosedRoadFloor",true,false);assert(floor!=null and bounds(floor).size.x>=31.999);checks+=1
 var end:Node3D=n.find_child("ClosedDarkEnd",true,false);assert(end!=null and abs(bounds(end).size.z-11)<.002 and abs(bounds(end).position.y+6.64)<.002);checks+=1
 var barriers:=n.find_children("Side*_Barrier","MeshInstance3D",true,false)
 # Blender names acquire unique numeric suffixes across appended modules.
 var count:=0
 for m in n.find_children("Side*","MeshInstance3D",true,false):
  if "_Barrier" in m.name and not "Edge" in m.name and not "Joint" in m.name:
   var b:=bounds(m);assert(abs(b.size.y-1.1)<.002);count+=1
 assert(count==16);checks+=1
 var tri:=0
 for m in n.find_children("*","MeshInstance3D",true,false):
  for surf in range(m.mesh.get_surface_count()):
   var arr:Array=m.mesh.surface_get_arrays(surf);tri+=int(arr[Mesh.ARRAY_INDEX].size()/3) if arr[Mesh.ARRAY_INDEX]!=null else int(arr[Mesh.ARRAY_VERTEX].size()/3)
 assert(tri==2760 and tri<=6000);checks+=1
 assert(abs(bounds(person).size.y-1.75)<.002 and bounds(car).size.y<2.1);checks+=1
 print("TUNNEL_MEASURED bounds=",bb," triangles=",tri," mouth4.5m front+X closed floor/end; car nominal4.85x1.87x1.48m/person1.75m")
func run():
 canvas=SubViewport.new();canvas.size=Vector2i(1600,1000);canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(canvas)
 var bg:=ColorRect.new();bg.size=Vector2(1600,1000);bg.color=Color("172d35");canvas.add_child(bg)
 label("TUNNEL / approved entrance sample / 32 x 16m / original 4m concrete members",Vector2(24,15),27)
 label("FRONT +X / car entering / 1.75m person on ground",Vector2(24,68),21)
 label("REVERSE / mouth faces away / closed cover end",Vector2(814,68),21)
 populate(stage(Vector2(20,110),false),true);populate(stage(Vector2(810,110),true),false)
 label("Road width 12m / inner trench 11m / asphalt 10.5m / grade 8%",Vector2(24,875),23)
 label("24m open trench: -4.08 to -6.00m / 8m covered: -6.00 to -6.64m / mouth clearance 4.50m",Vector2(24,915),23)
 label("Inspection only / no terrain cutting, placement, traffic operation, pier or rail fixture implemented.",Vector2(24,960),21)
 for i in range(20):await process_frame
 await RenderingServer.frame_post_draw
 var im:=canvas.get_texture().get_image();assert(im.get_size()==Vector2i(1600,1000));assert(im.save_png(OS.get_cmdline_user_args()[0])==OK)
 print("TUNNEL_SAMPLE_PASS checks=",checks," actual GL imported catalog model; two fixed-framebuffer views");quit()
