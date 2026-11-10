"""Original one-asset MART concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'medium-4x4-brick-services-06';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# Medium commercial 02 · Brick Services\n\nBrief: 벽돌형 식당·서비스 상가, 4x4 cells (16x16m), 4 occupied floors. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
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




box('Lot',(0,0,0),(16,16,.24),'stone',.04)
box('Paving',(0,0,.15),(15.9,15.9,.1),'paving')
box('BrickBody',(0,1.5,6),(12,9.5,11.6),'red')
# Restrained brick courses and stone pilasters distinguish this from the glazed office.
for z in [i*.34+.4 for i in range(34)]:
 box('FrontBrickCourse',(0,-3.26,z),(12,.015,.018),'wood',0)
 box('SideBrickCourse',(6.01,1.5,z),(.015,9.5,.018),'wood',0)
for x in [-5.9,-2,2,5.9]:box('FacadePier',(x,-3.32,6),(.22,.2,11.6),'cream')
for level in range(1,4):
 z=1.7+level*2.75
 for x in [-3.9,0,3.9]:
  box('WindowStoneFrame',(x,-3.38,z),(2.9,.22,1.9),'cream')
  box('ShopWindow',(x,-3.51,z),(2.65,.045,1.66),'glass')
  box('WindowMullion',(x,-3.55,z),(.06,.03,1.7),'metal')
 for y in [-1.7,1.5,4.7]:
  box('SideWindowFrame',(6.1,y,z),(.22,2.3,1.9),'cream')
  box('SideWindow',(6.23,y,z),(.045,2.05,1.66),'glass')
 box('FloorBand',(0,1.5,z-1.35),(12.45,9.9,.22),'cream')
for cx in [-3.9,3.9]:
 box('GroundGlass',(cx,-3.37,1.65),(3.3,.08,2.4),'glass')
 box('ShopDoor',(cx+.8,-3.45,1.5),(1.1,.04,2.2),'lightglass')
 bar('DoorHandle',(cx+1.05,-3.51,1.3),(cx+1.05,-3.51,1.7),.025)
box('StairEntrance',(0,-3.39,1.6),(2.2,.1,2.6),'metal')
box('StairGlass',(0,-3.46,1.55),(1.9,.03,2.4),'lightglass')
box('BistroSign',(-3.9,-3.47,3.18),(3.8,.22,.75),'darkgreen')
text('Bistro','BISTRO',(-3.9,-3.6,3.2),(math.pi/2,0,0),3.3,.47)
box('SalonSign',(3.9,-3.47,3.18),(3.8,.22,.75),'metal')
text('Salon','SALON',(3.9,-3.6,3.2),(math.pi/2,0,0),3.2,.47)
for cx,col in [(-3.9,'green'),(3.9,'metal')]:
 for i in range(8):
  x=cx-1.8+(i+.5)*.45
  box('ShopAwning',(x,-3.97,2.68),(.45,.95,.1),col if i%2==0 else 'ivory')
# Visible projecting tenant directory on the right corner: no luxury/jewellery tenants.
box('DirectoryMount',(6.55,-2.3,7.65),(1.05,.4,6.5),'cream')
for z,word,col in [(9.85,'FOOD','green'),(8.35,'CAFE','wood'),(6.85,'GYM','metal'),(5.35,'SALON','green')]:
 box('DirectoryPanel',(6.55,-2.55,z),(.94,.12,1.25),col)
 text('Directory_'+word,word,(6.55,-2.63,z),(math.pi/2,0,0),.82,.25)
box('RoofCornice',(0,1.5,11.95),(12.7,10.2,.35),'cream')
box('RoofDeck',(0,1.5,12.2),(12.2,9.7,.12),'roof')
for y in [-3.45,6.45]:box('Parapet',(0,y,12.45),(12.6,.18,.45),'cream')
for x in [-6.2,6.2]:box('Parapet',(x,1.5,12.45),(.18,9.9,.45),'cream')
box('KitchenExtractor',(2.8,3.3,12.75),(1.7,1.4,.8),'metal')
bar('ExhaustDuct',(2.8,3.3,13.1),(2.8,3.3,13.65),.28)
box('ExhaustCap',(2.8,3.3,13.7),(.85,.85,.1),'metal')
for cx in [-4.4,-2.4]:
 box('Table',(cx,-5.15,1),(1,1,.1),'wood')
 bar('TableBase',(cx,-5.15,.25),(cx,-5.15,.95),.07)
 for yy in [-5.95,-4.35]:
  box('ChairSeat',(cx,yy,.6),(.55,.55,.09),'green')
  box('ChairBack',(cx,yy+.23,.9),(.55,.07,.55),'green')
  for dx in [-.2,.2]:bar('ChairLeg',(cx+dx,yy,.25),(cx+dx,yy,.58),.035)
box('MenuBoard',(-.65,-4.7,.95),(.7,.14,1.4),'darkgreen')
text('Menu','MENU',(-.65,-4.79,1.15),(math.pi/2,0,0),.58,.2)
for x in [-6.6,6.6]:
 box('Planter',(x,-5.5,.6),(1,1.4,.8),'stone')
 box('Shrub',(x,-5.5,1.25),(.9,1.3,.8),'leaf',.1)
box('RearServiceDoor',(0,6.3,1.55),(1.5,.1,2.6),'metal')
for floor in range(4):
 o=bpy.data.objects.new('OccupiedFloor_%02d'%(floor+1),None);o['storey_index']=floor+1;scene.collection.objects.link(o)
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-8.001 and low[1]>=-8.001 and high[0]<=8.001 and high[1]<=8.001,(low,high)
checkpoint('MODEL',f'Original 4x4 local commercial model. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=5.5;distance=30
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=32;aim(camera,(0,0,target_z));scene.camera=camera
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
meta={'id':'medium-4x4-brick-services-06','name':'벽돌형 식당·서비스 상가','zone':'commercial','category':'medium_commercial','footprint_cells':[4,4],'cell_meters':4,'lot_meters':[16,16],'occupied_storeys':4,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((8,-8,.12)),'lot_corners_px':[pixel(v) for v in [(-8,-8,.12),(8,-8,.12),(8,8,.12),(-8,8,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':32,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['BISTRO and SALON storefronts','FOOD CAFE GYM SALON tenant directory','brick facade','four occupied floors'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS medium-4x4-brick-services-06, review only; no game registration')
