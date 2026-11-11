"""Regenerate measurement tables and verify this delivery's data/artifact invariants."""
import csv,hashlib,json,subprocess,sys
from collections import Counter
from pathlib import Path
from PIL import Image,ImageStat
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/register-30-assets-validation'
DEST=ROOT/next((a.split('=',1)[1] for a in sys.argv if a.startswith('--output=')),str(OUT.relative_to(ROOT)))
def load(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 entries=load(ROOT/'cities_do/assets/registered_30.json')['assets']
 original_index=load(ROOT/'docs/remaining-original-assets/catalog.json')['assets']
 assert len(entries)==30 and {e['id'] for e in entries}=={e['id'] for e in original_index}
 assert Counter(e['group'] for e in entries)=={'commercial':10,'industrial':8,'power':6,'water':4,'waste':2}
 hashes=load(OUT/'source-hashes.json')['sha256']
 approval_path=OUT/'approved-main-merge/approved-metadata.json'
 approvals={e['path']:e for e in load(approval_path)['changes']} if approval_path.exists() else {}
 authorized_changes=[]
 for p,value in hashes.items():
  if sha(ROOT/p)==value:continue
  assert p in approvals,('Unapproved original change',p)
  approval=approvals[p]
  assert approval['before_sha256']==value and approval['after_sha256']==sha(ROOT/p)
  assert load(ROOT/p)==approval['after']
  assert {k for k in approval['before'].keys()|approval['after'].keys() if approval['before'].get(k)!=approval['after'].get(k)}<=set(approval['allowed_fields'])
  authorized_changes.append(p)
 DEST.mkdir(parents=True,exist_ok=True)
 manifest=load(ROOT/'cities_do/assets/ui/thumbnails/manifest.json')
 baseline=json.loads(subprocess.check_output(['git','-C',str(ROOT),'show','12dbc38b8163a773ee384736b0219e547d1b1f6c:cities_do/assets/ui/thumbnails/manifest.json'],text=True,encoding='utf-8'))
 assert all(manifest[k]==value for k,value in baseline.items()),'Existing thumbnail records changed'
 rows=[]
 for entry in entries:
  original=next(e for e in original_index if e['id']==entry['id'])
  assert entry['source_metadata']==load(ROOT/original['metadata'])
  assert not entry['growth_enabled'] and not entry['simulation_enabled']
  for field in ['model','preview','spec']:
   assert (ROOT/'cities_do'/entry[field].removeprefix('res://')).is_file()
  source_png=next(ROOT/p for p in original['previews'] if 'reverse-review' not in p)
  assert sha(source_png)==sha(ROOT/'cities_do'/entry['preview'].removeprefix('res://'))
  thumbnail=ROOT/'cities_do'/manifest[entry['id']]['thumbnail'].removeprefix('res://')
  assert Image.open(thumbnail).size==(256,192) and sha(thumbnail)==manifest[entry['id']]['sha256']
  rows.append({'id':entry['id'],'name':entry['name'],'group':entry['group'],
               'lot_cells':str(entry['footprint_cells']) if entry['footprint_cells'] else 'null (parametric; presentation only)',
               'width_m':entry['width_m'],'depth_m':entry['length_m'],'height_m':entry['height_m'],
               'ground_offset_m':entry['ground_offset_m'],'front_feature_node':entry['front_feature_node'] or 'NOT VERIFIED: no named human entrance',
               'issues':'; '.join(entry['registration_issues']) or 'none'})
 with (DEST/'measurements.csv').open('w',encoding='utf-8-sig',newline='') as file:
  writer=csv.DictWriter(file,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
 lines=['# 원본 30종 실측표','', '단위 m. W=Godot X, D=Godot Z, H=Godot Y. 원본 부지 1칸=4m. 수력의 null 부지는 고정 15×8로 바꾸지 않았다.', '', '| ID | 이름 | 분류 | 원본 부지(칸) | W × D × H (m) | 출입구 근거 노드 |', '|---|---|---|---|---|---|']
 for row in rows:lines.append('| %s | %s | %s | %s | %.3f × %.3f × %.3f | %s |' % (row['id'],row['name'],row['group'],row['lot_cells'],row['width_m'],row['depth_m'],row['height_m'],row['front_feature_node']))
 lines+=['','## 예외 / 보존 사항','']+[f"- `{row['id']}`: {row['issues']}" for row in rows if row['issues']!='none']
 (DEST/'MEASUREMENTS_KO.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
 images=[]
 for name,count in [('overview-30',30),('scale-commercial',10),('scale-industrial',8),('scale-infrastructure',12)]:
  p=OUT/(name+'.png');data=load(p.with_suffix('.json'));image=Image.open(p)
  assert len(data['assets'])==count and len({e['id'] for e in data['assets']})==count
  assert list(image.size)==data['resolution'] and sha(p)==data['image_sha256']
  assert max(ImageStat.Stat(image.convert('RGB')).stddev)>3,'Blank/unusable render'
  assert all(not e['scale_changed'] for e in data['assets'])
  if count!=30:
   assert len(data['vehicle_instances'])==count*2
   assert all(v['instance_scale']==[1,1,1] for v in data['vehicle_instances'])
  images.append({'path':str(p),'size':list(image.size),'sha256':sha(p),'assets':count})
 captures=load(OUT/'captures.json')
 assert len(captures)==4 and all(e['passed'] for e in captures)
 for e in captures:
  p=Path(e['path']);assert sha(p)==e['sha256'] and list(Image.open(p).size)==e['png_size']
 for edge in ['top','bottom']:
  p=OUT/f'commercial-industrial-{edge}-1920.png';state=load(p.with_suffix('.state.json'))
  assert state['count']==18 and len(set(state['entries']))==18 and Image.open(p).size==(1920,1080)
  images.append({'path':str(p),'size':list(Image.open(p).size),'sha256':sha(p),'registered_models':18,'scroll_bottom':state['scroll_bottom']})
 report={'review_mode':'self-review','registered_count':len(entries),'group_counts':dict(Counter(e['group'] for e in entries)),
         'source_file_count':len(hashes),'all_original_sha256_unchanged':not authorized_changes,'authorized_metadata_changes':authorized_changes,'unapproved_original_changes':[],'all_source_metadata_values_preserved':True,
         'all_preview_copies_byte_identical':True,'new_thumbnail_count':len(entries),'total_thumbnail_count':len(manifest),
         'existing_thumbnail_records_unchanged':True,'missing_registration':[],'missing_thumbnails':[],
         'no_named_entrance_ids':[e['id'] for e in entries if not e['front_feature_node']],
         'issues':[{'id':e['id'],'issues':e['registration_issues']} for e in entries if e['registration_issues']],
         'images':images}
 (DEST/'delivery-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print('DELIVERY_AUDIT_OK',len(entries),'ORIGINALS',len(hashes),'THUMBNAILS',len(manifest),'RENDERED_IMAGES',len(images))
if __name__=='__main__':main()
