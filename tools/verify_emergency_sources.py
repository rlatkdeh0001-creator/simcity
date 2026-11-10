"""Read-only validation of the recovered seven emergency-service Blender sources."""
from pathlib import Path
import bpy,json,math
from mathutils import Vector
r=Path(__file__).resolve().parents[1];rows=[]
for group in ['fire','police','prison']:
 for path in sorted((r/f'assets/{group}-study').glob('*/metadata.json')):
  meta=json.loads(path.read_text());source=path.parent/'building.blend'
  bpy.ops.wm.open_mainfile(filepath=str(source))
  meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
  finite=all(math.isfinite(c) for o in meshes for v in o.data.vertices for c in v.co)
  bounds=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
  low=[min(v[i] for v in bounds) for i in range(3)];high=[max(v[i] for v in bounds) for i in range(3)]
  expected=meta['vertex_bounds_m']
  error=max(abs(a-b) for actual,wanted in zip([low,high],expected) for a,b in zip(actual,wanted))
  assert meshes and finite and error<.03,(str(path),error)
  rows.append({'id':meta['id'],'source':str(source.relative_to(r)),'opens':True,'mesh_count':len(meshes),'finite_vertices':finite,'bounds_metadata_max_error_m':error})
  print('SOURCE_OK',meta['id'],flush=True)
assert len(rows)==7
out=r/'docs/recovered-emergency-assets';out.mkdir(parents=True,exist_ok=True)
(out/'source-validation.json').write_text(json.dumps(rows,indent=2)+'\n')
print('RESULT 7/7 Blender source files opened, finite, matching metadata',flush=True)
