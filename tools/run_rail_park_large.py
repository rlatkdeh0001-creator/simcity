"""Bounded isolated actual-GLB inspection; no whole-game import or source edits."""
import argparse,json,re,shutil,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--cache',type=Path,required=True);a=p.parse_args()
f=a.cache/'park';f.mkdir(parents=True,exist_ok=False)
(f/'project.godot').write_text('[application]\nconfig/name="Rail Park Asset Inspection"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[display]\nwindow/size/viewport_width=1600\nwindow/size/viewport_height=1000\n',encoding='utf-8')
for name in ['facilities/park-large-8x8.glb','facilities/park-plaza-4x4.glb','facilities/catalog.json','vehicles/taxi-sedan-01.glb']:
    dest=f/'assets'/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'cities_do/assets'/name,dest)
shutil.copy2(ROOT/'tools/capture_rail_park_large.gd',f/'capture.gd')
out=ROOT/'docs/rail-park-validation';out.mkdir(parents=True,exist_ok=True)
cmd=[a.godot,'--path',str(f),'--audio-driver','Dummy','--rendering-method','gl_compatibility']
logs=[]
for extra in [['--headless','--editor','--import','--quit'],['--resolution','1600x1000','--borderless','--quit-after','240','--script','res://capture.gd','--',str(out/'park-large-1600.png')]]:
    proc=subprocess.run(cmd+extra,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=150);logs.append(proc.stdout)
    if proc.returncode or re.search(r'^\s*(SCRIPT ERROR:|ERROR:|FAIL\b)',proc.stdout,re.M):raise RuntimeError(proc.stdout)
assert 'LARGE_PARK_GRAPHICAL_PASS' in logs[-1],logs[-1]
assert struct.unpack('>II',(out/'park-large-1600.png').read_bytes()[16:24])==(1600,1000)
spec=json.loads((ROOT/'assets/facilities/park-large-8x8/spec.json').read_text())
(out/'PARK_LARGE_RESULTS.txt').write_text('Actual Godot GLB inspection PASS: load, 32x32m lot, front +Z, continuous ground/shallow water, 24 trees, existing fountain park/taxi/human scale.\nTriangles: '+str(spec['triangles'])+'; height_m: '+str(spec['height_m'])+'\nGraphical command: '+subprocess.list2cmdline(cmd+extra)+'\n'+'\n'.join(logs),encoding='utf-8')
print(logs[-1]);shutil.rmtree(f)
