"""Read-only 100-tile Blender review. Not a Godot runtime performance benchmark."""
import bpy,math,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/primary-industry/primary-tile-grain-01/primary-tile-grain-01.blend'))
scene=bpy.context.scene;originals=[o for o in scene.objects if o.type=='MESH']
# Centre a 40x40m patch; every copy shares mesh data and unchanged physical scale.
for ob in originals:ob.location+=Vector((-18,-18,0))
for ix in range(10):
 for iy in range(10):
  if ix==iy==0:continue
  for ob in originals:
   cp=ob.copy();scene.collection.objects.link(cp);cp.location=ob.location+Vector((ix*4,iy*4,0))
cam=scene.camera;cam.data.ortho_scale*=10
scene.render.filepath=str(ROOT/'docs/primary-industry/grain-ribbons/field-10x10.png');scene.cycles.samples=32
bpy.ops.render.render(write_still=True)
meta=json.loads((ROOT/'assets/primary-industry/primary-tile-grain-01/metadata.json').read_text())
print(f"FIELD_REVIEW: 100 tiles, 40x40m, {meta['triangles']*100} triangles; source unchanged; not a runtime benchmark")
