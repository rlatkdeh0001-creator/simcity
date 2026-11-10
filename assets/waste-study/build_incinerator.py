"""Original waste-facility concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'incinerator';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# 쓰레기 소각장\n\nBrief: road-side 8x8 waste incinerator concept. No landfill. User review pending; no game registration.\n\nCheckpoint: BRIEF\n')
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








m['water']=mat('Water','478b9b',.1,.24)
m['panel']=mat('SolarCells','284f78',.3,.22)
m['coal']=mat('Coal','33393a')
m['concrete']=mat('Concrete','b6b9ad')
box('Lot',(0,0,0),(32,32,.24),'stone',.04)
box('Ground',(0,0,.15),(31.9,31.9,.1),'paving')
def cyl(name,loc,radius,depth,col='metal',vertices=32):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc);o=bpy.context.object;o.name=name;o.data.materials.append(m[col]);return o
def sphere(name,loc,radius,col,scale=(1,1,1)):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=radius,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(m[col]);return o
def plant_hall(name,loc,size,col='cream'):
 x,y,z=loc;w,d,ht=size
 box(name,loc,size,col)
 box(name+'Roof',(x,y,z+ht/2+.12),(w+.4,d+.4,.24),'metal')
 for yy in [y-d*.32,y,y+d*.32]:
  box('HallSideWindow',(x+w/2+.06,yy,z+.4),(.06,d*.22,ht*.22),'glass')
def sign(word,x,y,z,width):
 box('Nameplate',(x,y,z),(width+.4,.16,.8),'green');text('Label_'+word,word,(x,y-.1,z),(math.pi/2,0,0),width,.5)
def pipe(a,b,r=.15,col='metal'):return bar('ServicePipe',a,b,r,col)
def stack(cx,cy,height,r=.65):
 cyl('Stack',(cx,cy,height/2+.2),r,height,'stone')
 for z in [height*.65,height*.77,height*.89]:cyl('StackBand',(cx,cy,z),r+.025,.6,'red')
 cyl('StackRim',(cx,cy,height+.25),r+.13,.2,'metal')
def tank(cx,cy,radius=2,height=4):
 cyl('StorageTank',(cx,cy,height/2+.5),radius,height,'roof')
 sphere('TankDome',(cx,cy,height+.5),radius,'roof',(1,1,.15))
 for z in [.8,height+.3]:
  bpy.ops.mesh.primitive_torus_add(major_radius=radius+.02,minor_radius=.05,major_segments=32,minor_segments=6,location=(cx,cy,z));bpy.context.object.data.materials.append(m['metal'])
def substation(cx,cy):
 box('SwitchyardBase',(cx,cy,.35),(5.2,4,.25),'stone')
 for dx in [-1.7,0,1.7]:
  box('Transformer',(cx+dx,cy,1.1),(1.1,1.4,1.3),'metal')
  for yy in [-.45,.45]:
   for zz in [1.9,2.15,2.4]:cyl('Insulator',(cx+dx,cy+yy,zz),.12,.16,'cream',12)
 for dx in [-2.3,2.3]:bar('SwitchyardUpright',(cx+dx,cy+1.6,.5),(cx+dx,cy+1.6,3.7),.07)
 bar('SwitchyardBeam',(cx-2.3,cy+1.6,3.7),(cx+2.3,cy+1.6,3.7),.07)





m['white']=mat('WarmWhitePanels','eeeee7')
m['lightgrey']=mat('LightGreyEquipment','c8cfca',.2,.55)
m['charcoal']=mat('DarkServiceTrim','435254',.15,.5)
# Rectangular incinerator with white panelled walls, an asymmetrical stepped roof
# and a broad enclosed waste receiving bay. No curved roofs or power-station stacks.
box('EnclosedWasteBunker',(-5,3,5.2),(17,19,10),'white')
box('BunkerBase',(-5,3,.7),(17.2,19.2,1),'stone')
box('BunkerRoof',(-5,3,10.35),(17.5,19.5,.3),'lightgrey')
# Tall rectangular furnace enclosure is integrated into the main building.
box('FurnaceEnclosure',(-1,5.5,9.1),(8,10,17.8),'white')
box('FurnaceRoof',(-1,5.5,18.15),(8.4,10.4,.3),'lightgrey')
for x in [-4.6,-2.8,-1,.8,2.6]:box('FurnacePanelJoint',(x,.46,11),(.025,.035,13.7),'stone',0)
for y in [1.4,3.4,5.4,7.4,9.4]:box('FurnaceSideJoint',(3.04,y,11),(.035,.025,13.7),'stone',0)
for x in [-12,-9,-6,-3,0,3]:box('BunkerPanelJoint',(x,-6.53,5.3),(.025,.03,9.7),'stone',0)
# Deep ground-floor tipping portals with clear waste receiving markings.
for cx in [-9,-2]:
 box('TippingPortal',(cx,-6.67,3.1),(6.1,.3,5.6),'charcoal')
 box('WasteDoor',(cx,-6.86,3.05),(5.65,.06,5.15),'lightgrey')
 for z in [i*.27+.65 for i in range(18)]:box('DoorSlat',(cx,-6.91,z),(5.6,.025,.025),'metal',0)
 for dx in [-3.2,3.2]:
  box('ImpactBollard',(cx+dx,-7.4,1),(.22,.22,1.6),'orange')
  box('BollardBand',(cx+dx,-7.4,1.3),(.23,.23,.22),'black')
 for dx in [-2.5,2.5]:box('ReceivingLane',(cx+dx,-10.3,.214),(.09,4.6,.014),'orange',0)
box('ReceivingCanopy',(-5.5,-7.6,6.1),(15.7,2.5,.25),'lightgrey')
box('WasteSignBack',(-5,-6.72,7.45),(15.2,.16,1),'charcoal')
text('WasteSign','WASTE INCINERATION',(-4.8,-6.83,7.47),(math.pi/2,0,0),13.8,.65)
# Small waste-bin pictogram avoids recycling-centre ambiguity.
y=-6.84
for a,c in [((-12.2,y,7.72),(-11.45,y,7.72)),((-12.1,y,7.65),(-12,y,7.17)),((-11.55,y,7.65),(-11.65,y,7.17)),((-12,y,7.17),(-11.65,y,7.17)),((-12.04,y,7.8),(-11.6,y,7.8))]:bar('WasteBinIcon',a,c,.025,'ivory')
for x in [-10.8,-8,-5.2]:
 box('HighLevelLouvre',(x,-6.62,9),(1.8,.14,.9),'metal')
 for z in [8.72,8.92,9.12,9.32]:box('LouvreSlat',(x,-6.71,z),(1.6,.03,.04),'stone')
# Main flue treatment train: bag filter bank and broad gas duct are outside.
box('BagFilterBank',(9,3.9,4.6),(7,10.4,8.8),'white')
box('FilterRoof',(9,3.9,9.2),(7.4,10.8,.25),'lightgrey')
for y in [.1,2.6,5.1,7.6]:
 box('FilterModuleFace',(12.56,y,4.9),(.12,1.8,6.2),'lightgrey')
 for z in [2.2,3.2,4.2,5.2,6.2,7.2]:box('FilterSlat',(12.64,y,z),(.025,1.5,.08),'metal')
box('MainGasDuct',(4.5,6.1,10.4),(4,1.8,1.8),'lightgrey')
box('FilterUptake',(6.4,6.1,9.4),(1.8,1.8,3),'lightgrey')
# A wide white rectangular exhaust tower rather than round striped twin chimneys.
box('WhiteExhaustTower',(10.2,11.6,11.3),(3.2,3.6,22.2),'white')
box('ExhaustTopRim',(10.2,11.6,22.5),(3.5,3.9,.3),'lightgrey')
box('DarkExhaustOpening',(10.2,11.6,22.67),(2.7,3.1,.035),'charcoal')
box('ExhaustConnection',(10.2,9,6),(1.7,5.3,1.7),'lightgrey')
# Compact staff/control room and sealed ash bins belong to the handling yard.
box('ControlRoom',(8.7,-6.8,2),(6.7,5.9,3.6),'white')
box('ControlRoof',(8.7,-6.8,3.95),(7,6.2,.22),'lightgrey')
box('StaffDoor',(9.6,-9.81,1.6),(1.25,.1,2.6),'metal')
for x in [6.2,8]:box('ControlWindow',(x,-9.81,2.4),(1.4,.05,1.1),'glass')
for y in [-8.6,-6.5,-4.4]:box('SideControlWindow',(12.11,y,2.4),(.05,1.2,1.1),'glass')
for cx in [-10,-6]:
 box('SealedAshContainer',(cx,14.2,1.2),(3.2,1.7,1.9),'lightgrey')
 box('AshContainerLid',(cx,14.2,2.2),(3.35,1.85,.13),'metal')
box('Weighbridge',(8.5,-12.6,.3),(3,5,.22),'metal')
for y in [-14.8,-10.4]:box('ScaleEndMark',(8.5,y,.42),(2.9,.12,.025),'orange',0)
# Enclosed roof ventilation with modest muted colour accents.
for cx in [-10,-6]:
 box('RoofVent',(cx,6,11),(1.7,2.4,1.1),'lightgrey')
 for dx in [-.5,0,.5]:box('VentLouvre',(cx+dx,4.76,11),(.12,.03,.8),'metal')
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-16.01 and low[1]>=-16.01 and high[0]<=16.01 and high[1]<=16.01,(low,high)
checkpoint('MODEL',f'White rectangular waste incineration facility. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=8.5;distance=100
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

def pixel(p):
 v=world_to_camera_view(scene,camera,Vector(p));return [round(v.x*900,4),round((1-v.y)*1100,4)]

meta={'id':'waste-incinerator','name':'쓰레기 소각장','category':'waste_utility','revision':'white-rectangular-incinerator','footprint_cells':[8,8],'footprint_status':'draft','cell_meters':4,'lot_meters':[32,32],'placement_surface':'land','road_adjacency_required':True,'landfill_included':False,'image_size':[900,1100],'anchor_px':pixel((16,-16,.12)),'lot_corners_px':[pixel(v) for v in [(-16,-16,.12),(16,-16,.12),(16,16,.12),(-16,16,.12)]],'vertex_bounds_m':[low,high],'approval_status':'pending-user-review','game_registered':False,'source':'original Blender geometry; DejaVu font; no external models or textures','scope':'incinerator visual concept only; no landfill, waste simulation or placement UI implemented'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front and reverse review renders complete. Pending approval; no runtime changes.')
print('PASS waste incinerator concept; no landfill')
