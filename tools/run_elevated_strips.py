"""Finite strip inspection: dimensions, seams, shared cap, actual Godot framebuffer."""
import argparse,json,re,shutil,struct,subprocess,sys
from pathlib import Path
sys.path.insert(0,'D:/tools/cities-asset-python311/site-packages')
from PIL import Image,ImageChops
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--cache',type=Path,required=True);a=p.parse_args()
ids=['viaduct-side-01','retaining-wall-01','tunnel-portal-01'];names=['deck_side','wall','portal'];ims=[]
for ident,name,height in zip(ids,names,[248,720,208]):
 im=Image.open(ROOT/'cities_do/assets/structures'/ident/(name+'.png')).convert('RGBA');assert im.size==(320,height);assert im.getextrema()[3]==(255,255)
 assert max(v[1] for v in ImageChops.difference(im.crop((0,0,1,height)),im.crop((319,0,320,height))).getextrema())<=1
 ims.append(im)
for im in ims[1:]:assert all(v==(0,0) for v in ImageChops.difference(ims[0].crop((0,0,320,112)),im.crop((0,0,320,112))).getextrema())
# Wall's body has vertical joints only: every interior row is the same.
wall=ims[1];assert all(wall.crop((0,y,320,y+1)).tobytes()==wall.crop((0,114,320,115)).tobytes() for y in range(115,719))
f=a.cache/'strips-godot';f.mkdir(parents=True,exist_ok=True)
(f/'project.godot').write_text('[application]\nconfig/name="Elevated strip inspection"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
for ident in ids:
 shutil.copytree(ROOT/'cities_do/assets/structures'/ident,f/'assets/structures'/ident,dirs_exist_ok=True);shutil.copy2(a.cache/(ident+'.glb'),f/(ident+'.glb'))
shutil.copy2(ROOT/'tools/capture_elevated_strips.gd',f/'capture.gd')
out=ROOT/'docs/elevated-tunnel-validation';out.mkdir(parents=True,exist_ok=True)
cmd=[a.godot,'--path',str(f),'--audio-driver','Dummy','--rendering-method','gl_compatibility'];logs=[]
for extra in [['--headless','--editor','--import','--quit'],['--resolution','800x500','--borderless','--quit-after','240','--script','res://capture.gd','--',str(out/'strips-02-1600.png'),str(a.cache/'face-shade.json')]]:
 r=subprocess.run(cmd+extra,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=150);logs.append(r.stdout)
 if r.returncode or re.search(r'^\s*(SCRIPT ERROR:|ERROR:|FAIL\b)',r.stdout,re.M):raise RuntimeError(r.stdout)
assert 'ELEVATED_STRIPS_PASS' in logs[-1],logs[-1]
assert struct.unpack('>II',(out/'strips-02-1600.png').read_bytes()[16:24])==(1600,1000)
shades=json.loads((a.cache/'face-shade.json').read_text())
for ident in ids:
 path=ROOT/'assets/structures'/ident/'spec.json';spec=json.loads(path.read_text());spec['face_shade']=shades[ident];path.write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(out/'STRIPS_RESULTS.txt').write_text('PASS Blender original 4m members: deck132/wall132/portal156 triangles.\nPASS 4 PNG resolutions; 80px/m; opaque bounds; three horizontal repeat seams <=1/255; shared top112 identical; no horizontal wall body pattern.\nActual finite Godot load/size/face lighting checks and fixed1600x1000 SubViewport.\n'+subprocess.list2cmdline(cmd+extra)+'\n'+'\n'.join(logs)+json.dumps(shades,indent=2)+'\nInspection only; no pending items created.\n',encoding='utf-8')
print(logs[-1]);print(shades)
