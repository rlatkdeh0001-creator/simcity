extends SceneTree
var canvas:SubViewport
var checks:=0
const IDS=["viaduct-side-01","retaining-wall-01","tunnel-portal-01"]
const FILES=["deck_side","wall","portal"]
const HEIGHTS=[248,720,208]
func _initialize():run.call_deferred()
func label(t:String,p:Vector2,s:int=20):
 var l:=Label.new();l.text=t;l.position=p;l.add_theme_font_size_override("font_size",s);canvas.add_child(l)
func tex(i:int)->Texture2D:return load("res://assets/structures/"+IDS[i]+"/"+FILES[i]+".png")
func sprite(t:Texture2D,p:Vector2,sz:Vector2):
 var n:=Sprite2D.new();n.texture=t;n.centered=false;n.position=p;n.scale=sz/Vector2(t.get_size());canvas.add_child(n)
func lum(im:Image)->float:
 var sum:=0.
 for y in range(im.get_height()):
  for x in range(im.get_width()):
   var c:=im.get_pixel(x,y);sum+=c.r*.2126+c.g*.7152+c.b*.0722
 return sum/(im.get_width()*im.get_height())
func shade_view(i:int,axis:int)->SubViewport:
 var v:=SubViewport.new();v.size=Vector2i(320,HEIGHTS[i]);v.own_world_3d=true;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(v)
 var e:=WorldEnvironment.new();e.environment=Environment.new();e.environment.background_mode=Environment.BG_COLOR;e.environment.background_color=Color.BLACK;e.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.environment.ambient_light_color=Color("d9e4f0");e.environment.ambient_light_energy=.75;v.add_child(e)
 var l:=DirectionalLight3D.new();l.rotation_degrees=Vector3(-55,-35,0);l.light_energy=1.1;v.add_child(l)
 var n:Node3D=load("res://"+IDS[i]+".glb").instantiate();v.add_child(n)
 # Blender -Y becomes Godot +Z; rotate member to face Godot +X.
 if axis==0:n.rotation_degrees.y=90
 var c:=Camera3D.new();c.projection=Camera3D.PROJECTION_ORTHOGONAL;c.keep_aspect=Camera3D.KEEP_HEIGHT;c.size=HEIGHTS[i]/80.;v.add_child(c)
 var target:=Vector3(0,1.1-HEIGHTS[i]/160.,0);c.position=target+(Vector3(20,0,0) if axis==0 else Vector3(0,0,20));c.look_at(target);c.current=true
 return v
func run():
 canvas=SubViewport.new();canvas.size=Vector2i(1600,1000);canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(canvas)
 var bg:=ColorRect.new();bg.size=Vector2(1600,1000);bg.color=Color("172d35");canvas.add_child(bg)
 label("CONCRETE / 4m original members / 80px per metre / unlit vertical strips",Vector2(24,12),26)
 var views:Array=[]
 for i in range(3):
  var t:=tex(i);assert(t.get_size()==Vector2(320,HEIGHTS[i]));checks+=1
  views.append([shade_view(i,0),shade_view(i,1)])
  # Three repeat panels at half source size, each 12m wide.
  var x:=24+i*520
  label(IDS[i]+" / 3 repeats",Vector2(x,65),20)
  for j in range(3):sprite(t,Vector2(x+j*160,100),Vector2(160,HEIGHTS[i]*.5))
  var atlas:=AtlasTexture.new();atlas.atlas=t;atlas.region=Rect2(0,0,320,112)
  sprite(atlas,Vector2(x,525),Vector2(480,168))
  label("Shared top 112px / barrier + cap",Vector2(x,495),19)
 var inner:Texture2D=load("res://assets/structures/viaduct-side-01/barrier_inner.png");assert(inner.get_size()==Vector2(320,88));checks+=1
 label("Inner barrier / 3 repeats",Vector2(24,265),19)
 for j in range(3):sprite(inner,Vector2(24+j*160,298),Vector2(160,44))
 label("Native game-scale repeats: 2.5px/m (left) / 11.7px/m (right); no enlargement",Vector2(24,725),22)
 for i in range(3):
  var x:=24+i*520
  for j in range(3):
   sprite(tex(i),Vector2(x+j*10,775),Vector2(10,HEIGHTS[i]/80.*2.5))
   sprite(tex(i),Vector2(x+120+j*46.8,775),Vector2(46.8,HEIGHTS[i]/80.*11.7))
 for k in range(20):await process_frame
 await RenderingServer.frame_post_draw
 var result:Dictionary={}
 for i in range(3):
  var ratios:Dictionary={}
  for axis in range(2):ratios["+X" if axis==0 else "-Y"]=lum(views[i][axis].get_texture().get_image())/lum(tex(i).get_image())
  result[IDS[i]]=ratios
  label("Measured face_shade +X %.4f / -Y %.4f"%[ratios["+X"],ratios["-Y"]],Vector2(24+i*520,910),19)
  checks+=2
 label("Inspection only / no pier, elevated sample or rail fixture; placement remains code-side.",Vector2(24,960),21)
 for k in range(3):await process_frame
 await RenderingServer.frame_post_draw
 var im:=canvas.get_texture().get_image();assert(im.get_size()==Vector2i(1600,1000));assert(im.save_png(OS.get_cmdline_user_args()[0])==OK)
 var f:=FileAccess.open(OS.get_cmdline_user_args()[1],FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
 print("ELEVATED_STRIPS_PASS checks=",checks," sizes/load and six actual lit-face measurements");quit()
