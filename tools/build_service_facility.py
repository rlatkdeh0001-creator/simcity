"""Original crematorium asset; metres, Blender -Y entrance / GLB +Z entrance.
blender -b --factory-startup -t 2 -P tools/build_service_facility.py
Uses the existing fleet's MIT common helpers; does not rebuild parks/parking.
"""
import sys,json,math
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_vehicle_fleet as B
B.C.reset_scene()
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene
scene.unit_settings.system='METRIC'
scene.unit_settings.scale_length=1
root=B.C.empty('CrematoriumRoot')
root['frontGltf']=[0.,0.,1.]
root['asset_id']='crematorium-4x4'
m={k:B.material(k,c) for k,c in {'stone':'d5cbb6','roof':'536b70','glass':'527584','wood':'987754','paving':'b9b9aa','grass':'8c9b75','leaf':'6f895c','metal':'46575b'}.items()}
def box(name,size,pos,mat,bevel=.025):return B.box(name,size,pos,m[mat],root,bevel)
# 16m square lot; 10.5 x 8m hall. Main entry faces -Y.
box('Lot',(16,16,.16),(0,0,.08),'grass')
box('FrontPath',(2.4,5.1,.12),(-2,-5.45,.20),'paving')
box('Hall',(10.5,8,4.0),(0,1,2.16),'stone')
box('HallRoof',(11,8.5,.30),(0,1,4.30),'roof')
box('CeremonyWing',(5,5,1.4),(-2,-.3,4.5),'stone')
box('CeremonyRoof',(5.4,5.4,.25),(-2,-.3,5.30),'roof')
box('EntranceDoor',(1.7,.06,2.3),(-2,-3.04,1.4),'glass')
box('EntryCanopy',(4,2.0,.18),(-2,-3.5,2.85),'roof')
for x in [-3.75,-.25]:box('CanopyPost',(.13,.13,2.7),(x,-4.2,1.5),'wood')
for x in [-4.3,.7,2.3,3.9]:box('FrontWindow',(1.05,.05,1.45),(x,-3.035,2.05),'glass')
box('ServiceDoor',(1.8,.05,2.4),(3.4,5.04,1.45),'metal')
box('RearServiceApron',(5,2.7,.12),(3.3,6.55,.20),'paving')
box('FurnaceWing',(3.6,5.2,3.3),(3.7,2,1.8),'stone')
box('ScreenedFlue',(1.25,1.25,6.9),(3.6,3.2,3.6),'stone')
box('FlueCap',(1.4,1.4,.17),(3.6,3.2,7.13),'roof')
for y in [2.77,3.0,3.23,3.46,3.69]:box('FlueLouver',(1.28,.08,.15),(3.6,y,6.7),'metal')
for x,y in [(-6,-5.6),(-6,5.8),(6,-5.6)]:
 B.cylinder('TreeTrunk',.13,1.5,(x,y,.9),m['wood'],root,axis='Z')
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1.05,location=(x,y,2.15))
 B.finish(bpy.context.object,m['leaf'],root)
for x in [-5.8,5.8]:
 box('MemorialBench',(1.7,.5,.12),(x,-2.7,.65),'wood')
 for dx in [-.6,.6]:box('BenchLeg',(.1,.35,.55),(x+dx,-2.7,.35),'metal')
source=ROOT/'assets/service-facilities/crematorium-4x4';source.mkdir(parents=True,exist_ok=True)
game=ROOT/'cities_do/assets/services';game.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source/'facility.blend'),compress=False)
bpy.ops.export_scene.gltf(filepath=str(game/'crematorium-4x4.glb'),export_format='GLB',export_extras=True,export_animations=False)
# Transparent preview at the same calibrated 30-degree isometric camera convention.
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=False
scene.render.resolution_x=800;scene.render.resolution_y=680;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard'
scene.world=bpy.data.worlds.new('World');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.80,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
light=bpy.data.lights.new('Key','AREA');light.energy=2200;light.size=15
ob=bpy.data.objects.new('Key',light);scene.collection.objects.link(ob);ob.location=(12,-15,22);ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
camera=bpy.data.cameras.new('Camera');ob=bpy.data.objects.new('Camera',camera);scene.collection.objects.link(ob);scene.camera=ob
camera.type='ORTHO';camera.ortho_scale=28
target=Vector((0,0,2.5));ob.location=target+Vector((30,-30,math.sqrt(1800)*math.tan(math.pi/6)))
ob.rotation_euler=(target-ob.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(game/'crematorium-4x4.png');bpy.ops.render.render(write_still=True)
entry={'id':'crematorium-4x4','name':'화장터','width':4,'depth':4,'metres':[16,16],'height_m':7.215,'storeys':1,'model':'res://assets/services/crematorium-4x4.glb','preview':'res://assets/services/crematorium-4x4.png','source':'assets/service-facilities/crematorium-4x4/facility.blend','front_axis':[0,1],'render':{'resolution':[800,680],'pixels_per_metre':800/28,'camera_elevation_deg':30},'status':'asset_preview_only','simulation_enabled':False}
B.write_json(source/'spec.json',entry)
B.write_json(game/'catalog.json',{'facilities':[entry]})
print('SERVICE_FACILITY_BUILT',entry['id'])
