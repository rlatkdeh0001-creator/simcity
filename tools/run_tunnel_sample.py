"""Requested item6 catalog load, bounds and two-view actual Godot capture."""
import argparse,json,re,shutil,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--cache',type=Path,required=True);a=p.parse_args()
f=a.cache/'sample-godot';f.mkdir(parents=True,exist_ok=True)
(f/'project.godot').write_text('[application]\nconfig/name="Tunnel sample inspection"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
for path in ['assets/facilities/catalog.json','assets/vehicles/car-sedan-03.glb','assets/structures/tunnel-sample-01/tunnel-sample-01.glb']:
 dest=f/path;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'cities_do'/path,dest)
shutil.copy2(ROOT/'tools/capture_tunnel_sample.gd',f/'capture.gd')
out=ROOT/'docs/elevated-tunnel-validation';cmd=[a.godot,'--path',str(f),'--audio-driver','Dummy','--rendering-method','gl_compatibility'];logs=[]
for extra in [['--headless','--editor','--import','--quit'],['--resolution','800x500','--borderless','--quit-after','240','--script','res://capture.gd','--',str(out/'tunnel-04-1600.png')]]:
 r=subprocess.run(cmd+extra,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=150);logs.append(r.stdout)
 if r.returncode or re.search(r'^\s*(SCRIPT ERROR:|ERROR:|FAIL\b)',r.stdout,re.M):raise RuntimeError(r.stdout)
assert 'TUNNEL_SAMPLE_PASS' in logs[-1],logs[-1]
assert struct.unpack('>II',(out/'tunnel-04-1600.png').read_bytes()[16:24])==(1600,1000)
s=json.loads((ROOT/'assets/structures/tunnel-sample-01/spec.json').read_text(encoding='utf-8'))
(out/'TUNNEL_RESULTS.txt').write_text('Blender4.3.2 actual build/save/reload: '+str(s['triangles'])+' triangles, '+str(s['bounds_blender_m'])+'\nActual requested two-view Godot fixed1600x1000 framebuffer; original car-sedan-03 and 1.75m person.\n'+subprocess.list2cmdline(cmd+extra)+'\n'+'\n'.join(logs)+'\nInspection_only catalog entry; no game implementation or pending assets.\n',encoding='utf-8')
print(logs[-1])
