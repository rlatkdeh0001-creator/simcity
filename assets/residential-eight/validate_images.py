"""Validate the eight requested assets and their sixteen transparent views."""
import json,hashlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parent
specs=json.loads((ROOT/'designs.json').read_text());groups={};manifest=[]
assert len(specs)==8 and len({s['id'] for s in specs})==8
for spec in specs:
 folder=ROOT/spec['id'];meta=json.loads((folder/'metadata.json').read_text())
 assert meta['occupied_storeys']==spec['floors'] and meta['footprint_cells']==[spec['size']]*2
 assert meta['category']==spec['category']
 hashes={}
 for name in ['building.png','reverse-review.png']:
  path=folder/name;im=Image.open(path);assert im.mode=='RGBA' and im.size==(900,1100)
  bounds=im.getchannel('A').getbbox();assert bounds and bounds[0]>0 and bounds[1]>0 and bounds[2]<900 and bounds[3]<1100,(spec['id'],name,bounds)
  hashes[name]=hashlib.sha256(path.read_bytes()).hexdigest()
 half=spec['size']*2;low,high=meta['vertex_bounds_m'];assert low[0]>=-half-.001 and low[1]>=-half-.001 and high[0]<=half+.001 and high[1]<=half+.001
 group=(spec['category'],spec['size']);groups[group]=groups.get(group,0)+1
 manifest.append({'id':spec['id'],'name':spec['name'],'category':spec['category'],'footprint':[spec['size']]*2,'storeys':spec['floors'],'source':f'{spec["id"]}/building.blend','texture':f'{spec["id"]}/building.png','sha256':hashes,'status':'concept-not-registered'})
 print('PASS images',spec['id'])
assert len(groups)==4 and all(n==2 for n in groups.values())
(ROOT/'asset-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('PASS exact requested 2+2+2+2 grouping, 8 assets, 16 unclipped RGBA images')
