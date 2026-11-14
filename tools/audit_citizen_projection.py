"""Project actual deformed attachment anchors for all 25 views/poses. No render/write source."""
from pathlib import Path
import bpy,json,sys
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'));import citizen_pilot_common as C
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/citizens/adult-pilot-01/citizen.blend'));C.studio(scale=1);rig=bpy.data.objects['CitizenRig'];rows=[]
for direction in C.DIRECTIONS:
 C.set_view(direction)
 for frame in C.FRAMES:
  C.set_pose(frame);record={}
  for name,bone,position in [('waist','pelvis',(0,0,.97)),('neck','head',(0,0,1.40)),('wrist_L','forearm.L',(.264,0,.942)),('wrist_R','forearm.R',(-.264,0,.942))]:
   world=rig.matrix_world@rig.pose.bones[bone].matrix@rig.data.bones[bone].matrix_local.inverted()@Vector(position);p=world_to_camera_view(bpy.context.scene,bpy.context.scene.camera,world);record[name]=[p.x*C.WIDTH,(1-p.y)*C.HEIGHT]
  rows.append(dict(direction=direction,frame=frame,attachment_px=record))
(ROOT/'docs/citizen-adult-pilot/attachment-projections.json').write_text(json.dumps(rows,indent=2)+'\n');print('25 posed attachment projections written; source untouched')
