"""Review sheet only: arrange original Blender PNGs without changing asset images."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
ROOT=Path(__file__).resolve().parents[1]
ids=['vegetable-01','pasture-01','forestry-01','mine-iron-01','mine-coal-01','oil-01','oil-02','mine-uranium-01','fishing-01']
font=ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',25)
for variant in ['tile','tile-3x3']:
 sheet=Image.new('RGB',(1260,1440),'#ebece5');draw=ImageDraw.Draw(sheet)
 for i,short in enumerate(ids):
  p=ROOT/'assets/primary-industry'/('primary-tile-'+short);m=json.loads((p/'metadata.json').read_text());x=(i%3)*420;y=(i//3)*480
  draw.rounded_rectangle((x+7,y+7,x+413,y+473),12,fill='#f8f8f3')
  with Image.open(p/(variant+'.png')) as im:
   preview=im.convert('RGBA');preview.thumbnail((406,406),Image.Resampling.LANCZOS);sheet.paste(preview,(x+7,y+7),preview)
  draw.text((x+17,y+412),m['name'],font=font,fill='#34413e');draw.text((x+17,y+444),f"{m['triangles']} tris | 4 x 4 m",font=font,fill='#57635c')
 sheet.save(ROOT/'docs/primary-industry/work-tiles'/('overview'+('-3x3' if variant=='tile-3x3' else '')+'.png'))
print('Review sheets arrange actual source renders; original PNGs untouched.')
