"""Original one-asset MART concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'large-8x8-chemical-complex-08';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# Large industrial 04 · Chemical Complex\n\nBrief: chemical production facility, 8x8 cells (32x32m), four occupied floors and separate low service annex. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
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
# New composition: four-storey central production block, low utility annex,
# broad horizontal storage vessels, rear vertical tank farm, and a loading court.
box('FourStoreyProduction',(-4.2,2,7.15),(16,20,13.9),'cream')
box('ProductionPlinth',(-4.2,2,.7),(16.2,20.2,1),'metal')
for floor in range(4):
 z=2.25+floor*3.4
 box('FrontRibbonGlass',(-4.2,-8.07,z),(15.2,.08,1.45),'glass')
 for x in [-11.5,-9.1,-6.7,-4.3,-1.9,.5,3]:box('FrontMullion',(x,-8.14,z),(.065,.045,1.5),'metal')
 for y in [-6.3,-3,.3,3.6,6.9,10.2]:
  box('SideWindowFrame',(3.87,y,z),(.14,2.5,1.55),'metal')
  box('SideWindow',(3.96,y,z),(.04,2.3,1.35),'glass')
 if floor<3:
  box('FrontFloorBand',(-4.2,-8.13,z+1.5),(16.3,.2,.26),'stone')
  box('SideFloorBand',(3.9,2,z+1.5),(.2,20.3,.26),'stone')
for x in [-12,-7.9,-3.8,.3,3.6]:box('FrontStonePier',(x,-8.2,7.3),(.2,.23,13.6),'stone')
# Two sealed dispatch docks and a separate personnel lobby.
for cx in [-9.2,-4.5]:
 box('DockPortal',(cx,-8.32,2),(4,.24,3.6),'metal')
 box('DockShutter',(cx,-8.47,2),(3.7,.06,3.3),'roof')
 for z in [i*.22+.5 for i in range(14)]:box('ShutterSlat',(cx,-8.52,z),(3.65,.025,.03),'metal',0)
 for x in [cx-2.1,cx+2.1]:
  box('Bollard',(x,-9.05,.9),(.18,.18,1.4),'orange')
  box('BollardStripe',(x,-9.05,1.15),(.19,.19,.2),'black')
box('LobbyPortal',(1,-8.33,1.95),(3.2,.25,3.5),'metal')
box('LobbyGlass',(1,-8.49,1.9),(2.9,.05,3.2),'lightglass')
box('DoorSplit',(1,-8.55,1.9),(.07,.035,3.2),'metal')
for x in [.8,1.2]:bar('Handle',(x,-8.6,1.4),(x,-8.6,2.1),.035)
box('LobbyCanopy',(1,-9.2,3.7),(4.3,1.8,.2),'metal')
box('BrandBand',(-4.2,-8.34,13.25),(16.3,.25,1.1),'green')
text('FactoryName','CHEM COMPLEX',(-4.2,-8.5,13.27),(math.pi/2,0,0),13.5,.75)
box('RoofCap',(-4.2,2,14.35),(16.6,20.6,.3),'cream')
box('RoofDeck',(-4.2,2,14.57),(16.2,20.2,.12),'roof')
for x in [-12.4,4]:box('RoofParapet',(x,2,14.8),(.18,20.5,.5),'cream')
for y in [-8.2,12.2]:box('RoofParapet',(-4.2,y,14.8),(16.5,.18,.5),'cream')
# Broad roof plant, paired ventilation stacks and service ducts.
for cx in [-8,-1]:
 box('AirHandlingUnit',(cx,5.5,15.4),(3.7,5,1.4),'metal')
 box('AirHandlingCap',(cx,5.5,16.15),(3.9,5.2,.15),'roof')
 for dx in [-1.3,-.65,0,.65,1.3]:box('AirLouvre',(cx+dx,2.96,15.4),(.14,.04,1),'stone')
 box('RoofDuct',(cx,-1,15.1),(1.3,7.8,.9),'stone')
for cx in [-8,-1]:
 bar('VentStack',(cx,9.4,14.6),(cx,9.4,17.4),.4)
 box('VentStackCap',(cx,9.4,17.5),(1.25,1.25,.18),'metal')
# Low, distinct service annex occupying the right rear corner.
box('UtilityAnnex',(9.8,6.3,2.3),(8.4,10.6,4.2),'metal')
box('AnnexRoof',(9.8,6.3,4.55),(8.8,11,.25),'roof')
for y in [2.2,4.8,7.4,10]:
 box('AnnexLouvre',(14.07,y,2.4),(.12,1.8,2.3),'stone')
 for z in [1.55,1.95,2.35,2.75,3.15]:box('LouvreSlat',(14.15,y,z),(.035,1.6,.06),'metal')
# Horizontal storage vessels: a different silhouette from the 4x4 vertical reactors.
for cy in [-5.6,-1]:
 cx=9.5;z=2.75
 for dx in [-2,2]:box('VesselSaddle',(cx+dx,cy,1.1),(.65,2,1.7),'stone')
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=1.35,depth=6.2,location=(cx,cy,z),rotation=(0,math.pi/2,0));bpy.context.object.name='HorizontalStorageVessel';bpy.context.object.data.materials.append(m['roof'])
 for x in [cx-3.1,cx+3.1]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1.35,location=(x,cy,z));o=bpy.context.object;o.name='VesselEnd';o.scale.x=.3;o.data.materials.append(m['roof'])
 for x in [cx-2.1,cx+2.1]:
  bpy.ops.mesh.primitive_torus_add(major_radius=1.37,minor_radius=.055,major_segments=24,minor_segments=6,location=(x,cy,z),rotation=(0,math.pi/2,0));bpy.context.object.data.materials.append(m['metal'])
 bar('VesselOutlet',(cx,cy,4),(cx,cy,5),.16,'green')
 bar('VesselSupply',(cx,cy,5),(4.1,cy,5),.16,'green')
# Rear tank farm remains lower than the four-storey main block.
for cx in [-8,-2.5,3]:
 cy=14.4
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=1.15,depth=5.2,location=(cx,cy,3.1));bpy.context.object.name='RearStorageTank';bpy.context.object.data.materials.append(m['roof'])
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1.15,location=(cx,cy,5.7));o=bpy.context.object;o.scale.z=.22;o.data.materials.append(m['roof'])
 bar('TankOutlet',(cx,cy,1),(cx,12.5,1),.14,'green')
bar('TankFarmTrunk',(-8,12.5,1),(4.8,12.5,1),.14,'green')
# Side utility risers and overhead service rack.
for y in [1,3]:
 bar('VerticalRiser',(4.7,y,.6),(4.7,y,15.6),.17,'metal')
 bar('RoofRiserElbow',(4.7,y,15.6),(3.4,y,15.6),.17,'metal')
for z in [4,8,12]:box('RiserBracket',(4.4,2,z),(.8,2.5,.15),'metal')
for y in [-5.6,-1]:
 box('PipeRackPost',(5.2,y,2.8),(.18,.18,5.2),'metal')
 box('PipeRackBeam',(5.2,y,5.3),(2,.18,.18),'metal')
# Larger logistics forecourt with crates, lane marks and dispatch bollards.
for cx in [-11,-7.5]:
 box('DispatchPallet',(cx,-12.3,.3),(2.5,1.6,.18),'wood')
 box('DispatchCrate',(cx,-12.3,1.1),(2.3,1.4,1.4),'wood')
 for dx in [-.75,.75]:box('CrateStrap',(cx+dx,-12.3,1.1),(.1,1.45,1.45),'metal')
for cx in [-9.2,-4.5]:
 for dx in [-1.8,1.8]:box('LoadingLane',(cx+dx,-11.4,.213),(.08,4.7,.012),'orange',0)
for x in [7,8,9,10]:
 bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.32,depth=1,location=(x,-12,.75));bpy.context.object.data.materials.append(m['green'])
box('RearServiceDoor',(-4.2,12.08,1.65),(1.5,.1,2.8),'metal')
for i in range(4):
 o=bpy.data.objects.new('OccupiedFloor_%02d'%(i+1),None);o['storey_index']=i+1;scene.collection.objects.link(o)
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-16.001 and low[1]>=-16.001 and high[0]<=16.001 and high[1]<=16.001,(low,high)
assert len([o for o in scene.objects if o.name.startswith('OccupiedFloor_')])==4
checkpoint('MODEL',f'Original 8x8 chemical production facility, four occupied storeys with redesigned horizontal tank yard. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=7;distance=65
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=65;aim(camera,(0,0,target_z));scene.camera=camera
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
meta={'id':'large-8x8-chemical-complex-08','name':'대규모 화학 플랜트','zone':'industrial','category':'large_industrial','footprint_cells':[8,8],'cell_meters':4,'lot_meters':[32,32],'occupied_storeys':4,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((16,-16,.12)),'lot_corners_px':[pixel(v) for v in [(-16,-16,.12),(16,-16,.12),(16,16,.12),(-16,16,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':65,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['CHEM COMPLEX sign','four-storey production block','horizontal storage vessels','low service annex','rear tank farm','roof air plant'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS large industrial chemical facility, four occupied storeys, review only')
