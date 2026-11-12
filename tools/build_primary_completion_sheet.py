"""Lay out original Blender PNGs into review sheets without editing the asset images."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
ROOT=Path(__file__).resolve().parents[1];font=ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',24);out=ROOT/'docs/primary-industry/completion'
sets=[('mains',['primary-farm-vegetable-01','primary-farm-livestock-01','primary-forestry-01','primary-mine-iron-01','primary-mine-coal-01','primary-oil-01','primary-mine-uranium-01','primary-fishing-01'],4,2,'building.png'),('tiles',['primary-tile-mine-iron-01','primary-tile-mine-coal-01','primary-tile-pasture-01','primary-tile-pasture-02','primary-tile-pasture-03'],3,2,'tile.png')]
for name,ids,columns,rows,filename in sets:
 canvas=Image.new('RGB',(columns*400,rows*530),'#e9ebe3');draw=ImageDraw.Draw(canvas)
 for i,ident in enumerate(ids):
  p=ROOT/'assets/primary-industry'/ident;m=json.loads((p/'metadata.json').read_text());x=(i%columns)*400;y=(i//columns)*530
  draw.rounded_rectangle((x+5,y+5,x+395,y+525),12,fill='#f8f8f1')
  with Image.open(p/filename) as im:
   im=im.convert('RGBA');im.thumbnail((390,465),Image.Resampling.LANCZOS);canvas.paste(im,(x+5+(390-im.width)//2,y+5),im)
  draw.text((x+14,y+470),m['name'],font=font,fill='#34413e');draw.text((x+14,y+500),f"{m['triangles']:,} tris",font=font,fill='#57645b')
 canvas.save(out/(name+'-overview.png'))
print('Actual source PNG review sheets built')
