"""Derive compact C-card previews from existing PNGs; never modify source art."""
import hashlib,json
from pathlib import Path
from PIL import Image,ImageDraw,ImageOps
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'cities_do/assets/ui/thumbnails'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 DEST.mkdir(parents=True,exist_ok=True)
 rows=[]
 for kind in ['services','facilities']:
  rows.extend(json.loads((ROOT/f'cities_do/assets/{kind}/catalog.json').read_text(encoding='utf-8'))['facilities'])
 report={}
 for e in rows:
  source=ROOT/'cities_do'/e['preview'].removeprefix('res://')
  original=digest(source)
  image=Image.open(source).convert('RGBA')
  bounds=image.getchannel('A').getbbox()
  assert bounds,(e['id'],'empty source')
  x0,y0,x1,y1=bounds
  padx=max(2,round((x1-x0)*.05));pady=max(2,round((y1-y0)*.05))
  bounds=(max(0,x0-padx),max(0,y0-pady),min(image.width,x1+padx),min(image.height,y1+pady))
  image=ImageOps.fit(image.crop(bounds),(256,192),method=Image.Resampling.LANCZOS,centering=(.5,.5))
  background=Image.new('RGBA',image.size,'#233b45');background.alpha_composite(image)
  mask=Image.new('L',image.size,0);ImageDraw.Draw(mask).rounded_rectangle((0,0,255,191),radius=14,fill=255)
  background.putalpha(mask)
  target=DEST/(e['id']+'.png');background.save(target)
  assert digest(source)==original
  report[e['id']]={'name':e['name'],'source':e['preview'],'source_sha256':original,'thumbnail':'res://assets/ui/thumbnails/'+target.name,'sha256':digest(target),'size':[256,192],'source_crop':list(bounds),'aspect':'centered cover; no stretching','round_radius_px':14}
 (DEST/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print('DERIVED_THUMBNAILS',len(report),'SOURCES_UNCHANGED')
if __name__=='__main__':main()
