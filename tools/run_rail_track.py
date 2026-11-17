"""Isolated requested six-view rail framebuffer; no game code dependencies."""
import argparse,json,re,shutil,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--cache',type=Path,required=True);a=p.parse_args()
f=a.cache/'track';f.mkdir(parents=True,exist_ok=False)
(f/'project.godot').write_text('[application]\nconfig/name="Rail Track Inspection"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[display]\nwindow/size/viewport_width=1600\nwindow/size/viewport_height=1000\n',encoding='utf-8')
paths=['assets/facilities/catalog.json','assets/vehicles/catalog.json']
for category,ids in [('facilities',['train-station-01','rail-track-01']),('vehicles',['train-loco-01','train-passenger-01'])]:
 doc=json.loads((ROOT/'cities_do/assets'/category/'catalog.json').read_text(encoding='utf-8'))
 for e in doc[category]:
  if e['id'] in ids:paths.append(e['model'].removeprefix('res://'))
for name in paths:
 dest=f/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'cities_do'/name,dest)
for name in ['strip','strip_end','strip_rails']:shutil.copy2(ROOT/'cities_do/assets/rail/rail-track-01'/(name+'.png'),f/'assets/rail/rail-track-01'/(name+'.png'))
shutil.copy2(ROOT/'tools/capture_rail_track.gd',f/'capture.gd')
out=ROOT/'docs/rail-park-validation';out.mkdir(parents=True,exist_ok=True)
cmd=[a.godot,'--path',str(f),'--audio-driver','Dummy','--rendering-method','gl_compatibility'];logs=[]
for extra in [['--headless','--editor','--import','--quit'],['--resolution','1600x1000','--borderless','--quit-after','240','--script','res://capture.gd','--',str(out/'rail-track-1600.png')]]:
 proc=subprocess.run(cmd+extra,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=150);logs.append(proc.stdout)
 if proc.returncode or re.search(r'^\s*(SCRIPT ERROR:|ERROR:|FAIL\b)',proc.stdout,re.M):raise RuntimeError(proc.stdout)
assert 'RAIL_TRACK_GRAPHICAL_PASS' in logs[-1],logs[-1]
assert struct.unpack('>II',(out/'rail-track-1600.png').read_bytes()[16:24])==(1600,1000)
spec=json.loads((ROOT/'assets/rail/rail-track-01/spec.json').read_text())
(out/'RAIL_TRACK_RESULTS.txt').write_text('Actual Blender source: '+str(spec['triangles'])+' triangles; bounds '+str(spec['bounds_blender_m'])+'\nSingle-track strips320x288 at80px/m; gauge inner faces1.435m =114.8px; rail width0.15m.\nDouble-track centres +/-2m; bed7.6m; plain middle gap0.4m; min inner radius32m.\nGraphical command: '+subprocess.list2cmdline(cmd+extra)+'\n'+'\n'.join(logs)+'\nInspection only. Station v2 NOT built; existing assets preserved; no game code, prices, operation, push or main.\n',encoding='utf-8')
print(logs[-1]);shutil.rmtree(f)
