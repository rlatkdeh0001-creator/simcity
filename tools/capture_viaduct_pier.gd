extends "res://common.gd"
const PPM=36.95041722813605 # vertical axis = exactly32px per metre at30deg
var textures:Dictionary={}
var parts:Dictionary={}
func render_part(part:String,size:Vector2i,target_y:float)->Dictionary:
 var v:=SubViewport.new();v.size=size;root.add_child(v);lighting(v,true)
 var n:=model(v,"res://assets/structures/viaduct-pier-01/viaduct-pier-01.glb")
 for m in n.find_children("*","MeshInstance3D",true,false):m.visible=m.name==part
 if part=="PierCap":n.position.y=-6
 var c:=Camera3D.new();c.projection=Camera3D.PROJECTION_ORTHOGONAL;c.keep_aspect=Camera3D.KEEP_HEIGHT;c.size=size.y/PPM;v.add_child(c)
 var target:=Vector3(0,target_y,0);c.position=target+Vector3(30,24.49489743,30);c.look_at(target);c.current=true
 return {"viewport":v,"camera":c}
func add_sprite(key:String,p:Vector2,scale_xy:Vector2):
 var n:=Sprite2D.new();n.centered=false;n.texture=textures[key];n.position=p;n.scale=scale_xy;canvas.add_child(n)
func stack(x:float,y:float,h:float,scale_value:float=1.):
 var overlap:=PPM*.5
 var cap_y:=y-(h-4)*32*scale_value
 var shaft_top:=cap_y-overlap*scale_value
 var shaft_bottom:=y-.3*32*scale_value+overlap*scale_value
 add_sprite("shaft",Vector2(x-parts.shaft.origin_pixel[0]*scale_value,shaft_top),Vector2(scale_value,(shaft_bottom-shaft_top)/32))
 add_sprite("base",Vector2(x,y)-Vector2(parts.base.origin_pixel[0],parts.base.origin_pixel[1])*scale_value,Vector2.ONE*scale_value)
 add_sprite("cap",Vector2(x,cap_y)-Vector2(parts.cap.origin_pixel[0],parts.cap.origin_pixel[1])*scale_value,Vector2.ONE*scale_value)
func run():
 var output:=OS.get_cmdline_user_args()[1]
 var jobs:Dictionary={}
 if OS.get_cmdline_user_args().has("--reuse-parts"):
  parts=JSON.parse_string(FileAccess.get_file_as_string(output+"/render_manifest.json")).parts
  for key in parts:textures[key]=ImageTexture.create_from_image(Image.load_from_file(output+"/pier_"+key+".png"));checks+=1
 else:jobs={"cap":render_part("PierCap",Vector2i(192,144),1.),"base":render_part("PierBase",Vector2i(192,80),.15),"shaft":render_part("PierShaft",Vector2i(192,32),3.15)}
 for k in range(20):await process_frame
 await RenderingServer.frame_post_draw
 for key in jobs:
  var im:Image=jobs[key].viewport.get_texture().get_image();assert(im.save_png(output+"/pier_"+key+".png")==OK);textures[key]=ImageTexture.create_from_image(im)
  var origin:Vector2=jobs[key].camera.unproject_position(Vector3.ZERO)
  parts[key]={"file":"pier_"+key+".png","resolution":[im.get_width(),im.get_height()],"origin_pixel":[origin.x,origin.y] if key!="shaft" else [origin.x,0.],"origin_definition":"axis at part bottom" if key!="shaft" else "axis x; cropped middle1m with no ellipse ends"}
  checks+=1
 var manifest={"camera_elevation_deg":30,"angles_deg":[0],"pixels_per_metre":PPM,"vertical_pixels_per_metre":32,"rotationally_symmetric":true,"light":{"rotation_degrees":[-55,-35,0],"energy":1.1,"ambient_color":"d9e4f0","ambient_energy":.75,"shadows":false},"parts":parts,"assembly":{"draw_order":["shaft","base","cap"],"base_z_m":0,"shaft_bottom_m":.3,"cap_bottom_m":"h-4.0","shaft_underlap_pixels_each_end":PPM*.5,"shaft_stretch":"height=(h-4.3)*32+2*underlap; upper y=project(h-4)-underlap"},"renderer":"Godot4.6.3 Compatibility actual transparent orthographic framebuffer"}
 var f:=FileAccess.open(output+"/render_manifest.json",FileAccess.WRITE);f.store_string(JSON.stringify(manifest,"  "));f.close()
 make_canvas();label("PIER / confirmed round column + flared head / actual three-part sprites",Vector2(24,16),27)
 for pair in [[140.,5.],[380.,10.],[650.,20.]]:
  stack(pair[0],730,pair[1]);label("Deck h=%.0fm"%pair[1],Vector2(pair[0]-75,770),23)
 label("Column D2.0m / cap D4.0m x2.0m / base D2.6m x0.3m",Vector2(24,840),22)
 label("Same source / 48 radial segments / parts 852 triangles",Vector2(24,883),22)
 var v:=stage(Vector2(870,85),Vector2i(710,420),36,Vector3(0,4,0))
 for z in [-5.,5.]:model(v,"res://assets/structures/viaduct-pier-01/viaduct-pier-01.glb",Vector3(0,0,z))
 cube(v,"WideDeck",Vector3(8,2,20),Vector3(0,9,0),"8f948f");cube(v,"Road",Vector3(8,.01,20),Vector3(0,10.005,0),"4c5659")
 model(v,"res://assets/vehicles/car-sedan-03.glb",Vector3(7,0,0));person(v,Vector3(5,0,5))
 label("20m deck / twin axes +/-5m / sedan +1.75m person",Vector2(870,53),20)
 label("Joint close-up / same sprite assembly",Vector2(875,535),20);stack(1020,860,5,1.6)
 label("Native game scale / h10m",Vector2(1230,575),20)
 stack(1280,840,10,2.5/PPM);stack(1440,840,10,11.7/PPM)
 label("2.5px/m       11.7px/m",Vector2(1230,875),19)
 var n:=model(v,"res://assets/structures/viaduct-pier-01/viaduct-pier-01.glb",Vector3(0,0,40));n.hide();assert(bounds(n).size.is_equal_approx(Vector3(4,8,4)));checks+=1
 for name in ["PierBase","PierShaft","PierCap"]:assert(n.find_child(name,true,false)!=null);checks+=1
 label("Assembly: shaft first, then base and cap; calibrated origin pixels + ellipse underlap in manifest.",Vector2(24,960),21)
 await finish(OS.get_cmdline_user_args()[0],"PIER_SPRITES_PASS")
