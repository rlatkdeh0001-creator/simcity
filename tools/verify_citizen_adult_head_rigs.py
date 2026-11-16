"""Run unchanged pilot attachment/rig validators on resolved full-layer staging views.
blender -b --factory-startup -t 2 --python-exit-code 1 -P tools/verify_citizen_adult_head_rigs.py
No original or delivered .blend is saved by either validator.
"""
from pathlib import Path
import argparse,json,os,runpy,sys

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--cache',type=Path,required=True);args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 doc=json.loads((args.cache/'run.json').read_text(encoding='utf-8'));completed=[]
 for row in doc['parts']:
  stage=Path(row['stage']);tools=stage/'tools';sys.path.insert(0,str(tools))
  runpy.run_path(str(tools/'audit_citizen_projection.py'),run_name='__main__')
  runpy.run_path(str(tools/'verify_citizen_adult_pilot.py'),run_name='__main__')
  result=json.loads((stage/'docs/citizen-adult-pilot/rig-validation.json').read_text(encoding='utf-8'));assert result['passed']
  completed.append({'id':row['id'],'rig_check_count':len(result['checks']),'passed':True})
  (args.cache/'rig-progress.json').write_text(json.dumps(completed,indent=2)+'\n',encoding='utf-8')
  print('HEAD_RIG_VERIFIED',row['id'],len(result['checks']),flush=True)
 print('HEAD_RIG_BATCH_DONE',len(completed),flush=True)
if __name__=='__main__':main()
