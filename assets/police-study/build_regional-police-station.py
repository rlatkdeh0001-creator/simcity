"""Original police-service concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'regional-police-station';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# 광역 경찰서\n\nBlue police facility, distinct architecture. Draft footprint 8x8. Pending user review; no game integration.\n')
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







m['fire_red']=mat('PoliceBlue','346a9b')
m['deep_red']=mat('DeepPoliceBlue','284c73')
m['white']=mat('WarmWhiteTrim','efeddd')
m['charcoal']=mat('CharcoalTrim','3b4c4e',.15,.5)
m['siren_blue']=mat('BlueEmergencyLight','518cb9',.25,.2)
m['siren_red']=mat('RedEmergencyLight','e05648',.15,.2)
def base(side):
 box('Lot',(0,0,0),(side,side,.24),'stone',.04)
 box('Paving',(0,0,.15),(side-.1,side-.1,.1),'paving')
def garage(cx,front,width=3.2,height=3.6):
 box('GarageTrim',(cx,front,height/2+.3),(width+.3,.2,height+.3),'white')
 box('GarageShutter',(cx,front-.13,height/2+.3),(width,.06,height),'charcoal')
 for z in [.55+i*.22 for i in range(int((height-.4)/.22))]:box('ShutterSlat',(cx,front-.18,z),(width-.05,.025,.025),'stone',0)
 box('DoorGlassBand',(cx,front-.2,height*.62),(width-.25,.025,.62),'glass')
 for dx in [-width*.28,0,width*.28]:box('DoorWindowDivision',(cx+dx,front-.23,height*.62),(.045,.025,.64),'metal')
def badge(cx,y,z,size=.8):
 # Original fire-service shield and flame, shared identity across all three buildings.
 vv=[(cx-size*.48,y,z+size*.45),(cx+size*.48,y,z+size*.45),(cx+size*.4,y,z-size*.1),(cx,y,z-size*.55),(cx-size*.4,y,z-size*.1)]
 mesh=bpy.data.meshes.new('Shield');mesh.from_pydata(vv,[],[(0,1,2,3,4)]);mesh.materials.append(m['white']);o=bpy.data.objects.new('PoliceBadge',mesh);scene.collection.objects.link(o)
 pts=[(cx,z-size*.28),(cx-size*.17,z),(cx,z+size*.29),(cx+size*.06,z+size*.03),(cx+size*.2,z+size*.12),(cx+size*.13,z-size*.18)]
 mesh=bpy.data.meshes.new('Flame');mesh.from_pydata([(x,y-.02,zz) for x,zz in pts],[],[tuple(range(len(pts)))]);mesh.materials.append(m['fire_red']);o=bpy.data.objects.new('PoliceBadgeCentre',mesh);scene.collection.objects.link(o)
def engine(cx,cy,scale=1):
 made=set(scene.objects)
 box('PatrolChassis',(cx,cy,.56),(1.85,4.4,.3),'charcoal')
 box('PatrolBody',(cx,cy,1),(1.9,4.35,.65),'white',.09)
 box('BlueHood',(cx,cy-1.65,1.23),(1.84,1.05,.16),'fire_red',.04)
 box('BlueBoot',(cx,cy+1.65,1.23),(1.84,1.05,.16),'fire_red',.04)
 box('Cabin',(cx,cy-.05,1.56),(1.65,2.1,.8),'fire_red',.09)
 box('Windscreen',(cx,cy-1.13,1.63),(1.47,.035,.5),'glass')
 box('RearGlass',(cx,cy+1.03,1.63),(1.47,.035,.5),'glass')
 for dx in [-.845,.845]:
  box('SideGlass',(cx+dx,cy-.05,1.63),(.025,1.8,.5),'glass')
  box('WindowPillar',(cx+dx*1.02,cy,1.63),(.035,.07,.52),'white')
  box('BlueDoorStripe',(cx+dx*1.14,cy,1),(.025,2.7,.24),'fire_red')
 box('FrontBumper',(cx,cy-2.23,.7),(1.95,.13,.2),'white')
 for dx in [-.64,.64]:box('Headlamp',(cx+dx,cy-2.21,1.05),(.35,.035,.18),'ivory')
 for yy in [-1.4,1.4]:
  for dx in [-.97,.97]:
   o=cyl('PatrolWheel',(cx+dx,cy+yy,.57),.38,.15,'black',20);o.rotation_euler.y=math.pi/2
   o=cyl('WheelHub',(cx+dx*1.02,cy+yy,.57),.19,.16,'stone',16);o.rotation_euler.y=math.pi/2
 box('LightbarBase',(cx,cy-.1,2.03),(1.45,.3,.1),'charcoal')
 for dx,col in [(-.45,'siren_red'),(.45,'siren_blue')]:box('PoliceLightbar',(cx+dx,cy-.1,2.15),(.5,.28,.17),col)
 if scale!=1:
  T=Matrix.Translation((cx,cy,0)) @ Matrix.Diagonal((scale,scale,scale,1)) @ Matrix.Translation((-cx,-cy,0))
  for o in set(scene.objects)-made:
   if o.type=='MESH':
    mesh=o.data.copy();transform=T @ o.matrix_world
    for v in mesh.vertices:v.co=transform@v.co
    o.data=mesh;o.matrix_world=Matrix.Identity(4)
def window_front(cx,y,z,w=2,h=1.3):
 box('WindowFrame',(cx,y,z),(w+.15,.12,h+.15),'white')
 box('WindowGlass',(cx,y-.08,z),(w,.035,h),'glass')
 box('WindowMullion',(cx,y-.11,z),(.045,.025,h),'metal')
def stripes(cx,cy,w,d):
 for dx in [-w/2,w/2]:box('ExitLane',(cx+dx,cy,.214),(.08,d,.013),'ivory',0)


def entry(cx,y):
 box('EntryFrame',(cx,y,1.7),(2.6,.2,2.8),'white')
 box('EntryGlass',(cx,y-.13,1.7),(2.3,.04,2.55),'glass')
 box('EntrySplit',(cx,y-.18,1.7),(.06,.03,2.55),'metal')
for_unused=None

base(32)
# Large four-storey headquarters: central glass entrance and two blue civic wings.
box('Headquarters',(0,2.4,8),(25,21,15.6),'fire_red')
box('GroundStoneBase',(0,2.4,1),(25.2,21.2,1.6),'white')
for floor in range(4):
 z=2.3+floor*3.65
 for cx in [-9,-5,5,9]:window_front(cx,-8.19,z,2.8,2.05)
 for yy in [-5.6,-2,1.6,5.2,8.8,11]:
  box('SideWindowFrame',(12.57,yy,z),(.12,2.35,2.1),'white')
  box('SideWindow',(12.65,yy,z),(.035,2.15,1.9),'glass')
 if floor<3:box('FrontWhiteBand',(0,-8.22,z+1.45),(25.3,.2,.22),'white')
box('CentralGlassFrame',(0,-8.45,8),(5.9,.6,15.3),'white')
box('CentralGlassAtrium',(0,-8.8,8),(5.4,.05,14.8),'glass')
for z in [4.3,7.95,11.6]:box('AtriumFloorLine',(0,-8.85,z),(5.5,.035,.1),'white')
entry(0,-8.93)
box('PublicEntryCanopy',(0,-9.5,3.5),(7,2,.25),'deep_red')
box('HeadquartersBrand',(0,-8.99,13.6),(12,.18,1.1),'deep_red')
text('HQName','REGIONAL POLICE',(0,-9.11,13.62),(math.pi/2,0,0),11,.7)
badge(0,-9.12,10.7,2)
box('RoofCornice',(0,2.4,16.1),(25.8,21.8,.4),'white')
box('RoofDeck',(0,2.4,16.37),(25.3,21.3,.12),'roof')
# Blue rooftop command crest, no helipad or fire-station training tower.
for cx in [-9,-4]:box('RoofPlant',(cx,11,17),(2.7,3.4,1),'metal')
bar('CommsMast',(8.9,11.4,16.5),(8.9,11.4,21),.1)
for z in [18,19.2,20.4]:bar('AntennaCross',(8.2,11.4,z),(9.6,11.4,z),.04)

roof_additions_before=set(scene.objects)
m['helipad']=mat('HelipadSurface','52655d',.1,.75)
PX,PY=-2.7,.5;PAD=14.8
box('HelipadDeck',(PX,PY,17.36),(PAD,PAD,.18),'helipad')
for yy in [PY-7,PY+7]:box('HelipadBoundary',(PX,yy,17.465),(14,.14,.025),'white',0)
for xx in [PX-7,PX+7]:box('HelipadBoundary',(xx,PY,17.465),(.14,14,.025),'white',0)
# Flat annulus and geometric H maintain crisp markings in the game view.
vs=[];ff=[];N=96
for rr in [5.65,5.4]:
 for i in range(N):
  a=i*math.tau/N;vs.append((PX+rr*math.cos(a),PY+rr*math.sin(a),17.485))
for i in range(N):j=(i+1)%N;ff.append((i,j,N+j,N+i))
mesh=bpy.data.meshes.new('HelipadCircleMesh');mesh.from_pydata(vs,[],ff);mesh.materials.append(m['white']);o=bpy.data.objects.new('HelipadCircle',mesh);scene.collection.objects.link(o)
for xx in [PX-1.6,PX+1.6]:box('HelipadH',(xx,PY,17.49),(.5,5.2,.025),'white',0)
box('HelipadHCrossbar',(PX,PY,17.515),(3.7,.5,.025),'white',0)
for xx in [PX-7.12,PX+7.12]:
 for yy in [PY-7.12,PY+7.12]:cyl('HelipadEdgeLight',(xx,yy,17.56),.12,.14,'orange',12)
# Keep the pad geometry clear of the roof plant, mast, and parapets.
assert PX-PAD/2>-13.65 and PX+PAD/2<11.65
assert PY-PAD/2>-7.75 and PY+PAD/2<13.15


# A compact roof stair enclosure links the landing pad to the main building.
# It is an access bulkhead, not another occupied office floor.
SX,SY=8.3,4.2;SW,SD=4.3,5
assert SX-SW/2>PX+PAD/2+.8,'Keep the enclosure clear of the landing deck'
box('RooftopStairBulkhead',(SX,SY,18.77),(SW,SD,2.64),'white')
box('StairBulkheadRedBase',(SX,SY,17.7),(SW+.06,SD+.06,.5),'fire_red')
box('StairBulkheadRoof',(SX,SY,20.2),(SW+.35,SD+.35,.22),'deep_red')
# Door faces the pad-side access route and has a glazed upper panel.
box('RoofStairDoorFrame',(SX,1.63,18.55),(1.8,.16,2.35),'fire_red')
box('RoofStairDoor',(SX,1.52,18.55),(1.55,.045,2.12),'metal')
box('StairDoorGlazing',(SX,1.485,18.97),(1.12,.025,.85),'glass')
bar('StairDoorHandle',(SX+.52,1.43,18.23),(SX+.52,1.43,18.65),.025,'white')
box('StairsNameplate',(SX,1.54,19.97),(2.9,.1,.42),'deep_red')
text('StairsLabel','STAIRS',(SX,1.47,19.98),(math.pi/2,0,0),2.45,.28)
# Side glazing makes the small access enclosure legible from the game camera.
box('StairSideWindowFrame',(10.51,4.1,18.95),(.12,2.15,1.25),'fire_red')
box('StairSideWindow',(10.59,4.1,18.95),(.03,1.95,1.05),'glass')
box('StairSideMullion',(10.62,4.1,18.95),(.025,.05,1.05),'metal')
# A flush L-shaped walkway meets the pad at its right edge and reaches the door.
box('HelipadAccessPath',(6.5,.5,17.36),(3.6,1.35,.18),'helipad')
box('DoorApproach',(8.3,1.1,17.36),(1.35,1.2,.18),'helipad')
for yy in [-.175,1.175]:box('AccessPathEdge',(6.5,yy,17.465),(3.6,.075,.02),'white',0)
for xx in [7.625,8.975]:box('DoorApproachEdge',(xx,1.1,17.465),(.075,1.2,.02),'white',0)
# Flat arrow directs arriving personnel toward the stair door.
box('AccessArrowStem',(6.45,.5,17.49),(.85,.12,.02),'white',0)
mesh=bpy.data.meshes.new('AccessArrowMesh');mesh.from_pydata([(7.3,.5,17.505),(6.8,.82,17.505),(6.8,.18,17.505)],[],[(0,1,2)]);mesh.materials.append(m['white']);o=bpy.data.objects.new('AccessArrow',mesh);scene.collection.objects.link(o)
assert SX+SW/2<11.65 and SY+SD/2<9,'Access block remains inside roof and away from communications mast'


for obj in set(scene.objects)-roof_additions_before:
 if obj.type=='MESH':
  mesh=obj.data.copy();transform=obj.matrix_world.copy()
  for vertex in mesh.vertices:
   vertex.co=transform@vertex.co;vertex.co.z-=.85
  obj.data=mesh;obj.matrix_world=Matrix.Identity(4)
 elif obj.type=='FONT':obj.location.z-=.85

engine(-8,-12,1);engine(7.5,-12,1)
stripes(-4,-12,2.8,5.4);stripes(3.5,-12,2.8,5.4)
# Clearly visible civic steps and two blue entry pillars.
for i in range(3):box('PublicSteps',(0,-10.2-i*.4,.45-i*.07),(5,.45,.25),'stone')
for x in [-3.9,3.9]:box('EntryPillar',(x,-10.2,1.4),(.4,.4,2.3),'deep_red')

bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-16.0-.02 and low[1]>=-16.0-.02 and high[0]<=16.0+.02 and high[1]<=16.0+.02,(low,high)
checkpoint('MODEL',f'Original police facility. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=8;distance=100
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
meta={'id':'regional-police-station','name':'광역 경찰서','category':'police_service','footprint_cells':[8,8],'footprint_status':'draft','cell_meters':4,'lot_meters':[32,32],'max_storeys':4,'rooftop_helipad':True,'rooftop_stair_access':True,'helipad_deck_m':[14.8,14.8],'revision':'police-headquarters-rooftop-helipad','placement_surface':'land','road_adjacency_required':True,'image_size':[900,1100],'anchor_px':pixel((16.0,-16.0,.12)),'lot_corners_px':[pixel(v) for v in [(-16.0,-16.0,.12),(16.0,-16.0,.12),(16.0,16.0,.12),(-16.0,16.0,.12)]],'vertex_bounds_m':[low,high],'approval_status':'pending-user-review','game_registered':False,'source':'original Blender geometry and patrol vehicles, adapted local helpers; DejaVu font; no external models or textures','scope':'police visual concepts only; crime, patrol and response simulation not implemented'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front and reverse renders complete; review only.')
print('PASS police regional-police-station')
