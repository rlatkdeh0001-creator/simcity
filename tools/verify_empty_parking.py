"""Read-only reimport validation for empty parking source-side GLBs."""
from pathlib import Path
import bpy,json,math
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];results=[]
def geometry():
 bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get();points=[];tri=0
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  e=o.evaluated_get(dep);me=e.to_mesh();points.extend(e.matrix_world@v.co for v in me.vertices);tri+=sum(len(p.vertices)-2 for p in me.polygons);e.to_mesh_clear()
 return [[min(v[i] for v in points) for i in range(3)],[max(v[i] for v in points) for i in range(3)]],tri
for ident in ['parking-small-2x4','parking-medium-4x4','parking-large-4x8','parking-tower-4x4-4f']:
 p=ROOT/'assets/facilities'/ident;bpy.ops.wm.open_mainfile(filepath=str(p/'facility.blend'));bb,tri=geometry();bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(p/'facility.glb'));gbb,gtri=geometry()
 checks=dict(glb_reimports=True,triangle_count_matches=tri==gtri,bounds_and_axes_match=max(abs(a-b) for v,w in zip(bb,gbb) for a,b in zip(v,w))<.0001,finite_glb_bounds=all(math.isfinite(v) for row in gbb for v in row))
 results.append(dict(id=ident,checks=checks,passed=all(checks.values()),triangles=tri,bounds_blender_m=bb));print('GLB_VERIFY',ident,checks,flush=True)
(ROOT/'docs/empty-parking/glb-validation.json').write_text(json.dumps(dict(assets=results,passed=all(r['passed'] for r in results)),ensure_ascii=False,indent=2)+'\n')
assert all(r['passed'] for r in results)
print('RESULT',sum(len(r['checks']) for r in results),'GLB reimport checks passed')
