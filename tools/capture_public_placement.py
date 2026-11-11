"""Capture actual approved public placement cards, world input, power and cash rejection."""
import argparse,hashlib,json,runpy,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/1b-public-placement-validation'
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);p.add_argument('--only',choices=['services','power','insufficient']);a=p.parse_args()
 helper=runpy.run_path(str(ROOT/'tools/validate_bottom_ui_main.py'),run_name='public_capture_helpers');execute=helper['execute'];execute.__globals__['OUT']=OUT
 rows=json.loads((OUT/'captures.json').read_text(encoding='utf-8')) if a.only and (OUT/'captures.json').exists() else []
 for scenario,name,count in [('services','services-placed-1920',4),('power','power-wire-supply-1920',1),('insufficient','insufficient-funds-1920',2)]:
  if a.only and scenario!=a.only:continue
  path=OUT/(name+'.png');path.unlink(missing_ok=True)
  row=execute(name,[a.godot,'--path',str(ROOT/'cities_do'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1920x1080','--position','0,0','--fullscreen','--script',str(ROOT/'tools/capture_public_placement.gd'),'--',f'--case={scenario}','--evidence='+str(path)],100)
  if path.exists():
   data=path.read_bytes();state=json.loads(path.with_suffix('.state.json').read_text(encoding='utf-8'));size=list(struct.unpack('>II',data[16:24]))
   row.update(path=str(path),size=size,sha256=hashlib.sha256(data).hexdigest(),state=state)
   row['passed']=row['passed'] and size==[1920,1080] and len(state['public_lots'])==count
   if scenario=='power':row['passed']=row['passed'] and state['network']['consumer']['powered'] and state['network']['wire_count']>0
   if scenario=='insufficient':row['passed']=row['passed'] and state['ghost']['code']=='insufficient_funds' and not state['ghost']['ok']
  else:row['passed']=False
  rows=[r for r in rows if r['name']!=name]+[row];(OUT/'captures.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 return 0 if all(row['passed'] for row in rows) else 1
if __name__=='__main__':raise SystemExit(main())
