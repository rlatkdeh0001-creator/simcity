"""Original one-asset MART concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'medium-4x4-circuitworks-04';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# Medium industrial 02 · Circuit Works\n\nBrief: electronics components factory, 4x4 cells (16x16m), three occupied floors. Approval pending; do not register in game. Original Blender geometry, game-art consistency and adapted kiln local source/visual-review principles. No external model, texture, or generation API.\n\nCheckpoint: BRIEF\n')
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
# Three occupied floors, clean insulated panels and restrained industrial glazing.
box('ProductionBuilding',(0,1.5,5.1),(12,10,9.8),'cream')
box('Plinth',(0,1.5,.65),(12.2,10.2,.9),'metal')
for x in [-5,-3,-1,1,3,5]:box('FrontPanelJoint',(x,-3.52,5.2),(.025,.025,9.4),'stone',0)
for y in [-2,0,2,4,6]:box('SidePanelJoint',(6.02,y,5.2),(.025,.025,9.4),'stone',0)
for level in range(3):
 z=2.25+level*3.15
 box('FrontWindowBand',(0,-3.57,z),(11.2,.08,1.15),'glass')
 box('SideWindowBand',(6.07,1.5,z),(.08,9.2,1.15),'glass')
 for x in [-5.3,-3.55,-1.8,0,1.8,3.55,5.3]:box('FrontWindowMullion',(x,-3.64,z),(.055,.04,1.2),'metal')
 for y in [-2.8,-.65,1.5,3.65,5.8]:box('SideWindowMullion',(6.14,y,z),(.04,.055,1.2),'metal')
 if level<2:
  box('FrontFloorBand',(0,-3.6,z+1.4),(12.2,.16,.18),'stone')
  box('SideFloorBand',(6.1,1.5,z+1.4),(.16,10.2,.18),'stone')
# Dedicated staff entrance and a single logistics bay, no retail windows/signs.
box('LoadingPortal',(-3.35,-3.7,1.8),(3.65,.2,3.2),'metal')
box('LoadingShutter',(-3.35,-3.83,1.8),(3.35,.05,2.95),'roof')
for z in [i*.2+.4 for i in range(14)]:box('ShutterSlat',(-3.35,-3.87,z),(3.3,.025,.025),'metal',0)
box('StaffPortal',(2.6,-3.73,1.75),(3.3,.2,3.1),'metal')
box('StaffGlass',(2.6,-3.87,1.7),(2.95,.04,2.8),'lightglass')
box('DoorSplit',(2.6,-3.92,1.7),(.06,.03,2.8),'metal')
for x in [2.4,2.8]:bar('Handle',(x,-3.97,1.25),(x,-3.97,1.85),.03)
box('EntryCanopy',(2.6,-4.25,3.4),(3.8,1.3,.16),'metal')
box('BrandBand',(0,-3.76,9.35),(12.3,.25,.8),'green')
text('Brand','CIRCUIT WORKS',(.35,-3.91,9.36),(math.pi/2,0,0),9.5,.55)
# Original microchip pictogram on front fascia.
box('ChipOutline',(-5.15,-3.93,9.36),(.6,.04,.48),'ivory')
box('ChipCore',(-5.15,-3.96,9.36),(.4,.02,.3),'green')
for dx in [-.2,0,.2]:
 for dz in [-.32,.32]:box('ChipPin',(-5.15+dx,-3.94,9.36+dz),(.04,.04,.16),'ivory')
# Flat roof with two large air-handling units and service ducts.
box('RoofCap',(0,1.5,10.17),(12.5,10.5,.25),'cream')
box('RoofDeck',(0,1.5,10.35),(12.1,10.1,.1),'roof')
for y in [-3.65,6.65]:box('Parapet',(0,y,10.58),(12.4,.15,.45),'cream')
for x in [-6.1,6.1]:box('Parapet',(x,1.5,10.58),(.15,10.3,.45),'cream')
for x in [-2.7,2.1]:
 box('AirHandlingUnit',(x,3.1,11.05),(2.7,2.9,1.25),'metal')
 box('AirUnitCap',(x,3.1,11.74),(2.85,3.05,.14),'roof')
 for dx in [-.9,-.45,0,.45,.9]:box('AirUnitLouvre',(x+dx,1.61,11.05),(.11,.03,.9),'stone')
 box('RoofDuct',(x,-.2,10.9),(.8,3.7,.7),'stone')
# External utility spine makes the production use readable from the main view.
for y,col in [(3.75,'metal'),(4.45,'green')]:
 bar('ServiceRiser',(6.65,y,.5),(6.65,y,10.95),.12,col)
 bar('ServiceRoofElbow',(6.65,y,10.95),(5.55,y,10.95),.12,col)
for z in [1.5,4.5,7.5]:box('PipeBracket',(6.47,4.1,z),(.65,1.05,.1),'metal')
box('UtilityCabinet',(6.65,1.65,1.3),(.7,1.7,2.1),'stone')
for y in [1.2,1.5,1.8,2.1]:box('CabinetLouvre',(7.02,y,1.3),(.025,.07,1.5),'metal')
# Packaged electronics dispatch crates and docking protection.
for x in [-5.3,-3.9]:
 box('Pallet',(x,-5.5,.3),(1.25,1.1,.18),'wood')
 box('ShippingCrate',(x,-5.5,.95),(1.15,1,1.1),'wood')
 for dx in [-.4,.4]:box('CrateStrap',(x+dx,-5.5,.95),(.07,1.05,1.15),'metal')
 box('ShippingLabel',(x,-6.02,1.03),(.45,.025,.3),'ivory')
for x in [-5.2,-1.5]:
 box('Bollard',(x,-4.15,.8),(.16,.16,1.2),'orange')
 box('BollardBand',(x,-4.15,1),(.17,.17,.18),'black')
for x in [-1,0,1]:
 o=box('LoadingMark',(x,-5.6,.213),(.08,2.3,.012),'orange',0);o.rotation_euler.z=-.35
box('RearServiceDoor',(1,6.57,1.55),(1.3,.1,2.6),'metal')
for i in range(3):
 o=bpy.data.objects.new('OccupiedFloor_%02d'%(i+1),None);o['storey_index']=i+1;scene.collection.objects.link(o)
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-8.001 and low[1]>=-8.001 and high[0]<=8.001 and high[1]<=8.001,(low,high)
assert len([o for o in scene.objects if o.name.startswith('OccupiedFloor_')])==3
checkpoint('MODEL',f'Original 4x4 electronics factory, three occupied storeys. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=5;distance=30
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=33;aim(camera,(0,0,target_z));scene.camera=camera
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
meta={'id':'medium-4x4-circuitworks-04','name':'전자부품 공장','zone':'industrial','category':'medium_industrial','footprint_cells':[4,4],'cell_meters':4,'lot_meters':[16,16],'occupied_storeys':3,'approval_status':'pending-user-review','game_registered':False,'image_size':[900,1100],'anchor_px':pixel((8,-8,.12)),'lot_corners_px':[pixel(v) for v in [(-8,-8,.12),(8,-8,.12),(8,8,.12),(-8,8,.12)]],'vertex_bounds_m':[low,high],'camera_elevation_degrees':30,'orthographic_scale':33,'source':'original scripted Blender geometry; system DejaVu font; no external models, textures or generation APIs','cues':['CIRCUIT WORKS sign','microchip pictogram','three production floors','loading bay','air handling units','external utility pipes'],'scope':'review-only concept; no game catalog or growth changes'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front/reverse 900x1100 RGBA outputs complete. Await user design approval; game registration prohibited until explicit approval.')
print('PASS medium industrial electronics factory, three storeys, review only')
