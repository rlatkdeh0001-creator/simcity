"""Original power-facility concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'hydro';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# 수력발전댐\n\nBrief: Variable-span dam; no fixed footprint; gameplay dragging not yet implemented. No game registration.\n\nCheckpoint: BRIEF\n')
def checkpoint(stage,text):
 with log.open('a') as f:f.write(f'\n## {stage}\n{text}\n\nCheckpoint: {stage}\n')
def rgb(h):
 v=[int(h[i:i+2],16)/255 for i in [0,2,4]];return tuple(x/12.92 if x<.04045 else ((x+.055)/1.055)**2.4 for x in v)+(1,)
def mat(name,h,metal=0,rough=.65):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=rgb(h);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;return m
colors={'cream':'e4dfce','paving':'d9dacd','stone':'bdbfb3','green':'346d58','darkgreen':'224f45','orange':'d6a253','ivory':'f8edcf','metal':'435759','glass':'75a1ab','lightglass':'afc4c1','roof':'949d96','wood':'a58056','shelf':'47584b','red':'c9694e','fruit':'d7a23d','leaf':'64815a','black':'34413e'}
m={key:mat('M_'+key,value,.25 if key in ['metal','glass'] else 0,.18 if key=='glass' else .65) for key,value in colors.items()}
p=m['ivory'].node_tree.nodes['Principled BSDF'];p.inputs['Emission Color'].default_value=rgb('f8edcf');p.inputs['Emission Strength'].default_value=.08
cache={}
def box(name,loc,size,material,bevel=.015):
 key=(tuple(size),material)
 if key not in cache:
  x,y,z=[v/2 for v in size];vertices=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
  mesh=bpy.data.meshes.new('SharedBox');mesh.from_pydata(vertices,[],[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]);mesh.update();mesh.materials.append(m[material]);cache[key]=mesh
 obj=bpy.data.objects.new(name,cache[key]);scene.collection.objects.link(obj);obj.location=loc
 if bevel:
  mod=obj.modifiers.new('EdgeHighlights','BEVEL');mod.width=min(bevel,min(size)*.2);mod.segments=2
 return obj

def bar(name,a,b,r=.025,material='metal'):
 delta=Vector(b)-Vector(a);bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=r,depth=delta.length,location=(Vector(a)+Vector(b))/2);o=bpy.context.object;o.name=name;o.rotation_euler=delta.to_track_quat('Z','Y').to_euler();o.data.materials.append(m[material]);return o

def text(name,body,location,rotation,width,height):
 curve=bpy.data.curves.new(name,'FONT');curve.body=body;curve.align_x='CENTER';curve.align_y='CENTER';curve.extrude=.009;curve.bevel_depth=.002
 font=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf')
 if font.exists():curve.font=bpy.data.fonts.load(str(font))
 obj=bpy.data.objects.new(name,curve);scene.collection.objects.link(obj);obj.location=location;obj.rotation_euler=rotation;obj.data.materials.append(m['ivory']);bpy.context.view_layer.update()
 # Measure text in its unrotated local XY plane, so front and side signs have equal cap height.
 raw_x=max(v[0] for v in obj.bound_box)-min(v[0] for v in obj.bound_box);raw_y=max(v[1] for v in obj.bound_box)-min(v[1] for v in obj.bound_box)
 factor=min(width/max(.001,raw_x),height/max(.001,raw_y));obj.scale=(factor,factor,factor)
 return obj








m['water']=mat('Water','478b9b',.1,.24)
m['panel']=mat('SolarCells','284f78',.3,.22)
m['coal']=mat('Coal','33393a')
m['concrete']=mat('Concrete','b6b9ad')
def cyl(name,loc,radius,depth,col='metal',vertices=32):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc);o=bpy.context.object;o.name=name;o.data.materials.append(m[col]);return o
def sphere(name,loc,radius,col,scale=(1,1,1)):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=radius,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(m[col]);return o
def plant_hall(name,loc,size,col='cream'):
 x,y,z=loc;w,d,ht=size
 box(name,loc,size,col)
 box(name+'Roof',(x,y,z+ht/2+.12),(w+.4,d+.4,.24),'metal')
 for yy in [y-d*.32,y,y+d*.32]:
  box('HallSideWindow',(x+w/2+.06,yy,z+.4),(.06,d*.22,ht*.22),'glass')
def sign(word,x,y,z,width):
 box('Nameplate',(x,y,z),(width+.4,.16,.8),'green');text('Label_'+word,word,(x,y-.1,z),(math.pi/2,0,0),width,.5)
def pipe(a,b,r=.15,col='metal'):return bar('ServicePipe',a,b,r,col)
def stack(cx,cy,height,r=.65):
 cyl('Stack',(cx,cy,height/2+.2),r,height,'stone')
 for z in [height*.65,height*.77,height*.89]:cyl('StackBand',(cx,cy,z),r+.025,.6,'red')
 cyl('StackRim',(cx,cy,height+.25),r+.13,.2,'metal')
def tank(cx,cy,radius=2,height=4):
 cyl('StorageTank',(cx,cy,height/2+.5),radius,height,'roof')
 sphere('TankDome',(cx,cy,height+.5),radius,'roof',(1,1,.15))
 for z in [.8,height+.3]:
  bpy.ops.mesh.primitive_torus_add(major_radius=radius+.02,minor_radius=.05,major_segments=32,minor_segments=6,location=(cx,cy,z));bpy.context.object.data.materials.append(m['metal'])
def substation(cx,cy):
 box('SwitchyardBase',(cx,cy,.35),(5.2,4,.25),'stone')
 for dx in [-1.7,0,1.7]:
  box('Transformer',(cx+dx,cy,1.1),(1.1,1.4,1.3),'metal')
  for yy in [-.45,.45]:
   for zz in [1.9,2.15,2.4]:cyl('Insulator',(cx+dx,cy+yy,zz),.12,.16,'cream',12)
 for dx in [-2.3,2.3]:bar('SwitchyardUpright',(cx+dx,cy+1.6,.5),(cx+dx,cy+1.6,3.7),.07)
 bar('SwitchyardBeam',(cx-2.3,cy+1.6,3.7),(cx+2.3,cy+1.6,3.7),.07)


import argparse,sys
parser=argparse.ArgumentParser()
parser.add_argument('--span-m',type=float,default=48)
parser.add_argument('--out',type=str,default='')
parser.add_argument('--model-only',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
assert math.isfinite(args.span_m) and args.span_m>0,'Dam span must be positive and finite'
SPAN=args.span_m;HALF=SPAN/2
if args.out:OUT=Path(args.out).resolve();OUT.mkdir(parents=True,exist_ok=True)
BAYS=max(1,int(SPAN/5));BAY=SPAN/BAYS;PIER=BAY*.35
WIDTH=SPAN+12

# Length-parametric visual construction kit. No fixed gameplay tile footprint.
box('PresentationBase',(0,0,0),(WIDTH,32,.24),'stone',.04)
box('UpstreamReservoir',(0,9,3.55),(SPAN+2,13,6.7),'water')
box('DownstreamRiver',(0,-9,.34),(SPAN,13,.3),'water')
for x in [-HALF-2.5,HALF+2.5]:
 box('RockAbutment',(x,1,4.2),(5,10,8),'stone')
 box('BankGrass',(x,8,3.7),(5,13,7),'leaf')
for i in range(BAYS+1):
 cx=-HALF+i*BAY;w=PIER/2
 verts=[(cx-w,3,.6),(cx+w,3,.6),(cx+w,-3,.6),(cx-w,-3,.6),(cx-w,3,8),(cx+w,3,8),(cx+w,1.4,8),(cx-w,1.4,8)]
 mesh=bpy.data.meshes.new('DamPierMesh');mesh.from_pydata(verts,[],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)]);mesh.materials.append(m['concrete']);o=bpy.data.objects.new('DamGravityPier',mesh);scene.collection.objects.link(o)
for i in range(BAYS):
 cx=-HALF+(i+.5)*BAY;gate_width=BAY-PIER-.1
 box('GateBayShadow',(cx,2,4),(gate_width,.2,5.8),'metal')
 box('SteelFloodgate',(cx,1.82,5.2),(gate_width*.96,.15,3.5),'roof')
 for z in [3.8,4.6,5.4,6.2]:box('GateStiffener',(cx,1.7,z),(gate_width*.96,.1,.13),'metal')
 o=box('Spillway',(cx,-3,3.15),(gate_width,8.8,.35),'concrete');o.rotation_euler.x=.61
 o=box('SpillWater',(cx,-3.15,3.36),(gate_width*.9,8.8,.07),'water');o.rotation_euler.x=.61
 for yy in [-6.7,-7.2,-7.7]:box('TailwaterFoam',(cx,yy,.53),(gate_width*.85,.2,.035),'ivory')
 box('GateHoist',(cx,2.3,9.1),(min(1.1,gate_width*.8),1,1.1),'metal')
box('DamCrestRoad',(0,2.4,8.3),(SPAN+5,2.8,.45),'stone')
for y in [1.02,3.78]:
 for z in [8.9,9.35]:bar('CrestGuardrail',(-HALF-2.5,y,z),(HALF+2.5,y,z),.055)
 count=max(2,math.ceil((SPAN+5)/2))
 for i in range(count+1):
  x=-HALF-2.5+(SPAN+5)*i/count
  bar('GuardrailPost',(x,y,8.5),(x,y,9.35),.045)
# The bank-side powerhouse scales down for short authoring examples.
PW=min(10,SPAN*.4);PX=HALF-PW/2
plant_hall('Powerhouse',(PX,-9,1.85),(PW,6,3.3),'cream')
for dx in [-.32,0,.32]:box('PowerhouseWindow',(PX+dx*PW,-12.06,2.1),(PW*.23,.05,1.3),'glass')
sign('HYDRO POWER',PX,-12.2,3.35,PW*.84)
for dx in [-.22,.22]:pipe((PX+dx*PW,-4.7,.8),(PX+dx*PW,-8,.8),min(.55,PW*.06))
box('AccessRoad',(-HALF-2.5,-8,.23),(3,13,.05),'stone')
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-WIDTH/2-.01 and high[0]<=WIDTH/2+.01
assert len([o for o in scene.objects if o.name.startswith('SteelFloodgate')])==BAYS
checkpoint('MODEL',f'Variable-span dam: {SPAN}m, {BAYS} gate bays; no fixed gameplay footprint.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=3;distance=100
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=max(61,WIDTH*1.86);aim(camera,(0,0,target_z));scene.camera=camera
bpy.ops.object.light_add(type='SUN',location=(-20,-30,60));light=bpy.context.object;light.data.energy=2;light.data.angle=math.radians(12);aim(light,(0,0,0))
scene.world=bpy.data.worlds.new('World');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.55,.65,.75,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False;scene.cycles.device='CPU';scene.render.threads_mode='FIXED';scene.render.threads=6
scene.render.resolution_x=900;scene.render.resolution_y=1100;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
bpy.ops.file.pack_all()
scene.render.filepath=str(OUT/'building.png');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'building.blend'));checkpoint('SAVED','Editable original saved; transparent front and reverse rendering next.')

if not args.model_only:bpy.ops.render.render(write_still=True)
camera.location=(-distance,distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30)));aim(camera,(0,0,target_z));scene.render.filepath=str(OUT/'reverse-review.png');
if not args.model_only:bpy.ops.render.render(write_still=True)
camera.location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30)));aim(camera,(0,0,target_z));bpy.context.view_layer.update()
def pixel(p):
 v=world_to_camera_view(scene,camera,Vector(p));return [round(v.x*900,4),round((1-v.y)*1100,4)]

def pixel(p):
 v=world_to_camera_view(scene,camera,Vector(p));return [round(v.x*900,4),round((1-v.y)*1100,4)]

meta={'id':'power-hydro','name':'수력발전댐','category':'power_facility','footprint_cells':None,'placement_mode':'drag_across_watercourse','fixed_size_limit':False,'dam_span_m':SPAN,'gate_bays':BAYS,'presentation_lot_cells':None,'presentation_lot_meters':[WIDTH,32],'cell_meters':4,'image_size':[900,1100],'anchor_px':pixel((WIDTH/2,-16,.12)),'lot_corners_px':[pixel(v) for v in [(-WIDTH/2,-16,.12),(WIDTH/2,-16,.12),(WIDTH/2,16,.12),(-WIDTH/2,16,.12)]],'vertex_bounds_m':[low,high],'approval_status':'pending-user-review','game_registered':False,'source':'original length-parametric Blender geometry; DejaVu font; no external models or textures','scope':'length-parametric dam visual prototype; gameplay dragging, terrain and hydrology checks not yet implemented'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED' if not args.model_only else 'MODEL_ONLY','Variable-span source saved. No runtime placement or hydrology implementation.')
print(f'PASS hydro span {SPAN}m, {BAYS} gates')
