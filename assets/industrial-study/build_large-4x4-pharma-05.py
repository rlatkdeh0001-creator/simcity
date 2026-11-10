"""Original one-asset MART concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'large-4x4-pharma-05';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# Large industrial 01 · Pharma\n\nBrief: pharmaceutical production facility, 4x4 cells (16x16m), four occupied floors. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
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
# Four occupied production floors, with a narrow utility yard to the right.
box('PharmaProduction',(-1.35,1.5,6.75),(9.5,10,13.1),'cream')
box('Plinth',(-1.35,1.5,.65),(9.7,10.2,.9),'metal')
for x in [-5.4,-3.5,-1.6,.3,2.2]:box('FrontPanelJoint',(x,-3.52,6.9),(.025,.025,12.8),'stone',0)
for floor in range(4):
 z=2.15+floor*3.2
 box('FrontWindowBand',(-1.35,-3.58,z),(8.85,.08,1.3),'glass')
 for x in [-5.6,-3.5,-1.35,.8,2.9]:box('FrontMullion',(x,-3.65,z),(.055,.04,1.35),'metal')
 for y in [-2,.5,3,5.5]:
  box('SideWindowFrame',(3.46,y,z),(.12,1.85,1.4),'metal')
  box('SideWindow',(3.54,y,z),(.035,1.65,1.2),'glass')
 if floor<3:box('FrontFloorBand',(-1.35,-3.62,z+1.4),(9.7,.16,.2),'stone')
box('LoadingPortal',(-3.75,-3.75,1.85),(3.4,.2,3.3),'metal')
box('LoadingDoor',(-3.75,-3.88,1.85),(3.1,.05,3.05),'roof')
for z in [i*.2+.45 for i in range(14)]:box('ShutterSlat',(-3.75,-3.92,z),(3.05,.025,.025),'metal',0)
box('StaffPortal',(.75,-3.75,1.8),(3.2,.2,3.2),'metal')
box('StaffDoors',(.75,-3.89,1.75),(2.85,.04,2.9),'lightglass')
box('DoorSplit',(.75,-3.94,1.75),(.06,.03,2.9),'metal')
for x in [.55,.95]:bar('DoorHandle',(x,-3.99,1.3),(x,-3.99,1.95),.03)
box('EntryCanopy',(.75,-4.25,3.5),(3.7,1.3,.16),'metal')
box('BrandBand',(-1.35,-3.77,12.65),(9.8,.25,.9),'green')
text('PharmaName','PHARMA LAB',(-1.05,-3.92,12.67),(math.pi/2,0,0),7.5,.6)
# Capsule pictogram: two rounded ends and a divider, original geometry.
for x in [-5.55,-5.15]:
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.22,location=(x,-3.96,12.67));o=bpy.context.object;o.scale=(1,.2,1);o.data.materials.append(m['ivory'])
box('CapsuleMiddle',(-5.35,-3.96,12.67),(.4,.07,.44),'ivory')
box('CapsuleDivider',(-5.35,-4.01,12.67),(.04,.02,.44),'green')
box('RoofCap',(-1.35,1.5,13.45),(10,10.5,.25),'cream')
box('RoofDeck',(-1.35,1.5,13.64),(9.6,10.1,.12),'roof')
for y in [-3.65,6.65]:box('Parapet',(-1.35,y,13.85),(9.9,.15,.45),'cream')
for x in [-6.2,3.5]:box('Parapet',(x,1.5,13.85),(.15,10.3,.45),'cream')
# Large unoccupied air-handling plant and roof ducts identify a controlled production facility.
for x in [-3.5,.3]:
 box('AirHandlingUnit',(x,3,14.5),(2.8,3.3,1.5),'metal')
 box('AirUnitTop',(x,3,15.3),(3,3.5,.15),'roof')
 for dx in [-.9,-.45,0,.45,.9]:box('FilterLouvre',(x+dx,1.31,14.5),(.12,.035,1.1),'stone')
 box('RoofAirDuct',(x,-.5,14.15),(.9,3.8,.8),'stone')
# Two stainless utility tanks, legs and a guarded external service platform.
for yy in [.4,4.2]:
 cx=5.5
 for dx in [-.65,.65]:
  for dy in [-.65,.65]:box('TankLeg',(cx+dx,yy+dy,1.3),(.15,.15,2.1),'metal')
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=1.02,depth=4.1,location=(cx,yy,4.1));bpy.context.object.name='SealedUtilityTank';bpy.context.object.data.materials.append(m['roof'])
 for zz in [2.05,6.15]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1.02,location=(cx,yy,zz));o=bpy.context.object;o.name='TankEnd';o.scale.z=.3;o.data.materials.append(m['roof'])
 for zz in [2.5,5.7]:
  bpy.ops.mesh.primitive_torus_add(major_radius=1.03,minor_radius=.045,major_segments=24,minor_segments=6,location=(cx,yy,zz));bpy.context.object.data.materials.append(m['metal'])
 bar('TankOutlet',(cx,yy,1.9),(cx,yy,1.2),.13)
 bar('ServicePipe',(cx,yy,1.2),(3.35,yy,1.2),.13)
bar('VerticalUtilityPipe',(4.05,5.8,.5),(4.05,5.8,14.6),.13,'green')
bar('RoofUtilityElbow',(4.05,5.8,14.6),(2.9,5.8,14.6),.13,'green')
box('UtilityControlCabinet',(6.7,-2.5,1.5),(.6,1.4,2.5),'stone')
for z in [1,1.4,1.8,2.2]:box('CabinetLouvre',(7.02,-2.5,z),(.025,1.1,.06),'metal')
# Dispatch pallet and low impact bollards.
box('DispatchPallet',(-4.7,-5.5,.3),(1.8,1.2,.18),'wood')
for x in [-5.15,-4.25]:
 for z in [.68,1.36]:
  box('SealedCarton',(x,-5.5,z),(.8,1,.6),'wood')
  box('CartonLabel',(x,-6.02,z),(.38,.025,.25),'ivory')
for x in [-5.5,-2]:
 box('Bollard',(x,-4.2,.85),(.16,.16,1.3),'orange')
 box('BollardBand',(x,-4.2,1.05),(.17,.17,.18),'black')
for x in [-1,0,1]:
 o=box('ApronMark',(x,-5.7,.213),(.08,2.1,.012),'orange',0);o.rotation_euler.z=-.35
box('RearServiceDoor',(-1,6.58,1.6),(1.4,.1,2.7),'metal')
for i in range(4):
 o=bpy.data.objects.new('OccupiedFloor_%02d'%(i+1),None);o['storey_index']=i+1;scene.collection.objects.link(o)
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-8.001 and low[1]>=-8.001 and high[0]<=8.001 and high[1]<=8.001,(low,high)
assert len([o for o in scene.objects if o.name.startswith('OccupiedFloor_')])==4
checkpoint('MODEL',f'Original 4x4 pharmaceutical production facility, four occupied storeys. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=6.5;distance=30
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=37;aim(camera,(0,0,target_z));scene.camera=camera
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
meta={'id':'large-4x4-pharma-05','name':'제약 생산시설','zone':'industrial','category':'large_industrial','footprint_cells':[4,4],'cell_meters':4,'lot_meters':[16,16],'occupied_storeys':4,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((8,-8,.12)),'lot_corners_px':[pixel(v) for v in [(-8,-8,.12),(8,-8,.12),(8,8,.12),(-8,8,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':37,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['PHARMA LAB sign','capsule pictogram','four production floors','sealed utility tanks','roof air handling units','loading bay'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS large industrial pharma facility, four storeys, review only')
