"""Original one-asset MART concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'small-2x2-metalworks-01';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# Small industrial 01 · Metalworks\n\nBrief: small metalworking workshop, 2x2 cells (8x8m), one occupied floor. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
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


box('Lot_2x2',(0,0,0),(8,8,.24),'stone',.04)
box('ConcreteYard',(0,0,.15),(7.9,7.9,.1),'paving')
box('WorkshopBody',(0,.6,2.05),(6.25,5.4,3.7),'stone')
# Corrugated metal facade, broad shutter and separate worker entrance.
for x in [i*.22-3 for i in range(28)]:box('FrontCladdingRib',(x,-2.13,2.05),(.035,.06,3.6),'metal',0)
for y in [i*.23-1.95 for i in range(23)]:box('SideCladdingRib',(3.15,y,2.05),(.06,.035,3.6),'metal',0)
box('ShutterFrame',(-.8,-2.2,1.65),(3.5,.18,2.85),'metal')
box('RollerShutter',(-.8,-2.31,1.65),(3.2,.05,2.6),'roof')
for z in [i*.17+.4 for i in range(15)]:box('ShutterSlat',(-.8,-2.35,z),(3.17,.025,.025),'metal',0)
box('WorkerDoor',(2.02,-2.23,1.4),(1,.15,2.3),'green')
box('DoorWindow',(2.02,-2.32,1.8),(.7,.04,.7),'glass')
bar('DoorHandle',(2.3,-2.36,1.15),(2.3,-2.36,1.45),.022)
box('Sign',(-.8,-2.24,3.45),(4.5,.18,.68),'metal')
text('WorkshopSign','METAL WORKS',(-.8,-2.35,3.46),(math.pi/2,0,0),4,.4)
# Roof with shallow industrial pitch and ridge vent, not an occupied second floor.
for x,angle in [(-1.6,-.10),(1.6,.10)]:
 o=box('RoofSheet',(x,.6,4.05),(3.3,5.9,.16),'metal');o.rotation_euler.y=angle
 for yy in [-2,-1.1,-.2,.7,1.6,2.5,3.3]:
  o=box('RoofSeam',(x,yy,4.15),(3.3,.025,.025),'roof',0);o.rotation_euler.y=angle
box('RidgeCap',(0,.6,4.3),(.3,5.95,.12),'roof')
box('RoofVent',(.1,1.3,4.65),(.85,1.3,.6),'metal')
box('VentCap',(.1,1.3,5), (1.05,1.5,.12),'roof')
for z in [4.48,4.64,4.8]:box('VentLouvre',(.1,.62,z),(.72,.03,.045),'stone')
# Clerestory windows and visible extraction unit.
for yy in [-.9,.5,1.9]:
 box('HighWindowFrame',(3.23,yy,3),(.12,1.15,.7),'metal')
 box('HighWindow',(3.31,yy,3),(.035,.98,.53),'glass')
box('Extractor',(3.35,2.4,1.5),(.4,.85,.9),'metal')
for z in [1.2,1.4,1.6,1.8]:box('ExtractorSlat',(3.57,2.4,z),(.02,.7,.035),'stone')
# Pallet, bundled stock, oil drums, bollards and marked delivery apron.
box('Pallet',(-2.4,-3.1,.3),(1.45,.9,.18),'wood')
for i in range(4):box('SteelStock',(-2.4,-3.35+i*.18,.52),(1.55,.13,.22),'metal')
for xx in [2.5,3.05]:
 bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.22,depth=.7,location=(xx,-3.15,.57));bpy.context.object.name='SealedDrum';bpy.context.object.data.materials.append(m['green'])
 for zz in [.32,.8]:
  bpy.ops.mesh.primitive_torus_add(major_radius=.221,minor_radius=.015,major_segments=16,minor_segments=6,location=(xx,-3.15,zz));bpy.context.object.data.materials.append(m['metal'])
for xx in [-1.1,-.4,.3,1]:
 o=box('DeliveryMark',(xx,-3.35,.212),(.07,.65,.012),'orange',0);o.rotation_euler.z=-.5
for xx in [-2.65,1.05]:
 box('Bollard',(xx,-2.6,.65),(.13,.13,.9),'orange')
 box('BollardStripe',(xx,-2.6,.82),(.14,.14,.14),'black')
box('RearDoor',(1,3.36,1.4),(1.1,.1,2.3),'metal')
marker=bpy.data.objects.new('OccupiedFloor_01',None);marker['storey_index']=1;scene.collection.objects.link(marker)
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-4.001 and low[1]>=-4.001 and high[0]<=4.001 and high[1]<=4.001,(low,high)
assert len([o for o in scene.objects if o.name.startswith('OccupiedFloor_')])==1
checkpoint('MODEL',f'Original one-storey metal workshop. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=2.0;distance=30
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=15;aim(camera,(0,0,target_z));scene.camera=camera
bpy.ops.object.light_add(type='SUN',location=(-20,-30,60));light=bpy.context.object;light.data.energy=2;light.data.angle=math.radians(12);aim(light,(0,0,0))
scene.world=bpy.data.worlds.new('World');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.55,.65,.75,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False;scene.cycles.device='CPU';scene.render.threads_mode='FIXED';scene.render.threads=6
scene.render.resolution_x=900;scene.render.resolution_y=1100;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
bpy.ops.file.pack_all()
scene.render.filepath=str(OUT/'building.png');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'building.blend'));checkpoint('SAVED','Editable original saved; transparent front and reverse rendering next.')
bpy.ops.render.render(write_still=True)
camera.location=(-distance,distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30)));aim(camera,(0,0,target_z));scene.render.filepath=str(OUT/'reverse-review.png');bpy.ops.render.render(write_still=True)
camera.location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30)));aim(camera,(0,0,target_z));bpy.context.view_layer.update()
def pixel(p):
 v=world_to_camera_view(scene,camera,Vector(p));return [round(v.x*900,4),round((1-v.y)*1100,4)]
meta={'id':'small-2x2-metalworks-01','name':'금속가공 작업장','zone':'industrial','category':'small_industrial','footprint_cells':[2,2],'cell_meters':4,'lot_meters':[8,8],'occupied_storeys':1,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((4,-4,.12)),'lot_corners_px':[pixel(v) for v in [(-4,-4,.12),(4,-4,.12),(4,4,.12),(-4,4,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':15,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['METAL WORKS sign','roller shutter','corrugated cladding','ridge vent','stock pallet','delivery apron'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS industrial 2x2 workshop, one occupied floor, review only')
