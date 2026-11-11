"""Read source specifications and build the building/facility size index; no game edits."""
import csv,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/asset-sizes'
GROUPS=[('주거','assets/residential-growth','metadata.json'),('상업','assets/commercial-growth','metadata.json'),('공업','assets/industrial-growth','metadata.json'),('주거','assets/mansion-study','metadata.json'),('주거','assets/residential-eight','metadata.json'),('상업','assets/commercial-study','metadata.json'),('공업','assets/industrial-study','metadata.json'),('발전','assets/power-study','metadata.json'),('상하수도','assets/water-study','metadata.json'),('쓰레기','assets/waste-study','metadata.json'),('소방','assets/fire-study','metadata.json'),('경찰','assets/police-study','metadata.json'),('교정','assets/prison-study','metadata.json'),('의료','assets/medical-study','metadata.json'),('교육','assets/education-study','metadata.json'),('공원·주차','assets/facilities','spec.json'),('기타 공공시설','assets/service-facilities','spec.json')]
registered={}
for file,key in [('cities_do/assets/buildings/catalog.json','buildings'),('cities_do/assets/services/catalog.json','facilities'),('cities_do/assets/facilities/catalog.json','facilities')]:
 doc=json.loads((ROOT/file).read_text())
 for e in doc.get(key,[]):registered[e['id']]=e
rows=[]
for group,folder,name in GROUPS:
 for path in sorted((ROOT/folder).glob('*/'+name)):
  d=json.loads(path.read_text());ident=d.get('id',d.get('asset_id'));assert ident
  current=registered.get(ident,{})
  assert d.get('cell_meters',4)==4,ident
  label=d.get('name',current.get('name',ident))
  size=d.get('footprint_cells') if 'footprint_cells' in d else [d['width'],d['depth']]
  if size is not None:
   assert len(size)==2 and all(isinstance(v,(int,float)) and int(v)==v and v>0 for v in size),ident
   size=[int(v) for v in size]
   if 'footprint' in current:assert size==current['footprint'],ident
   if 'width' in current:assert size==[current['width'],current['depth']],ident
  status={'draft':'시안 규격','user-specified':'사용자 지정'}.get(d.get('footprint_status'),'원본 규격')
  if size is None:status='가변 길이 · 고정 필지 없음'
  rows.append({'group':group,'id':ident,'name':label,'footprint_cells':size,'lot_metres':None if size is None else [v*4 for v in size],'dimension_status':status,'spec_file':path.relative_to(ROOT).as_posix(),'spec_field':'footprint_cells' if 'footprint_cells' in d else 'width/depth'})
assert len(rows)==len({e['id'] for e in rows})
assert not set(registered).difference(e['id'] for e in rows), 'Registered asset missing source specification'
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'sizes.json').write_text(json.dumps({'cell_metres':4,'assets':rows},ensure_ascii=False,indent=2)+'\n')
with (OUT/'sizes.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.writer(f);w.writerow(['분류','이름','ID','가로칸','세로칸','가로m','세로m','크기상태','규격파일','규격필드'])
 for e in rows:w.writerow([e['group'],e['name'],e['id'],*(e['footprint_cells'] or ['가변','가변']),*(e['lot_metres'] or ['가변','가변']),e['dimension_status'],e['spec_file'],e['spec_field']])
lines=['# 건물·시설 크기표','', '1칸=4m. **2×2=8×8m, 4×4=16×16m, 8×8=32×32m**다. 크기는 건물 본체가 아닌 건물이 차지하는 부지 기준이다.','', '원본 규격은 각 폴더의 `metadata.json` → `footprint_cells`, 공원·주차·화장터는 `spec.json` → `width`/`depth`에 있다.','게임 등록 크기는 `cities_do/assets/buildings/catalog.json`의 `footprint`, services/facilities 카탈로그의 `width`/`depth`에도 있다.','[CSV 내려받기/Excel용](sizes.csv) · [JSON](sizes.json)','', '주거·상업·공업 일반 건물 부지는 2×2·4×4·8×8뿐이다(8×8은 성장 5단계 대형 전용). 6×6은 소방서·경찰서·병원 등 직접 배치 서비스 건물의 사용자 확정 크기다. 2×4·4×8 주차장은 원본 값 그대로.','수력발전댐은 사용자가 길이를 정하므로 고정 칸 수가 없다. 시안의 48m 댐 길이나 배경판 60×32m를 고정 필지로 쓰지 않는다.','이 표는 규격 조회용이며 런타임 로더가 아니다. 크기를 수정할 때 원본·실제 모델·게임 카탈로그를 함께 맞춰야 한다.','',f'총 {len(rows)}종. 과거 archive와 차량은 중복 집계하지 않았다.','']
for group,_,_ in GROUPS:
 if any(line==f'## {group}' for line in lines):continue
 entries=[e for e in rows if e['group']==group]
 lines += [f'## {group}','','| 이름 | 부지(칸) | 부지(m) | 규격 상태 | ID / 원본 규격 |','|---|---|---|---|---|']
 for e in entries:
  tiles='가변' if e['footprint_cells'] is None else '×'.join(map(str,e['footprint_cells']))
  metres='가변' if e['lot_metres'] is None else '×'.join(map(str,e['lot_metres']))
  lines.append(f"| {e['name']} | {tiles} | {metres} | {e['dimension_status']} | [{e['id']}](../../{e['spec_file']}) |")
 lines.append('')
lines+=['재생성: 저장소 루트에서 `python tools/build_asset_size_index.py`. 원본·카탈로그 값이 다르면 생성이 중단된다.','']
(OUT/'README_KO.md').write_text('\n'.join(lines))
print('Indexed',len(rows),'building/facility specifications; registered dimensions agree.')
