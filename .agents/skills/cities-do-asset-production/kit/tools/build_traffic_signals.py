"""Original source-only four-aspect signals. No GLB, game placement or timing controller.
blender -b --factory-startup -t 4 -P tools/build_traffic_signals.py
"""
from pathlib import Path
import bpy,sys,math,json,importlib.util
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[1]
s=importlib.util.spec_from_file_location('fleet_materials',ROOT/'tools/build_vehicle_fleet.py');B=importlib.util.module_from_spec(s);s.loader.exec_module(B)
LAMPS=['lamp_red','lamp_yellow','lamp_left_arrow','lamp_green']
PALETTE={'frame':'354640','backboard':'151b19','housing':'222b28','rim':'101713','arrow_backing':'07110b','hardware':'5c6962'}
ON=['f23e32','ffcb35','3de878','3de878'];OFF=['30100c','302607','102b18','102b18']

def empty(name,parent=None,location=(0,0,0)):
 o=B.C.empty(name,location)
 if parent:o.parent=parent
 return o

def mesh(name,vertices,faces,material,parent):
 data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.materials.append(material);data.update();o=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(o);o.parent=parent;return o

def box(name,center,size,mat,parent):
 x,y,z=[v/2 for v in size];cx,cy,cz=center
 vs=[(cx+a,cy+b,cz+c) for a,b,c in [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]]
 return mesh(name,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat,parent)

def cylinder(name,center,radius,length,mat,parent,axis='Z',segments=12):
 vs=[]
 for depth in [-length/2,length/2]:
  for i in range(segments):
   c=radius*math.cos(i*math.tau/segments);s=radius*math.sin(i*math.tau/segments)
   v=Vector((c,s,depth) if axis=='Z' else (c,depth,s));vs.append(tuple(Vector(center)+v))
 n=segments
 if axis=='Z':faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
 else:faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]+[(j,j+n,(j+1)%n+n,(j+1)%n) for j in range(n)]
 ob=mesh(name,vs,faces,mat,parent)
 for p in ob.data.polygons:
  if len(p.vertices)==4:p.use_smooth=True
 return ob

def bar(name,a,b,width,mat,parent):
 d=Vector(b)-Vector(a);o=box(name,(0,0,0),(width,width,d.length),mat,parent);o.location=(Vector(a)+Vector(b))/2;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o

def visor(x,index,mat,parent):
 vs=[];steps=6
 for radius in [.267,.254]:
  for y in [-.20,-.51]:
   vs.extend([(x+radius*math.cos(j*math.pi/steps),y,radius*math.sin(j*math.pi/steps)) for j in range(steps+1)])
 n=steps+1;faces=[]
 for j in range(steps):
  faces.extend([(j,j+1,n+j+1,n+j),(2*n+j,3*n+j,3*n+j+1,2*n+j+1),(j,2*n+j,2*n+j+1,j+1),(n+j,n+j+1,3*n+j+1,3*n+j)])
 faces.extend([(0,n,3*n,2*n),(steps,2*n+steps,3*n+steps,n+steps)])
 return mesh('visor_%d'%index,vs,faces,mat,parent)

def arrow(mat,parent,x):
 # Front viewer is at -Y looking +Y: negative X is the visible left arrow direction.
 polygon=[(-.19,0),(-.035,.135),(-.035,.055),(.17,.055),(.17,-.055),(-.035,-.055),(-.035,-.135)]
 polygon.reverse()  # Counter-clockwise X/Z gives the forward cap an outward -Y normal.
 vs=[(x+a,y,z) for y in [-.292,-.306] for a,z in polygon];n=len(polygon)
 faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
 return mesh('lamp_left_arrow',vs,faces,mat,parent)

def make_materials():
 mats={name:B.material('mat_'+name,color) for name,color in PALETTE.items()}
 for name,on,off in zip(LAMPS,ON,OFF):
  for state,color in [('on',on),('off',off)]:
   mat=B.material('mat_'+name+'_'+state,color);mat.use_fake_user=True;node=mat.node_tree.nodes['Principled BSDF'];node.inputs['Roughness'].default_value=.32 if state=='on' else .88
   node.inputs['Emission Color'].default_value=node.inputs['Base Color'].default_value;node.inputs['Emission Strength'].default_value=2.0 if state=='on' else 0.0
   mats[name+'_'+state]=mat
 return mats

def head(root,location,mats):
 parent=empty('SignalHead',root,location)
 box('HeadBackboard',(0,0,0),(2.60,.05,.84),mats['backboard'],parent)
 box('HeadHousing',(0,-.105,0),(2.44,.18,.67),mats['housing'],parent)
 for i,name in enumerate(LAMPS):
  x=(i-1.5)*.60
  cylinder('lens_rim_%d'%i,(x,-.218,0),.257,.065,mats['rim'],parent,'Y')
  if name=='lamp_left_arrow':
   cylinder('arrow_lens_backing',(x,-.26,0),.225,.023,mats['arrow_backing'],parent,'Y');o=arrow(mats[name+'_off'],parent,x)
  else:o=cylinder(name,(x,-.26,0),.225,.023,mats[name+'_off'],parent,'Y')
  o['material_on']='mat_'+name+'_on';o['material_off']='mat_'+name+'_off';o['switch_material_slot']=0
  visor(x,i,mats['housing'],parent)
 parent['facing_blender']=[0,-1,0];parent['lamp_radius_m']=.225;return parent

def geometry():
 bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get();pts=[];tri=0
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  e=o.evaluated_get(dep);me=e.to_mesh();pts.extend(e.matrix_world@v.co for v in me.vertices);tri+=sum(len(p.vertices)-2 for p in me.polygons);e.to_mesh_clear()
 lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
 return pts,lo,hi,tri

def set_lamps(enabled):
 for name in LAMPS:bpy.data.objects[name].data.materials[0]=bpy.data.materials['mat_'+name+('_on' if name in enabled else '_off')]

def studio(points):
 scene=bpy.context.scene;lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)];target=Vector([(a+b)/2 for a,b in zip(lo,hi)])
 cd=bpy.data.cameras.new('PreviewCamera');cam=bpy.data.objects.new('PreviewCamera',cd);scene.collection.objects.link(cam);scene.camera=cam
 cam.location=target+Vector((12,-12*math.sqrt(3),24*math.tan(math.pi/6)));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=2
 scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
 for _ in range(12):
  bpy.context.view_layer.update();ps=[world_to_camera_view(scene,cam,p) for p in points];ratio=max(max(abs(p.x-.5)/.43,abs(p.y-.5)/.43) for p in ps)
  if ratio<=1.001:break
  cd.ortho_scale*=ratio*1.01
 cam['target_m']=list(target);cam['elevation_degrees']=30
 scene.world=bpy.data.worlds.new('StudioWorld');scene.world.use_nodes=True;bg=scene.world.node_tree.nodes['Background'];bg.inputs[0].default_value=(.62,.69,.76,1);bg.inputs[1].default_value=.65
 ld=bpy.data.lights.new('StudioKey','AREA');ld.energy=2000;ld.size=10;light=bpy.data.objects.new('StudioKey',ld);scene.collection.objects.link(light);light.location=target+Vector((3,-9,12));light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
 scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=48;scene.cycles.use_denoising=False;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='Standard';scene.view_settings.exposure=-.2

def build(ident,label,arm):
 B.C.reset_scene();bpy.context.preferences.filepaths.save_version=0;scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
 root=empty('SignalRoot');root['asset_id']=ident;root['forward_blender']=[0,-1,0];m=make_materials();height=6.5 if arm else 4.5
 box('BasePlate',(0,0,.03),(.44,.44,.06),m['frame'],root)
 cylinder('Pole',(0,0,(height+.06)/2),.12 if arm else .105,height-.06,m['frame'],root)
 cylinder('PoleBaseCollar',(0,0,.18),.145,.25,m['hardware'],root,segments=8)
 for x in [-.16,.16]:
  for y in [-.16,.16]:cylinder('AnchorBolt',(x,y,.0775),.025,.035,m['hardware'],root,segments=4)
 if arm:
  box('RoadwardArm',(-3.5,0,6.40),(7.0,.18,.18),m['frame'],root)
  bar('ArmBrace',(-.04,0,5.65),(-1.5,0,6.35),.10,m['frame'],root)
  h=head(root,(-5.90,-.22,5.70),m)
  for x in [-6.6,-5.2]:box('HeadHanger',(x,-.11,6.16),(.10,.28,.34),m['hardware'],root)
 else:
  h=head(root,(0,-.22,4.50),m)
  for z in [4.28,4.49]:box('HeadMount',(0,-.12,z),(.22,.30,.10),m['hardware'],root)
 points,lo,hi,tri=geometry();clearance=h.location.z-.42
 assert abs(lo[2])<.00001 and ((500<=tri<=1200 and clearance>=4.5) if arm else 300<=tri<=800),(ident,tri,clearance)
 studio(points);out=ROOT/'assets/street-furniture'/ident;out.mkdir(parents=True,exist_ok=True)
 data=dict(id=ident,name=label,category='street-furniture',style='traffic-signal',height_m=hi[2],pole_height_m=height,arm_length_m=7.0 if arm else 0.0,head_clearance_m=clearance,lamp_order_left_to_right=LAMPS,lamp_materials={n:['mat_'+n+'_on','mat_'+n+'_off'] for n in LAMPS},frame_blender=dict(forward='-Y',left='+X',up='+Z'),frame_gltf=dict(forward='+Z',left='+X',up='+Y'),origin='pole base center, z=0',triangles=tri,not_validated=['signal timing','traffic AI','large-city performance'],vertex_bounds_m=[lo,hi],measured_dimensions_m=[hi[i]-lo[i] for i in range(3)],head_origin_blender_m=list(h.location),head_dimensions_m=[2.6,.535,.84],lamp_diameter_m=.45,nominal_reference_lamp_diameter_m=.30,lens_scale=1.5,default_state='all_off',arm_direction_blender='-X' if arm else None,front_view_note='observer at -Y looking +Y: red to green follows increasing X; arrow tip points negative X',source='original scripted geometry; existing fleet material helper; no external models, textures, fonts or generation APIs',game_registered=False)
 data['material_definitions']={mat.name:dict(base_color_linear=list(mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value),emission_color_linear=list(mat.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value),emission_strength=mat.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value,roughness=mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value) for key,mat in m.items() if key.endswith(('_on','_off'))}
 B.write_json(out/'spec.json',data);set_lamps([]);bpy.ops.wm.save_as_mainfile(filepath=str(out/'signal.blend'))
 scene.render.filepath=str(out/'preview-off.png');bpy.ops.render.render(write_still=True)
 set_lamps(LAMPS);scene.render.filepath=str(out/'preview-on.png');bpy.ops.render.render(write_still=True)
 print('TRAFFIC_SIGNAL_DONE',ident,tri,'head clearance',clearance,'full height',hi[2],flush=True)

if __name__=='__main__':
 build('traffic-signal-post-01','기둥형 4색 차량 신호등',False)
 build('traffic-signal-arm-01','가로대형 4색 차량 신호등',True)
