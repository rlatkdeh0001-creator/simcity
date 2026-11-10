"""Original waste-facility concept for user review. Never writes game resources."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent/'recycling-center';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
log=OUT/'production_log.md';log.write_text('# 재활용센터\n\nBrief: road-side 8x8 recycling and material sorting centre concept. No incinerator or landfill. User review pending; no game registration.\n\nCheckpoint: BRIEF\n')
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






m['white']=mat('WarmWhitePanels','ecece2')
m['sage']=mat('SageGreenCladding','799a7b')
m['bluebin']=mat('BlueSortingBin','518698')
m['yellowbin']=mat('YellowSortingBin','c9a65b')
m['paper']=mat('PressedCardboard','b59a6f')
m['plastic']=mat('PressedPlastic','86aaa0')
m['charcoal']=mat('CharcoalTrim','405452',.15,.5)
# Low green sorting hall and a long sawtooth skylight, no stack or combustion tower.
box('SortingHall',(-3.5,4,3.25),(20,17,6.1),'white')
box('GreenBase',(-3.5,4,.9),(20.2,17.2,1.4),'sage')
for x in [-12,-9,-6,-3,0,3,6]:box('FacadePanelJoint',(x,-4.53,3.55),(.025,.03,5.2),'stone',0)
# Shallow asymmetrical roof over the processing floor.
for x,angle in [(-8.7,-.08),(1.7,.08)]:
 o=box('LowPitchedRoof',(x,4,6.64),(10.8,17.6,.18),'sage');o.rotation_euler.y=angle
box('RoofRidge',(-3.5,4,7.07),(.35,17.8,.14),'metal')
for cy in [-.5,5.5,10]:
 box('RooflightFrame',(-3.5,cy,7.23),(4.7,2.4,.22),'metal')
 box('RooflightGlass',(-3.5,cy,7.37),(4.4,2.1,.06),'glass')
 for dx in [-1.45,0,1.45]:box('RooflightDivider',(-3.5+dx,cy,7.42),(.05,2.1,.04),'stone')
# Two logistics bays plus separate staff entrance.
for cx in [-9,0]:
 box('LoadingPortal',(cx,-4.66,2.45),(6.3,.2,4.4),'charcoal')
 box('LoadingShutter',(cx,-4.8,2.45),(5.95,.06,4.1),'roof')
 for z in [i*.23+.55 for i in range(17)]:box('DoorSlat',(cx,-4.84,z),(5.9,.025,.025),'metal',0)
 for dx in [-3.3,3.3]:
  box('Bollard',(cx+dx,-5.3,.85),(.18,.18,1.3),'orange')
  box('BollardStripe',(cx+dx,-5.3,1.08),(.19,.19,.18),'black')
box('WideReceivingCanopy',(-3.8,-5.45,4.8),(19,2,.2),'metal')
box('BrandBand',(-3.5,-4.69,5.73),(20.2,.2,.95),'green')
text('RecyclingName','RECYCLING CENTER',(-2.1,-4.82,5.75),(math.pi/2,0,0),15.8,.6)
# Original three-arrow loop symbol in the sign plane.
y=-4.84;cx=-12.1;cz=5.77
points=[(cx,cz+.33),(cx-.4,cz-.23),(cx+.4,cz-.23)]
for i in range(3):
 a=Vector(points[i]);c=Vector(points[(i+1)%3]);d=(c-a).normalized();end=c-d*.09
 bar('RecyclingArrow',(a.x,y,a.y),(end.x,y,end.y),.035,'ivory')
 side=Vector((-d.y,d.x));tip=c;left=end-d*.12+side*.12;right=end-d*.12-side*.12
 mesh=bpy.data.meshes.new('ArrowHead');mesh.from_pydata([(tip.x,y,tip.y),(left.x,y,left.y),(right.x,y,right.y)],[],[(0,1,2)]);mesh.materials.append(m['ivory']);o=bpy.data.objects.new('RecycleArrowHead',mesh);scene.collection.objects.link(o)
# Four clearly labelled material collection bunkers in the front forecourt.
for cx,label,col in [(-10.6,'PAPER','bluebin'),(-4.6,'PLASTIC','yellowbin'),(1.4,'GLASS','green'),(7.4,'METAL','metal')]:
 cy=-10.2
 box('SortingBunker',(cx,cy,.9),(5,5,1.4),'stone')
 box('BinLid',(cx,cy,1.7),(5.1,5.1,.18),col)
 # Dark loading aperture in the coloured cover.
 box('CollectionOpening',(cx,cy-.8,1.81),(3.7,.7,.035),'charcoal')
 box('CategoryLabelBack',(cx,cy-2.57,1.1),(4.65,.1,.68),col)
 text('Category_'+label,label,(cx,cy-2.64,1.12),(math.pi/2,0,0),4.15,.45)
# Pressed materials on a roofed dispatch pad along the right side.
box('BaleDispatchPad',(10.5,6.2,.35),(7.8,13.2,.25),'stone')
for x in [7.2,13.8]:
 for y in [.5,11.9]:box('CanopyPost',(x,y,2.6),(.16,.16,4.6),'metal')
box('DispatchCanopy',(10.5,6.2,5.05),(7.6,12.8,.18),'sage')
for cy,col in [(3,'paper'),(7,'plastic')]:
 for cx in [8.8,12.1]:
  box('DispatchPallet',(cx,cy,.58),(2.8,2.3,.2),'wood')
  for z in [1.4,2.9]:
   box('PressedRecyclableBale',(cx,cy,z),(2.65,2.1,1.35),col)
   for dx in [-.8,.8]:box('BaleStrap',(cx+dx,cy,z),(.09,2.15,1.4),'metal')
# Conveyor links sorting to the bale area, with no incineration apparatus.
box('ConveyorFrame',(6.8,4,1.8),(3.4,1.3,.45),'metal')
box('ConveyorBelt',(6.8,4,2.06),(3.25,1.1,.08),'charcoal')
for x in [5.3,6.8,8.3]:box('ConveyorLeg',(x,4,1.1),(.13,.8,1.4),'metal')
for dx in [-2.6,2.6]:box('LoadingApronMark',(-4.5+dx,-6.1,.214),(.08,1.8,.012),'orange',0)
# Compact green staff office at the rear.
box('StaffDoor',(4.8,-4.67,1.6),(1.2,.1,2.6),'green')
box('StaffDoorWindow',(4.8,-4.74,2.1),(.85,.03,.9),'glass')
for yy in [7.8,10.5]:box('HallSideWindow',(6.56,yy,4),(.05,1.8,1.2),'glass')
bpy.context.view_layer.update()
vertices=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
assert low[0]>=-16.01 and low[1]>=-16.01 and high[0]<=16.01 and high[1]<=16.01,(low,high)
checkpoint('MODEL',f'Low-rise recycling and sorting centre; no combustion equipment. Bounds {low} to {high}.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
target_z=3;distance=100
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=60;aim(camera,(0,0,target_z));scene.camera=camera
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


meta={'id':'waste-recycling-center','name':'재활용센터','category':'waste_utility','footprint_cells':[8,8],'footprint_status':'draft','cell_meters':4,'lot_meters':[32,32],'placement_surface':'land','road_adjacency_required':True,'landfill_included':False,'incineration_included':False,'image_size':[900,1100],'anchor_px':pixel((16,-16,.12)),'lot_corners_px':[pixel(v) for v in [(-16,-16,.12),(16,-16,.12),(16,16,.12),(-16,16,.12)]],'vertex_bounds_m':[low,high],'approval_status':'pending-user-review','game_registered':False,'source':'original Blender geometry; DejaVu font; no external models or textures','scope':'recycling facility concept only; no waste collection or sorting simulation implemented'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDERED','Front and reverse review renders complete. Pending approval; no runtime changes.')
print('PASS recycling centre concept; no landfill or incineration')
