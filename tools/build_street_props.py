"""Original metre-scale geometry. Run Blender -b -P <asset>/build.py.
No external artwork; palettes match edda3f3 vehicle signals. MIT project code.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[1]

def material(name,h,on=False):
 c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
 c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
 m=bpy.data.materials.new(name);m.use_nodes=True;m.use_fake_user=True
 b=m.node_tree.nodes['Principled BSDF'];b.inputs['Base Color'].default_value=(*c,1);b.inputs['Roughness'].default_value=.32 if on else .88
 b.inputs['Emission Color'].default_value=(*c,1);b.inputs['Emission Strength'].default_value=2 if on else 0
 return m

def box(name,p,d,m):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.name=name;o.dimensions=d
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m);return o

def cylinder(name,p,r,h,m,axis='Z',n=24):
 bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=h,location=p,rotation=(math.pi/2,0,0) if axis=='Y' else (0,0,0))
 o=bpy.context.object;o.name=name;o.data.materials.append(m);return o

def join(parts,name,pivot=None):
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=parts[0];o.name=name
 if pivot is not None:
  bpy.context.scene.cursor.location=pivot;bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 return o

def segment(name,a,b,w,m):
 d=Vector(b)-Vector(a);o=box(name,(Vector(a)+Vector(b))/2,(w,.015,d.length),m);o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o

def geometry(exclude_arm=False):
 bpy.context.view_layer.update();pts=[];tri=0
 for o in bpy.context.scene.objects:
  if o.type!='MESH' or (exclude_arm and o.name=='arm'):continue
  pts.extend(o.matrix_world@v.co for v in o.data.vertices);tri+=sum(len(p.vertices)-2 for p in o.data.polygons)
 lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
 return lo,hi,tri

def build(ident):
 crossing=ident=='rail-crossing-signal-01'
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.context.preferences.filepaths.save_version=0
 s=bpy.context.scene;s.unit_settings.system='METRIC';s.unit_settings.scale_length=1
 frame=material('mat_frame','354640');black=material('mat_black','151b19');yellow=material('mat_warning_yellow','efbd32');hardware=material('mat_hardware','5c6962')
 names=['lamp_left','lamp_right'] if crossing else ['lamp_ped_red','lamp_ped_green']
 for i,n in enumerate(names):
  material('mat_'+n+'_on','f23e32' if crossing or i==0 else '3de878',True)
  material('mat_'+n+'_off','30100c' if crossing or i==0 else '102b18')
 height=3.85 if crossing else 3.35;radius=.08 if crossing else .06
 cylinder('Pole',(0,0,height/2),radius,height,frame,n=32 if crossing else 16)
 box('BasePlate',(0,0,.025),(.28,.28,.05),frame)
 for x in [-.10,.10]:
  for y in [-.10,.10]:cylinder('AnchorBolt',(x,y,.06),.018,.02,hardware,n=6)
 if crossing:
  for i in range(5):cylinder('WarningPoleBand',(0,0,.1+i*.2),.081,.2,yellow if i%2==0 else black,n=32)
  for angle in [-45,45]:
   o=box('CrossbuckBack',(0,-.10,3.25),(1.30,.03,.22),frame);o.rotation_euler.y=math.radians(angle)
   o=box('CrossbuckBlackBorder',(0,-.117,3.25),(1.30,.004,.22),black);o.rotation_euler.y=math.radians(angle)
   o=box('CrossbuckYellowFace',(0,-.120,3.25),(1.24,.002,.16),yellow);o.rotation_euler.y=math.radians(angle)
  box('WarningHeadSupport',(0,0,2.30),(1.03,.12,.10),frame)
  for n,x in zip(names,[-.4,.4]):
   cylinder(n+'_backboard',(x,-.10,2.30),.31,.04,black,'Y',32)
   cylinder(n+'_rim',(x,-.145,2.30),.235,.055,frame,'Y',32)
   cylinder(n,(x,-.181,2.30),.21,.018,bpy.data.materials['mat_'+n+'_off'],'Y',32)
   box(n+'_hood',(x,-.21,2.57),(.48,.30,.025),black)
   for side in [-1,1]:box(n+'_hood_side',(x+side*.232,-.21,2.51),(.016,.30,.12),black)
  box('BarrierHousing',(-.26,0,.8),(.36,.30,.70),yellow)
  box('BarrierServicePanel',(-.26,-.155,.8),(.28,.012,.49),frame)
  cylinder('ArmPivotBearing',(-.30,-.035,1),.115,.10,hardware,'Y',24)
  parts=[]
  for i in range(6):
   length=min(1,5.25-i)
   parts.append(box('ArmStripe',(-.30-i-length/2,-.05,1),(length,.16,.16),yellow if i%2==0 else black))
  arm=join(parts,'arm',(-.30,-.05,1));arm['preview_only']=True;arm['sprite_excluded']=True
 else:
  box('HeadHousing',(0,-.13,2.79),(.48,.22,.98),frame)
  box('HeadFront',(0,-.242,2.79),(.455,.004,.95),black)
  for i,n in enumerate(names):
   z=3.02 if i==0 else 2.56
   box(n+'_lens',(0,-.250,z),(.40,.012,.40),black)
   box(n+'_hood',(0,-.295,z+.207),(.44,.19,.018),frame)
   for x in [-.212,.212]:box(n+'_hood_side',(x,-.295,z+.155),(.016,.19,.10),frame)
   m=bpy.data.materials['mat_'+n+'_off'];y=-.266
   parts=[cylinder('HumanHead',(0,y,z+.115),.038,.014,m,'Y',12)]
   if i==0:
    pairs=[((0,.065),(0,-.035)),((-.045,.055),(-.065,-.045)),((.045,.055),(.065,-.045)),((-.018,-.03),(-.04,-.155)),((.018,-.03),(.04,-.155))]
   else:
    pairs=[((.015,.065),(-.025,-.035)),((.01,.045),(-.085,-.01)),((.01,.045),(.095,.005)),((-.02,-.03),(-.10,-.145)),((-.02,-.03),(.09,-.12))]
   for a,b in pairs:parts.append(segment('HumanLimb',(a[0],y,z+a[1]),(b[0],y,z+b[1]),.037,m))
   join(parts,n,(0,y,z))
 for n in names:
  o=bpy.data.objects[n];o['material_on']='mat_'+n+'_on';o['material_off']='mat_'+n+'_off';o['switch_material_slot']=0
 def state(enabled):
  for n in names:
   o=bpy.data.objects[n]
   for j in range(len(o.data.materials)):o.data.materials[j]=bpy.data.materials['mat_'+n+('_on' if n in enabled else '_off')]
 lo,hi,tri=geometry(True);alllo,allhi,alltri=geometry()
 assert (800<=tri<=2000) if crossing else (300<=tri<=900),(ident,tri)
 src=ROOT/'assets/street-furniture'/ident;src.mkdir(parents=True,exist_ok=True)
 runtime=ROOT/'cities_do/assets/street_furniture';runtime.mkdir(parents=True,exist_ok=True)
 spec=dict(id=ident,name='건널목 경보기·차단기' if crossing else '보행자 신호등',category='street-furniture',style='traffic-signal',status='inspection_only',height_m=hi[2],pole_height_m=height,pole_diameter_m=radius*2,head_clearance_m=1.99 if crossing else 2.30,lamp_materials={n:['mat_'+n+'_on','mat_'+n+'_off'] for n in names},frame_blender={'forward':'-Y','up':'+Z'},frame_gltf={'forward':'+Z','up':'+Y'},origin='pole base center, z=0',triangles=tri,triangles_including_arm=alltri,vertex_bounds_m=[lo,hi],measured_dimensions_m=[hi[i]-lo[i] for i in range(3)],all_mesh_dimensions_m=[allhi[i]-alllo[i] for i in range(3)],default_state='all_off',source='original scripted geometry; no external images, textures or models',game_registered=False,not_validated=['placement','signal timing','traffic AI'],material_definitions={})
 for n in names:
  for st in ['on','off']:
   key='mat_'+n+'_'+st;b=bpy.data.materials[key].node_tree.nodes['Principled BSDF'];spec['material_definitions'][key]={'base_color_linear':list(b.inputs['Base Color'].default_value),'emission_strength':b.inputs['Emission Strength'].default_value}
 if crossing:
  spec['lamp_centres_blender_m']=[[-.4,-.181,2.30],[.4,-.181,2.30]];spec['lamp_diameter_m']=.42
  spec['arm']={'object':'arm','pivot_blender_m':[-.30,-.05,1.0],'lowered_direction_blender':'-X','reference_length_m':5.25,'cross_section_m':[.16,.16],'stripe_length_m':1.0,'yellow_hex':'efbd32','black_hex':'151b19','source_pose':'lowered','sprite_excluded':True,'runtime_draw':'game procedural arm; GLB arm is preview only'}
 else:spec['head_dimensions_m']=[.48,.22,.98];spec['lens_dimensions_m']=[.40,.40];spec['lamp_order_top_to_bottom']=names
 (src/'spec.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 cd=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',cd);s.collection.objects.link(cam);s.camera=cam;cd.type='ORTHO'
 def camera(az,scale,target):
  a=math.radians(az);t=Vector(target);cam.location=t+Vector((20*math.sin(a),-20*math.cos(a),20*math.tan(math.pi/6)));cam.rotation_euler=(t-cam.location).to_track_quat('-Z','Y').to_euler();cd.ortho_scale=scale;bpy.context.view_layer.update()
 s.world=bpy.data.worlds.new('Studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.7,.75,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.7
 ld=bpy.data.lights.new('Key','AREA');light=bpy.data.objects.new('Key',ld);s.collection.objects.link(light);light.location=(2,-8,10);ld.energy=1300;ld.size=8
 light.rotation_euler=(Vector((0,0,2))-light.location).to_track_quat('-Z','Y').to_euler()
 s.render.engine='CYCLES';s.cycles.samples=16;s.cycles.use_denoising=False;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.resolution_percentage=100;s.view_settings.view_transform='Standard'
 camera(25,8 if crossing else 4.5,(-2,0,1.8) if crossing else (0,0,1.65));s.render.resolution_x=512;s.render.resolution_y=512
 state([]);bpy.ops.wm.save_as_mainfile(filepath=str(src/'signal.blend'))
 bpy.ops.object.select_all(action='DESELECT')
 for o in s.objects:
  if o.type=='MESH':o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(runtime/(ident+'.glb')),export_format='GLB',use_selection=True,export_extras=True)
 for st,enabled in [('off',[]),('on',names)]:
  state(enabled);s.render.filepath=str(src/('preview-'+st+'.png'));bpy.ops.render.render(write_still=True)
 if crossing:bpy.data.objects['arm'].hide_render=True
 folder=runtime/'sprites'/ident;folder.mkdir(parents=True,exist_ok=True)
 s.render.resolution_x=256;s.render.resolution_y=256
 states={'off':[],'left':[names[0]],'right':[names[1]]} if crossing else {'off':[],'red':[names[0]],'green':[names[1]]}
 sprites=[]
 for st,enabled in states.items():
  state(enabled)
  for az in range(0,360,45):
   camera(az,256/48,(0,0,1.8));p=world_to_camera_view(s,cam,Vector((0,0,0)))
   file=folder/(st+'_'+str(az).zfill(3)+'.png');s.render.filepath=str(file);bpy.ops.render.render(write_still=True)
   sprites.append({'state':st,'azimuth_degrees':az,'file':file.relative_to(runtime).as_posix(),'origin_pixel':[p.x*256,(1-p.y)*256]})
 manifest_path=runtime/'render_manifest.json'
 manifest=json.loads(manifest_path.read_text()) if manifest_path.exists() else {'camera_elevation_degrees':30,'azimuth_degrees':list(range(0,360,45)),'assets':{}}
 manifest['assets'][ident]={'status':'inspection_only','pixels_per_metre':48,'states':list(states),'sprite_size':[256,256],'arm_in_sprites':False,'sprites':sprites}
 manifest_path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
 bpy.ops.wm.open_mainfile(filepath=str(src/'signal.blend'))
 for n in names:assert all(m.name=='mat_'+n+'_off' for m in bpy.data.objects[n].data.materials)
 if crossing:
  o=bpy.data.objects['arm'];assert (o.location-Vector((-.30,-.05,1))).length<1e-6 and abs(o.dimensions.x-5.25)<1e-5 and not o.hide_render
 assert abs(bpy.data.objects['Pole'].dimensions.z-height)<1e-5
 print('STREET_PROP_SOURCE_PASS',ident,tri,spec['measured_dimensions_m'],flush=True)
