"""Original one-asset MART concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'small-2x2-mart-01';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# Small commercial 01 · MART\n\nBrief: one neighbourhood grocery, 2x2 cells (8x8m), one occupied floor. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
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

box('Lot_2x2',(0,0,0),(8,8,.24),'stone',.04);box('Lot_Paving',(0,0,.15),(7.9,7.9,.1),'paving')
for x in [-3,-2,-1,0,1,2,3]:box('PavingJoint',(x,-3.2,.205),(.014,1.5,.007),'stone',0)
for y in [-3.7,-3.0]:box('PavingJoint',(0,y,.205),(7.7,.014,.007),'stone',0)
box('ShopBody',(0,.6,2.1),(6.2,5.4,3.6),'cream',.03)
box('BaseSkirt',(0,.6,.42),(6.35,5.52,.24),'stone')
# Commercial storefront: broad glazing, one retail entrance, no residential balconies.
box('ShopfrontFrame',(-1.25,-2.15,1.63),(3.4,.17,2.45),'metal')
box('ShopfrontGlass',(-1.25,-2.255,1.63),(3.18,.045,2.2),'glass',.003)
for x in [-2.3,-1.2,-.1]:box('ShopfrontMullion',(x,-2.3,1.63),(.045,.03,2.2),'metal',.003)
box('ShopfrontTransom',(-1.25,-2.3,2.35),(3.2,.03,.045),'metal',.003)
box('DoorFrame',(1.45,-2.18,1.61),(1.75,.2,2.55),'metal')
box('DoorGlass',(1.45,-2.3,1.61),(1.52,.04,2.32),'lightglass',.003)
for x in [1.02,1.88]:bar('DoorHandle',(x,-2.37,1.3),(x,-2.37,1.75),.022)
box('DoorCenterBar',(1.45,-2.35,1.61),(.045,.035,2.32),'metal')
box('RightDisplayGlass',(2.76,-2.2,1.6),(.4,.12,2.32),'glass')
box('SideWindowFrame',(3.15,.5,1.7),(.16,3.65,2.2),'metal')
box('SideWindowGlass',(3.25,.5,1.7),(.04,3.42,1.98),'glass',.003)
for y in [-.6,.5,1.6]:box('SideWindowBar',(3.29,y,1.7),(.03,.045,2.0),'metal',.003)
box('SideTransom',(3.29,.5,2.35),(.03,3.42,.05),'metal')
# Front and side brand fascia; text is actual Blender lettering, not a generated bitmap.
box('FrontSign',(0,-2.29,3.36),(6.48,.3,.94),'green')
box('SideSign',(3.22,.6,3.36),(.3,5.85,.94),'green')
box('FrontSignAccent',(0,-2.46,2.92),(6.48,.06,.105),'orange')
box('SideSignAccent',(3.39,.6,2.92),(.06,5.85,.105),'orange')
text('MART_Front','MART',(.42,-2.46,3.38),(math.pi/2,0,0),3.9,.66)
text('MART_Side','MART',(3.39,.7,3.38),(math.pi/2,0,math.pi/2),3.5,.64)
# Basket pictogram beside the front name, drawn as 3D linework in the sign plane.
y=-2.47
for a,b in [((-2.7,y,3.53),(-2.05,y,3.53)),((-2.64,y,3.5),(-2.53,y,3.16)),((-2.11,y,3.5),(-2.22,y,3.16)),((-2.53,y,3.16),(-2.22,y,3.16)),((-2.58,y,3.57),(-2.44,y,3.74)),((-2.18,y,3.57),(-2.32,y,3.74))]:bar('BasketLogo',a,b,.026,'ivory')
for x in [-2.46,-2.33]:bar('BasketLogoStripe',(x,y,3.22),(x,y,3.45),.018,'ivory')
# Retractable striped awning emphasizes retail frontage.
for i in range(13):
 color='green' if i%2==0 else 'ivory';x=-3.12+(i+.5)*6.24/13
 o=box('AwningStripe',(x,-2.74,2.82),(6.24/13,.9,.075),color,.005);o.rotation_euler.x=math.radians(8)
 box('AwningValance',(x,-3.18,2.7),(6.24/13,.06,.2),color,.005)
for x in [-3,3]:bar('AwningSupport',(x,-2.24,2.45),(x,-3.11,2.72),.018)
# Low roof parapet, utilitarian equipment and rear delivery entrance.
box('RoofCap',(0,.6,3.99),(6.55,5.75,.2),'cream')
box('RoofDeck',(0,.6,4.11),(6.1,5.3,.08),'roof')
for side_y in [-2.14,3.34]:box('Parapet',(0,side_y,4.23),(6.5,.15,.32),'cream')
for side_x in [-3.2,3.2]:box('Parapet',(side_x,.6,4.23),(.15,5.6,.32),'cream')
box('HVACUnit',(1.3,1.2,4.57),(1.55,1.45,.85),'metal')
box('HVACTop',(1.3,1.2,5.02),(1.65,1.55,.1),'roof')
for offset in [-.45,-.25,-.05,.15,.35]:box('HVACLouvre',(1.3+offset,.45,4.58),(.06,.025,.62),'stone',0)
box('RearServiceDoor',(-1.5,3.34,1.47),(1.35,.12,2.35),'metal')
box('RearVent',(1.5,3.36,2.6),(1.1,.12,.6),'metal')
for zz in [2.4,2.55,2.7,2.85]:box('RearVentSlat',(1.5,3.44,zz),(1.05,.025,.025),'stone',0)
# Original produce stand; grouped, restrained color patches stay readable as a game asset.
box('ProduceStand',(-1.95,-3.3,.62),(1.55,.7,.8),'wood')
box('StandTop',(-1.95,-3.3,1.05),(1.63,.76,.09),'darkgreen')
for bin_index,color in enumerate(['red','fruit']):
 center_x=-2.34+bin_index*.77
 box('ProduceCrate',(center_x,-3.3,1.17),(.68,.62,.18),'wood')
 for row in range(3):
  for col in range(3):
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.095,location=(center_x-.2+col*.2,-3.5+row*.2,1.32))
   bpy.context.object.name='Produce';bpy.context.object.data.materials.append(m[color])
# Shopping trolley is a second commercial cue visible near the entrance.
cx,cy=2.85,-3.14
for x in [cx-.25,cx+.25]:
 for yy in [cy-.28,cy+.28]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.09,location=(x,yy,.34));bpy.context.object.name='TrolleyWheel';bpy.context.object.data.materials.append(m['black'])
for z in [.52,1.08]:
 for a,b in [((cx-.3,cy-.35,z),(cx+.3,cy-.35,z)),((cx+.3,cy-.35,z),(cx+.3,cy+.35,z)),((cx+.3,cy+.35,z),(cx-.3,cy+.35,z)),((cx-.3,cy+.35,z),(cx-.3,cy-.35,z))]:bar('TrolleyBasket',a,b,.018)
for x in [cx-.3,cx,cx+.3]:
 for yy in [cy-.35,cy+.35]:bar('TrolleyUpright',(x,yy,.52),(x,yy,1.08),.014)
for x in [cx-.3,cx+.3]:bar('TrolleyHandleStem',(x,cy+.35,1.05),(x,cy+.52,1.25),.019)
bar('TrolleyHandle',(cx-.3,cy+.52,1.25),(cx+.3,cy+.52,1.25),.035,'green')
# One occupied floor, no apartment-style floor stack.
marker=bpy.data.objects.new('OccupiedFloor_01',None);marker['storey_index']=1;scene.collection.objects.link(marker)
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-4.001 and low[1]>=-4.001 and high[0]<=4.001 and high[1]<=4.001,(low,high)
assert len([o for o in scene.objects if o.name.startswith('OccupiedFloor_')])==1
assert bpy.data.objects['MART_Front'].data.body=='MART' and bpy.data.objects['MART_Side'].data.body=='MART'
checkpoint('MODEL',f'Original 2x2 grocery geometry, one floor, world bounds {low} to {high}. Two actual MART letterings, basket icon, awning, produce crates and trolley. No third-party textures.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=2.0;distance=30
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=15;aim(camera,(0,0,target_z));scene.camera=camera
bpy.ops.object.light_add(type='SUN',location=(-20,-30,60));light=bpy.context.object;light.data.energy=2;light.data.angle=math.radians(12);aim(light,(0,0,0))
scene.world=bpy.data.worlds.new('World');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.55,.65,.75,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False;scene.cycles.device='CPU';scene.render.threads_mode='FIXED';scene.render.threads=6
scene.render.resolution_x=900;scene.render.resolution_y=1100;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
bpy.ops.file.pack_all()
scene.render.filepath=str(OUT/'mart.png');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'mart.blend'));checkpoint('SAVED','Editable original saved; transparent front and reverse rendering next.')
bpy.ops.render.render(write_still=True)
camera.location=(-distance,distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30)));aim(camera,(0,0,target_z));scene.render.filepath=str(OUT/'reverse-review.png');bpy.ops.render.render(write_still=True)
camera.location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30)));aim(camera,(0,0,target_z));bpy.context.view_layer.update()
def pixel(p):
 v=world_to_camera_view(scene,camera,Vector(p));return [round(v.x*900,4),round((1-v.y)*1100,4)]
meta={'id':'small-2x2-mart-01','name':'동네 MART','zone':'commercial','category':'small_commercial','footprint_cells':[2,2],'cell_meters':4,'lot_meters':[8,8],'occupied_storeys':1,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((4,-4,.12)),'lot_corners_px':[pixel(v) for v in [(-4,-4,.12),(4,-4,.12),(4,4,.12),(-4,4,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':15,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['MART lettering','shopping basket icon','wide shopfront','striped awning','produce stand','shopping trolley'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS MART concept, 2x2, one floor, two literal MART signs, no game registration')
