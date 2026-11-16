"""Reproduce an adult-head batch in fresh output, or verify existing parts read-only.
Use the bundled Blender Python3.11 and process-local approved Pillow PYTHONPATH.
"""
from pathlib import Path
import argparse,json,os,runpy,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]


def main():
 ap=argparse.ArgumentParser();ap.add_argument('--phase',choices=['all','verify-existing','capture','source-smoke'],default='all');ap.add_argument('--blender');ap.add_argument('--godot',required=True);ap.add_argument('--cache',type=Path,required=True);ap.add_argument('--output-root',type=Path,default=ROOT);ap.add_argument('--resume',action='store_true');args=ap.parse_args()
 if args.phase in ['all','verify-existing'] and not args.blender:ap.error('--blender is required for source/rig work')
 cache=args.cache.resolve();asset_root=args.output_root.resolve();cache.mkdir(parents=True,exist_ok=True)
 env=os.environ.copy();env['CITIZEN_ASSET_ROOT']=str(asset_root)
 def call(argv,required=None):
  print('RUN',subprocess.list2cmdline([str(x) for x in argv]),flush=True)
  result=subprocess.run([str(x) for x in argv],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace')
  print(result.stdout,flush=True);result.check_returncode()
  if any(line.startswith(('SCRIPT ERROR:','ERROR:','Error:','FAIL','Traceback')) for line in result.stdout.splitlines()):raise RuntimeError('Runtime reported an error despite process status0')
  if required and required not in result.stdout:raise RuntimeError('Missing runtime success marker: '+required)
 blender=[args.blender,'-b','--factory-startup','-t','2','--python-exit-code','1'] if args.blender else []
 if args.phase=='all':
  cmd=blender+['-P',ROOT/'tools/build_citizen_adult_heads.py','--','--cache',cache,'--output-root',asset_root]
  if args.resume:cmd.append('--resume')
  call(cmd)
 if args.phase in ['all','verify-existing']:
  call([sys.executable,ROOT/'tools/finalize_citizen_adult_heads.py','prepare','--cache',cache])
  call(blender+['-P',ROOT/'tools/verify_citizen_adult_head_rigs.py','--','--cache',cache])
  call([sys.executable,ROOT/'tools/finalize_citizen_adult_heads.py','verify','--cache',cache])
 doc=asset_root/'docs/citizens-full/adult-heads';samples=doc/'preview-samples.json'
 if args.phase=='capture':
  # Refresh only the inspection sheet after display/filter changes; do not re-render models or re-run audits.
  previous=os.environ.get('CITIZEN_ASSET_ROOT');os.environ['CITIZEN_ASSET_ROOT']=str(asset_root)
  module=runpy.run_path(str(ROOT/'tools/finalize_citizen_adult_heads.py'),run_name='asset_preview_library')
  module['batch_preview'](json.loads((cache/'run.json').read_text(encoding='utf-8'))['parts'])
  if previous is None:os.environ.pop('CITIZEN_ASSET_ROOT',None)
  else:os.environ['CITIZEN_ASSET_ROOT']=previous
 fixture=cache/'godot-check';(fixture/'core').mkdir(parents=True,exist_ok=True)
 ref=json.loads(samples.read_text(encoding='utf-8'))['game_scale_ref']
 pinned=ROOT/'tools/citizen_demo_reference'
 assert ref==json.loads((pinned/'reference.json').read_text(encoding='utf-8'))['source_commit']
 for filename in ['citizen_demo_sprites.gd','citizen_demo.gdshader']:
  shutil.copy2(pinned/filename,fixture/'core'/filename)
 (fixture/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Citizen asset read-only fixture"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
 shutil.copy2(ROOT/'tools/verify_citizen_hair_glb.gd',fixture/'verify_glb.gd')
 call([args.godot,'--headless','--path',fixture,'--quit-after','3','--script','res://verify_glb.gd','--',asset_root/'assets/citizens/full-set/adult-heads/catalog.json'],required='CITIZEN_HAIR_GLB_LOAD_OK')
 if args.phase=='source-smoke':return
 shutil.copy2(ROOT/'tools/capture_citizen_adult_heads.gd',fixture/'capture.gd')
 call([args.godot,'--path',fixture,'--rendering-method','gl_compatibility','--script','res://capture.gd','--','--run',cache/'run.json','--samples',samples,'--capture',doc/'godot-combinations.png'],required='CITIZEN_HEADS_GODOT_OK')
 print('ADULT_HEAD_PIPELINE_OK',doc,flush=True)
if __name__=='__main__':main()
