"""Original one-asset MART concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'large-4x4-department-07';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# Large commercial 01 · Department Store\n\nBrief: AUREL 백화점, 4x4 cells (16x16m), 8 occupied floors. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
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
box('RetailPodium',(0,.9,3.65),(13,11.4,6.9),'cream')
box('TowerBody',(0,1.1,16.3),(11.8,10.2,18.4),'cream')
# Double-height luxury shopfront and broad public entrance.
box('FrontShopGlass',(0,-4.85,2.8),(12.4,.08,4.7),'glass')
for x in [-6,-4,-2,0,2,4,6]:box('ShopMullion',(x,-4.92,2.8),(.09,.07,4.8),'metal')
box('SideShopGlass',(6.55,.9,2.8),(.08,10.8,4.7),'glass')
for y in [-4.2,-2.2,-.2,1.8,3.8,5.8]:box('SideMullion',(6.62,y,2.8),(.07,.09,4.8),'metal')
box('EntryFrame',(0,-4.99,1.9),(3.5,.15,3.4),'metal')
box('EntryDoors',(0,-5.09,1.85),(3.15,.04,3.15),'lightglass')
for x in [-1.05,0,1.05]:box('DoorDivision',(x,-5.14,1.85),(.06,.03,3.2),'metal')
for x in [-.2,.2]:bar('DoorHandle',(x,-5.2,1.35),(x,-5.2,2.1),.035)
box('EntryCanopy',(0,-5.55,3.85),(4.6,1.45,.23),'metal')
box('FrontBrandBand',(0,-4.98,5.9),(13.2,.25,1.4),'darkgreen')
text('FrontBrand','AUREL',(0,-5.13,5.9),(math.pi/2,0,0),7.4,.9)
box('SideBrandBand',(6.63,.9,5.9),(.25,11.6,1.4),'darkgreen')
text('SideBrand','AUREL',(6.78,.9,5.9),(math.pi/2,0,math.pi/2),6.8,.85)
box('FrontGoldTrim',(0,-5.14,5.18),(13.2,.05,.09),'orange')
box('SideGoldTrim',(6.78,.9,5.18),(.05,11.6,.09),'orange')
# Original geometric jewellery silhouettes inside two display bays.
for cx in [-4.4,4.4]:
 box('DisplayPlinth',(cx,-5.03,1.15),(1.5,.25,.65),'darkgreen')
 pts=[(cx-.55,-5.18,2.7),(cx-.3,-5.18,3),(cx+.3,-5.18,3),(cx+.55,-5.18,2.7),(cx,-5.18,2.1)]
 for i,j in [(0,1),(1,2),(2,3),(3,4),(4,0),(0,3),(1,4),(2,4)]:bar('DisplayGem',pts[i],pts[j],.035,'orange')
box('PodiumCornice',(0,.9,7.13),(13.5,11.9,.28),'stone')
# Upper retail floors: stone piers and narrow glazing, no apartment balconies.
for floor in range(6):
 z=8.7+floor*2.8
 for x in [-4.7,-2.35,0,2.35,4.7]:
  box('UpperFrontGlass',(x,-4.05,z),(1.7,.07,1.95),'glass')
  box('FrontWindowSplit',(x,-4.1,z),(.045,.03,1.95),'metal')
 for y in [-2.9,-.7,1.5,3.7,5.5]:box('UpperSideGlass',(5.96,y,z),(.07,1.5,1.95),'glass')
 box('FrontFloorTrim',(0,-4.1,z-1.2),(12,.13,.15),'stone')
 box('SideFloorTrim',(6.01,1.1,z-1.2),(.13,10.3,.15),'stone')
for x in [-5.8,-3.5,-1.17,1.17,3.5,5.8]:
 box('VerticalPier',(x,-4.15,16.5),(.18,.27,17.8),'stone')
 box('GoldPierInset',(x,-4.3,16.5),(.045,.035,17.6),'orange')
for y in [-3.9,-1.8,.4,2.6,4.8,6.1]:box('SidePier',(6.06,y,16.5),(.27,.18,17.8),'stone')
box('CrownCornice',(0,1.1,25.76),(12.5,10.9,.4),'cream')
box('RoofDeck',(0,1.1,26.03),(12,10.4,.15),'roof')
for y in [-4.2,6.4]:box('RoofParapet',(0,y,26.4),(12.4,.18,.6),'cream')
for x in [-6.1,6.1]:box('RoofParapet',(x,1.1,26.4),(.18,10.6,.6),'cream')
# Large corner-mounted diamond emblem: immediately identifies luxury retail.
box('DiamondBacking',(6.45,-3.7,22.3),(1.1,.35,2.4),'darkgreen')
pts=[(5.99,-3.91,22.5),(6.18,-3.91,23),(6.72,-3.91,23),(6.91,-3.91,22.5),(6.45,-3.91,21.65)]
for i,j in [(0,1),(1,2),(2,3),(3,4),(4,0),(0,3),(1,4),(2,4)]:bar('DiamondLogo',pts[i],pts[j],.045,'orange')
for x in [-2.1,1.8]:
 box('HVAC',(x,3,26.65),(2.4,2.2,1),'metal')
 for dx in [-.8,-.4,0,.4,.8]:box('HVACLouvre',(x+dx,1.87,26.65),(.1,.03,.7),'stone')
for x in [-6,6]:
 box('EntryPlanter',(x,-6.1,.65),(1.25,1.4,.9),'stone')
 box('EntryShrub',(x,-6.1,1.35),(1.1,1.25,.8),'leaf',.12)
box('RearLoadingDoor',(0,6.65,2),(3,.12,3.5),'metal')
for i in range(8):
 o=bpy.data.objects.new('OccupiedFloor_%02d'%(i+1),None);o['storey_index']=i+1;scene.collection.objects.link(o)
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-8.001 and low[1]>=-8.001 and high[0]<=8.001 and high[1]<=8.001,(low,high)
checkpoint('MODEL',f'Original 4x4 local commercial model. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=12;distance=60
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=46;aim(camera,(0,0,target_z));scene.camera=camera
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
meta={'id':'large-4x4-department-07','name':'AUREL 백화점','zone':'commercial','category':'large_commercial','density':'high','retail_type':'department_store','footprint_cells':[4,4],'cell_meters':4,'lot_meters':[16,16],'occupied_storeys':8,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((8,-8,.12)),'lot_corners_px':[pixel(v) for v in [(-8,-8,.12),(8,-8,.12),(8,8,.12),(-8,8,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':46,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['AUREL department-store lettering','diamond emblem','double-height shopfront','stone vertical piers','eight occupied floors'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS large-4x4-department-07, review only; no game registration')
