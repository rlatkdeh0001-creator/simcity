"""Reproducible finite batchII-IV pipeline; no live game modifications or automatic Git writes."""
from pathlib import Path
import argparse,json,os,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--batch',choices=['adult-tops','adult-bottoms','child'],required=True);ap.add_argument('--phase',choices=['all','finish','verify-existing'],default='all');ap.add_argument('--cache',type=Path,required=True);ap.add_argument('--blender',required=True);ap.add_argument('--godot',required=True);args=ap.parse_args();cache=args.cache.resolve();cache.mkdir(parents=True,exist_ok=True)
 def call(argv,marker=None):
  argv=[str(x) for x in argv];print('RUN',subprocess.list2cmdline(argv),flush=True);r=subprocess.run(argv,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,encoding='utf-8',errors='replace');print(r.stdout,flush=True);r.check_returncode()
  assert not any(l.startswith(('SCRIPT ERROR:','ERROR:','Error:','FAIL','Traceback')) for l in r.stdout.splitlines()),'Runtime error despite exit0'
  assert marker is None or marker in r.stdout,'Missing success marker '+str(marker)
 blender=[args.blender,'-b','--factory-startup','-t','2','--python-exit-code','1']
 if args.phase=='all':call(blender+['-P',ROOT/'tools/build_citizen_remaining.py','--','--batch',args.batch,'--cache',cache],marker='BATCH_RENDERED')
 pipeline=ROOT/'tools/citizen_remaining_pipeline.py';common=['--batch',args.batch,'--cache',cache]
 call([sys.executable,pipeline,'--phase','prepare']+common,marker='RESOLVED_STAGES')
 call(blender+['-P',pipeline,'--','--phase','rig']+common,marker='BATCH_RIG_OK')
 call([sys.executable,pipeline,'--phase','check']+common,marker='BATCH_VERIFIED')
 call([sys.executable,pipeline,'--phase','combinations']+common,marker='ALL_COMBINATIONS_OK')
 call([sys.executable,pipeline,'--phase','preview']+common,marker='PREVIEW_INPUTS_READY')
 fixture=cache/'godot-check';(fixture/'core').mkdir(parents=True,exist_ok=True)
 for name in ['citizen_demo_sprites.gd','citizen_demo.gdshader']:shutil.copy2(ROOT/'tools/citizen_demo_reference'/name,fixture/'core'/name)
 (fixture/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Citizen modular asset validation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
 shutil.copy2(ROOT/'tools/verify_citizen_remaining_glb.gd',fixture/'verify_glb.gd');shutil.copy2(ROOT/'tools/capture_citizen_remaining.gd',fixture/'capture.gd')
 call([args.godot,'--headless','--path',fixture,'--quit-after','3','--script','res://verify_glb.gd','--',ROOT/f'assets/citizens/full-set/{args.batch}/catalog.json'],marker='CITIZEN_REMAINING_GLB_OK')
 doc=ROOT/f'docs/citizens-full/{args.batch}'
 call([args.godot,'--path',fixture,'--rendering-method','gl_compatibility','--script','res://capture.gd','--','--run',cache/'preview-run.json','--samples',doc/'preview-samples.json','--capture',doc/'combinations.png'],marker='CITIZEN_PARTS_GODOT_OK')
 result=json.loads((doc/'validation-results.json').read_text());combinations=json.loads((doc/'combination-checks.json').read_text());parts=json.loads((ROOT/f'assets/citizens/full-set/{args.batch}/catalog.json').read_text())['parts']
 text=f'# {args.batch} — verified asset batch\n\n'
 text+=f"Parts: {result['part_count']}; additional base: {result['base_count']}; native PNG: {result['native_png_count']}. Rig checks: {result['rig_checks']}; sprite checks: {result['sprite_checks']}; mirror cases: {result['mirror_cases']}. All passed.\n\n"
 text+=f"All combinations: {combinations['complete_combinations']} ×25poses; minimum joint alpha {combinations['minimum_joint_alpha']}; minimum head/top gap {combinations['minimum_head_top_gap_m']:.5f}m. Evaluated waist vertices stay inside the common12-sided top envelope in all5poses.\n\n"
 text+='[Actual Godot combination sheet](combinations.png) / [validation](validation-results.json) / [all combinations](combination-checks.json) / [persistent12 IDs and tint palettes](preview-samples.json). Above: live game scale at zoom1; below: native1x and whole-character2x. Four gray layers,64x96/40px/m/foot(32,84),5stored directions+3RGBA/depth mirrors,Idle+Walk4,14named bones.\n\n'
 text+='Geometry authored directly in `tools/build_citizen_remaining.py`, reuse of original scripted pilot only. No external models/textures/generation APIs. Uniform uses adult body and ages12–17; child clothes are separate0–11 models. Optional bind GLBs loaded by actual Godot GLTFDocument with14bones and source-matching bounds; not3D animated gameplay. Live game code/population/fees untouched, no push/main.\n\n'
 if args.batch=='child':text+='Child has a distinct1.10m archetype: body/bone lengths and animation translations0.60×, head0.78× with moved centre for a proportionally larger head. Original adult validators remain unchanged; temporary child validators parameterize ONLY height1.10, waist overlap.042 and anatomical anchor positions. Alpha240/error1e-5/bone/material/foot/loop/camera rules are unchanged. Skin is still one head/neck/hands layer; no facial details.\n\n'
 text+='Source scripts and .blend are retained per part; published sources are never overwritten. `build.py` calls the central generator with a fixed batch/ID; supply explicit scratch `--cache` and a fresh output root inside this checkout for replay. The remaining pipeline uses the approved D:Pillow11.3.0 target and existing Blender4.3.2 Python3.11/NumPy1.24.3, with process-local PYTHONPATH only. Run `tools/run_citizen_remaining.py --batch '+args.batch+' --phase verify-existing --cache <agent-scratch> --blender <absolute-exe> --godot <absolute-exe>` with that Python to recheck existing PNGs without rerender.\n\n'
 text+='Economic proposal: appearance data has no independent construction/upkeep/production/capacity; no economic implementation. Review mode self-review; final evidence only, raw render/temp resolved views removed after delivery.\n'
 (doc/'README_KO.md').write_text(text,encoding='utf-8')
 print('REMAINING_BATCH_OK',args.batch,result['part_count'],flush=True)
if __name__=='__main__':main()
