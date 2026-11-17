"""Isolated native Godot inspection; no game imports or source changes."""
import argparse,json,re,shutil,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--cache',type=Path,required=True);a=p.parse_args()
f=a.cache/'station-v2';f.mkdir(parents=True,exist_ok=True)
(f/'project.godot').write_text('[application]\nconfig/name="Station v2 Inspection"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[display]\nwindow/size/viewport_width=1600\nwindow/size/viewport_height=1000\n',encoding='utf-8')
paths=['assets/facilities/catalog.json','assets/vehicles/catalog.json','assets/facilities/train-station-01.glb','assets/vehicles/taxi-sedan-01.glb']
for category,ids in [('facilities',['train-station-01','rail-track-01']),('vehicles',['train-loco-freight-01','train-loco-01','train-passenger-01','train-flatcar-01','container-20ft-01'])]:
 doc=json.loads((ROOT/'cities_do/assets'/category/'catalog.json').read_text(encoding='utf-8'))
 selected=[e for e in doc[category] if e['id'] in ids];assert len(selected)==len(ids)
 for e in selected:paths.append(e['model'].removeprefix('res://'))
for name in paths:
 dest=f/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'cities_do'/name,dest)
# Preserved template: inherited helpers only; scene/run are overridden.
shutil.copy2(ROOT/'tools/capture_rail_freight.gd',f/'common.gd')
shutil.copy2(ROOT/'tools/capture_rail_station_v2.gd',f/'capture.gd')
out=ROOT/'docs/rail-park-validation';out.mkdir(parents=True,exist_ok=True)
cmd=[a.godot,'--path',str(f),'--audio-driver','Dummy','--rendering-method','gl_compatibility'];logs=[]
for extra in [['--headless','--editor','--import','--quit'],['--resolution','1600x1000','--borderless','--quit-after','240','--script','res://capture.gd','--',str(out/'station-v2-1600.png')]]:
 proc=subprocess.run(cmd+extra,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=150);logs.append(proc.stdout)
 if proc.returncode or re.search(r'^\s*(SCRIPT ERROR:|ERROR:|FAIL\b)',proc.stdout,re.M):raise RuntimeError(proc.stdout)
assert 'STATION_V2_GRAPHICAL_PASS' in logs[-1],logs[-1]
assert struct.unpack('>II',(out/'station-v2-1600.png').read_bytes()[16:24])==(1600,1000)
spec=json.loads((ROOT/'assets/facilities/train-station-01/v2/spec.json').read_text(encoding='utf-8'))
assert struct.unpack('>II',(ROOT/'assets/facilities/train-station-01/v2/preview.png').read_bytes()[16:24])==(800,680)
(out/'STATION_V2_RESULTS.txt').write_text('Actual Blender: '+str(spec['triangles'])+' triangles; measured bounds '+str(spec['bounds_blender_m'])+'\nTwo32x4.2m platforms at1.1m; stair floor-3.6m bottom-3.85m, two intermediate landings, eight closed walls, 1.8m inner width/2.1m track-side walk. No under-track tunnel.\nGraphical command: '+subprocess.list2cmdline(cmd+extra)+'\n'+logs[-1]+'\nOne raw1600x1000 framebuffer: front/rear, same-scale v1, taxi/human, labelled canopy-only inspection cutaway. Source visibility unchanged.\nInspection_only: live terrain cutout, placement, tunnel connectivity and operation remain code-side work. No push/main/game-code or original source edits.\n',encoding='utf-8')
print(logs[-1]);shutil.rmtree(f)
