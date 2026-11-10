"""Original one-asset MART concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'small-2x2-foodworks-02';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# Small industrial 02 · Foodworks\n\nBrief: small food-processing workshop, 2x2 cells (8x8m), one occupied floor. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
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
box('FoodProcessingBody',(0,.6,2.05),(6.25,5.4,3.7),'cream')
box('WashableBase',(0,.6,.65),(6.4,5.55,.9),'green')
# Clean insulated wall panels contrast with the dark metal workshop.
for x in [-2.5,-1.25,0,1.25,2.5]:box('PanelJoint',(x,-2.12,2.35),(.025,.03,2.9),'stone',0)
for y in [-1.5,-.3,.9,2.1,3.1]:box('SidePanelJoint',(3.14,y,2.35),(.03,.025,2.9),'stone',0)
box('ColdDoorFrame',(-1.05,-2.22,1.7),(3,.22,2.9),'metal')
box('InsulatedLoadingDoor',(-1.05,-2.36,1.7),(2.72,.06,2.65),'lightglass')
box('DoorSplit',(-1.05,-2.41,1.7),(.065,.035,2.65),'metal')
for x in [-1.28,-.82]:bar('LoadingHandle',(x,-2.47,1.25),(x,-2.47,1.95),.03)
box('DoorTopRail',(-1.05,-2.44,3.12),(3.15,.16,.13),'metal')
box('StaffDoor',(2.05,-2.2,1.4),(.95,.13,2.3),'green')
box('StaffDoorGlass',(2.05,-2.29,1.85),(.65,.04,.65),'glass')
bar('StaffHandle',(2.3,-2.35,1.15),(2.3,-2.35,1.45),.025)
box('BrandFascia',(0,-2.23,3.55),(6.4,.2,.65),'green')
text('FoodWorksSign','FOOD WORKS',(.28,-2.35,3.56),(math.pi/2,0,0),4.6,.4)
# Simple wheat relief identifies food production instead of a retail storefront.
y=-2.36
bar('WheatStem',(-2.8,y,3.32),(-2.8,y,3.8),.02,'ivory')
for z in [3.44,3.57,3.7]:
 bar('WheatGrain',(-2.8,y,z),(-2.96,y,z+.09),.025,'ivory')
 bar('WheatGrain',(-2.8,y,z),(-2.64,y,z+.09),.025,'ivory')
box('LoadingCanopy',(-1.05,-2.78,3.2),(3.45,1,.12),'metal')
# Flat industrial roof, ventilation and cooling equipment; all unoccupied.
box('RoofCap',(0,.6,3.99),(6.6,5.8,.22),'cream')
box('RoofDeck',(0,.6,4.14),(6.2,5.4,.1),'roof')
for y in [-2.18,3.38]:box('Parapet',(0,y,4.28),(6.5,.13,.3),'cream')
for x in [-3.22,3.22]:box('Parapet',(x,.6,4.28),(.13,5.6,.3),'cream')
box('RoofVent',(0,1.65,4.6),(1,1.1,.7),'metal')
box('VentCap',(0,1.65,4.99),(1.2,1.3,.12),'roof')
for z in [4.4,4.57,4.74]:box('VentSlat',(0,1.08,z),(.85,.025,.045),'stone')
# High windows and an external condenser with two visible round fan grilles.
for yy in [-1.1,.3]:
 box('HighWindowFrame',(3.18,yy,3),(.12,1.05,.65),'metal')
 box('HighWindow',(3.26,yy,3),(.035,.9,.5),'glass')
box('CondenserFeet',(3.44,1.65,.45),(.6,1.8,.35),'metal')
box('Condenser',(3.44,1.65,1.3),(.65,1.9,1.4),'cream')
for yy in [1.17,2.12]:
 bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.34,depth=.03,location=(3.79,yy,1.35),rotation=(0,math.pi/2,0));bpy.context.object.name='FanGrille';bpy.context.object.data.materials.append(m['metal'])
 for angle in [0,math.pi/3,2*math.pi/3]:
  dy=.27*math.cos(angle);dz=.27*math.sin(angle)
  bar('FanSpoke',(3.815,yy-dy,1.35-dz),(3.815,yy+dy,1.35+dz),.018,'stone')
# Dispatch crates on a pallet, no customer display or shopping trolley.
box('DispatchPallet',(-2.2,-3.25,.3),(1.7,.85,.18),'wood')
for x in [-2.65,-1.8]:
 for z in [.64,1.2]:
  box('SealedFoodCarton',(x,-3.25,z),(.75,.7,.52),'wood')
  box('CartonTape',(x,-3.25,z+.265),(.12,.7,.012),'ivory',0)
  box('DispatchLabel',(x,-3.61,z),(.36,.018,.17),'ivory',0)
for x in [-.6,.1,.8]:
 o=box('LoadingMark',(x,-3.4,.212),(.065,.65,.012),'orange',0);o.rotation_euler.z=-.5
for x in [-2.65,.55]:
 box('Bollard',(x,-2.65,.65),(.13,.13,.9),'orange')
 box('BollardBand',(x,-2.65,.82),(.14,.14,.13),'black')
box('RearServiceDoor',(0,3.36,1.4),(1.1,.1,2.3),'metal')
marker=bpy.data.objects.new('OccupiedFloor_01',None);marker['storey_index']=1;scene.collection.objects.link(marker)
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-4.001 and low[1]>=-4.001 and high[0]<=4.001 and high[1]<=4.001,(low,high)
assert len([o for o in scene.objects if o.name.startswith('OccupiedFloor_')])==1
checkpoint('MODEL',f'Original one-storey food-processing workshop. Bounds {low} to {high}.')
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
meta={'id':'small-2x2-foodworks-02','name':'식품가공 작업장','zone':'industrial','category':'small_industrial','footprint_cells':[2,2],'cell_meters':4,'lot_meters':[8,8],'occupied_storeys':1,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((4,-4,.12)),'lot_corners_px':[pixel(v) for v in [(-4,-4,.12),(4,-4,.12),(4,4,.12),(-4,4,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':15,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['FOOD WORKS sign','wheat pictogram','insulated loading door','external condenser','sealed dispatch cartons','one occupied floor'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS industrial 2x2 workshop, one occupied floor, review only')
