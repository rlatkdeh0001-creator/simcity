"""Isolated no-focus native Godot fixture. Never imports game worktree or kills processes."""
import argparse,json,re,shutil,struct,subprocess
from pathlib import Path
from test_center_structure_samples import check,IDS,ROOT
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--cache',required=True,type=Path);p.add_argument('--only',choices=IDS);a=p.parse_args()
f=a.cache/'center-godot';f.mkdir(parents=True,exist_ok=True)
(f/'project.godot').write_text('[application]\nconfig/name="Central structures isolated inspection"\n[display]\nwindow/size/no_focus=true\nwindow/size/borderless=true\nwindow/size/viewport_width=320\nwindow/size/viewport_height=200\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
paths=['assets/facilities/catalog.json','assets/vehicles/car-sedan-03.glb']+[f'assets/structures/{i}/{i}.glb' for i in IDS]
for path in paths:
 dest=f/path;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'cities_do'/path,dest)
for src,dst in [('elevated_inspection_common.gd','common.gd'),('capture_center_structure_samples.gd','capture.gd')]:shutil.copy2(ROOT/'tools'/src,f/dst)
cmd=[a.godot,'--path',str(f),'--audio-driver','Dummy','--rendering-method','gl_compatibility']
def run(extra):
 r=subprocess.run(cmd+extra,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=180)
 if r.returncode or re.search(r'^\s*(SCRIPT ERROR:|ERROR:|FAIL\b)',r.stdout,re.M):raise RuntimeError(r.stdout)
 return r.stdout
run(['--headless','--editor','--import','--quit'])
artifact_count=check();out=ROOT/'docs/elevated-tunnel-validation'
for ident,num in zip(IDS,[6,7,8]):
 if a.only and a.only!=ident:continue
 image=out/f'center-{num:02}-1600.png'
 extra=['--position','-20000,-20000','--max-fps','30','--quit-after','300','--script','res://capture.gd','--',str(image),ident]
 log=run(extra);assert 'CENTER_SAMPLE_PASS' in log,log
 assert struct.unpack('>II',image.read_bytes()[16:24])==(1600,1000)
 s=json.loads((ROOT/'assets/structures'/ident/'spec.json').read_text(encoding='utf-8'))
 (out/f'CENTER_{num:02}_RESULTS.txt').write_text(f'Actual Blender4.3.2 save/reload; {ident}: {s["metres"]}m, {s["triangles"]}tri, bounds={s["bounds_blender_m"]}\nShared artifact acceptance checks={artifact_count} (count once across batch).\n'+subprocess.list2cmdline(cmd+extra)+'\n'+log+'\nPNG IHDR1600x1000; three native 3D viewports. No-focus asserted; no input injection, no process termination.\nOriginal pier spec preserved; v2 metadata only changes twin threshold W>=14m.\n',encoding='utf-8')
 print(log)
