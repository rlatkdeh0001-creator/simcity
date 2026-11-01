"""Blender source geometry and decoded preview validation; no files modified except report."""
import bpy,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];results=[]
for folder in sorted((ROOT/'assets/facilities').iterdir()):
 if not folder.is_dir():continue
 spec=json.loads((folder/'spec.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(folder/'facility.blend'))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];base=next(o for o in meshes if o.name.startswith(('ParkBase','Asphalt','TowerBase')))
 bpy.context.view_layer.update()
 decks=[o for o in meshes if o.name.startswith('ParkingDeck_')]
 checks={'opens':True,'finite_vertices':all(math.isfinite(v) for o in meshes for vert in o.data.vertices for v in vert.co),'flat_ground_axis':base.dimensions.z<.3,'four_decks_only':len(decks)==(4 if spec['kind']=='parking_tower' else 0),'no_external_images':not any(im.filepath and not im.packed_file for im in bpy.data.images)}
 results.append({'id':spec['id'],'checks':checks,'passed':all(checks.values())})
passed=len(results)==8 and all(r['passed'] for r in results)
(ROOT/'assets/facilities/source-validation.json').write_text(json.dumps({'passed':passed,'assets':results},indent=2)+'\n')
print('SOURCE_CHECK',passed,len(results),flush=True)
if not passed:raise RuntimeError('Facility source check failed')
