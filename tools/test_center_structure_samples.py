"""Finite acceptance checks for inspection artifacts; no game imports."""
import json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
IDS=['center-flyover-sample-01','center-flyover-sample-02','center-underpass-sample-01']
def check():
 count=0
 cat=json.loads((ROOT/'cities_do/assets/facilities/catalog.json').read_text(encoding='utf-8'))['facilities']
 for ident,w,c in zip(IDS,[20,32,20],[7,14,7]):
  folder=ROOT/'assets/structures'/ident
  assert (folder/'spec.json').exists(),f'Missing authorized sample: {ident}'
  s=json.loads((folder/'spec.json').read_text(encoding='utf-8'))
  assert s['metres']==[304,w] and s['center_width_m']==c;count+=1
  assert s['ramp_length_m']==128 and s['road_grade']==10/128 and s['flat_length_m']==32;count+=1
  assert s['status']=='inspection_only' and s['kind']=='structure_sample' and not s['map_placement_implemented'];count+=1
  assert [v for v in cat if v['id']==ident]==[s];count+=1
  for key in ['model','preview']:
   p=ROOT/'cities_do'/s[key].removeprefix('res://');assert p.is_file() and p.stat().st_size>100;count+=1
  assert (folder/'sample.blend').is_file() and (folder/'build.py').is_file();count+=1
  if 'flyover' in ident:
   assert s['underdeck_clear_m']==8 and all(abs(p[0])>=16 for p in s['pier_positions_blender_m']);count+=1
   assert sorted(set(p[1] for p in s['pier_positions_blender_m']))==([-3.5,3.5] if c==14 else [0]);count+=1
  else:
   assert s['mouth_clear_road_m']==4.5 and s['portal_road_z_m']==-6 and s['closed_floor_and_cover_ends'];count+=1
 new=json.loads((ROOT/'assets/structures/viaduct-pier-01/v2/spec.json').read_text(encoding='utf-8'))
 old=json.loads((ROOT/'assets/structures/viaduct-pier-01/spec.json').read_text(encoding='utf-8'))
 assert old['twin_rule']=='W ≥ 16m: ±W/4' and new['twin_rule']=='W ≥ 14m: ±W/4';count+=1
 print(f'CENTER_ARTIFACTS_PASS checks={count}')
 return count
if __name__=='__main__':check()
