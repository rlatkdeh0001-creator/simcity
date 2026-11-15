"""CITIES_DO original road/tile studies, Blender 4.3+, no API or purchased assets."""
import bpy, math, json, sys, argparse
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--lanes',type=int,choices=[2,4],required=True)
args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
lanes=args.lanes;folder=OUT/f'road-{lanes}';folder.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
def color(h):
 v=[int(h[i:i+2],16)/255 for i in [0,2,4]]
 return tuple(x/12.92 if x<.04045 else ((x+.055)/1.055)**2.4 for x in v)+(1,)
def mat(name,h):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=color(h);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.8;return m
asphalt=mat('Asphalt','4c5659');curb=mat('Curb','c8cbc3');paving=mat('Paving','cfd0c6');yellow=mat('CenterYellow','e4bd5f');white=mat('LaneWhite','e8e7dc');joint=mat('PavingJoint','a7aea2');grass=mat('Grass','829674');soil=mat('SoilEdge','63735b')
def box(name,loc,size,material,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material)
 if bevel:
  mod=o.modifiers.new('EdgeSoftness','BEVEL');mod.width=bevel;mod.segments=2
 return o
width=8 if lanes==2 else 16;carriage=6 if lanes==2 else 13;length=32;walk=(width-carriage)/2
box('RoadFoundation',(0,0,-.18),(length,width,.35),curb,.04)
box('Asphalt',(0,0,.005),(length,carriage,.05),asphalt)
for sign in [-1,1]:
 y=sign*(carriage/2+walk/2)
 box('Sidewalk',(0,y,.115),(length,walk,.22),paving,.02)
 box('CurbLip',(0,sign*(carriage/2+.1),.15),(length,.18,.28),curb,.015)
 for x in range(-16,17,2):box('WalkJoint',(x,y,.23),(.018,walk-.15,.007),joint)
 # thin edge lines keep road legible at game zoom
 box('RoadEdge',(0,sign*(carriage/2-.2),.037),(length,.1,.012),white)
 # parallel center lines mean opposing traffic; lanes count is total 1+1 / 2+2
 box('CenterLine',(0,sign*.1,.037),(length,.1,.012),yellow)
if lanes==4:
 for sign in [-1,1]:
  for x in [-14,-9,-4,1,6,11]:box('LaneDivider',(x,sign*3.25,.039),(3,.1,.012),white)
# Render one isolated 1x1 terrain tile as another scene, same projected ratio.
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(35,-35,math.sqrt(2450)*math.tan(math.radians(30))));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=44;aim(cam,(0,0,0));scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(-12,-15,26));light=bpy.context.object;light.data.energy=2800;light.data.size=14;aim(light,(0,0,0))
scene.world=bpy.data.worlds.new('StudioWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.55,.65,.75,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False;scene.render.threads_mode='FIXED';scene.render.threads=6
scene.render.resolution_x=1000;scene.render.resolution_y=760;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='AgX'
scene.render.filepath=str(folder/'road.png');bpy.ops.wm.save_as_mainfile(filepath=str(folder/'road.blend'));bpy.ops.render.render(write_still=True)
meta={'lanes_total':lanes,'directional_lanes':[lanes//2,lanes//2],'cell_meters':4,'width_cells':width/4,'total_width_m':width,'carriageway_m':carriage,'sidewalk_each_m':walk,'length_cells':8,'length_m':length,'camera_elevation_degrees':30,'orthographic_scale':44,'source':'original Blender geometry, no external models/textures/API','scope':'straight road art concept; runtime uses vector ribbons for free curves'}
(folder/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
if lanes==2:
 # Preserve road blend separately; tile is its own original asset.
 for o in list(scene.objects):
  if o.type=='MESH':bpy.data.objects.remove(o,do_unlink=True)
 box('TerrainTile_1x1',(0,0,-.12),(4,4,.24),soil,.025);box('GrassSurface',(0,0,.015),(4,4,.05),grass,.02)
 cam.data.ortho_scale=6.5
 scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.filepath=str(OUT/'grass-tile.png');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'grass-tile.blend'));bpy.ops.render.render(write_still=True)
print('PASS',meta)
