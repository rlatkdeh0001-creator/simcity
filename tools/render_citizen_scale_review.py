"""Read-only real-metre comparison with an existing sedan; not a game screenshot."""
from pathlib import Path
import bpy,sys,math,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'));import citizen_pilot_common as C
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/citizens/adult-pilot-01/citizen.blend'));C.studio(scale=1);C.set_pose('idle');bpy.data.objects['CitizenRig'].location=(1.65,-.75,0)
with bpy.data.libraries.load(str(ROOT/'assets/vehicle-fleet/car-sedan-03/vehicle.blend'),link=False) as (src,dst):dst.objects=src.objects
objects=[o for o in dst.objects if o and o.type in ['MESH','EMPTY']];owned=set(objects)
for o in objects:bpy.context.scene.collection.objects.link(o)
for o in objects:
 if o.parent not in owned:o.location+=Vector((-1.2,0,0))
scene=bpy.context.scene;scene.render.resolution_x=480;scene.render.resolution_y=240;scene.cycles.samples=32;cam=scene.camera;target=Vector((0,0,.85));cam.location=target+Vector((12,-12,math.sqrt(288)*math.tan(math.pi/6)));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=12;bpy.context.view_layer.update()
right=cam.rotation_euler.to_matrix()@Vector((1,0,0));a=world_to_camera_view(scene,cam,target-right*.5);b=world_to_camera_view(scene,cam,target+right*.5);cam.data.ortho_scale*=(b.x-a.x)*480/40;bpy.context.view_layer.update()
scene.render.filepath=str(ROOT/'docs/citizen-adult-pilot/scale-review.png');bpy.ops.render.render(write_still=True)
print('SCALE_REVIEW: original 1.75m adult / existing nominal 4.85m sedan, 40px/m, 30deg, no mesh rescaling; source files untouched')
