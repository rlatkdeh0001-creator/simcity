"""Original one-asset MART concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'large-8x8-grand-department-09';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# AUREL GRAND 대형 백화점\n\nBrief: AUREL GRAND 대형 백화점, 8x8 cells (32x32m), 8 occupied floors. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
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






box('Lot',(0,0,0),(32,32,.24),'stone',.04)
box('Plaza',(0,0,.15),(31.9,31.9,.1),'paving')
for x in range(-15,16,2):box('PavingJoint',(x,-11,.207),(.02,9,.007),'stone',0)
for y in [-15,-13,-11,-9]:box('PavingJoint',(0,y,.207),(31.5,.02,.007),'stone',0)
def front_windows(width,front,z,height,step=2.6):
 box('FrontGlass',(0,front,z),(width,.08,height),'glass')
 count=int(width/step)
 for i in range(count+1):box('FrontMullion',(-width/2+i*width/count,front-.08,z),(.08,.06,height),'metal')
def side_windows(x,cy,depth,z,height):
 box('SideGlass',(x,cy,z),(.08,depth,height),'glass')
 count=int(depth/2.6)
 for i in range(count+1):box('SideMullion',(x+.08,cy-depth/2+i*depth/count,z),(.06,.08,height),'metal')
def entrance(cx,front):
 box('LobbyFrame',(cx,front,2.2),(5.5,.2,3.9),'metal')
 box('LobbyGlass',(cx,front-.14,2.1),(5.1,.06,3.6),'lightglass')
 for dx in [-1.65,0,1.65]:box('DoorSplit',(cx+dx,front-.2,2.1),(.07,.04,3.6),'metal')
 box('Canopy',(cx,front-.9,4.25),(6.5,2,.2),'metal')
def diamond(cx,y,z,size=1):
 pts=[(cx-size,y,z+.3*size),(cx-.6*size,y,z+.85*size),(cx+.6*size,y,z+.85*size),(cx+size,y,z+.3*size),(cx,y,z-size)]
 for a,b in [(0,1),(1,2),(2,3),(3,4),(4,0),(0,3),(1,4),(2,4)]:bar('DiamondEmblem',pts[a],pts[b],.055,'orange')
def plaza_props():
 for x in [-13,13]:
  for y in [-12,-7]:
   box('Planter',(x,y,.7),(1.8,2,1),'stone')
   box('Shrub',(x,y,1.5),(1.6,1.8,1),'leaf',.15)
 for x in [-8,8]:
  box('Bench',(x,-12,.85),(3,.8,.16),'wood')
  for dx in [-1,1]:box('BenchFoot',(x+dx,-12,.5),(.2,.65,.6),'metal')

# Broad eight-floor department store, two wings wrapping a taller glazed atrium.
box('MainDepartmentBody',(0,2.5,14.25),(27,23,28.1),'cream')
for floor in range(8):
 z=2.1+floor*3.45
 front_windows(26,-9.06,z,2.4)
 side_windows(13.56,2.5,22,z,2.4)
 box('FrontFloorBand',(0,-9.17,z-1.4),(27.3,.25,.32),'stone')
 box('SideFloorBand',(13.67,2.5,z-1.4),(.25,23.2,.32),'stone')
for x in [-12.7,-9.5,-6.3,6.3,9.5,12.7]:
 box('FrontStonePier',(x,-9.25,14.2),(.5,.5,27.7),'cream')
 box('GoldInset',(x,-9.52,14.2),(.09,.04,27.4),'orange')
# The central public atrium interrupts repetitive floors.
box('AtriumFrame',(0,-9.45,14),(9,.6,27.5),'metal')
box('AtriumGlass',(0,-9.79,14),(8.5,.06,27),'glass')
for x in [-4,-2,0,2,4]:box('AtriumUpright',(x,-9.86,14),(.09,.07,27),'metal')
for z in [4,8,12,16,20,24]:box('AtriumTransom',(0,-9.87,z),(8.5,.07,.09),'metal')
entrance(0,-9.95)
box('BrandBand',(0,-9.95,6.2),(9.4,.25,1.5),'darkgreen')
text('Brand','AUREL GRAND',(0,-10.1,6.2),(math.pi/2,0,0),8.5,.85)
box('SideBrandBand',(13.75,2.5,6.2),(.25,23.3,1.5),'darkgreen')
text('SideBrand','DEPARTMENT STORE',(13.9,2.5,6.2),(math.pi/2,0,math.pi/2),17,.85)
for cx in [-10,10]:diamond(cx,-9.55,4.1,1)
box('RoofCornice',(0,2.5,28.55),(27.8,23.8,.45),'cream')
box('RoofDeck',(0,2.5,28.85),(27.2,23.2,.15),'roof')
# A large atrium skylight makes the roof recognisable from the game camera.
box('SkylightBase',(0,1.7,29.1),(7,11,.3),'metal')
box('Skylight',(0,1.7,29.5),(6.7,10.7,.55),'glass')
for y in [-2.8,-.5,1.8,4.1,6.4]:box('SkylightRib',(0,y,29.8),(6.8,.08,.08),'metal')
for x in [-10,10]:
 box('RoofPlant',(x,9,29.5),(3.3,3.6,1.2),'metal')
 for dx in [-1.1,-.55,0,.55,1.1]:box('PlantLouvre',(x+dx,7.17,29.5),(.13,.04,.8),'stone')
for x in [-13.65,13.65]:box('RoofParapet',(x,2.5,29.15),(.2,23.5,.6),'cream')
for y in [-9.2,14.2]:box('RoofParapet',(0,y,29.15),(27.5,.2,.6),'cream')
box('LoadingDoor',(-6,14.08,2.2),(4,.12,4),'metal')
plaza_props()

for i in range(8):
 o=bpy.data.objects.new('OccupiedFloor_%02d'%(i+1),None);o['storey_index']=i+1;scene.collection.objects.link(o)
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-16.001 and low[1]>=-16.001 and high[0]<=16.001 and high[1]<=16.001,(low,high)
checkpoint('MODEL',f'Original 8x8 large commercial model. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=13;distance=100
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=67;aim(camera,(0,0,target_z));scene.camera=camera
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
meta={'id':'large-8x8-grand-department-09','name':'AUREL GRAND 대형 백화점','zone':'commercial','category':'large_commercial','density':'high','retail_type':'department_store','footprint_cells':[8,8],'cell_meters':4,'lot_meters':[32,32],'occupied_storeys':8,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((16,-16,.12)),'lot_corners_px':[pixel(v) for v in [(-16,-16,.12),(16,-16,.12),(16,16,.12),(-16,16,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':67,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['wide department-store wings', 'central glazed atrium', 'roof skylight', 'diamond emblems', 'AUREL GRAND sign'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS large-8x8-grand-department-09, review only; no game registration')
