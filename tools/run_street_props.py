"""Finite original/GLB/sprite inspection, isolated from the C# game.
python tools/run_street_props.py <id> --blender <exe> --godot <exe> --cache <scratch>
Pinned reference is read with git show; never switch or save other worktrees.
"""
import argparse,json,re,shutil,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('ident',choices=['rail-crossing-signal-01','ped-signal-01']);p.add_argument('--blender',required=True);p.add_argument('--godot',required=True);p.add_argument('--cache',type=Path,required=True);a=p.parse_args()
a.cache.mkdir(parents=True,exist_ok=True);f=a.cache/a.ident;f.mkdir(parents=True,exist_ok=True)
ref=a.cache/'vehicle-signal.glb'
if not ref.exists():
 blend=a.cache/'vehicle-signal.blend';blend.write_bytes(subprocess.check_output(['git','-C',str(ROOT),'show','edda3f3:assets/street-furniture/traffic-signal-post-01/signal.blend']))
 expr="import bpy; bpy.ops.object.select_all(action='DESELECT'); [(o.select_set(True)) for o in bpy.context.scene.objects if o.type=='MESH']; bpy.ops.export_scene.gltf(filepath="+repr(str(ref))+",export_format='GLB',use_selection=True)"
 result=subprocess.run([a.blender,'-b',str(blend),'--python-expr',expr],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=120)
 assert result.returncode==0 and ref.exists(),result.stdout
(f/'project.godot').write_text('[application]\nconfig/name="Street props inspection"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[display]\nwindow/size/viewport_width=1600\nwindow/size/viewport_height=1000\n',encoding='utf-8')
runtime=ROOT/'cities_do/assets/street_furniture';src=ROOT/'assets/street-furniture'/a.ident
for source,dest in [(runtime/(a.ident+'.glb'),'prop.glb'),(src/'spec.json','spec.json'),(ref,'vehicle-signal.glb'),(ROOT/'cities_do/assets/vehicles/car-sedan-03.glb','car.glb'),(ROOT/'tools/capture_street_props.gd','capture.gd')]:shutil.copy2(source,f/dest)
shutil.copytree(runtime/'sprites'/a.ident,f/'sprites',dirs_exist_ok=True)
manifest=json.loads((runtime/'render_manifest.json').read_text());entry=manifest['assets'][a.ident]
files=list((runtime/'sprites'/a.ident).glob('*.png'));assert len(files)==24
assert len(entry['sprites'])==24 and entry['pixels_per_metre']>=24 and manifest['camera_elevation_degrees']==30
assert all(struct.unpack('>II',x.read_bytes()[16:24])==(256,256) for x in files)
assert not entry['arm_in_sprites'];assert {x['azimuth_degrees'] for x in entry['sprites']}==set(range(0,360,45))
out=ROOT/'docs/street-props-validation';out.mkdir(parents=True,exist_ok=True);image=out/(a.ident+'-1600.png')
if image.exists():image.unlink()
base=[a.godot,'--path',str(f),'--audio-driver','Dummy','--rendering-method','gl_compatibility'];logs=[]
for extra in [['--headless','--editor','--import','--quit'],['--resolution','1600x1000','--borderless','--quit-after','360','--script','res://capture.gd','--',str(image),a.ident]]:
 result=subprocess.run(base+extra,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=150);logs.append(result.stdout)
 if result.returncode or re.search(r'^\s*(SCRIPT ERROR:|ERROR:|FAIL\b)',result.stdout,re.M):raise RuntimeError(result.stdout)
assert 'STREET_PROP_GRAPHICAL_PASS' in logs[-1],logs[-1]
assert struct.unpack('>II',image.read_bytes()[16:24])==(1600,1000)
spec=json.loads((src/'spec.json').read_text(encoding='utf-8'))
text='inspection_only; original geometry, Blender4.3.2 + Godot4.6.3 GL Compatibility\nMeasured static dimensions XYZ metres: '+str(spec['measured_dimensions_m'])+'; triangles (arm excluded): '+str(spec['triangles'])+'; all geometry triangles: '+str(spec['triangles_including_arm'])+'\nSource saved/reopened all lamps off. Arm lowered, pivot (-0.30,-0.05,1.0), omitted from sprites (crossing only).\n24 real Blender RGBA sprites,8 azimuths x3 states, elevation30,48px/m; per-sprite base-origin pixels recorded.\nGraphical command: '+subprocess.list2cmdline(base+extra)+'\n'+logs[-1]+'\nReference: car-sedan-03 existing GLB; vehicle pole signal exported read-only from edda3f3 .blend.\nCatalog absent: not created (request section2). No gameplay code, placement, timing, sound, pricing, push or main.\n'
(out/(a.ident+'-RESULTS.txt')).write_text(text,encoding='utf-8');print(text)
