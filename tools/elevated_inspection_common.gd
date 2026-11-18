extends SceneTree
var canvas:SubViewport
var checks:=0
func _initialize():run.call_deferred()
func run():pass
func make_canvas():
 canvas=SubViewport.new();canvas.size=Vector2i(1600,1000);canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(canvas)
 var bg:=ColorRect.new();bg.size=Vector2(1600,1000);bg.color=Color("172d35");canvas.add_child(bg)
func label(t:String,p:Vector2,s:int=21):
 var l:=Label.new();l.text=t;l.position=p;l.add_theme_font_size_override("font_size",s);canvas.add_child(l)
func bounds(n:Node3D)->AABB:
 if n is MeshInstance3D:return n.global_transform*n.get_aabb()
 var b:=AABB();var first:=true
 for m in n.find_children("*","MeshInstance3D",true,false):
  var a:AABB=m.global_transform*m.get_aabb()
  if first:b=a;first=false
  else:b=b.merge(a)
 return b
func model(v:SubViewport,path:String,p:Vector3=Vector3.ZERO,yaw:float=0)->Node3D:
 var n:Node3D=load(path).instantiate();v.add_child(n);n.position=p;n.rotation_degrees.y=yaw;return n
func lighting(v:SubViewport,transparent:bool=false):
 v.own_world_3d=true;v.transparent_bg=transparent;v.msaa_3d=Viewport.MSAA_4X;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 var e:=WorldEnvironment.new();e.environment=Environment.new();e.environment.background_mode=Environment.BG_CLEAR_COLOR if transparent else Environment.BG_COLOR;e.environment.background_color=Color("334851");e.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.environment.ambient_light_color=Color("d9e4f0");e.environment.ambient_light_energy=.75;v.add_child(e)
 var l:=DirectionalLight3D.new();l.rotation_degrees=Vector3(-55,-35,0);l.light_energy=1.1;v.add_child(l)
func stage(pos:Vector2,sz:Vector2i,span:float,target:Vector3,direction:Vector3=Vector3(30,24.4949,30))->SubViewport:
 var h:=SubViewportContainer.new();h.position=pos;canvas.add_child(h)
 var v:=SubViewport.new();v.size=sz;h.add_child(v);lighting(v)
 var c:=Camera3D.new();c.projection=Camera3D.PROJECTION_ORTHOGONAL;c.keep_aspect=Camera3D.KEEP_WIDTH;c.size=span;v.add_child(c);c.position=target+direction;c.look_at(target);c.current=true
 return v
func cube(v:SubViewport,n:String,size:Vector3,p:Vector3,color:String)->MeshInstance3D:
 var m:=MeshInstance3D.new();m.name=n;var b:=BoxMesh.new();b.size=size;m.mesh=b;var mat:=StandardMaterial3D.new();mat.albedo_color=Color(color);mat.roughness=1.;m.material_override=mat;v.add_child(m);m.position=p;return m
func person(v:SubViewport,p:Vector3):
 var m:=MeshInstance3D.new();var c:=CapsuleMesh.new();c.height=1.75;c.radius=.19;m.mesh=c;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("dcaa72");m.material_override=mat;v.add_child(m);m.position=p+Vector3(0,.875,0)
func finish(path:String,marker:String):
 for k in range(16):await process_frame
 await RenderingServer.frame_post_draw
 var im:=canvas.get_texture().get_image();assert(im.get_size()==Vector2i(1600,1000));assert(im.save_png(path)==OK)
 print(marker," checks=",checks);quit()
