"""Capture approved deterministic lot policies through actual game APIs and HUD input."""
import argparse,hashlib,json,runpy,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/growth-appearance-validation/lot-rules'
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);a=p.parse_args()
 helper=runpy.run_path(str(ROOT/'tools/validate_bottom_ui_main.py'),run_name='lot_capture_helpers');execute=helper['execute'];execute.__globals__['OUT']=OUT
 rows=[]
 for scenario,name,lot,stage in [('wide','initial-4x4-priority-1920',4,1),('narrow','initial-2x2-fallback-1920',2,1),('stage5','stage5-8x8-expansion-1920',8,5)]:
  path=OUT/(name+'.png');path.unlink(missing_ok=True)
  row=execute(name,[a.godot,'--path',str(ROOT/'cities_do'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1920x1080','--position','0,0','--fullscreen','--script',str(ROOT/'tools/capture_lot_rules.gd'),'--',f'--case={scenario}','--evidence='+str(path)],90)
  if path.exists():
   data=path.read_bytes();state=json.loads(path.with_suffix('.state.json').read_text(encoding='utf-8'));size=list(struct.unpack('>II',data[16:24]))
   row.update(path=str(path),size=size,sha256=hashlib.sha256(data).hexdigest(),state=state)
   row['passed']=row['passed'] and size==[1920,1080] and state['funds']==50000 and len(state['buildings'])==3 and all(b['stage']==stage and b['size']==lot and bool(b['asset_id']) for b in state['buildings']) and len(state['growth_button_actions'])==3*(stage-1)
  else:row['passed']=False
  rows.append(row);(OUT/'captures.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 return 0 if all(r['passed'] for r in rows) else 1
if __name__=='__main__':raise SystemExit(main())
