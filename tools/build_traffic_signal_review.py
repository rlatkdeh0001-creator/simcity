"""Arrange source renders; validate real individual-state pixels and PNG frames."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/traffic-signals';font=ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',24)
ids=['traffic-signal-post-01','traffic-signal-arm-01'];names=['lamp_red','lamp_yellow','lamp_left_arrow','lamp_green'];records=[];canvas=Image.new('RGB',(1100,1200),'#ebece5');draw=ImageDraw.Draw(canvas)
for row,ident in enumerate(ids):
 for col,state in enumerate(['off','on']):
  path=ROOT/'assets/street-furniture'/ident/('preview-'+state+'.png');x=550*col;y=600*row
  with Image.open(path) as im:
   im.load();assert im.mode=='RGBA' and im.size==(1100,1100);a=im.getchannel('A');box=a.getbbox();assert box and min(box[:2])>0 and box[2]<1100 and box[3]<1100 and a.getextrema()[0]==0
   records.append(dict(path=str(path.relative_to(ROOT)),size_px=list(im.size),alpha_bbox_px=box,sha256=hashlib.sha256(path.read_bytes()).hexdigest()));thumb=im.copy();thumb.thumbnail((530,530),Image.Resampling.LANCZOS)
   draw.rounded_rectangle((x+5,y+5,x+545,y+595),12,fill='#f8f8f1');canvas.paste(thumb,(x+10,y+10),thumb)
  label=('기둥형' if row==0 else '가로대형')+(' · 전체 꺼짐' if col==0 else ' · 전체 켜짐')
  draw.text((x+20,y+550),label,font=font,fill='#34413e')
canvas.save(OUT/'overview.png')
probes=json.loads((OUT/'state-image-probes.json').read_text());states=[];strip=Image.new('RGB',(900,1360),'#f4f5ee');d=ImageDraw.Draw(strip)
for i,name in enumerate(names):
 path=OUT/(name+'-only.png')
 with Image.open(path) as im:
  im.load();assert im.mode=='RGBA' and im.size==(900,300)
  rgb={n:list(im.getpixel(tuple(probes[n]))[:3]) for n in names};r,g,b=rgb[name]
  color_ok=(r>150 and r>g*1.5 and r>b*1.5) if i==0 else ((r>150 and g>150 and b<150) if i==1 else (g>150 and g>r*1.3 and g>b*1.3))
  inactive_ok=all(max(rgb[n])<100 for n in names if n!=name);assert color_ok and inactive_ok,(name,rgb)
  strip.paste(im,(0,i*340),im);d.text((18,i*340+302),['빨강 단독','노랑 단독','좌회전 화살표 단독','초록 단독'][i],font=font,fill='#34413e')
  states.append(dict(active=name,probe_rgb=rgb,active_color_correct=color_ok,other_three_dark=inactive_ok))
strip.save(OUT/'individual-states.png');(OUT/'image-validation.json').write_text(json.dumps(dict(previews=records,individual_states=states,passed=True),ensure_ascii=False,indent=2)+'\n')
print('Four source PNGs passed; four real single-lamp renders have correct active colors and three dark neighbors.')
