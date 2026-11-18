extends "res://common.gd"
func quad(v:SubViewport,pts:PackedVector3Array,uv:PackedVector2Array,mat:Material):
 var a:Array=[];a.resize(Mesh.ARRAY_MAX);a[Mesh.ARRAY_VERTEX]=pts;a[Mesh.ARRAY_TEX_UV]=uv;a[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a);var n:=MeshInstance3D.new();n.mesh=mesh;n.material_override=mat;v.add_child(n)
func flat(color:String)->StandardMaterial3D:
 var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=Color(color);m.cull_mode=BaseMaterial3D.CULL_DISABLED;return m
func curve(v:SubViewport):
 var mat:=flat("ffffff");mat.albedo_texture=load("res://assets/structures/viaduct-side-01/deck_side.png");mat.texture_repeat=true
 var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://side-spec.json"));var shade:float=spec.face_shade["+X"];mat.albedo_color=Color(shade,shade,shade)
 var road:=flat("4c5659");var top:=flat("b9bbb3")
 for j in range(48):
  var a:=lerpf(-.23,.23,j/48.);var b:=lerpf(-.23,.23,(j+1)/48.)
  var p:=Vector3(cos(a),0,sin(a));var q:=Vector3(cos(b),0,sin(b));var offset:=Vector3(-64,0,0)
  quad(v,PackedVector3Array([p*58+Vector3(0,10,0)+offset,q*58+Vector3(0,10,0)+offset,q*70+Vector3(0,10,0)+offset,p*70+Vector3(0,10,0)+offset]),PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]),road)
  for radius in [58.,70.]:
   quad(v,PackedVector3Array([p*radius+Vector3(0,11.1,0)+offset,q*radius+Vector3(0,11.1,0)+offset,q*radius+Vector3(0,8,0)+offset,p*radius+Vector3(0,8,0)+offset]),PackedVector2Array([Vector2((a+.23)*radius/4,0),Vector2((b+.23)*radius/4,0),Vector2((b+.23)*radius/4,1),Vector2((a+.23)*radius/4,1)]),mat)
   var inside:float=radius+.4 if radius<64 else radius-.4
   quad(v,PackedVector3Array([p*radius+Vector3(0,11.1,0)+offset,q*radius+Vector3(0,11.1,0)+offset,q*inside+Vector3(0,11.1,0)+offset,p*inside+Vector3(0,11.1,0)+offset]),PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]),top)
 checks+=1
func run():
 make_canvas();label("VIADUCT / 40 x 12m / deck+10m / closed ends and underside / 8m clearance",Vector2(24,15),27)
 var v:=stage(Vector2(20,90),Vector2i(1010,790),59,Vector3(0,4,0))
 var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/facilities/catalog.json"));var e:Dictionary=catalog.facilities.filter(func(row):return row.id=="viaduct-sample-01")[0]
 var n:=model(v,e.model);var bb:=bounds(n);assert(abs(bb.size.x-40)<.002 and abs(bb.size.z-12)<.002 and abs(bb.end.y-11.1)<.002);checks+=1
 assert(e.kind=="structure_sample" and e.status=="inspection_only");checks+=1
 var core:Node3D=n.find_child("ClosedDeckCore",true,false);assert(abs(bounds(core).position.y-8)<.002);checks+=1
 var supports:=n.find_children("Support*PierCap*","MeshInstance3D",true,false);assert(supports.size()==2)
 for m in supports:assert(abs(bounds(m).end.y-8)<.002 and abs(abs(bounds(m).get_center().x)-16)<.002)
 checks+=1
 cube(v,"GroundRoad",Vector3(12,.10,40),Vector3(0,-.05,0),"c8cbc3");cube(v,"GroundAsphalt",Vector3(10.5,.01,40),Vector3(0,.005,0),"4c5659")
 for z in range(-18,20,6):cube(v,"GroundCentreLine",Vector3(.12,.01,3),Vector3(0,.015,z),"d9d3b6")
 model(v,"res://assets/vehicles/car-sedan-03.glb",Vector3(-7,10,2.5),90);model(v,"res://assets/vehicles/car-sedan-03.glb",Vector3(7,10,-2.5),-90)
 model(v,"res://assets/vehicles/car-sedan-03.glb",Vector3(2.5,.01,10),180);person(v,Vector3(7,0,10))
 var curved:=stage(Vector2(1050,150),Vector2i(530,620),39,Vector3(0,9,0),Vector3(38,30,24));curve(curved)
 label("2 cars above / road +car below / person1.75m",Vector2(24,55),21)
 label("CURVE FIXTURE / centre radius64m",Vector2(1050,105),20)
 label("Actual deck_side texture / period4m",Vector2(1050,795),20)
 label("Surface width12m; side UV follows arc length",Vector2(1050,830),18)
 label("Pier spacing32m at x+/-16m / 4404 triangles / source front -Y / original solid geometry",Vector2(24,915),23)
 label("Inspection only; arbitrary road placement, height layering and traffic remain code-side work.",Vector2(24,960),21)
 await finish(OS.get_cmdline_user_args()[0],"VIADUCT_SAMPLE_PASS")
