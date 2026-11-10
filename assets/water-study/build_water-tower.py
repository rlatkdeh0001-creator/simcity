"""Original water-utility concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'water-tower';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# 급수탑\n\nBrief: 2x2 draft footprint, placement=land, road_required=True. User review pending; no game registration.\n\nCheckpoint: BRIEF\n')
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



m['cleanwater']=mat('CleanWater','5a9fa7',.05,.25)
m['wastewater']=mat('WasteWater','78876b',.03,.38)
m['blue']=mat('WaterUtilityBlue','397d97',.12,.48)
def rail_rect(cx,cy,w,d,z,col='orange'):
 for yy in [cy-d/2,cy+d/2]:
  for zz in [z+.45,z+.95]:bar('SafetyRail',(cx-w/2,yy,zz),(cx+w/2,yy,zz),.035,col)
  count=max(1,math.ceil(w/1.5))
  for i in range(count+1):
   x=cx-w/2+w*i/count;bar('RailPost',(x,yy,z),(x,yy,z+1),.03,col)
 for xx in [cx-w/2,cx+w/2]:
  for zz in [z+.45,z+.95]:bar('SafetyRail',(xx,cy-d/2,zz),(xx,cy+d/2,zz),.035,col)
def land_base(side):
 box('Lot',(0,0,0),(side,side,.24),'stone',.04)
 box('Paving',(0,0,.15),(side-.1,side-.1,.1),'paving')
def water_context(side):
 box('Context_Water',(0,0,-.35),(side,side,.45),'water')
def deck_piles(cx,cy,w,d,z):
 box('OverwaterDeck',(cx,cy,z),(w,d,.35),'stone')
 for x in [cx-w*.4,cx+w*.4]:
  for y in [cy-d*.4,cy+d*.4]:cyl('Pile',(x,y,(z-2)/2),.2,z+2,'metal')
def pump(cx,cy,z,col='blue'):
 cyl('PumpBase',(cx,cy,z+.16),.55,.25,'metal')
 cyl('PumpMotor',(cx,cy,z+.7),.42,.85,col)
 pipe((cx,cy,z+.4),(cx,cy-1,z+.4),.18,col)
 for zz in [z+.5,z+.65,z+.8]:cyl('MotorRib',(cx,cy,zz),.45,.06,'metal',24)
def open_pipe(name,a,b,r=.3,col='blue'):
 # Hollow pipe makes the intake/outfall opening readable.
 delta=Vector(b)-Vector(a);axis=delta.normalized();u=axis.cross(Vector((0,0,1)))
 if u.length<.01:u=axis.cross(Vector((0,1,0)))
 u.normalize();v=axis.cross(u);vs=[];faces=[];n=32
 for pnt in [Vector(a),Vector(b)]:
  for rr in [r,r*.75]:
   for i in range(n):
    ang=i*math.tau/n;vs.append(pnt+rr*(math.cos(ang)*u+math.sin(ang)*v))
 for i in range(n):
  j=(i+1)%n
  faces.extend([(i,j,2*n+j,2*n+i),(n+i,3*n+i,3*n+j,n+j),(i,n+i,n+j,j),(2*n+i,2*n+j,3*n+j,3*n+i)])
 mesh=bpy.data.meshes.new(name+'Mesh');mesh.from_pydata(vs,[],faces);mesh.materials.append(m[col]);o=bpy.data.objects.new(name,mesh);scene.collection.objects.link(o)
def basin(cx,cy,radius):
 n=48;vs=[];faces=[]
 for z in [.35,1.8]:
  for rr in [radius,radius-.3]:
   for i in range(n):
    a=i*math.tau/n;vs.append((cx+rr*math.cos(a),cy+rr*math.sin(a),z))
 for i in range(n):
  j=(i+1)%n;faces.extend([(i,j,2*n+j,2*n+i),(n+i,3*n+i,3*n+j,n+j),(2*n+i,2*n+j,3*n+j,3*n+i)])
 mesh=bpy.data.meshes.new('ClarifierWall');mesh.from_pydata(vs,[],faces);mesh.materials.append(m['stone']);o=bpy.data.objects.new('ClarifierBasin',mesh);scene.collection.objects.link(o)
 cyl('SettlingWater',(cx,cy,1.15),radius-.32,.2,'wastewater',48)
 cyl('ClarifierHub',(cx,cy,1.7),.5,1,'metal')
 box('ScraperBridge',(cx,cy,2),(radius*2,.45,.12),'metal')
 for zz in [2.5,2.9]:bar('BridgeRail',(cx-radius,cy-.22,zz),(cx+radius,cy-.22,zz),.025,'orange')
 for xx in [-radius,-radius/2,0,radius/2,radius]:bar('BridgePost',(cx+xx,cy-.22,2),(cx+xx,cy-.22,2.95),.025,'orange')

land_base(8)
# Raised water vessel on braced steel legs, compact 2x2 road-side installation.
for x in [-1.65,1.65]:
 for y in [-1.65,1.65]:
  box('ConcreteFoot',(x,y,.35),(.75,.75,.3),'stone')
  bar('TowerLeg',(x,y,.5),(x,y,9.3),.13)
for z in [1,4.6,8.3]:
 for y in [-1.65,1.65]:bar('CrossBrace',(-1.65,y,z),(1.65,y,z+3.4),.065);bar('CrossBrace',(1.65,y,z),(-1.65,y,z+3.4),.065)
 for x in [-1.65,1.65]:bar('CrossBrace',(x,-1.65,z),(x,1.65,z+3.4),.065)
cyl('ElevatedTank',(0,0,11.1),2.4,3.6,'blue',48)
sphere('TankBottom',(0,0,9.3),2.4,'blue',(1,1,.35))
sphere('TankRoof',(0,0,12.9),2.4,'cream',(1,1,.3))
for z in [9.55,12.65]:
 bpy.ops.mesh.primitive_torus_add(major_radius=2.41,minor_radius=.06,major_segments=48,minor_segments=8,location=(0,0,z));bpy.context.object.data.materials.append(m['ivory'])
for i,letter in enumerate('WATER'):
 ang=(i-2)*.26
 text('TankLabel_'+letter,letter,(2.425*math.sin(ang),-2.425*math.cos(ang),11.1),(math.pi/2,0,ang),.56,.65)
pipe((.5,.5,.3),(.5,.5,9.2),.17,'blue')
pipe((.5,.5,.45),(3.4,.5,.45),.17,'blue')
for x in [-.35,.35]:bar('LadderRail',(x,1.9,.5),(x,1.9,13.2),.035)
for z in [i*.35+.6 for i in range(36)]:bar('LadderRung',(-.35,1.9,z),(.35,1.9,z),.025)
box('ControlCabinet',(2.6,2.2,1.05),(1.1,1.2,1.6),'metal')
# Front service apron is intended to face an existing road.
box('RoadConnectionApron',(0,-3.1,.21),(3,1.5,.03),'stone')

bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-4.0-.02 and low[1]>=-4.0-.02 and high[0]<=4.0+.02 and high[1]<=4.0+.02,(low,high)
checkpoint('MODEL',f'Original water utility concept. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=6;distance=100
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=26;aim(camera,(0,0,target_z));scene.camera=camera
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
meta={'id':'water-water-tower','name':'급수탑','category':'water_utility','footprint_cells':[2,2],'footprint_status':'draft','cell_meters':4,'lot_meters':[8,8],'placement_surface':'land','road_adjacency_required':True,'image_size':[900,1100],'anchor_px':pixel((4.0,-4.0,0)),'lot_corners_px':[pixel(v) for v in [(-4.0,-4.0,0),(4.0,-4.0,0),(4.0,4.0,0),(-4.0,4.0,0)]],'vertex_bounds_m':[low,high],'approval_status':'pending-user-review','game_registered':False,'source':'original Blender geometry; DejaVu font; no external models or textures','scope':'visual concept and placement intent only; water networks and runtime siting not implemented'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front and reverse review renders complete. Pending approval; no runtime changes.')
print('PASS water utility water-tower')
