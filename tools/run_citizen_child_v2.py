"""Reproduce/verify childv2 without rewritingv1 or approved adults."""
from pathlib import Path
import argparse,json,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]

def main():
 p=argparse.ArgumentParser();p.add_argument('--phase',choices=['all','finish','verify-existing'],default='all');p.add_argument('--cache',type=Path,required=True);p.add_argument('--blender',required=True);p.add_argument('--godot',required=True);a=p.parse_args();cache=a.cache;cache.mkdir(parents=True,exist_ok=True)
 def call(argv,marker):
  r=subprocess.run([str(x) for x in argv],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace');print(r.stdout,flush=True);r.check_returncode();assert marker in r.stdout;assert not any(s.startswith(('SCRIPT ERROR:','ERROR:','Error:','Traceback','FAIL')) for s in r.stdout.splitlines())
 b=[a.blender,'-b','--factory-startup','-t','2','--python-exit-code','1']
 if a.phase=='all':call(b+['-P',ROOT/'tools/build_citizen_child_v2.py','--','--cache',cache],'V2_BUILD_DONE')
 verify=ROOT/'tools/verify_citizen_child_v2.py'
 call([sys.executable,verify,'--phase','prepare','--cache',cache],'V2_PREPARED')
 call(b+['-P',verify,'--','--phase','rig','--cache',cache],'BATCH_RIG_OK')
 call([sys.executable,verify,'--phase','check','--cache',cache],'BATCH_VERIFIED')
 call([sys.executable,verify,'--phase','combinations','--cache',cache],'ALL_COMBINATIONS_OK')
 call([sys.executable,verify,'--phase','preview','--cache',cache],'V2_COMPARISON_READY')
 fixture=cache/'godot-check';(fixture/'core').mkdir(parents=True,exist_ok=True)
 for n in ['citizen_demo_sprites.gd','citizen_demo.gdshader']:shutil.copy2(ROOT/'tools/citizen_demo_reference'/n,fixture/'core'/n)
 (fixture/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Childv2 same-scale inspection"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
 shutil.copy2(ROOT/'tools/verify_citizen_child_v2_glb.gd',fixture/'verify.gd');shutil.copy2(ROOT/'tools/capture_citizen_child_v2.gd',fixture/'capture.gd')
 call([a.godot,'--headless','--path',fixture,'--quit-after','3','--script','res://verify.gd','--',ROOT/'assets/citizens/full-set/child-v2/catalog.json'],'CITIZEN_REMAINING_GLB_OK')
 doc=ROOT/'docs/citizens-full/child-v2'
 call([a.godot,'--path',fixture,'--rendering-method','gl_compatibility','--script','res://capture.gd','--','--run',cache/'preview-run.json','--samples',doc/'preview-samples.json','--capture',doc/'adult-comparison.png'],'CHILD_V2_COMPARISON_OK')
 rows=json.loads((ROOT/'assets/citizens/full-set/child-v2/catalog.json').read_text())['parts'];m=json.loads((ROOT/rows[0]['source']/'spec.json').read_text());results=json.loads((doc/'validation-results.json').read_text());heights=[r['height_m'] for r in results['results']]
 stats=dict(height_m_range=[min(heights),max(heights)],skull_height_m=m['skull_height_m'],skull_width_m=m['skull_width_m'],skull_depth_m=m['skull_depth_m'],heads_tall=min(heights)/m['skull_height_m'],body_scale=m['body_scale'],limb_radial_factor=1.12,shoulder_centre_scale=.56)
 (doc/'proportions.json').write_text(json.dumps(stats,indent=2)+'\n');print('CHILD_V2_VERIFIED',json.dumps(stats),flush=True)
if __name__=='__main__':main()
