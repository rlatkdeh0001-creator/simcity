"""Original fire-service concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'fire-station';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# 소방서\n\nBrief: red fire facility, 6x6 draft lot, distinct architecture. User review pending; no game registration.\n\nCheckpoint: BRIEF\n')
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







m['fire_red']=mat('FireStationRed','b64137')
m['deep_red']=mat('DeepRedRoof','833c36')
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
 mesh=bpy.data.meshes.new('Shield');mesh.from_pydata(vv,[],[(0,1,2,3,4)]);mesh.materials.append(m['white']);o=bpy.data.objects.new('FireServiceBadge',mesh);scene.collection.objects.link(o)
 pts=[(cx,z-size*.28),(cx-size*.17,z),(cx,z+size*.29),(cx+size*.06,z+size*.03),(cx+size*.2,z+size*.12),(cx+size*.13,z-size*.18)]
 mesh=bpy.data.meshes.new('Flame');mesh.from_pydata([(x,y-.02,zz) for x,zz in pts],[],[tuple(range(len(pts)))]);mesh.materials.append(m['fire_red']);o=bpy.data.objects.new('BadgeFlame',mesh);scene.collection.objects.link(o)
def engine(cx,cy,scale=1):
 # Compact original fire engine pointing toward -Y, with roller equipment lockers and roof ladder.
 made=set(scene.objects)
 box('EngineChassis',(cx,cy,.65),(2,4.9,.35),'charcoal')
 box('EngineRearBody',(cx,cy+.6,1.45),(2,3.2,1.35),'fire_red',.06)
 box('EngineCab',(cx,cy-1.7,1.6),(2,1.45,1.7),'fire_red',.08)
 box('EngineWindscreen',(cx,cy-2.44,1.95),(1.75,.035,.73),'glass')
 box('EngineBumper',(cx,cy-2.5,.82),(2.1,.15,.2),'white')
 for dx in [-.65,.65]:box('Headlamp',(cx+dx,cy-2.53,1.12),(.32,.03,.2),'ivory')
 for dx in [-1.025,1.025]:
  for yy in [cy-.1,cy+1.25]:
   box('EquipmentLocker',(cx+dx,yy,1.55),(.025,1.1,.8),'stone')
  box('EngineWhiteStripe',(cx+dx,cy+.55,1.02),(.03,3.1,.13),'white')
 for yy in [cy-1.7,cy+1.65]:
  for dx in [-1.04,1.04]:
   o=cyl('TruckWheel',(cx+dx,yy,.65),.43,.18,'black',20);o.rotation_euler.y=math.pi/2
   o=cyl('WheelHub',(cx+dx*1.015,yy,.65),.22,.19,'stone',16);o.rotation_euler.y=math.pi/2
 for dx in [-.6,.6]:bar('RoofLadder',(cx+dx,cy-.7,2.25),(cx+dx,cy+2,2.25),.035,'stone')
 for yy in [cy-.6+i*.35 for i in range(8)]:bar('LadderRung',(cx-.6,yy,2.25),(cx+.6,yy,2.25),.027,'stone')
 box('LightBarBase',(cx,cy-1.7,2.5),(1.65,.35,.12),'charcoal')
 for dx,col in [(-.5,'siren_red'),(.5,'siren_blue')]:box('LightBar',(cx+dx,cy-1.7,2.65),(.55,.33,.2),col)
 if scale!=1:
  # Bake world geometry around the chosen vehicle centre.
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

base(24)
# L-shaped station: low three-bay appliance hall and tall glazed office/stair wing.
box('ApplianceHall',(-4.5,1.5,2.7),(13,11,5),'fire_red')
box('HallRoof',(-4.5,1.5,5.4),(13.5,11.5,.3),'white')
for cx in [-8.3,-4.2,-.1]:garage(cx,-4.12,3.45,3.85)
box('GarageNameBand',(-4.5,-4.26,4.75),(13.2,.18,.65),'deep_red')
text('StationName','CITY FIRE STATION',(-4.5,-4.37,4.77),(math.pi/2,0,0),11.9,.42)
box('ThreeStoreyOffice',(6.4,3.1,4.9),(6.5,14.2,9.4),'fire_red')
box('OfficeRoof',(6.4,3.1,9.8),(6.9,14.6,.3),'white')
# A white vertical entrance frame and tall staircase glazing define the front corner.
box('EntryFrame',(6.4,-4.15,4.75),(3,.3,8.9),'white')
box('StaircaseGlass',(6.4,-4.33,5.25),(2.6,.04,7.1),'glass')
for z in [3,5.9,8.8]:box('StairTransom',(6.4,-4.39,z),(2.65,.03,.06),'metal')
box('OfficeDoor',(6.4,-4.43,1.6),(1.55,.04,2.6),'lightglass')
for floor in range(3):
 z=2.1+floor*2.85
 for y in [-2,1,4,7,9]:
  box('OfficeSideFrame',(9.72,y,z),(.12,1.9,1.5),'white')
  box('OfficeSideWindow',(9.8,y,z),(.035,1.72,1.32),'glass')
badge(3.9,-4.44,7.9,1)
engine(-8.3,-7.7,1)
for cx in [-4.2,-.1]:stripes(cx,-7.8,3.5,5.5)
# Rear low training/service wing, with roof hose racks instead of a tower.
box('RearServiceWing',(-3,8.7,2.1),(10,2.8,3.8),'white')
box('ServiceRoof',(-3,8.7,4.2),(10.3,3.1,.2),'deep_red')
for x in [-6,-3,0]:bar('HoseRack',(x,8,4.5),(x,9.6,4.5),.055)

bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-12.0-.02 and low[1]>=-12.0-.02 and high[0]<=12.0+.02 and high[1]<=12.0+.02,(low,high)
assert len([o for o in scene.objects if o.name.startswith('GarageShutter')])==3
checkpoint('MODEL',f'Original fire facility. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=4;distance=100
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=47;aim(camera,(0,0,target_z));scene.camera=camera
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
meta={'id':'fire-station','name':'소방서','category':'fire_service','footprint_cells':[6,6],'footprint_status':'draft','cell_meters':4,'lot_meters':[24,24],'max_storeys':3,'garage_bays':3,'placement_surface':'land','road_adjacency_required':True,'image_size':[900,1100],'anchor_px':pixel((12.0,-12.0,.12)),'lot_corners_px':[pixel(v) for v in [(-12.0,-12.0,.12),(12.0,-12.0,.12),(12.0,12.0,.12),(-12.0,12.0,.12)]],'vertex_bounds_m':[low,high],'approval_status':'pending-user-review','game_registered':False,'source':'original Blender buildings, badges and fire engines; DejaVu font; no external models or textures','scope':'visual concept only; emergency dispatch, coverage and fire simulation not implemented'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front and reverse review renders complete. Pending approval; no runtime changes.')
print('PASS fire facility fire-station')
