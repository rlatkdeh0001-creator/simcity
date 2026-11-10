"""Original one-asset MART concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'large-8x8-auto-assembly-07';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# Large industrial 03 · Auto Assembly\n\nBrief: automobile assembly facility, 8x8 cells (32x32m), one tall production hall and three office floors. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
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







box('Lot_8x8',(0,0,0),(32,32,.24),'stone',.04)
box('ConcreteYard',(0,0,.15),(31.9,31.9,.1),'paving')
# Wide single-storey assembly hall; the office wing has three occupied floors.
box('AssemblyHall',(-3,3,4.1),(20,22,7.8),'stone')
for x in [i*.65-12.6 for i in range(30)]:box('FrontCladdingRib',(x,-8.03,4.1),(.045,.045,7.6),'metal',0)
for y in [i*.65-7.5 for i in range(33)]:box('SideCladdingRib',(-13.03,y,4.1),(.045,.045,7.6),'metal',0)
box('OfficeWing',(10,3,4.9),(5.8,22,9.4),'cream')
box('OfficePlinth',(10,3,.65),(6,22.2,.9),'green')
for floor in range(3):
 z=2.15+floor*3.05
 box('OfficeFrontGlass',(10,-8.07,z),(5.15,.08,1.65),'glass')
 for x in [7.6,10,12.4]:box('OfficeFrontMullion',(x,-8.14,z),(.065,.04,1.7),'metal')
 for y in [-6.3,-3.3,-.3,2.7,5.7,8.7,11.7]:
  box('OfficeSideFrame',(12.97,y,z),(.12,2.3,1.7),'metal')
  box('OfficeSideWindow',(13.05,y,z),(.035,2.1,1.5),'glass')
 if floor<2:box('OfficeFloorBand',(10,3,z+1.4),(6.1,22.3,.2),'stone')
box('OfficeRoof',(10,3,9.82),(6.3,22.5,.25),'cream')
box('OfficeRoofDeck',(10,3,10),(5.9,22.1,.1),'roof')
box('StaffPortal',(10,-8.2,1.85),(3.2,.18,3.3),'metal')
box('StaffGlass',(10,-8.32,1.8),(2.9,.05,3.05),'lightglass')
box('DoorSplit',(10,-8.38,1.8),(.07,.03,3.05),'metal')
box('StaffCanopy',(10,-9.05,3.55),(4.1,1.8,.2),'metal')
# Four wide vehicle/loading doors.
for cx in [-10,-4,2]:
 box('LoadingPortal',(cx,-8.13,2.9),(5.1,.22,5.3),'metal')
 box('LoadingShutter',(cx,-8.27,2.9),(4.8,.06,5),'roof')
 for z in [i*.27+.5 for i in range(18)]:box('ShutterSlat',(cx,-8.32,z),(4.75,.025,.03),'metal',0)
 for x in [cx-2.6,cx+2.6]:
  box('Bollard',(x,-8.85,1),(.2,.2,1.6),'orange')
  box('BollardStripe',(x,-8.85,1.3),(.21,.21,.22),'black')
box('BrandBand',(-3,-8.18,6.95),(20.3,.24,1.15),'green')
text('FactoryName','AUTO ASSEMBLY',(-2.6,-8.34,6.97),(math.pi/2,0,0),15.7,.78)
# Original car pictogram beside the factory name.
y=-8.35
pts=[(-12,6.6),(-12,6.95),(-11.6,7),(-11.25,7.4),(-10.65,7.4),(-10.25,7),(-9.9,6.9),(-9.9,6.6)]
for a,c in zip(pts,pts[1:]):bar('CarPictogram',(a[0],y,a[1]),(c[0],y,c[1]),.045,'ivory')
for x in [-11.65,-10.3]:
 bpy.ops.mesh.primitive_torus_add(major_radius=.15,minor_radius=.035,major_segments=16,minor_segments=6,location=(x,y,6.63),rotation=(math.pi/2,0,0));bpy.context.object.data.materials.append(m['ivory'])
# Four sawtooth roof bays span the single-volume hall.
for cy in [-5.2,.3,5.8,11.3]:
 o=box('SawtoothRoof',(-3,cy,8.48),(20.5,5.55,.18),'metal');o.rotation_euler.x=.14
 box('RooflightFrame',(-3,cy-2.76,8.4),(20.4,.14,.95),'metal')
 box('Rooflight',(-3,cy-2.85,8.4),(20,.04,.72),'glass')
 for x in [-12.5,-9.4,-6.3,-3.2,-.1,3,6.1]:box('RooflightMullion',(x,cy-2.89,8.4),(.08,.035,.78),'metal')
for cy in [-3,7]:
 box('AirHandlingUnit',(10,cy,10.7),(3,3.8,1.2),'metal')
 for dx in [-1,-.5,0,.5,1]:box('AirVent',(10+dx,cy-1.94,10.7),(.12,.035,.85),'stone')
# External extraction spine along the rear of the production hall.
for x in [-8,1]:
 bar('ExtractorRiser',(x,14.6,1),(x,14.6,9.5),.25)
 bar('ExtractionElbow',(x,14.6,9.5),(x,12.7,9.5),.25)
 box('FilterCabinet',(x,14.4,1.6),(2,1.5,2.6),'metal')
# Vehicle dispatch: three original miniature cars, not retail displays.
def car(cx,cy,col):
 box('FinishedCarBody',(cx,cy,.92),(3.6,1.6,.6),col,.1)
 box('CarCabin',(cx+.1,cy,1.45),(1.9,1.4,.65),col,.1)
 box('CarSideGlass',(cx+.1,cy-.72,1.5),(1.6,.03,.4),'glass')
 box('Windshield',(cx-.87,cy,1.5),(.04,1.25,.4),'glass')
 for dx in [-1.15,1.15]:
  for dy in [-.8,.8]:
   bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.36,depth=.18,location=(cx+dx,cy+dy,.65),rotation=(math.pi/2,0,0));bpy.context.object.data.materials.append(m['black'])
   bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.2,depth=.19,location=(cx+dx,cy+dy,.65),rotation=(math.pi/2,0,0));bpy.context.object.data.materials.append(m['stone'])
for cy,col in [(-11,'red'),(-13.5,'cream')]:car(8.5,cy,col)
for y in [-9.7,-12.25,-14.8]:box('DispatchBayMark',(8.5,y,.213),(5.2,.075,.012),'ivory',0)
for x in [-10,-4,2]:
 for dx in [-2.1,2.1]:box('LoadingLane',(x+dx,-11.7,.213),(.08,5.3,.012),'orange',0)
for cx in [-12.5,-9.5]:
 box('Pallet',(cx,-13.5,.3),(2.3,1.5,.18),'wood')
 box('PartsCrate',(cx,-13.5,1.05),(2.1,1.3,1.3),'wood')
 for dx in [-.7,.7]:box('CrateStrap',(cx+dx,-13.5,1.05),(.1,1.35,1.35),'metal')
box('RearServiceDoor',(10,14.08,1.6),(1.5,.1,2.7),'metal')
for i in range(3):
 o=bpy.data.objects.new('OccupiedFloor_%02d'%(i+1),None);o['storey_index']=i+1;scene.collection.objects.link(o)
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-16.001 and low[1]>=-16.001 and high[0]<=16.001 and high[1]<=16.001,(low,high)
assert len([o for o in scene.objects if o.name.startswith('OccupiedFloor_')])==3
checkpoint('MODEL',f'Original 8x8 automobile assembly facility, one production hall and three-storey office wing. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=4.5;distance=65
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=59;aim(camera,(0,0,target_z));scene.camera=camera
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
meta={'id':'large-8x8-auto-assembly-07','name':'자동차 조립공장','zone':'industrial','category':'large_industrial','footprint_cells':[8,8],'cell_meters':4,'lot_meters':[32,32],'occupied_storeys':3,'production_hall_storeys':1,'office_wing_storeys':3,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((16,-16,.12)),'lot_corners_px':[pixel(v) for v in [(-16,-16,.12),(16,-16,.12),(16,16,.12),(-16,16,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':59,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['AUTO ASSEMBLY sign','single-volume production hall','three-storey office wing','sawtooth rooflights','loading bays','vehicle dispatch yard'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS 8x8 automobile assembly factory, low-rise, review only')
