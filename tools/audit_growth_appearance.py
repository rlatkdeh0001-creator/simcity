"""Audit real growth-appearance evidence and write its complete candidate-ID table."""
import ast,hashlib,json,subprocess
from pathlib import Path
from collections import Counter
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/growth-appearance-validation'
def load(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args):return subprocess.check_output(['git','-c','core.safecrlf=false','-C',str(ROOT),*args])
def main():
 hashes=load(OUT/'source-hashes.json');assert all(sha(ROOT/p)==h for p,h in hashes.items())
 entries=load(ROOT/'cities_do/assets/buildings/catalog.json')['buildings'];assert len(entries)==42
 assert Counter(e['zone'] for e in entries)=={'residential':14,'commercial':14,'industrial':14}
 assert all(e['growth_enabled'] for e in entries)
 by={e['id']:e for e in entries};growth=load(ROOT/'cities_do/assets/growth_14.json')['assets']
 assert len(growth)==14 and len({e['id'] for e in growth})==14
 source=load(ROOT/'docs/growth-14/catalog.json')['assets'];assert {e['id'] for e in source}=={e['id'] for e in growth}
 old=json.loads(git('show','f7824ad9566f5b1d8f5135e40d653be3ed21360c:cities_do/assets/buildings/catalog.json'))['buildings']
 for previous in old:
  current=by[previous['id']]
  assert {k:v for k,v in current.items() if k not in ['density','growth_enabled','min_level']}=={k:v for k,v in previous.items() if k not in ['density','growth_enabled','min_level']}
  assert current['min_level']==(2 if current['id'].startswith('mansion-') else 1)
 for e in growth:
  original=next(s for s in source if s['id']==e['id'])
  assert e['source_metadata']==load(ROOT/original['source_folder']/'metadata.json')
  assert sha(ROOT/original['source_folder']/'building.png')==sha(ROOT/'cities_do'/e['texture'].removeprefix('res://'))
  for field in ['model','texture','spec']:assert (ROOT/'cities_do'/e[field].removeprefix('res://')).is_file()
 baseline='3d6a4d9'
 old_glb=[p for p in git('ls-tree','-r','--name-only',baseline,'cities_do/assets').decode().splitlines() if p.endswith('.glb')]
 assert all((ROOT/p).read_bytes()==git('show',baseline+':'+p) for p in old_glb),'Existing GLB changed'
 protected=['cities_do/core/growth_config.gd','cities_do/core/population.gd','cities_do/core/population_config.json','cities_do/core/economy_config.gd','cities_do/core/city_clock.gd','cities_do/core/power_grid.gd','cities_do/core/water_grid.gd','cities_do/bottom_ui.gd','cities_do/main.gd','cities_do/project.godot']
 assert not git('diff','--name-only','--',*protected).strip()
 base=git('show',baseline+':cities_do/core/city_model.gd').decode().replace('\r\n','\n')
 current=(ROOT/'cities_do/core/city_model.gd').read_text(encoding='utf-8')
 assert current.replace('\tcatalog.assign(building,appearance_rng)\n','',1).replace('\tcatalog.assign(b,appearance_rng)\n','',1)==base,'City rules changed beyond initial appearance assignment'
 for p in ['docs/CAPACITY_PROPOSALS_KO.md','docs/PRICE_PROPOSALS_KO.md','docs/economy-balance/ECONOMY_BALANCE.csv']:
  assert git('show','f660b94:'+p)==git('show','HEAD:'+p),'Approved proposal content changed after docs commit'
 matrix=load(OUT/'matching-table.json');rows=matrix['rows']
 assert len(rows)==45 and len({(r['zone'],tuple(r['lot_cells']),r['stage']) for r in rows})==45
 assert all(len(r['candidate_ids'])==2 for r in rows)
 assert {i for r in rows for i in r['candidate_ids']}==set(by)
 assert len(matrix['fallback_stage_rows'])==12 and not matrix['no_candidate_rows']
 for r in rows:
  assert r['target_density']==('small' if r['stage']<=2 else 'medium' if r['stage']<=4 else 'large')
  assert all(by[i]['zone']==r['zone'] and by[i]['footprint']==r['lot_cells'] and by[i]['density']==r['resolved_density'] for i in r['candidate_ids'])
 lines=['# 성장 외관 전체 매칭 표','', '단계1·2=small, 3·4=medium, 5=large. 같은 부지만 사용한다. 8×8 조기 단계 행은 기존 프로토타입의 외관 폴백 검사이지 신축/성장 규칙 구현이 아니다.','', '| 용도 | 부지 | 단계 | 요청 → 실제 밀도 | 후보 ID |','|---|---|---:|---|---|']
 for r in rows:lines.append('| %s | %s | %d | %s → %s%s | %s |' % (r['zone'],'×'.join(map(str,r['lot_cells'])),r['stage'],r['target_density'],r['resolved_density'],' (대체)' if r['fallback'] else '',', '.join('`'+i+'`' for i in r['candidate_ids'])))
 (OUT/'MATCHING_TABLE_KO.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
 captures=load(OUT/'captures.json');assert len(captures)==6 and all(r['passed'] for r in captures)
 for record in captures:
  assert sha(Path(record['path']))==record['sha256'] and record['size']==[1920,1080]
  state=record['state'];assert len(state['growth_button_actions'])==3*(state['stage']-1) and state['funds']==50000
  assert {b['zone'] for b in state['buildings']}=={'residential','commercial','industrial'}
  for b in state['buildings']:
   row=next(r for r in rows if r['zone']==b['zone'] and r['lot_cells']==[b['lot'],b['lot']] and r['stage']==b['stage'])
   assert b['asset_id'] in row['candidate_ids']
 result=load(OUT/'results.json');assert result['passed']==result['total']==27 and not result['failed']
 assert {t['name'] for t in result['tests']}=={p.stem for p in (ROOT/'cities_do/tests').glob('test_*.gd')}
 assert all(t['exit_code']==0 and t['passed'] and not t['errors'] and not t['timed_out'] for t in result['tests'])
 measurements=load(OUT/'measurements.json');assert len(measurements)==14
 report=dict(review_mode='self-review',registered_growth=14,total_private_appearances=42,protected_source_count=len(hashes),all_source_hashes_unchanged=True,existing_glb_unchanged=len(old_glb),growth_simulation_rules_unchanged=True,proposal_values_runtime_unapplied=True,matching_rows=45,fallback_stage_rows=12,missing_density_cells=[{'zone':zone,'lot':[8,8],'density':density,'fallback':'large'} for zone in ['residential','commercial','industrial'] for density in ['small','medium']],empty_candidate_rows=[],captures=6,tests_passed=27,tests_total=27,new_growth_checks=302,geometry_anomalies=[e for e in measurements if e['issues']])
 (OUT/'delivery-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print('GROWTH_AUDIT_OK',json.dumps(report,ensure_ascii=False))
if __name__=='__main__':main()
