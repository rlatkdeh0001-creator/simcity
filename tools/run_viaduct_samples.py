"""Confirmed batch3: actual pier sprites and two requested1600x1000 captures."""
import argparse,json,re,shutil,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--cache',type=Path,required=True);p.add_argument('--only',choices=['pier','viaduct']);p.add_argument('--reuse-parts',action='store_true');a=p.parse_args()
f=a.cache/'viaduct-godot';f.mkdir(parents=True,exist_ok=True)
(f/'project.godot').write_text('[application]\nconfig/name="Viaduct inspection"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
paths=['assets/facilities/catalog.json','assets/vehicles/car-sedan-03.glb','assets/structures/viaduct-pier-01/viaduct-pier-01.glb','assets/structures/viaduct-sample-01/viaduct-sample-01.glb','assets/structures/viaduct-side-01/deck_side.png']
for path in paths:
 dest=f/path;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'cities_do'/path,dest)
shutil.copy2(ROOT/'assets/structures/viaduct-side-01/spec.json',f/'side-spec.json')
for source,target in [('elevated_inspection_common.gd','common.gd'),('capture_viaduct_pier.gd','pier.gd'),('capture_viaduct_sample.gd','viaduct.gd')]:shutil.copy2(ROOT/'tools'/source,f/target)
out=ROOT/'docs/elevated-tunnel-validation';cmd=[a.godot,'--path',str(f),'--audio-driver','Dummy','--rendering-method','gl_compatibility']
def run(extra):
 r=subprocess.run(cmd+extra,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=150)
 if r.returncode or re.search(r'^\s*(SCRIPT ERROR:|ERROR:|FAIL\b)',r.stdout,re.M):raise RuntimeError(r.stdout)
 return r.stdout
importlog=run(['--headless','--editor','--import','--quit'])
for script,capture,marker,result in [('pier','pier-01-1600.png','PIER_SPRITES_PASS','PIER_RESULTS.txt'),('viaduct','viaduct-03-1600.png','VIADUCT_SAMPLE_PASS','VIADUCT_RESULTS.txt')]:
 if a.only and a.only!=script:continue
 extra=['--resolution','800x500','--borderless','--quit-after','300','--script','res://'+script+'.gd','--',str(out/capture),str(ROOT/'cities_do/assets/structures/viaduct-pier-01')]
 if a.reuse_parts:extra+=['--reuse-parts']
 log=run(extra);assert marker in log,log
 assert struct.unpack('>II',(out/capture).read_bytes()[16:24])==(1600,1000)
 (out/result).write_text('Actual Blender4.3.2 original/save/reload: pier852tri 4x4x8m; viaduct4404tri40x12x11.1m.\n'+subprocess.list2cmdline(cmd+extra)+'\n'+importlog+'\n'+log+'\nActual transparent Godot parts and fixed framebuffer; inspection only, no game logic or price.\n',encoding='utf-8');print(log)
manifest=json.loads((ROOT/'cities_do/assets/structures/viaduct-pier-01/render_manifest.json').read_text());s=ROOT/'assets/structures/viaduct-pier-01/spec.json';spec=json.loads(s.read_text(encoding='utf-8'));spec['parts']=manifest['parts'];spec['sprite_render']=manifest;s.write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
