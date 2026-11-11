"""Read-only close-up of the ambulance mirror mount; intentionally cropped body."""
from pathlib import Path
import bpy, math
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/vehicle-fleet/ambulance-01/vehicle.blend'))
scene=bpy.context.scene;cam=scene.camera;target=Vector((1.12,-1.40,1.49))
cam.location=target+Vector((3,1.8,1.6));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.88
scene.render.resolution_x=640;scene.render.resolution_y=640;scene.cycles.samples=48
scene.render.filepath=str(ROOT/'docs/service-vehicles-2/ambulance-revision/mirror-mount.png')
bpy.ops.render.render(write_still=True)
print('MIRROR_REVIEW: existing source camera repositioned; no model edits or rescaling')
