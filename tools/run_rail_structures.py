"""Approved final fixture only: shared rail bridge/portal actual Godot1600 capture."""
import argparse,json,re,shutil,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--cache',type=Path,required=True);a=p.parse_args()
f=a.cache/'rail-structures-godot';f.mkdir(parents=True,exist_ok=True)
(f/'project.godot').write_text('[application]\nconfig/name="Shared rail structures inspection"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
paths=['assets/vehicles/catalog.json','assets/structures/viaduct-pier-01/viaduct-pier-01.glb','assets/structures/viaduct-side-01/deck_side.png','assets/structures/viaduct-side-01/barrier_inner.png','assets/structures/retaining-wall-01/wall.png','assets/structures/tunnel-portal-01/portal.png','assets/rail/rail-track-01/strip.png']
cat=json.loads((ROOT/'cities_do/assets/vehicles/catalog.json').read_text(encoding='utf-8'))
for e in cat['vehicles']:
 if e['id'] in ['train-loco-01','train-passenger-01','train-loco-freight-01']:paths.append(e['model'].removeprefix('res://'))
for path in paths:
 dest=f/path;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'cities_do'/path,dest)
shutil.copy2(ROOT/'assets/structures/viaduct-side-01/spec.json',f/'side-spec.json')
for source,target in [('elevated_inspection_common.gd','common.gd'),('capture_viaduct_sample.gd','viaduct_geometry.gd'),('capture_rail_structures.gd','capture.gd')]:shutil.copy2(ROOT/'tools'/source,f/target)
out=ROOT/'docs/elevated-tunnel-validation';cmd=[a.godot,'--path',str(f),'--audio-driver','Dummy','--rendering-method','gl_compatibility'];logs=[]
for extra in [['--headless','--editor','--import','--quit'],['--resolution','800x500','--borderless','--quit-after','300','--script','res://capture.gd','--',str(out/'rail-05-1600.png')]]:
 r=subprocess.run(cmd+extra,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=150);logs.append(r.stdout)
 if r.returncode or re.search(r'^\s*(SCRIPT ERROR:|ERROR:|FAIL\b)',r.stdout,re.M):raise RuntimeError(r.stdout)
assert 'RAIL_STRUCTURES_PASS' in logs[-1],logs[-1]
assert struct.unpack('>II',(out/'rail-05-1600.png').read_bytes()[16:24])==(1600,1000)
(out/'RAIL_STRUCTURES_RESULTS.txt').write_text('Actual shared strips/pier fixture; no new model, catalog entry, or rail gameplay code.\nBridge40x10m deck+10m; portal32x10m structural width, level rail-7m, clearance5.5m. No ramp; confirmed railway grade3.5% unaltered.\n'+subprocess.list2cmdline(cmd+extra)+'\n'+'\n'.join(logs)+'\nExisting v3 passenger lead/coach and approved freight v3 preserved.\n',encoding='utf-8')
print(logs[-1])
