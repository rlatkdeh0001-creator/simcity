"""Original one-asset MART concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'small-4x4-market-03';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# Small commercial 01 · MART\n\nBrief: 동네 슈퍼마켓, 4x4 cells (16x16m), 1 occupied floors. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
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
box('LotPaving',(0,0,.15),(15.9,15.9,.1),'paving')
for x in range(-7,8):box('Joint',(x,-5.5,.207),(.012,4.8,.007),'stone',0)
for y in [-7,-6,-5,-4]:box('Joint',(0,y,.207),(15.6,.012,.007),'stone',0)

box('MarketBody',(0,1.6,2.35),(12,9,4.3),'cream')
box('Base',(0,1.6,.4),(12.2,9.2,.3),'stone')
box('FrontGlazing',(0,-2.96,1.9),(11.5,.09,2.8),'glass')
for x in [-5.5,-3.6,-1.8,0,1.8,3.6,5.5]:box('GlazingFrame',(x,-3.03,1.9),(.07,.07,2.9),'metal')
box('Entrance',(0,-3.08,1.65),(2.6,.08,2.5),'lightglass')
box('DoorSplit',(0,-3.15,1.65),(.06,.04,2.5),'metal')
for x in [-.25,.25]:bar('DoorHandle',(x,-3.19,1.4),(x,-3.19,1.85),.03)
box('Sign',(0,-3.08,3.8),(12.3,.3,1.1),'green')
text('MarketName','FRESH MART',(0,-3.25,3.82),(math.pi/2,0,0),9.5,.75)
box('SignStripe',(0,-3.26,3.25),(12.3,.04,.09),'orange')
box('SideSign',(6.1,1.6,3.8),(.3,9.3,1.1),'green')
text('SideName','MARKET',(6.27,1.4,3.82),(math.pi/2,0,math.pi/2),6.6,.7)
for i in range(20):
 x=-5.9+(i+.5)*11.8/20
 o=box('Awning',(x,-3.7,3.15),(11.8/20,1.25,.09),'green' if i%2==0 else 'ivory');o.rotation_euler.x=.12
box('Roof',(0,1.6,4.62),(12.4,9.4,.22),'cream')
box('RoofDeck',(0,1.6,4.78),(12.0,9,.1),'roof')
for y in [-3,6.2]:box('Parapet',(0,y,4.9),(12.35,.15,.3),'cream')
for x in [-6.1,6.1]:box('Parapet',(x,1.6,4.9),(.15,9.2,.3),'cream')
for x in [-2,2]:
 box('HVAC',(x,3,5.25),(1.7,1.6,.8),'metal')
 for xx in [-.5,-.25,0,.25,.5]:box('Vent',(x+xx,2.18,5.25),(.08,.03,.55),'stone')
for cx,color in [(-4.4,'red'),(-2.6,'fruit')]:
 box('ProduceStand',(cx,-4.3,.75),(1.5,.85,1.05),'wood')
 box('ProduceTray',(cx,-4.3,1.32),(1.6,.9,.12),'darkgreen')
 for i in range(5):
  for j in range(3):
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.13,location=(cx-.55+i*.27,-4.58+j*.27,1.48));bpy.context.object.data.materials.append(m[color])
# Marked forecourt bicycle parking and bollards, not a luxury frontage.
for x in [2.7,3.6,4.5]:
 for a,b in [((x,-4.6,.3),(x,-4.6,1.15)),((x,-4.6,1.15),(x,-5.4,1.15)),((x,-5.4,1.15),(x,-5.4,.3))]:bar('CycleRack',a,b,.045)
for x in [-6.5,6.5]:
 box('Planter',(x,-4.2,.6),(.9,1.2,.8),'stone')
 box('Shrub',(x,-4.2,1.2),(.8,1.1,.7),'leaf',.12)
box('DeliveryDoor',(-2,6.16,1.75),(2,.12,3),'metal')
o=bpy.data.objects.new('OccupiedFloor_01',None);scene.collection.objects.link(o)
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-8.001 and low[1]>=-8.001 and high[0]<=8.001 and high[1]<=8.001,(low,high)
checkpoint('MODEL',f'Original 4x4 local commercial model. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=2.7;distance=30
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=28;aim(camera,(0,0,target_z));scene.camera=camera
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
meta={'id':'small-4x4-market-03','name':'동네 슈퍼마켓','zone':'commercial','category':'small_commercial','footprint_cells':[4,4],'cell_meters':4,'lot_meters':[16,16],'occupied_storeys':1,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((8,-8,.12)),'lot_corners_px':[pixel(v) for v in [(-8,-8,.12),(8,-8,.12),(8,8,.12),(-8,8,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':28,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['FRESH MART lettering', 'produce stands', 'striped awning', 'cycle racks'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS small-4x4-market-03, review only; no game registration')
