"""Audit 1B public-placement scope and publish the applied CSV price/capacity table."""
import ast,csv,hashlib,json,re,struct,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[1];O=R/'docs/1b-public-placement-validation';BASE='40f030b'
def git(*a):return subprocess.check_output(['git','-c','core.safecrlf=false','-C',str(R),*a],stderr=subprocess.PIPE)
def load(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 definitions=load(R/'cities_do/assets/economy/public_facilities.json')['facilities'];assert len(definitions)==34 and len({e['id'] for e in definitions})==34 and all(e['id']!='power-hydro' for e in definitions)
 source=R/'docs/economy-balance/ECONOMY_BALANCE.csv';mirror=R/'cities_do/assets/economy/ECONOMY_BALANCE.csv.txt';assert source.read_bytes()==mirror.read_bytes()
 with source.open(encoding='utf-8',newline='') as f:rows=list(csv.DictReader(f))
 by={r['항목ID']:r for r in rows};assert len(by)==len(rows)
 old=list(csv.DictReader(git('show',BASE+':docs/economy-balance/ECONOMY_BALANCE.csv').decode().splitlines()))
 approved={e[k] for e in definitions for k in ['price_key','upkeep_key']}
 for row in old:
  key=row['항목ID'];current=by[key]
  if key in approved:assert current['값']==row['값'] and current['단위']==row['단위'] and current['상태']=='임시 승인 2026-11-11'
  elif key!='sheet.purpose':assert current==row,'Unapproved economics row changed: '+key
 catalog={}
 for group in ['services','facilities']:catalog.update({e['id']:e for e in load(R/f'cities_do/assets/{group}/catalog.json')['facilities']})
 table=[]
 for d in definitions:
  e=catalog[d['id']];prefix='public.'+d['id']+'.capacity.'
  caps={key.removeprefix(prefix):{'value':float(row['값']),'unit':row['단위'],'status':row['상태']} for key,row in by.items() if key.startswith(prefix)}
  assert caps and all(c['status']=='임시 승인 2026-11-11' for c in caps.values())
  active={'power':['average_output_kw'],'water':['supply_m3_day'],'sewage':['sewage_m3_day'],'none':[]}[d['engine']]
  for field in caps:caps[field]['active_in_existing_engine']=field in active
  table.append({'id':d['id'],'name':e['name'],'lot':[e['width'],e['depth']],'construction':int(by[d['price_key']]['값']),'monthly_upkeep':int(by[d['upkeep_key']]['값']),'price_key':d['price_key'],'upkeep_key':d['upkeep_key'],'engine':d['engine'],'capacities':caps,'active_capacity_fields':active})
 (O/'applied-prices-capacities.json').write_text(json.dumps(table,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 lines=['# 1B 임시 승인 적용 가격·용량','', '단일 편집 원본: docs/economy-balance/ECONOMY_BALANCE.csv. 월=게임 하루. 가격은 기존 제안값 그대로, 용량은 CAPACITY_PROPOSALS_KO에서 임시 승인 2026-11-11로 전사했다.','', '| ID / 시설 | 부지 | 건설 doth | 유지 doth/월 | 연결 | CSV 용량 데이터(단위) |','|---|---|---:|---:|---|---|']
 for t in table:
  cap='; '.join(f"{k}={v['value']:g} {v['unit']}" for k,v in t['capacities'].items())
  lines.append('| `%s` / %s | %s | %d | %d | %s | %s |' % (t['id'],t['name'],'×'.join(map(str,t['lot'])),t['construction'],t['monthly_upkeep'],t['engine'],cap))
 lines+=['','power는 average_output_kw만 실제 순출력으로 사용한다(rated는 등록값). water는 supply_m3_day, sewage는 sewage_m3_day를 기존 엔진에 연결한다.','그 외 용량·자체 부하·오염 제거율은 데이터 등록만이며 서비스 효과/저장/쓰레기 처리 엔진을 만들지 않았다. 소각 발전은0, 급수탑 생산은0이다.','기존 service.* 용량 제안은 역사 기록이며 1B의 현재 용량 키는 public.<ID>.capacity.* 이다. 공공차량 구입/연료·민간 정원·도로/관로 가격은 이번에 적용하지 않는다.']
 (O/'APPLIED_PRICES_CAPACITIES_KO.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
 protected=['AGENTS.md','cities_do/core/population.gd','cities_do/core/population_config.json','cities_do/core/growth_config.gd','cities_do/core/city_clock.gd','cities_do/core/power_grid.gd','cities_do/core/water_grid.gd','cities_do/core/water_tariffs.json','cities_do/assets/buildings/catalog.json']
 assert not git('diff',BASE,'--name-only','--',*protected).strip()
 original_tree=git('ls-tree','-r',BASE,'assets','cities_do/assets').decode().splitlines()
 original_models=[]
 for line in original_tree:
  info,path=line.split('\t',1)
  if not path.endswith(('.blend','.glb','.png')):continue
  data=(R/path).read_bytes();digest=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
  assert digest==info.split()[2],path
  original_models.append(path)
 source_hashes=load(R/'docs/growth-appearance-validation/source-hashes.json');assert all(sha(R/p)==v for p,v in source_hashes.items())
 tests=load(O/'results.json');expected={p.stem for p in (R/'cities_do/tests').glob('test_*.gd')};assert len(tests['tests'])==len(expected)==30 and {t['name'] for t in tests['tests']}==expected
 assert all(t['passed'] and t['exit_code']==0 and not t['errors'] and not t['timed_out'] for t in tests['tests'])
 captures=load(O/'captures.json');assert len(captures)==3 and all(c['passed'] for c in captures)
 for c in captures:
  path=Path(c['path']);assert sha(path)==c['sha256'] and list(struct.unpack('>II',path.read_bytes()[16:24]))==[1920,1080]
  state=c['state'];spent=sum(t['construction'] for r in state['public_lots'] for t in table if r['public_asset_id']==t['id']);assert state['initial_fixture_budget']-spent==state['funds']
  assert state['monthly_upkeep']==sum(t['monthly_upkeep'] for r in state['public_lots'] for t in table if r['public_asset_id']==t['id'])
 for p in ['tools/capture_public_placement.py','tools/sync_public_economy.py','tools/audit_public_placement.py']:ast.parse((R/p).read_text(encoding='utf-8'))
 report={'review_mode':'self-review','public_placeable':len(table),'excluded_hydro':True,'capacity_rows':sum(len(t['capacities']) for t in table),'tests_passed':30,'tests_total':30,'new_test_summaries':{t['name']:t['summaries'] for t in tests['tests'] if t['name'] in ['test_public_placement','test_public_ui']},'captures':3,'original_model_image_files_unchanged':len(original_models),'growth_source_hashes_unchanged':len(source_hashes),'protected_rules_and_agents_unchanged':True,'new_layout_panels':0,'runtime_csv_sha256':sha(mirror),'no_storage_waste_service_fuel_or_loan_engine':True,'legacy_overlap':['power_plant adjustable 300kW prototype','water_supply adjustable intake prototype','water_treatment adjustable sewage prototype'],'known_limits':['upkeep uses whole-day boundary; no proration/refund','negative cash after mandatory upkeep is recorded; no loan is created','water/sewage continue existing engine behavior; no new electrical interlock','non-generation capacity and own-load values are registered data only','CSV export fallback must be synchronized via tools/sync_public_economy.py']}
 (O/'delivery-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print('PUBLIC_DELIVERY_AUDIT_OK',json.dumps(report,ensure_ascii=False))
if __name__=='__main__':main()
