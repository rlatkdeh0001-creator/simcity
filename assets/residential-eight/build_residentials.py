"""Original CITIES_DO residential concepts; Blender 4.3+, no external API/assets.
Each invocation builds exactly one asset; source transforms are baked in shared meshes.
"""
import bpy, math, json, sys, argparse
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent
SPECS=[
 {'id':'small-2x2-a','name':'단층 전원주택','category':'small_residential','size':2,'floors':1,'style':'cottage','frame':15},
 {'id':'small-2x2-b','name':'2층 타운하우스','category':'small_residential','size':2,'floors':2,'style':'townhouse','frame':15},
 {'id':'small-4x4-a','name':'정원형 단독주택','category':'small_residential','size':4,'floors':2,'style':'garden','frame':32},
 {'id':'small-4x4-b','name':'안뜰형 연립주택','category':'small_residential','size':4,'floors':3,'style':'courtyard','frame':32},
 {'id':'large-4x4-a','name':'발코니 아파트','category':'large_residential','size':4,'floors':8,'style':'balcony','frame':46},
 {'id':'large-4x4-b','name':'코너 주거타워','category':'large_residential','size':4,'floors':10,'style':'corner','frame':46},
 {'id':'large-8x8-a','name':'L자형 주거 아파트','category':'large_residential','size':8,'floors':14,'style':'slab','frame':84},
 {'id':'large-8x8-b','name':'계단형 주거타워','category':'large_residential','size':8,'floors':18,'style':'terrace','frame':84},
]
parser=argparse.ArgumentParser();parser.add_argument('--id',choices=[s['id'] for s in SPECS],required=True);parser.add_argument('--samples',type=int,default=32)
opts=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
spec=next(s for s in SPECS if s['id']==opts.id);folder=OUT/spec['id'];folder.mkdir(parents=True,exist_ok=True)
log=folder/'production_log.md'
log.write_text(f'# {spec["name"]}\n\nBrief: {spec["size"]}x{spec["size"]} cells, {spec["floors"]} occupied floors; 1 cell=4m.\nOriginal geometry, no downloaded textures/meshes, no API.\nMethod: game-art consistency principles and adapted kiln local scripting/source preservation/opposite-view inspection; not an unmodified kiln toolkit run.\n\nCheckpoint: BRIEF\n')
def checkpoint(name,text):
 with log.open('a') as f:f.write(f'\n## {name}\n{text}\n\nCheckpoint: {name}\n')
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
mesh_cache={}
def rgb(h):
 v=[int(h[i:i+2],16)/255 for i in [0,2,4]]
 return tuple(x/12.92 if x<.04045 else ((x+.055)/1.055)**2.4 for x in v)+(1,)
def material(name,h,metallic=0,roughness=.65):
 m=bpy.data.materials.new('M_'+name);m.use_nodes=True;p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=rgb(h);p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=roughness;return m
m={key:material(key,h, .25 if key in ['glass','roof','metal'] else 0,.25 if key=='glass' else .65) for key,h in {'cream':'dfd6bd','white':'e5e5db','brick':'a16c58','clay':'be886b','roof':'526b70','terracotta':'a76c50','metal':'344b53','glass':'648a96','lightglass':'96b2b6','wood':'aa8059','stone':'c9c6b8','paving':'e1dfd3','grass':'8c9b75','hedge':'58734c','leaf':'728653','bark':'776044','charcoal':'596364','sage':'94a599','gravel':'aaa99b'}.items()}
# Brick is procedural in .blend, no external raster texture required.
nt=m['brick'].node_tree;tex=nt.nodes.new('ShaderNodeTexBrick');tex.inputs['Color1'].default_value=rgb('99604d');tex.inputs['Color2'].default_value=rgb('b48165');tex.inputs['Mortar'].default_value=rgb('c6b9a2');tex.inputs['Scale'].default_value=1;tex.inputs['Mortar Size'].default_value=.018;tex.inputs['Brick Width'].default_value=.52;tex.inputs['Row Height'].default_value=.23
coord=nt.nodes.new('ShaderNodeTexCoord');nt.links.new(coord.outputs['UV'],tex.inputs['Vector']);nt.links.new(tex.outputs['Color'],nt.nodes['Principled BSDF'].inputs['Base Color'])
def box(name,loc,size,mat='white',bevel=.018):
 key=(tuple(round(float(x),4) for x in size),mat)
 if key not in mesh_cache:
  sx,sy,sz=[x/2 for x in size];verts=[(-sx,-sy,-sz),(sx,-sy,-sz),(sx,sy,-sz),(-sx,sy,-sz),(-sx,-sy,sz),(sx,-sy,sz),(sx,sy,sz),(-sx,sy,sz)];faces=[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]
  mesh=bpy.data.meshes.new('SharedBox');mesh.from_pydata(verts,[],faces);mesh.update();mesh.materials.append(m[mat]);uv=mesh.uv_layers.new()
  for poly in mesh.polygons:
   for li in poly.loop_indices:
    co=mesh.vertices[mesh.loops[li].vertex_index].co;u=co.x if abs(poly.normal.y)>.5 else co.y;uv.data[li].uv=(u,co.z)
  mesh_cache[key]=mesh
 obj=bpy.data.objects.new(name,mesh_cache[key]);scene.collection.objects.link(obj);obj.location=loc
 if bevel:
  mod=obj.modifiers.new('EdgeHighlights','BEVEL');mod.width=min(bevel,min(size)*.2);mod.segments=1
 return obj

def tree(x,y,h=2.5):
 box('TreeTrunk',(x,y,h*.45+.25),(.17,.17,h*.9),'bark')
 for dx,dy,dz,r in [(-.22,0,0,.6),(.25,.05,.15,.65),(0,0,.6,.55)]:
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=r,location=(x+dx,y+dy,h+dz));bpy.context.object.name='TreeCrown';bpy.context.object.data.materials.append(m['leaf'])
def planter(x,y,z,w=1.2,d=.6):
 box('Planter',(x,y,z+.18),(w,d,.36),'stone');box('Shrub',(x,y,z+.44),(w*.88,d*.8,.32),'hedge',.08)
def bench(x,y,z=.25):
 for dy in [-.17,0,.17]:box('BenchSlat',(x,y+dy,z+.55),(1.6,.13,.1),'wood')
 for dx in [-.55,.55]:box('BenchLeg',(x+dx,y,z+.25),(.1,.45,.5),'metal')

def roof(cx,cy,w,d,z,peak,mat='roof'):
 vertices=[(cx-w/2,cy-d/2,z),(cx+w/2,cy-d/2,z),(cx+w/2,cy+d/2,z),(cx-w/2,cy+d/2,z),(cx-w*.33,cy,z+peak),(cx+w*.33,cy,z+peak)]
 mesh=bpy.data.meshes.new('HipRoof');mesh.from_pydata(vertices,[],[(0,1,5,4),(1,2,5),(2,3,4,5),(3,0,4),(3,2,1,0)]);mesh.update();mesh.materials.append(m[mat]);ob=bpy.data.objects.new('HipRoof_Unoccupied',mesh);scene.collection.objects.link(ob);box('RoofRidge',(cx,cy,z+peak+.04),(w*.67,.13,.12),mat)

def window(x,y,z,w=1.3,h=1.65,side='front',frame='cream'):
 if side in ['front','back']:
  sign=-1 if side=='front' else 1
  box('WindowFrame',(x,y,z),(w+.16,.15,h+.16),frame)
  box('WindowGlass',(x,y+sign*.09,z),(w,.04,h),'glass',.003)
  box('WindowMullion',(x,y+sign*.12,z),(.045,.025,h),frame,.003)
  box('WindowSill',(x,y+sign*.14,z-h/2-.08),(w+.28,.28,.11),'stone')
 else:
  sign=1 if side=='right' else -1
  box('SideFrame',(x,y,z),(.15,w+.16,h+.16),frame)
  box('SideGlass',(x+sign*.09,y,z),(.04,w,h),'glass',.003)
  box('SideMullion',(x+sign*.12,y,z),(.025,.045,h),frame,.003)

def door(x,y,z=.3,w=1.2):
 box('EntryFrame',(x,y,z+1.2),(w+.22,.2,2.4),'metal');box('EntryDoor',(x,y-.13,z+1.2),(w,.04,2.2),'glass');box('DoorHandle',(x+w*.28,y-.18,z+1.2),(.04,.035,.4),'cream');box('EntryCanopy',(x,y-.4,z+2.5),(w+1,.95,.16),'roof')

def facade(cx,cy,w,d,floors,base=.3,wall='white',frame='metal',floor_height=3.05,balconies=False,cap_offset=0.0,corner_glass=False):
 box('BuildingBody',(cx,cy,base+floors*floor_height/2),(w,d,floors*floor_height),wall,.025)
 cols=max(2,int(w/2.8));rows=max(1,int(d/3.0))
 for floor in range(floors):
  z=base+floor*floor_height
  box('FloorBand',(cx,cy,z+.04),(w+.16,d+.16,.13),'cream' if wall=='brick' else 'white')
  for col in range(cols):
   x=cx-w/2+(col+.5)*w/cols
   if (floor or abs(x-cx)>=1.15) and not (corner_glass and col==cols-1):
    ww=min(1.7,w/cols-.5) if floor else min(1.5,w/cols-.5,2*(abs(x-cx)-.85))
    window(x,cy-d/2-.035,z+1.65,ww,1.8,'front',frame)
   window(x,cy+d/2+.035,z+1.65,min(1.7,w/cols-.5),1.8,'back',frame)
  for row in range(rows):
   y=cy-d/2+(row+.5)*d/rows
   for side in ['left','right']:
    if not (corner_glass and side=='right' and row==0):
     window(cx+(w/2+.035)*(1 if side=='right' else -1),y,z+1.65,min(1.6,d/rows-.6),1.8,side,frame)
  if balconies and floor>0:
   box('BalconySlab',(cx,cy-d/2-.55,z+.12),(w+.3,1.2,.18),'white')
   box('BalconyGlass',(cx,cy-d/2-1.1,z+.73),(w+.2,.04,.85),'lightglass',.003)
   box('BalconyRail',(cx,cy-d/2-1.1,z+1.2),(w+.3,.07,.07),'metal',.003)
   for x in [cx-w/2,cx,cx+w/2]:box('BalconyPost',(x,cy-d/2-1.1,z+.7),(.05,.05,1),'metal',.003)
 box('RoofCap',(cx,cy,base+floors*floor_height+cap_offset),(w+.25,d+.25,.2),'cream' if wall=='brick' else 'white')
 door(cx,cy-d/2-.15,base)
 return base+floors*floor_height

lot=spec['size']*4;half=lot/2;style=spec['style'];height=3.05
box('LotBase',(0,0,0),(lot,lot,.24),'stone',.04);box('LotTop',(0,0,.15),(lot-.1,lot-.1,.1),'paving')
# Lawn and paving stay within the logical lot; there is no permanent gameplay grid on it.
for sign in [-1,1]:
 box('GrassSide',(sign*(half-.7),0,.22),(1.0,lot-1.2,.06),'grass')
 planter(sign*(half-.75),-half+1,.25,.85,.65)
 if spec['size']>=4:tree(sign*(half-1),half-1.2,2.8 if spec['size']==4 else 3.4)
box('EntryPath',(0,-half+1.1,.23),(1.8 if spec['size']==2 else 2.8,2.1,.08),'gravel')

if style=='cottage':
 z=facade(0,.4,5.2,4.5,1,wall='cream',frame='white');roof(0,.4,5.65,4.95,z+.1,1.35,'roof');box('Chimney',(-1.5,1.1,z+1.1),(.55,.6,1.5),'brick')
 for obj in list(scene.objects):
  if obj.name.startswith('EntryCanopy'):bpy.data.objects.remove(obj,do_unlink=True)
 box('PorchRoof',(0,-2.4,2.95),(3.2,1.3,.16),'roof')
 for x in [-1.3,1.3]:box('PorchPost',(x,-2.9,1.61),(.12,.12,2.52),'wood')
 box('PorchDeck',(0,-2.4,.35),(3.2,1.3,.22),'wood');planter(2.1,-2.7,.25,.75,.6)
elif style=='townhouse':
 z=facade(0,.35,4.8,4.9,2,wall='brick',frame='cream');box('FlatParapet',(0,.35,z+.35),(5.0,5.1,.55),'charcoal')
 box('Balcony',(0,-2.55,3.5),(4.9,1,.18),'stone');box('BalconyFront',(0,-3.0,4.05),(4.8,.06,.9),'metal');planter(1.6,-2.6,3.6,.85,.4)
 box('VerticalEntryAccent',(-1.8,-2.18,3.35),(.3,.2,5.9),'white')
elif style=='garden':
 z=facade(-1.6,.6,8.4,7.8,2,wall='white',frame='roof');roof(-1.6,.6,8.9,8.3,z+.1,1.5,'terracotta')
 box('GarageBody',(4.9,1.4,1.8),(3.3,5.4,3),'cream');roof(4.9,1.4,3.6,5.8,3.3,.7,'terracotta')
 box('GarageDoor',(4.9,-1.34,1.55),(2.65,.1,2.4),'wood')
 for dz in [.65,1.15,1.65,2.15,2.65]:box('GarageDoorSeam',(4.9,-1.405,dz),(2.65,.02,.025),'roof',0)
 box('FrontLawn',(-3.7,-5.8,.235),(5.6,2.4,.05),'grass');tree(-5.5,-5.4,2.6);bench(-2,-5.8)
elif style=='courtyard':
 facade(0,3.4,11.6,3.7,3,wall='cream',frame='metal')
 for x in [-4.5,4.5]:facade(x,-1.2,2.9,5.5,3,wall='white',frame='roof',cap_offset=.04)
 box('CourtyardLawn',(0,-1.8,.23),(5.4,4,.05),'grass');box('CourtyardPath',(0,-2,.28),(1.6,5.8,.08),'stone');bench(-1.9,-1.8);planter(1.8,-1.5,.25,1.1,1.6)
 for x in [-4.5,4.5]:planter(x,-4.6,.25,2.0,.6)
elif style=='balcony':
 z=facade(0,.8,10.8,9.2,8,wall='cream',frame='metal',balconies=True)
 for x in [-4.7,4.7]:box('VerticalClayFin',(x,-3.88,z/2),(1.05,.18,z-.3),'clay')
 for floor in [1,3,5,7]:planter(-3.5,-4.3,.3+floor*height+.23,1.3,.5)
 for y in [-3.7,5.3]:box('RoofParapet',(0,y,z+.4),(11,.2,.7),'white')
 box('RoofMechanical',(2,2,z+.6),(2,2,1),'roof')
elif style=='corner':
 z=facade(0,1.0,10.0,9.8,8,wall='charcoal',frame='metal',corner_glass=True)
 facade(0,1.0,7.8,8.0,2,base=z,wall='sage',frame='metal',corner_glass=True)
 # Glass corner and warm vertical fins distinguish it from the cream slab.
 for floor in range(10):
  zz=.3+floor*height+1.6;w=10.0 if floor<8 else 7.8;d=9.8 if floor<8 else 8.0
  box('CornerGlazingFront',(w/2-1,1-d/2-.14,zz),(2.0,.07,2.5),'glass')
  box('CornerGlazingSide',(w/2+.14,1-d/2+1,zz),(.07,2.0,2.5),'glass')
  box('CornerPost',(w/2+.07,1-d/2-.07,zz),(.1,.1,2.9),'metal')
  box('WarmFin',(-w/2+.7,1-d/2-.14,zz),(.18,.18,2.9),'wood')
 planter(-4.0,-5.5,.25,2,.8);bench(3.5,-5.6)
elif style=='slab':
 z=facade(0,4.2,24.5,9.0,14,wall='white',frame='metal',balconies=True)
 facade(-8,-5.4,8.5,10.2,14,wall='cream',frame='metal',cap_offset=.04)
 for floor in range(14):
  zz=.3+floor*height+1.5
  for x in [-9,0,9]:box('BlueFacadePanel',(x,-.39,zz),(.48,.17,2.85),'roof')
 box('GardenCourt',(4.5,-7.8,.23),(12,8,.06),'grass');tree(5,-8.5,3.5);tree(9,-6,3);bench(4,-11);bench(8,-11)
 for x in [-8,7]:box('RoofMechanical',(x,4,z+.7),(2,2,1.2),'roof')
elif style=='terrace':
 z1=facade(0,0,26.4,20.5,3,wall='cream',frame='metal')
 z2=facade(0,1.4,16.6,13.8,10,base=z1,wall='white',frame='metal',balconies=True)
 z3=facade(0,2.0,12.7,11.0,5,base=z2,wall='sage',frame='metal',balconies=True)
 # Terraced open gardens do not add occupied floors.
 for x in [-10.7,10.7]:
  for y in [-6,-1,4]:planter(x,y,z1+.15,1.4,2.0)
 for x in [-6.9,6.9]:planter(x,-3.9,z2+.15,1.0,2)
 for y in [-3.4,7.4]:box('RoofParapet',(0,y,z3+.35),(12.9,.18,.65),'white')
 box('RoofMechanical',(2,3,z3+.7),(2.4,2.8,1.2),'roof')
 for x in [-10,10]:bench(x,-12)

for floor in range(spec['floors']):
 obj=bpy.data.objects.new('OccupiedFloor_%02d'%(floor+1),None);obj.location.z=.3+floor*height;obj['storey_index']=floor+1;scene.collection.objects.link(obj)
bpy.context.view_layer.update()
meshes=[o for o in scene.objects if o.type=='MESH'];verts=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
low=[min(v[i] for v in verts) for i in range(3)];high=[max(v[i] for v in verts) for i in range(3)]
assert low[0]>=-half-.001 and low[1]>=-half-.001 and high[0]<=half+.001 and high[1]<=half+.001,(spec['id'],low,high)
assert sum(o.name.startswith('OccupiedFloor_') for o in scene.objects)==spec['floors']
checkpoint('MODEL',f'{len(meshes)} mesh objects. Occupied floors={spec["floors"]}. Measured world vertices: {low} to {high}. Lot bounds asserted. Procedural palette materials, no downloaded textures.')
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
# Each footprint/category pair uses identical framing. Angle, unit scale and illumination never change.
target_z=max(1.5,high[2]*.43)
distance=max(30,high[2]*1.7)
bpy.ops.object.camera_add(location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30))));camera=bpy.context.object;camera.name='Camera_2to1';camera.data.type='ORTHO';camera.data.ortho_scale=spec['frame'];aim(camera,(0,0,target_z));scene.camera=camera
# Sun + world keep illumination invariant for small houses and tall towers.
bpy.ops.object.light_add(type='SUN',location=(-20,-30,60));light=bpy.context.object;light.name='SharedSun';light.data.energy=2;light.data.angle=math.radians(12);aim(light,(0,0,0))
scene.world=bpy.data.worlds.new('SharedWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.55,.65,.75,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55
scene.render.engine='CYCLES';scene.cycles.samples=opts.samples;scene.cycles.use_denoising=False;scene.cycles.device='CPU';scene.render.threads_mode='FIXED';scene.render.threads=6
scene.render.resolution_x=900;scene.render.resolution_y=1100;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
def pixel(point):
 p=world_to_camera_view(scene,camera,Vector(point));return [round(p.x*900,4),round((1-p.y)*1100,4)]
source_corners=[(-half,-half,.12),(half,-half,.12),(half,half,.12),(-half,half,.12)]
# Framing preflight is geometry-based so a tower is not silently cropped.
for vertex in verts:
 p=world_to_camera_view(scene,camera,vertex)
 assert .015<p.x<.985 and .015<p.y<.985,('framing',spec['id'],list(p))
scene.render.filepath=str(folder/'building.png');bpy.ops.wm.save_as_mainfile(filepath=str(folder/'building.blend'));checkpoint('SAVED','Editable source saved, 900x1100 transparent primary render next.')
bpy.ops.render.render(write_still=True)
camera.location=(-distance,distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30)));aim(camera,(0,0,target_z));scene.render.filepath=str(folder/'reverse-review.png');bpy.ops.render.render(write_still=True)
camera.location=(distance,-distance,target_z+math.sqrt(2)*distance*math.tan(math.radians(30)));aim(camera,(0,0,target_z));bpy.context.view_layer.update()
meta={**spec,'zone':'residential','footprint_cells':[spec['size'],spec['size']],'cell_meters':4,'lot_meters':[lot,lot],'occupied_storeys':spec['floors'],'storey_height_m':height,'image_size':[900,1100],'anchor_px':pixel((half,-half,.12)),'lot_corners_px':[pixel(p) for p in source_corners],'camera_elevation_degrees':30,'projection':'2:1 dimetric','orthographic_scale':spec['frame'],'vertex_bounds_m':[low,high],'mesh_objects':len(meshes),'source':'original scripted Blender geometry, no downloaded assets or external generation APIs','scope':'concept only; not registered in gameplay catalog; interior/LOD/game integration not provided'}
(folder/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n');checkpoint('RENDERED','Primary and reverse RGBA renders complete. Await visual review before delivery.');print('PASS',spec['id'],spec['size'],spec['floors'],len(meshes))
