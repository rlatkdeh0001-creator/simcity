"""Capture real bottom-bar v2 viewports. Never resize acceptance captures."""
import argparse,hashlib,json,runpy,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/bottom-bar-v2-validation'
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--godot',required=True)
 p.add_argument('--only',nargs='*')
 a=p.parse_args()
 OUT.mkdir(parents=True,exist_ok=True)
 v=runpy.run_path(str(ROOT/'tools/validate_bottom_ui_main.py'),run_name='capture_delivery')
 execute=v['execute'];execute.__globals__['OUT']=OUT
 shots=[('main-default-1920','1920x1080','',False),('main-police-1920','1920x1080','police',False),('main-zoning-1920','1920x1080','build',False),('main-police-1280','1280x820','police',False),('main-police-960','960x640','police',False),('review-fixture-1920','1920x1080','',True)]
 if a.only:shots=[s for s in shots if s[0] in a.only]
 assert shots,'No requested capture jobs matched'
 report=[]
 for name,resolution,tab,fixture in shots:
  path=OUT/(name+'.png')
  path.unlink(missing_ok=True)
  path.with_suffix('.state.json').unlink(missing_ok=True)
  command=[a.godot,'--path',str(ROOT/'cities_do'),'--audio-driver','Dummy','--rendering-method','gl_compatibility','--resolution',resolution,'--position','0,0','--fullscreen' if resolution=='1920x1080' else '--borderless']
  if fixture:command+=['res://bottom_ui_preview.tscn']
  command+=['--','--capture-bottom-ui='+str(path)]
  if tab:command+=['--bottom-tab='+tab]
  result=execute(name,command,60)
  if path.exists():
   data=path.read_bytes();assert data[:8]==b'\x89PNG\r\n\x1a\n'
   result.update(png_size=list(struct.unpack('>II',data[16:24])),sha256=hashlib.sha256(data).hexdigest(),path=str(path),fixture=fixture)
   result['passed']=result['passed'] and result['png_size']==list(map(int,resolution.split('x')))
   state=json.loads(path.with_suffix('.state.json').read_text(encoding='utf-8'))
   result['state']=state
   result['passed']=result['passed'] and state['tab']==(tab or ('power' if fixture else ''))
  else:result['passed']=False
  report.append(result)
  (OUT/('captures-selected.json' if a.only else 'captures.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 return 0 if all(r['passed'] for r in report) else 1
if __name__=='__main__':raise SystemExit(main())
