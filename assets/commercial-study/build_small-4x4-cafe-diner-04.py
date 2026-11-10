"""Original one-asset MART concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'small-4x4-cafe-diner-04';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# Small commercial 01 · MART\n\nBrief: 식당·카페 복합상가, 4x4 cells (16x16m), 2 occupied floors. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
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

box('RowBody',(0,1.6,3.15),(12.5,9,5.9),'cream')
box('Base',(0,1.6,.4),(12.7,9.2,.3),'stone')
for cx in [-3.15,3.15]:
 box('ShopGlass',(cx,-2.96,1.65),(5.7,.08,2.45),'glass')
 for xx in [-2.6,0,2.6]:box('ShopFrame',(cx+xx,-3.03,1.65),(.07,.06,2.55),'metal')
 box('ShopDoor',(cx+1.8,-3.08,1.55),(1.35,.06,2.25),'lightglass')
 bar('Handle',(cx+2.2,-3.15,1.3),(cx+2.2,-3.15,1.75),.025)
box('CafeSign',(-3.15,-3.12,3.08),(6.1,.25,.76),'green')
box('DinerSign',(3.15,-3.12,3.08),(6.1,.25,.76),'red')
text('CafeName','CAFE',(-3.15,-3.27,3.08),(math.pi/2,0,0),3.8,.5)
text('DinerName','DINER',(3.15,-3.27,3.08),(math.pi/2,0,0),4,.5)
for x in [-4.6,-1.6,1.6,4.6]:
 box('UpperWindowFrame',(x,-2.96,4.7),(2,.12,1.65),'metal')
 box('UpperWindow',(x,-3.04,4.7),(1.8,.035,1.45),'glass')
 box('WindowSplit',(x,-3.08,4.7),(.05,.03,1.5),'metal')
for y in [-1.4,1.4,4.2]:
 box('SideUpperFrame',(6.3,y,4.7),(.12,1.8,1.65),'metal')
 box('SideUpperGlass',(6.38,y,4.7),(.03,1.6,1.45),'glass')
box('Cornice',(0,1.6,6.23),(12.9,9.4,.24),'cream')
box('RoofDeck',(0,1.6,6.4),(12.4,8.9,.12),'roof')
for y in [-3,6.2]:box('Parapet',(0,y,6.55),(12.8,.16,.35),'cream')
for x in [-6.3,6.3]:box('Parapet',(x,1.6,6.55),(.16,9.2,.35),'cream')
box('RoofExtractor',(3,3.5,6.9),(1.4,1.4,.6),'metal')
for cx,col in [(-3.15,'green'),(3.15,'red')]:
 for i in range(10):
  x=cx-2.8+(i+.5)*5.6/10
  o=box('Awning',(x,-3.65,2.65),(.56,1.15,.08),col if i%2==0 else 'ivory');o.rotation_euler.x=.1
# Outdoor cafe tables, chairs, menu boards and planters.
for cx in [-4.7,-1.5,3.5]:
 box('TableTop',(cx,-5.25,1.05),(1.1,1.1,.1),'wood',.04)
 bar('TableLeg',(cx,-5.25,.25),(cx,-5.25,1),.07)
 for yy in [-6.1,-4.4]:
  box('ChairSeat',(cx,yy,.65),(.65,.6,.09),'green')
  box('ChairBack',(cx,yy+.25,1),(.65,.08,.65),'green')
  for xx in [-.23,.23]:bar('ChairLeg',(cx+xx,yy,.25),(cx+xx,yy,.64),.035)
box('MenuBoard',(1,-4.7,.95),(.8,.12,1.4),'darkgreen')
text('Menu','MENU',(1,-4.78,1.2),(math.pi/2,0,0),.64,.22)
for zz in [.9,.75,.6]:box('MenuLine',(1,-4.79,zz),(.5,.025,.025),'ivory')
for x in [-6.8,6.8]:
 box('Planter',(x,-5,.6),(.8,2.6,.8),'stone')
 box('Hedge',(x,-5,1.2),(.7,2.5,.7),'leaf',.12)
box('RearServiceDoor',(0,6.17,1.5),(1.5,.12,2.5),'metal')
o=bpy.data.objects.new('OccupiedFloor_01',None);scene.collection.objects.link(o)
o=bpy.data.objects.new('OccupiedFloor_02',None);scene.collection.objects.link(o)
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
meta={'id':'small-4x4-cafe-diner-04','name':'식당·카페 복합상가','zone':'commercial','category':'small_commercial','footprint_cells':[4,4],'cell_meters':4,'lot_meters':[16,16],'occupied_storeys':2,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((8,-8,.12)),'lot_corners_px':[pixel(v) for v in [(-8,-8,.12),(8,-8,.12),(8,8,.12),(-8,8,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':28,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['CAFE and DINER signs', 'outdoor seating', 'menu board', 'two-storey neighbourhood shops'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS small-4x4-cafe-diner-04, review only; no game registration')
