"""Blender 4.3.2 original parks/parking; run from repository root.
blender -b --factory-startup -t 2 -P tools/build_facilities.py
Uses zstack/vehicle common helpers through build_vehicle_fleet (MIT).
"""
import bpy,sys,math,json,shutil
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_vehicle_fleet as B
from facility_layout import SPECS,parking_layout
M={};W=D=0;root=None

def box(name,p,size,mat,bevel=.025):
 return B.box(name,(size[0],size[2],size[1]),(p[0]-W/2,-p[2]+D/2,p[1]),M[mat],root,bevel)
def tilt(ob,angle,axis):
 c=sum((v.co for v in ob.data.vertices),Vector())/len(ob.data.vertices)
 ob.data.transform(Matrix.Translation(c) @ Matrix.Rotation(angle,4,axis) @ Matrix.Translation(-c))
def cyl(name,p,radius,height,mat):
 return B.cylinder(name,radius,height,(p[0]-W/2,-p[2]+D/2,p[1]),M[mat],root,axis='Z',segments=20)
def tree(x,z,h=2.8):
 cyl('TreeTrunk',(x,h*.45,z),.13,h*.9,'wood')
 for dx,dz,dh,r in [(-.35,0,0,.8),(.3,.1,.2,.85),(0,0,.7,.7)]:
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=r,location=(x+dx-W/2,-z-dz+D/2,h+dh))
  B.finish(bpy.context.object,M['leaf'],root)
def bench(x,z,angle=0):
 for dz in [-.2,0,.2]:box('BenchSeat',(x,.65,z+dz),(1.7,.10,.15),'wood')
 box('BenchBack',(x,.98,z+.27),(1.7,.48,.10),'wood')
 for dx in [-.58,.58]:box('BenchLeg',(x+dx,.35,z),(.10,.6,.5),'metal')
def planter(x,z,w=1.4,d=1.2):
 box('Planter',(x,.32,z),(w,.4,d),'curb')
 box('FlowerBed',(x,.56,z),(w-.2,.12,d-.2),'soil')
 for dx in [-.35,.35]:
  for dz in [-.25,.25]:
   cyl('Flower',(x+dx,.7,z+dz),.16,.18,'flower')
def car(x,z,index=0):
 box('ParkedCarBody',(x,.65,z),(3.9,.65,1.6),'car'+str(index%3),.13)
 box('ParkedCarCabin',(x-.1,1.18,z),(1.9,.58,1.4),'glass',.09)
 box('ParkedCarRoof',(x-.1,1.5,z),(1.5,.08,1.24),'car'+str(index%3),.05)
 for dx in [-1.2,1.2]:
  for dz in [-.78,.78]:
   ob=B.cylinder('ParkedCarWheel',.30,.16,(x+dx-W/2,-z-dz+D/2,.38),M['metal'],root,axis='Y',segments=12)

def park(style):
 box('ParkBase',(W/2,.1,D/2),(W,.2,D),'curb')
 box('Lawn',(W/2,.24,D/2),(W-.35,.12,D-.35),'grass')
 for end in [0,1]:
  length=D/2-.85
  box('MainWalk',(W/2,.32,.15+length/2 if end==0 else D-.15-length/2),(1.5,.06,length),'paving')
 box('CrossWalk',(W/2,.32,D/2),(W-.3,.06,1.4),'paving')
 if style=='pocket':
  tree(1.7,1.6);tree(6.3,6.2);bench(2,5.4);bench(6,2.4);planter(1.7,6.8)
 elif style=='garden':
  for x,z in [(1.7,1.8),(6.3,1.8),(1.7,6.2),(6.3,6.2)]:planter(x,z,2.3,2.2)
  bench(4,6.4)
  for x in [2.5,5.5]:
   for z in [3,5]:box('PergolaPost',(x,1.65,z),(.14,2.7,.14),'wood')
  for z in [2.9,3.4,3.9,4.4,4.9]:box('PergolaBeam',(4,3.05,z),(3.5,.16,.18),'wood')
 elif style=='plaza':
  cyl('FountainBasin',(8,.55,8),2.5,.45,'curb');cyl('FountainWater',(8,.8,8),2.25,.08,'water')
  cyl('FountainColumn',(8,1.35,8),.35,1.2,'curb');cyl('FountainUpperBowl',(8,1.95,8),1.15,.17,'curb')
  cyl('FountainUpperWater',(8,2.05,8),1.02,.04,'water')
  for x,z in [(2,2),(14,2),(2,14),(14,14)]:tree(x,z,3.4)
  for x,z in [(4,6),(12,10),(8,3),(8,13)]:bench(x,z)
  for x in [3.5,12.5]:planter(x,12.5,2.6,1.5)
 elif style=='play':
  box('PlaySurface',(5,.35,5),(6.5,.12,6.5),'rubber')
  box('PlayTowerDeck',(4,1.6,4),(2, .18,2),'wood')
  for x,z in [(3.2,3.2),(4.8,3.2),(3.2,4.8),(4.8,4.8)]:box('PlayPost',(x,1.4,z),(.14,2.2,.14),'metal')
  box('PlayRoof',(4,2.9,4),(2.5,.18,2.5),'accent')
  slide=box('Slide',(6.2,1.0,4),(3.6,.13,1.0),'accent');tilt(slide,math.radians(-25),'Y')
  for x in [10,13]:box('SwingPost',(x,1.8,4),(.15,3,.15),'metal')
  box('SwingBeam',(11.5,3.3,4),(3.6,.18,.18),'accent')
  for x in [10.9,12.1]:
   for z in [3.8,4.2]:box('SwingRope',(x,2.0,z),(.035,2.2,.035),'metal')
   box('SwingSeat',(x,.92,4),(.65,.08,.5),'wood')
  for x,z in [(2,12),(13,12),(13,8)]:tree(x,z,3.1)
  bench(6,12);bench(10,12);planter(3,8)

def tower():
 box('TowerBase',(8,.1,8),(16,.2,16),'curb')
 for level in range(4):
  y=.35+level*3.1
  box('ParkingDeck_'+str(level+1),(8,y,8),(15.7,.25,15.7),'concrete')
  for x in [1.0,5.5,10.5,15.0]:
   for z in [1,8,15]:box('Column',(x,y+1.5,z),(.42,2.8,.42),'concrete')
  for z in [.28,15.72]:
   box('GuardRail',(8,y+.75,z),(15.7,.38,.18),'curb')
   box('AccentBand',(8,y+.35,z),(15.9,.16,.20),'accent')
  for x in [.28,15.72]:box('SideGuardRail',(x,y+.75,8),(.18,.38,15.7),'curb')
  for z in [3.8,6.4,9.0,11.6,14.2]:box('BayLine',(3.1,y+.14,z),(5,.025,.055),'paint')
  for z in [5.1,10.3]:
   box('CarBody',(3,y+.65,z),(3.8,.65,1.6),'car'+str(level%3),.12)
   box('CarCabin',(3,y+1.15,z),(1.9,.45,1.3),'glass',.08)
  if level<3:
   ramp=box('Ramp_'+str(level+1),(13,y+1.55,8),(2.9,.18,12.4),'asphalt')
   tilt(ramp,math.atan2(3.1,12.0)*(1 if level%2 else -1),'X')
 box('UnoccupiedRoof',(8,12.85,8),(16,.28,16),'roof')
 box('StairCore',(9.9,6.5,13.8),(2.3,12.7,3.3),'cream')
 box('StairDoor',(9.9,1.35,15.53),(1.2,2.1,.06),'glass')
 box('EntryCanopy',(10,2.6,16),(3.3,.18,1.0),'accent')
 box('ParkingSign',(15.86,6.7,8),(.10,2.5,2.4),'accent')
 # P glyph is mesh geometry, so it survives GLB export without fonts.
 box('PStem',(15.93,6.7,7.5),(.035,1.6,.16),'paint')
 for h in [6.65,7.42]:box('PBar',(15.93,h,8.0),(.035,.16,1.0),'paint')
 box('PRight',(15.93,7.04,8.45),(.035,.9,.16),'paint')

def render(path):
 s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=False
 s.render.resolution_x=800;s.render.resolution_y=680;s.render.resolution_percentage=100;s.render.film_transparent=True
 s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.view_settings.view_transform='Standard'
 s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.80,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.65
 data=bpy.data.lights.new('Key','AREA');data.energy=2200;data.size=15
 ob=bpy.data.objects.new('Key',data);s.collection.objects.link(ob);ob.location=(12,-15,22);ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
 data=bpy.data.cameras.new('Camera');ob=bpy.data.objects.new('Camera',data);s.collection.objects.link(ob);s.camera=ob
 h=13 if spec['kind']=='parking_tower' else 3.5;target=Vector((0,0,h*(.5 if spec['kind']=='parking_tower' else .32)))
 ob.location=target+Vector((30,-30,math.sqrt(1800)*math.tan(math.radians(30))))
 ob.rotation_euler=(target-ob.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO'
 data.ortho_scale=max((W+D)*.707,((W+D)*.354+h*.866)*800/680)*1.16
 s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
 return {'resolution':[800,680],'pixels_per_metre':800/data.ortho_scale,'camera_elevation_deg':30}

entries=[]
for spec in SPECS:
 B.C.reset_scene();bpy.context.preferences.filepaths.save_version=0;W=spec['width']*4;D=spec['depth']*4
 bpy.context.scene.unit_settings.system='METRIC';root=B.C.empty('FacilityRoot');root['asset_id']=spec['id']
 M={k:B.material(k,c) for k,c in {'asphalt':'4c5659','paint':'eee7cf','curb':'c8cbc3','grass':'8c9b75','leaf':'6f895c','wood':'aa8059','metal':'344b53','paving':'ded6bf','soil':'796751','flower':'d18b9b','water':'73aeb8','rubber':'bd9871','accent':'507c89','cream':'e2dcc8','concrete':'c4c7bd','roof':'526b70','glass':'527584','car0':'d8aa61','car1':'739eaa','car2':'b56f5d'}.items()}
 capacity=0
 if spec['kind']=='park':park(spec['style'])
 elif spec['kind']=='parking_tower':tower();capacity=16
 else:
  layout=parking_layout([(x,z) for x in range(spec['width']//2) for z in range(spec['depth']//2)])
  for item in layout['boxes']:box(item['name'],item['pos'],item['size'],item['mat'],.008)
  capacity=layout['capacity']
  for i,(x,z) in enumerate(layout['blocks']):
   if i%2==0:car(x*8+2.6,z*8+4.25,i)
 folder=ROOT/'assets/facilities'/spec['id'];folder.mkdir(parents=True,exist_ok=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(folder/'facility.blend'),compress=False)
 # Export as a single combined mesh (multiple material surfaces retained).
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 bpy.ops.object.select_all(action='DESELECT')
 for ob in meshes:ob.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();bpy.context.object.name='FacilityCombinedMesh'
 game=ROOT/'cities_do/assets/facilities';game.mkdir(parents=True,exist_ok=True)
 bpy.ops.export_scene.gltf(filepath=str(game/(spec['id']+'.glb')),export_format='GLB',export_extras=True,export_animations=False)
 info=render(folder/'preview.png');shutil.copyfile(folder/'preview.png',game/(spec['id']+'.png'))
 row={**spec,'capacity':capacity,'metres':[W,D], 'model':'res://assets/facilities/'+spec['id']+'.glb','preview':'res://assets/facilities/'+spec['id']+'.png','source':'assets/facilities/'+spec['id']+'/facility.blend','render':info}
 (folder/'spec.json').write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n');entries.append(row)
 print('FACILITY_BUILT',spec['id'],flush=True)
(ROOT/'cities_do/assets/facilities/catalog.json').write_text(json.dumps({'facilities':entries},ensure_ascii=False,indent=2)+'\n')
(ROOT/'assets/facilities').mkdir(exist_ok=True)
fixtures={name:parking_layout(blocks) for name,blocks in {'rectangle':[(0,0),(1,0),(0,1),(1,1)],'L':[(0,0),(0,1),(1,1)],'hole':[(x,z) for x in range(3) for z in range(3) if (x,z)!=(1,1)]}.items()}
(ROOT/'cities_do/assets/facilities/layout-fixtures.json').write_text(json.dumps(fixtures,indent=2)+'\n')
