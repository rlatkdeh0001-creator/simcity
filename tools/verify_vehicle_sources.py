"""Open and inspect every generated .blend with Blender; no assets modified.

blender -b --factory-startup -t 2 -P tools/verify_vehicle_sources.py
"""
import json
import math
from pathlib import Path
import bpy

ROOT=Path(__file__).resolve().parents[1]
results=[]
for source in sorted((ROOT/'assets/vehicle-fleet').glob('*/vehicle.blend')):
    bpy.ops.wm.open_mainfile(filepath=str(source))
    spec=json.loads((source.parent/'spec.json').read_text())
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    spins=[o for o in bpy.context.scene.objects if o.name.startswith('Wheel_') and o.name.endswith('_Spin')]
    triangles=sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons)
    checks={
        'opens':True,
        'finite_vertices':all(math.isfinite(v) for o in meshes for vertex in o.data.vertices for v in vertex.co),
        'triangle_count_matches':triangles==spec['triangles'],
        'wheel_pivots':len(spins)>=4 and all(o.parent and o.parent.name.startswith('Wheel_') for o in spins),
        'left_hand_drive':bpy.data.objects['Seat_FL'].matrix_world.translation.x>0,
        'no_external_images':not any(im.filepath and not im.packed_file for im in bpy.data.images),
    }
    results.append({'id':spec['id'],'checks':checks,'passed':all(checks.values()),'triangles':triangles})
output=ROOT/'assets/vehicle-fleet/source-validation.json'
output.write_text(json.dumps({'expected':23,'passed':len(results)==23 and all(r['passed'] for r in results),'vehicles':results},indent=2)+'\n')
print('SOURCE_CHECK',len(results),all(r['passed'] for r in results),flush=True)
if len(results)!=23 or not all(r['passed'] for r in results):
    raise RuntimeError('Source validation failed; see '+str(output))
