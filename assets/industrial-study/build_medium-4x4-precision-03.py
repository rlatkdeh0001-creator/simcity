"""Original one-asset MART concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'medium-4x4-precision-03';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# Medium industrial 01 · Precision Works\n\nBrief: precision machinery factory, 4x4 cells (16x16m), two occupied office floors and one production hall. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
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



box('Lot_4x4',(0,0,0),(16,16,.24),'stone',.04)
box('ConcreteYard',(0,0,.15),(15.9,15.9,.1),'paving')
# Tall single-volume production hall plus an occupied two-storey office/service wing.
box('ProductionHall',(-1.8,1.5,2.85),(8.2,10,5.3),'stone')
for y in [i*.38-3.35 for i in range(26)]:box('HallSideRib',(-5.93,y,2.85),(.045,.035,5.2),'metal',0)
for x in [i*.36-5.7 for i in range(23)]:box('HallFrontRib',(x,-3.53,2.85),(.035,.045,5.2),'metal',0)
box('OfficeWing',(4.2,1.5,3.35),(3.8,10,6.3),'cream')
box('OfficeBase',(4.2,1.5,.65),(3.95,10.1,.9),'green')
for level in range(2):
 z=1.85+level*2.9
 box('OfficeFrontWindow',(4.2,-3.56,z),(3.25,.08,1.75),'glass')
 for x in [2.7,4.2,5.7]:box('OfficeFrontFrame',(x,-3.63,z),(.065,.045,1.8),'metal')
 for y in [-2.1,.4,2.9,5.4]:
  box('OfficeSideFrame',(6.17,y,z),(.12,1.85,1.8),'metal')
  box('OfficeSideWindow',(6.25,y,z),(.035,1.65,1.6),'glass')
box('OfficeFloorBand',(4.2,1.5,3.25),(4,10.2,.18),'stone')
box('StaffDoor',(4.35,-3.72,1.45),(1.3,.1,2.4),'green')
box('StaffDoorGlass',(4.35,-3.79,1.85),(1.05,.035,1.2),'lightglass')
bar('StaffHandle',(4.8,-3.84,1.1),(4.8,-3.84,1.5),.03)
box('StaffCanopy',(4.2,-4.03,2.9),(3.1,1,.14),'metal')
# Two delivery shutters and worker-scale impact bollards.
for cx in [-3.7,.1]:
 box('ShutterFrame',(cx,-3.62,2.05),(3.35,.18,3.7),'metal')
 box('LoadingShutter',(cx,-3.74,2.05),(3.08,.05,3.42),'roof')
 for z in [i*.21+.45 for i in range(16)]:box('ShutterSlat',(cx,-3.78,z),(3.05,.025,.025),'metal',0)
 for x in [cx-1.7,cx+1.7]:
  box('Bollard',(x,-4.08,.8),(.16,.16,1.2),'orange')
  box('BollardBand',(x,-4.08,1),(.17,.17,.2),'black')
box('FactorySign',(-1.8,-3.65,4.65),(8,.22,.85),'green')
text('FactoryName','PRECISION WORKS',(-1.8,-3.8,4.67),(math.pi/2,0,0),7.3,.52)
# Original gear-like emblem on office corner, no retail display.
y=-3.72;cx=4.2;cz=6
bpy.ops.mesh.primitive_torus_add(major_radius=.3,minor_radius=.07,major_segments=16,minor_segments=6,location=(cx,y,cz),rotation=(math.pi/2,0,0));bpy.context.object.data.materials.append(m['metal'])
for i in range(8):
 ang=i*math.pi/4
 o=box('GearTooth',(cx+.38*math.cos(ang),y,cz+.38*math.sin(ang)),(.17,.1,.17),'metal');o.rotation_euler.y=-ang
box('OfficeRoof',(4.2,1.5,6.62),(4.15,10.4,.24),'cream')
box('OfficeRoofDeck',(4.2,1.5,6.79),(3.85,10.1,.1),'roof')
# Two sawtooth roof bays; glazed faces are rooflights, not additional floors.
for center_y in [-1,4]:
 roof=box('SawtoothRoof',(-1.8,center_y,5.75),(8.6,5,.14),'metal');roof.rotation_euler.x=.15
 box('RooflightFrame',(-1.8,center_y-2.47,5.72),(8.5,.13,.85),'metal')
 box('SawtoothRooflight',(-1.8,center_y-2.55,5.72),(8.15,.04,.64),'glass')
 for x in [-5.6,-3.7,-1.8,.1,2]:box('RooflightMullion',(x,center_y-2.59,5.72),(.06,.03,.68),'metal')
box('OfficeHVAC',(4.1,4,7.25),(1.6,2,.8),'metal')
for y in [3.4,3.7,4,4.3,4.6]:box('HVACVent',(4.94,y,7.25),(.03,.08,.55),'stone')
box('DustCollector',(-6.65,3.7,1.65),(1.1,1.5,2.8),'metal')
bar('ExtractionPipe',(-6.65,3.7,3),(-6.65,3.7,4.9),.18)
bar('HallExtraction',(-6.65,3.7,4.9),(-5.75,3.7,4.9),.18)
# Dispatch pallets and marked loading apron.
for cy in [-5.2,-6.5]:
 box('Pallet',(-5.6,cy,.3),(1.8,1,.18),'wood')
 for i in range(3):box('StockBundle',(-5.6,cy-.3+i*.3,.61),(1.9,.2,.4),'metal')
for cx in [-2.5,0,2.5]:
 o=box('LoadingApronMark',(cx,-5.8,.213),(.08,2.4,.012),'orange',0);o.rotation_euler.z=-.35
box('DispatchCrate',(5.2,-5.3,.8),(1.3,1.3,1.2),'wood')
for x in [4.7,5.7]:box('CrateStrap',(x,-5.3,.8),(.08,1.35,1.25),'metal')
box('RearServiceDoor',(4,6.57,1.55),(1.3,.1,2.6),'metal')
for i in range(2):
 o=bpy.data.objects.new('OccupiedFloor_%02d'%(i+1),None);o['storey_index']=i+1;scene.collection.objects.link(o)
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-8.001 and low[1]>=-8.001 and high[0]<=8.001 and high[1]<=8.001,(low,high)
assert len([o for o in scene.objects if o.name.startswith('OccupiedFloor_')])==2
checkpoint('MODEL',f'Original 4x4 precision factory, two occupied storeys in office wing and one tall production hall. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=3;distance=30
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=30;aim(camera,(0,0,target_z));scene.camera=camera
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
meta={'id':'medium-4x4-precision-03','name':'정밀기계 공장','zone':'industrial','category':'medium_industrial','footprint_cells':[4,4],'cell_meters':4,'lot_meters':[16,16],'occupied_storeys':2,'production_hall_storeys':1,'office_wing_storeys':2,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((8,-8,.12)),'lot_corners_px':[pixel(v) for v in [(-8,-8,.12),(8,-8,.12),(8,8,.12),(-8,8,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':30,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['PRECISION WORKS sign','two loading shutters','sawtooth rooflights','two-storey office wing','dust extraction','stock pallets'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS medium industrial 4x4 precision factory, two storeys, review only')
