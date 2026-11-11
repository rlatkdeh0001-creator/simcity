"""Capture actual existing HUD growth controls; never resize acceptance frames."""
import argparse,hashlib,json,runpy,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/growth-appearance-validation'
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);p.add_argument('--only',nargs='*');a=p.parse_args()
 helper=runpy.run_path(str(ROOT/'tools/validate_bottom_ui_main.py'),run_name='growth_capture_helpers');execute=helper['execute'];execute.__globals__['OUT']=OUT
 rows=[]
 for lot in [2,4]:
  for stage in [1,3,5]:
   name=f'lot-{lot}x{lot}-stage-{stage}-1920'
   if a.only and name not in a.only:continue
   path=OUT/(name+'.png');path.unlink(missing_ok=True);path.with_suffix('.state.json').unlink(missing_ok=True)
   command=[a.godot,'--path',str(ROOT/'cities_do'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1920x1080','--position','0,0','--fullscreen','--script',str(ROOT/'tools/capture_growth_appearance.gd'),'--',f'--lot={lot}',f'--stage={stage}','--evidence='+str(path)]
   row=execute(name,command,90)
   if path.exists():
    data=path.read_bytes();state=json.loads(path.with_suffix('.state.json').read_text(encoding='utf-8'))
    row.update(path=str(path),size=list(struct.unpack('>II',data[16:24])),sha256=hashlib.sha256(data).hexdigest(),state=state)
    row['passed']=row['passed'] and row['size']==[1920,1080] and state['funds']==50000 and len(state['buildings'])==3 and all(b['stage']==stage and b['lot']==lot and bool(b['asset_id']) for b in state['buildings'])
   else:row['passed']=False
   rows.append(row);(OUT/('captures-selected.json' if a.only else 'captures.json')).write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 return 0 if rows and all(r['passed'] for r in rows) else 1
if __name__=='__main__':raise SystemExit(main())
