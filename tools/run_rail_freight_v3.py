"""Isolated freight inspection using catalog-selected approved GLB paths."""
import argparse,json,re,shutil,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--cache',type=Path,required=True);a=p.parse_args()
f=a.cache/'freight-v3';f.mkdir(parents=True,exist_ok=False)
(f/'project.godot').write_text('[application]\nconfig/name="Electric Freight Inspection"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[display]\nwindow/size/viewport_width=1600\nwindow/size/viewport_height=1000\n',encoding='utf-8')
paths=['assets/vehicles/train-loco-freight-01-v2.glb','assets/facilities/catalog.json','assets/vehicles/catalog.json']
for category,ids in [('vehicles',['train-loco-freight-01'])]:
 doc=json.loads((ROOT/'cities_do/assets'/category/'catalog.json').read_text(encoding='utf-8'))
 selected=[e for e in doc[category] if e['id'] in ids];assert len(selected)==len(ids)
 for e in selected:paths.append(e['model'].removeprefix('res://'))
for name in paths:
 dest=f/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'cities_do'/name,dest)
shutil.copy2(ROOT/'tools/capture_rail_freight_v3.gd',f/'capture.gd')
out=ROOT/'docs/rail-park-validation';out.mkdir(parents=True,exist_ok=True)
cmd=[a.godot,'--path',str(f),'--audio-driver','Dummy','--rendering-method','gl_compatibility'];logs=[]
for extra in [['--headless','--editor','--import','--quit'],['--resolution','1600x1000','--borderless','--quit-after','240','--script','res://capture.gd','--',str(out/'freight-loco-v3-1600.png')]]:
 proc=subprocess.run(cmd+extra,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=150);logs.append(proc.stdout)
 if proc.returncode or re.search(r'^\s*(SCRIPT ERROR:|ERROR:|FAIL\b)',proc.stdout,re.M):raise RuntimeError(proc.stdout)
assert 'FREIGHT_GRAPHICAL_PASS' in logs[-1],logs[-1]
assert struct.unpack('>II',(out/'freight-loco-v3-1600.png').read_bytes()[16:24])==(1600,1000)
spec=json.loads((ROOT/'assets/vehicle-fleet/train-loco-freight-01/v3/spec.json').read_text())
sprites=list((ROOT/'cities_do/assets/vehicles/sprites/train-loco-freight-01-v3').glob('*.png'));assert len(sprites)==8
assert all(struct.unpack('>II',p.read_bytes()[16:24])==(430,245) for p in sprites)
(out/'FREIGHT_LOCO_V3_RESULTS.txt').write_text('Actual Blender source: '+str(spec['triangles'])+' triangles; measured LWH '+str(spec['measured_dimensions_lwh_m'])+'; body9m.\nOne recessed electric pickup top '+str(spec['pantograph_top_z_m'])+'m; no diesel exhaust/tank/nose. Eight430x245 sprites.\nGraphical command: '+subprocess.list2cmdline(cmd+extra)+'\n'+logs[-1]+'\nInspection only. Existing park/subway/station/vehicles preserved; station v2 unchanged. No game code, prices, operations, push or main.\n',encoding='utf-8')
print(logs[-1]);shutil.rmtree(f)
