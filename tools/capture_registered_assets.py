"""Actual viewport captures for thirty-asset registration; never resize evidence."""
import argparse,hashlib,json,runpy,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/register-30-assets-validation'
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--godot',required=True);args=parser.parse_args()
 helper=runpy.run_path(str(ROOT/'tools/validate_bottom_ui_main.py'),run_name='registered_capture_helpers')
 execute=helper['execute'];execute.__globals__['OUT']=OUT
 rows=[]
 for name,res,tab in [('power-1920','1920x1080','power'),('water-1920','1920x1080','water'),('environment-1920','1920x1080','environment'),('power-1280','1280x820','power')]:
  path=OUT/(name+'.png');path.unlink(missing_ok=True);path.with_suffix('.state.json').unlink(missing_ok=True)
  command=[args.godot,'--path',str(ROOT/'cities_do'),'--audio-driver','Dummy','--rendering-method','gl_compatibility','--resolution',res,'--position','0,0','--fullscreen' if res=='1920x1080' else '--borderless','--','--capture-bottom-ui='+str(path),'--bottom-tab='+tab]
  row=execute(name,command,60)
  if path.exists():
   data=path.read_bytes();state=json.loads(path.with_suffix('.state.json').read_text(encoding='utf-8'))
   row.update(png_size=list(struct.unpack('>II',data[16:24])),sha256=hashlib.sha256(data).hexdigest(),path=str(path),state=state)
   row['passed']=row['passed'] and row['png_size']==list(map(int,res.split('x'))) and state['tab']==tab and state['funds']==50000
  else:row['passed']=False
  rows.append(row);(OUT/'captures.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 return 0 if len(rows)==4 and all(row['passed'] for row in rows) else 1
if __name__=='__main__':raise SystemExit(main())
