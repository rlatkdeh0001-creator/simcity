"""Read-only geometry/frontage audit; never run source builders or save originals."""
import hashlib,json,math
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/register-30-assets-validation'
def bounds(objects):
 graph=bpy.context.evaluated_depsgraph_get()
 points=[o.matrix_world@Vector(v) for src in objects for o in [src.evaluated_get(graph)] for v in o.bound_box]
 return [[fn(p[axis] for p in points) for axis in range(3)] for fn in [min,max]]
def dump(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 originals=[p for group in ['commercial','industrial','power','water','waste'] for p in (ROOT/f'assets/{group}-study').rglob('*') if p.is_file()]
 hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in originals}
 dump(OUT/'source-hashes.json',{'sha256':hashes})
 report=[]
 for item in json.loads((ROOT/'docs/remaining-original-assets/catalog.json').read_text(encoding='utf-8'))['assets']:
  bpy.ops.wm.open_mainfile(filepath=str(ROOT/item['source']),load_ui=False,use_scripts=False)
  objects=[o for o in bpy.context.scene.objects if o.type in ['MESH','FONT','CURVE']]
  low,high=bounds(objects)
  features=[];ground=[]
  for o in objects:
   if any(t in o.name.lower() for t in ['door','entrance','entry','gate','lobby']):
    a,b=bounds([o]);features.append({'name':o.name,'center':[(a[i]+b[i])/2 for i in range(3)],'size':[b[i]-a[i] for i in range(3)]})
   if any(t in o.name.lower() for t in ['lot','ground','slab','land','base','terrain','platform']):
    a,b=bounds([o]);ground.append({'name':o.name,'bounds':[a,b]})
  data={'id':item['id'],'group':item['group'],'raw_bounds':[low,high],'size_m':[high[i]-low[i] for i in range(3)],'unit_scale':bpy.context.scene.unit_settings.scale_length,'features':features,'ground_candidates':ground,'parented_meshes':sum(o.parent is not None for o in objects),'font_objects':sum(o.type=='FONT' for o in objects)}
  assert all(math.isfinite(v) for row in [low,high] for v in row)
  report.append(data);dump(OUT/'source-audit.json',report)
  print('AUDITED',item['id'],'FEATURES',[f['name'] for f in features],'GROUND',[g['name'] for g in ground],flush=True)
 assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items())
 print('SOURCE_AUDIT_COMPLETE',len(report),len(hashes),flush=True)
if __name__=='__main__':main()
