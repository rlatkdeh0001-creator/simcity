"""Original one-asset MART concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'large-4x4-office-nova-08';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# Large commercial 02 · NOVA Office\n\nBrief: NOVA 오피스 타워, 4x4 cells (16x16m), 10 occupied floors. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
def checkpoint(stage,text):
 with log.open('a') as f:f.write(f'\n## {stage}\n{text}\n\nCheckpoint: {stage}\n')
def rgb(h):
 v=[int(h[i:i+2],16)/255 for i in [0,2,4]];return tuple(x/12.92 if x<.04045 else ((x+.055)/1.055)**2.4 for x in v)+(1,)
def mat(name,h,metal=0,rough=.65):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=rgb(h);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;return m
colors={'cream':'e4dfce','paving':'d9dacd','stone':'bdbfb3','green':'346d58','darkgreen':'224f45','orange':'d6a253','ivory':'f8edcf','metal':'435759','glass':'527e89','lightglass':'afc4c1','roof':'949d96','wood':'a58056','shelf':'47584b','red':'c9694e','fruit':'d7a23d','leaf':'64815a','black':'34413e'}
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
box('Plaza',(0,0,.15),(15.9,15.9,.1),'paving')
# Public retail podium and separately legible business lobby.
box('RetailPodium',(0,1,3.35),(13,11.2,6.3),'metal')
for floor in range(2):
 z=1.75+floor*2.9
 box('PodiumFrontGlass',(0,-4.65,z),(12.5,.08,2.45),'glass')
 box('PodiumSideGlass',(6.55,1,z),(.08,10.7,2.45),'glass')
 for x in [-6,-4,-2,0,2,4,6]:box('FrontMullion',(x,-4.73,z),(.07,.05,2.5),'metal')
 for y in [-4.1,-2.1,-.1,1.9,3.9,5.9]:box('SideMullion',(6.63,y,z),(.05,.07,2.5),'metal')
box('PodiumMidBand',(0,1,3.1),(13.2,11.4,.28),'stone')
box('LobbyPortal',(0,-4.82,1.9),(3.5,.25,3.4),'cream')
box('LobbyDoors',(0,-4.97,1.8),(3.1,.04,3.1),'lightglass')
for x in [-1,0,1]:box('DoorDivision',(x,-5.02,1.8),(.05,.03,3.1),'metal')
for x in [-.2,.2]:bar('Handle',(x,-5.08,1.3),(x,-5.08,2.1),.035)
box('LobbyCanopy',(0,-5.5,3.55),(4.2,1.5,.18),'metal')
text('LobbyLabel','OFFICE',(0,-6.27,3.55),(math.pi/2,0,0),2.6,.24)
for cx,name,col in [(-4.6,'CAFE','green'),(4.6,'TECH','metal')]:
 box('TenantSign',(cx,-4.85,2.95),(3.4,.2,.66),col)
 text('Tenant_'+name,name,(cx,-4.98,2.97),(math.pi/2,0,0),2.8,.42)
box('PodiumTop',(0,1,6.65),(13.5,11.7,.28),'stone')
# Eight office floors over two retail floors. Two setbacks form a different skyline.
for floor in range(8):
 w=11.2 if floor<5 else (9.3 if floor<7 else 7.3)
 depth=9.8 if floor<5 else (8.1 if floor<7 else 6.4)
 cy=1.35+(9.8-depth)/2
 bottom=6.8+floor*2.8;z=bottom+1.4
 box('OfficeFloor',(0,cy,z),(w,depth,2.8),'metal')
 front=cy-depth/2
 box('OfficeFrontGlass',(0,front-.05,z+.1),(w-.22,.06,2.35),'glass')
 box('OfficeSideGlass',(w/2+.05,cy,z+.1),(.06,depth-.22,2.35),'glass')
 for i in range(7):
  x=-w/2+.15+i*(w-.3)/6
  box('FrontFineMullion',(x,front-.1,z+.1),(.045,.04,2.4),'metal')
 for i in range(6):
  y=cy-depth/2+.15+i*(depth-.3)/5
  box('SideFineMullion',(w/2+.1,y,z+.1),(.04,.045,2.4),'metal')
 box('FrontFloorBand',(0,front-.1,bottom+.12),(w+.1,.16,.24),'metal')
 box('SideFloorBand',(w/2+.1,cy,bottom+.12),(.16,depth+.1,.24),'metal')
 if floor in [4,6,7]:
  box('SetbackCap',(0,cy,bottom+2.85),(w+.4,depth+.4,.16),'stone')
  if floor!=7:
   for xx in [-w/2+.6,w/2-.6]:
    box('TerracePlanter',(xx,front+.7,bottom+3.1),(.7,1.1,.45),'stone')
    box('TerraceShrub',(xx,front+.7,bottom+3.5),(.6,1,.45),'leaf',.08)
# Branding on a corner pylon, no residential balconies or luxury-shop icon.
box('BrandPylon',(5.9,-3.3,21),(1.05,.28,5),'metal')
for i,letter in enumerate('NOVA'):
 text('Brand_'+letter,letter,(5.9,-3.47,22.65-i*1.08),(math.pi/2,0,0),.72,.7)
box('RoofPlant',(0,3.5,29.9),(3.3,2.5,1.4),'metal')
box('RoofPlantCap',(0,3.5,30.65),(3.5,2.7,.16),'stone')
for x in [-1.2,-.8,-.4,0,.4,.8,1.2]:box('PlantVent',(x,2.23,29.9),(.1,.03,.9),'stone')
for cx in [-5.7,5.7]:
 box('PlazaPlanter',(cx,-6.1,.65),(1.2,1.3,.9),'stone')
 box('Shrub',(cx,-6.1,1.35),(1.05,1.15,.8),'leaf',.1)
for cx in [-3.3,3.3]:
 box('Bench',(cx,-6.35,.7),(1.8,.6,.13),'wood')
 for dx in [-.6,.6]:box('BenchFoot',(cx+dx,-6.35,.43),(.15,.5,.45),'metal')
box('RearServiceDoor',(0,6.65,1.65),(1.8,.1,2.8),'metal')
for i in range(10):
 o=bpy.data.objects.new('OccupiedFloor_%02d'%(i+1),None);o['storey_index']=i+1;scene.collection.objects.link(o)
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-8.001 and low[1]>=-8.001 and high[0]<=8.001 and high[1]<=8.001,(low,high)
checkpoint('MODEL',f'Original 4x4 local commercial model. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=14;distance=60
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=50;aim(camera,(0,0,target_z));scene.camera=camera
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
meta={'id':'large-4x4-office-nova-08','name':'NOVA 오피스 타워','zone':'commercial','category':'large_commercial','density':'high','retail_type':'office_with_retail','footprint_cells':[4,4],'cell_meters':4,'lot_meters':[16,16],'occupied_storeys':10,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((8,-8,.12)),'lot_corners_px':[pixel(v) for v in [(-8,-8,.12),(8,-8,.12),(8,8,.12),(-8,8,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':50,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['NOVA vertical lettering','CAFE and TECH podium','separate OFFICE lobby','two upper setbacks','ten occupied floors'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS large-4x4-office-nova-08, review only; no game registration')
