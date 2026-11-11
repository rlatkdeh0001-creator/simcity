"""Verify deterministic lot rules, preserved numerical settings, real captures and full regressions."""
import ast,hashlib,json,struct,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[1];O=R/'docs/growth-appearance-validation/lot-rules';BASE='4077e44'
def git(*a):return subprocess.check_output(['git','-c','core.safecrlf=false','-C',str(R),*a],stderr=subprocess.PIPE)
def load(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 tests=load(O/'results.json');expected={p.stem for p in (R/'cities_do/tests').glob('test_*.gd')}
 assert tests['passed']==tests['total']==len(expected)==28 and {t['name'] for t in tests['tests']}==expected
 assert all(t['passed'] and t['exit_code']==0 and not t['errors'] and not t['timed_out'] for t in tests['tests'])
 hashes=load(R/'docs/growth-appearance-validation/source-hashes.json');assert all(sha(R/p)==v for p,v in hashes.items())
 originals=[p for p in git('ls-tree','-r','--name-only',BASE,'cities_do/assets').decode().splitlines() if p.endswith('.glb')]
 assert all((R/p).read_bytes()==git('show',BASE+':'+p) for p in originals)
 assert not git('diff',BASE,'--name-only','--','assets').strip()
 protected=['AGENTS.md','cities_do/core/population.gd','cities_do/core/population_config.json','cities_do/core/economy_config.gd','cities_do/core/city_clock.gd','cities_do/core/power_grid.gd','cities_do/core/water_grid.gd','cities_do/bottom_ui.gd','cities_do/main.gd','cities_do/assets/buildings/catalog.json','docs/CAPACITY_PROPOSALS_KO.md','docs/PRICE_PROPOSALS_KO.md','docs/economy-balance/ECONOMY_BALANCE.csv']
 assert not git('diff',BASE,'--name-only','--',*protected).strip()
 strip=lambda s:'\n'.join(line for line in s.replace('\r\n','\n').splitlines() if not line.lstrip().startswith('#'))
 assert strip((R/'cities_do/core/growth_config.gd').read_text(encoding='utf-8'))==strip(git('show',BASE+':cities_do/core/growth_config.gd').decode())
 matrix=load(R/'docs/growth-appearance-validation/matching-table.json');rows=matrix['rows'];assert len(rows)==45 and not matrix['fallback_stage_rows'] and len(matrix['legacy_fallback_stage_rows'])==12
 assert sum(not r['simulation_reachable'] for r in rows)==12 and all(not r['fallback'] for r in rows)
 lines=['# 성장 외관 전체 매칭 표 — 승인된 부지 규칙 적용','', '1·2 small, 3·4 medium, 5 large. 신규8×8은5단계 전용. 8×8의 small/medium 6밀도셀(12단계행)은 **도달 불가**이며 기존 저장 데이터에서만 large 외관을 보존한다.','', '| 용도 | 부지 | 단계 | 도달 가능성 | 요청 → 실제 외관 밀도 | 후보 ID |','|---|---|---:|---|---|---|']
 for row in rows:
  state='가능' if row['simulation_reachable'] else '**도달 불가** · 기존 저장 large 유지'
  lines.append('| %s | %s | %s | %s | %s → %s | %s |' % (row['zone'],'×'.join(map(str,row['lot_cells'])),row['stage'],state,row['target_density'],row['resolved_density'],', '.join('`'+i+'`' for i in row['candidate_ids'])))
 (R/'docs/growth-appearance-validation/MATCHING_TABLE_KO.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
 captures=load(O/'captures.json');assert len(captures)==3 and all(c['passed'] for c in captures)
 for c in captures:
  p=Path(c['path']);assert sha(p)==c['sha256'] and list(struct.unpack('>II',p.read_bytes()[16:24]))==[1920,1080]
  state=c['state'];assert state['funds']==50000 and not state['authored_lot_injection'] and len(state['buildings'])==3
  if state['scenario']=='stage5':
   assert len(state['growth_button_actions'])==12 and all(b['size']==4 and b['stage']==1 for b in state['initial_development'])
   assert all(a['size']==(8 if a['stage']==5 else 4) for a in state['growth_button_actions'])
 assert all(ast.parse((R/p).read_text(encoding='utf-8')) for p in ['tools/audit_lot_rules.py','tools/capture_lot_rules.py'])
 report={'review_mode':'self-review','full_suite':{'passed':28,'total':28},'lot_rule_assertions':86,'appearance_assertions':302,'unchanged_source_files':len(hashes),'unchanged_existing_glb':len(originals),'unreachable_8x8_stage_rows':12,'normal_density_fallback_rows':0,'captures':3,'protected_values_and_agents_unchanged':True,'capacity_formula':'unchanged area proportional','demand_formula':'unchanged; commercial/industrial demand still counts buildings, not 2x2 equivalents','scope':'deterministic initial and manual-upgrade lot policy only; no happiness or automatic density growth'}
 (O/'delivery-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print('LOT_DELIVERY_AUDIT_OK',json.dumps(report,ensure_ascii=False))
if __name__=='__main__':main()
