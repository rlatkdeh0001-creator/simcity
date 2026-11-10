"""Place approved mockup and untouched real Godot capture side by side.
Outputs are labeled comparisons, never replacements for original captures.
"""
import hashlib,json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/bottom-bar-v2-validation'

def main():
 left=ROOT/'docs/concepts/bottom-ui-v2/mockup-A2.png'
 right=OUT/'main-default-1920.png'
 font=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',24)
 images=[Image.open(p).convert('RGB') for p in [left,right]]
 assert all(image.size==(1920,1080) for image in images)
 manifest={'sources':[{'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in [left,right]],'resized':False,'raw_capture_preserved':True,'comparisons':[]}
 for name,crop in [('A2-comparison.png',False),('A2-hud-comparison.png',True)]:
  height=196 if crop else 1080
  canvas=Image.new('RGB',(3840,height+44),'#102633')
  draw=ImageDraw.Draw(canvas)
  draw.text((18,4),'승인 시안 A2 · 예시 값 (실제 게임 수치 아님)',font=font,fill='#e4eef1')
  draw.text((1938,4),'실제 Godot 본게임 · 실제 초기 값 / 미구현 값은 —',font=font,fill='#e4eef1')
  for x,image in zip([0,1920],images):
   if crop:image=image.crop((0,884,1920,1080))
   canvas.paste(image,(x,44))
  path=OUT/name;canvas.save(path)
  manifest['comparisons'].append({'path':str(path),'size':list(canvas.size),'hud_crop_only':crop,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
 (OUT/'comparison.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(manifest,ensure_ascii=True))
if __name__=='__main__':main()
