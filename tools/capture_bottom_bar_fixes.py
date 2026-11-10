"""Capture approved C-card/focus/pause fixes, preserving earlier A2 evidence."""
import argparse,hashlib,json,runpy,struct
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/bottom-bar-v2-validation/fix-c'
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);a=p.parse_args()
 OUT.mkdir(parents=True,exist_ok=True)
 v=runpy.run_path(str(ROOT/'tools/validate_bottom_ui_main.py'),run_name='capture_fixes')
 execute=v['execute'];execute.__globals__['OUT']=OUT
 rows=[]
 shots=[('fix-police-1920','1920x1080','police'),('fix-health-1920','1920x1080','health'),('fix-park-1920','1920x1080','park'),('fix-police-1280','1280x820','police'),('fix-police-960','960x640','police'),('fix-default-1920','1920x1080','')]
 for name,res,tab in shots:
  path=OUT/(name+'.png');path.unlink(missing_ok=True);path.with_suffix('.state.json').unlink(missing_ok=True)
  command=[a.godot,'--path',str(ROOT/'cities_do'),'--audio-driver','Dummy','--rendering-method','gl_compatibility','--resolution',res,'--position','0,0','--fullscreen' if res=='1920x1080' else '--borderless','--','--capture-bottom-ui='+str(path)]
  if tab:command+=['--bottom-tab='+tab]
  result=execute(name,command,60)
  if path.exists():
   data=path.read_bytes();state=json.loads(path.with_suffix('.state.json').read_text(encoding='utf-8'))
   result.update(png_size=list(struct.unpack('>II',data[16:24])),sha256=hashlib.sha256(data).hexdigest(),path=str(path),state=state)
   result['passed']=result['passed'] and result['png_size']==list(map(int,res.split('x'))) and state['tab']==tab
  else:result['passed']=False
  rows.append(result);(OUT/'captures.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 if not all(r['passed'] for r in rows):return 1
 left=ROOT/'docs/concepts/bottom-ui-v2/fix-C.png';right=OUT/'fix-police-1920.png'
 images=[Image.open(path).convert('RGB') for path in [left,right]]
 assert all(image.size==(1920,1080) for image in images)
 font=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',24)
 canvas=Image.new('RGB',(3840,1124),'#102633');draw=ImageDraw.Draw(canvas)
 draw.text((18,4),'승인 시안 fix-C',font=font,fill='white');draw.text((1938,4),'실제 Godot · C형 썸네일 / 선택과 키보드 포커스 구분',font=font,fill='white')
 for x,image in zip([0,1920],images):canvas.paste(image,(x,44))
 path=OUT/'fix-C-comparison.png';canvas.save(path)
 (OUT/'comparison.json').write_text(json.dumps({'resized':False,'sources':[{'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in [left,right]],'output':str(path),'size':list(canvas.size),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 return 0
if __name__=='__main__':raise SystemExit(main())
