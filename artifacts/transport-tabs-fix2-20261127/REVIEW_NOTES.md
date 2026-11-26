# 교통 탭 후속 검수 — 2026-11-27

기준: `D:/project/simcity`, `perf/render-sim-cadence`, `cdc8b47`. 이 폴더에만 교통 검수 원본·확대본을 남긴다. 이전 캡처를 덮어쓰지 않는다.

## 파트 7 — 버스 노선 그림

- 실제 운행 계획에서 도로 구간과 주행 방향을 사용한다. 겹쳐 방문한 같은 방향 구간은 최초 통과의 노선 ID·편집 구간을 유지하며 한 번만 표시한다. 꺾임은 양쪽 접근 방향을 잇는 베지어 곡선으로 그린다. 화면상 아스팔트 폭 안에서 노선 간격부터 줄이고, 굵기 4→최소 2px, 그 뒤에는 겹침을 허용한다. 도로·운행 계획은 변경하지 않았다.
- 화살표 길이 8px·기본 피치 30px, 교차로 중심 12px 이내 및 이미 표시된 화살표에 가까운 위치는 생략한다. 현재 버스 플래너는 물리 정류장 ID마다 단일 방향 정차를 반환한다. 같은 도로를 반대로 지나가더라도 그 방향에 정차한 것으로 잡지 않는다. 공유 정류장은 각 실제 정차 방향의 도트를 하나의 흰 고리로 감싼다.
- 기존 실제 장면의 검사 10개에서 결함을 재현했다. 최종 헤드리스 `test_route_overlay` 54/54, `test_route_edit` 31/31, 버스 장면 23/23. 동일한 버스 장면은 native GL에서도 23/23. 접속 역방향 없음, 교차로에서 곡선쌍 최대 한 번 교차, 노면·정류장 정렬과 화살표 간격을 검사했다.
- [1920×1080 원본](bus.png) · 6배 확대 [왼쪽 위](bus-junction-upper-left-6x.png) / [오른쪽 아래](bus-junction-lower-right-6x.png). 실제 GL Compatibility framebuffer에서 캡처했다. 원본에는 같은 작업 트리의 파트 8 도구 아이콘도 보인다. 교차부에서 색 띠가 만나는 것은 남으며, 확대본에서 별도로 확인했다.

## 파트 8 — 승인 B 아이콘

- 탭의 실제 도구 카드에는 철도·터널·여객 노선 B 도형을 적용했다. 화물·삭제의 B 도형도 공유 카드 빌더에 연결하되, 오버레이로 옮긴 동작을 트레이에 다시 추가하지 않았다. 시설 카드의 원본 썸네일과 레이아웃은 그대로다.
- `test_transport_tabs` 헤드리스 126/126; 실제 native 탭 전환 3/3. 1920×1080 [버스](tray-0.png) · [지하철](tray-1.png) · [기차](tray-2.png)를 확인했다.

## 파트 9 — 정차역 삽입 회귀

- `f2ef9aa`가 직선 리본을 합친 뒤 테스트가 고른 구간 중앙점이 삽입 역에서 약 6px 떨어졌고, 테스트 자체의 20px 제외 기준 때문에 드래그가 시작되지 않았다. 실제 리본에서 중간점과 ¼·¾ 지점을 검사해 대상 노선의 삽입 히트를 찾도록 fixture만 고쳤다. 승인 동작·드래그 경로·기존 단언을 유지했다.
- `test_review_fix_dialog` 기준 25/27 → 헤드리스·실제 native 각각 42/42. 중복 실행의 단언 수를 합산하지 않는다.

## 파트 10 — 병합 전 전체 테스트

- 로컬 커밋: 파트 7 `092d8a5`, 파트 8 `5f52945`, 파트 9 `4cda9db`.
- `4cda9db` 최초 전수 실행: **헤드리스 137/172, 네이티브 30/43 스위트 통과**. 모드별 35·13 스위트 실패에 엔진/종료 진단도 포함한다. 정상 종료·무진단 스위트의 보고된 단언 수는 각각 168,991·1,308개이며, 같은 단언의 두 모드 재검증은 합산하지 않는다. 카운트 없는 헤드리스 통과 스위트 6개는 단언 수에 넣지 않았다. `test_neighbor_commuting_contract.gd`는 헬퍼라 `test_neighbor_commuting`을 통해 검증했다. 원본 로그와 SHA·결과는 프로필 scratch `transport-20261127-full-4cda9db/{run.json,results.jsonl}`. 구 테스트의 증거 쓰기는 scratch로 돌려 보호 파일을 덮어쓰지 않았다.
- 최초 헤드리스 실패(이름의 `test_` 생략): `bottom_ui`, `building_assets`, `city`, `city_worker_parity`, `facilities`, `growth_appearance`, `junctions`, `main_bottom_ui`, `native_worker_parity`, `play_tools`, `population`, `population_three_days`, `public_road_snap`, `recovered_assets`, `registered_30_assets`, `road_angle_snap`, `road_cursor`, `road_demolition_input`, `road_draw_modes`, `road_grade_flow`, `road_grid_snap`, `road_junction_spacing_input`, `road_length_units`, `road_midpoint_connections`, `road_parcels`, `road_preview_round`, `road_setback`, `showcase`, `thumbnail_hud`, `traffic`, `transit_facilities_fifo`, `transit_facilities_view`, `ui`, `vehicles`, `zoning_development`.
- 최초 네이티브 실패(이름의 `test_` 생략): `horizontal_card_strip`, `main_bottom_ui`, `public_road_snap`, `registered_30_assets`, `road_continue`, `road_demolition_input`, `road_draw_modes`, `road_grade_flow`, `road_junction_spacing_input`, `road_length_units`, `road_midpoint_connections`, `thumbnail_hud`, `underground_rail_ui`. 실제 GL이 필요한 `transit_facilities_view`는 네이티브 49/49. 교통 탭/노선/대화상자 자체는 양쪽 모드에서 통과했다.
- 기준 SHA 사전 실행(전체 수에 미포함): `test_growth_appearance` 273/274와 중간 배열 오류. 기존 4차선 중심선에서 승인된 폭(5칸)이 기존 건물과 0.5칸 겹쳤다. 테스트 사본에서 중심선을 y=40.5로 옮기고 양쪽 배치/성장 성공을 먼저 확인하자 308/308이었다. 소비자 게임이나 원본은 수정하지 않았다.
- `test_bottom_ui` 최초 39/43. 미리보기의 기존 도로 폭과 8×8 맞은편 구획이 승인된 규칙과 맞지 않았고, 배속 검사는 worker의 확정 시각을 기다리지 않았다. 도로/부지 좌표와 테스트의 worker 경계만 바꾼 scratch 재현에서 48/48이었다. `test_building_assets`도 같은 폭 변경으로 처음 부지를 만들지 못했다. scratch 사본에서 실제 맞은편 도로 간격을 맞추고 도시 교체 전 기존 worker를 종료한 결과 27/27 및 정상 종료를 확인했다. `test_city`는 새 도로 폭에 맞게 중심선을 조정한 사본에서 당초 24개 단언을 모두 통과했다. 이 실험들은 기준 실행의 입력 파일을 바꾸지 않았다.
- `test_traffic` 재검증 44/44 및 정상 종료, `test_transit_traffic_regression` 28/28. 별도 교통 데모가 모델 교체 전에 빈 도시의 worker를 종료하도록 수정했다. 100대의 고정 스텝 간격 검사는 그대로 두고 비용 계측만 `--benchmark-traffic`으로 명시할 때 실행한다. 재검증 로그는 scratch `transport-20261127-traffic-rerun/`.

- `8611121` 위 작업 사본에서 회귀 fixture 보정 후 선별 재시험: 헤드리스 40/40, 네이티브 13/16. 원래 전체 로그에 이 결과를 같은 모드·스위트별로 대체하고 소스/로그 해시를 검사하면 헤드리스 171/171, 네이티브 40/43이다. 역 SubViewport 픽셀 단언은 네이티브 전용으로 재분류해 헤드리스 대상이 하나 줄었다. 새 전체 실행이 아닌 최초 전체 + 선별 재시험 합산이다. 원시 로그는 프로필 scratch `transport-20261127-repair-8611121/`.
- 도로·부지 좌표와 카탈로그 기대값을 현행 규칙에 맞추고, 테스트가 도시를 교체할 때 이전 worker를 종료한다. Worker parity는 원래 비교하던 11개 필드를 누락 없이 비교하고, 3일 oracle은 옛 모델의 청구 콜백을 그 fixture에만 사용한다. 주거 전시는 기존 10개 건물과 8×8 부지를 보존하고 도로 중심을 현행 연석에 맞췄다(28/28).
- 네이티브에서 남았던 세 스위트: `road_continue` 10/17, `road_length_units` 41/42, `road_profile_connections` 44/46. `road_continue` 재현에서는 초기 실제 포인터 움직임이 첫 합성 드래그에 끼어 `(10,40)` 다음에 의도하지 않은 `(57.615,175.144)`가 기록됐다. 테스트의 첫 입력 전 창 안정화, 불도저 클릭 전 hover 갱신, 좁은 차로 띠에서 클릭 전 대상 카드를 스크롤로 드러내기를 적용해 세 스위트를 두 모드에서 20/20·42/42·50/50으로 통과했다(`transport-20261127-road-final-8611121/`). 최종 기록은 **헤드리스 171/171, 네이티브 43/43 스위트**, 실패 0. 로그에 집계값이 있는 단언은 각각 311,927개·2,568개(헤드리스 무집계 7개, 모드 간 중복은 합산하지 않음). 소스·원시 로그 SHA-256 대조를 완료했다. 공원 탭 철도 견본의 클릭 동작은 배치가 일어나지 않는 것만 확인했다. 별도 검사창 연결은 이번 검수 범위 밖이다.

## 파트 11 — 큰 도시 렌더러 비교

- `PERFORMANCE_NOTES_KO.md`의 240명 실화면 항목에 연결된 `727a9e1`의 최대 네이티브 렌더 장면을 사용한다. 시드 20261114, 100×100칸, 도로 6개, 건물 61채, 120가구·240명, 지정 32칸. 30만 장면은 렌더·HUD가 없는 별도 규모 계측이라 이 비교에 넣지 않는다. 당시 카메라 위치와 0.9배를 고정하며 당시 WASD 이동을 재생하지 않는다. 앞선 실화면의 배치 지문은 남아 있지 않아 당시 레시피를 재현한 결과다.
- 최초 전체 테스트가 끝난 뒤 다른 Godot 프로세스가 없는 상태에서 6건을 순차 계측했다. 결과: 커밋 `8611121`의 [정지·실행 비교 표](../renderer-compare-20261126/README.md#기존-최대-실화면-도시--2026-11-27)와 [원시 표본](../renderer-compare-20261126/large-20261127/summary.json). 오류·경고·렌더러 대체 없음.

## 확인 대기

- 버스 정류장 표시는 임시 규칙이다. 한 방향만 서면 그 방향 선 위, 양방향으로 실제 정차하면 두 줄 사이, 공유 정류장은 흰 고리로 노선 묶음을 둘러싼다. 현행 정류장 ID에 두 방향이 정차하는 경우는 플래너가 지원하지 않아 실증하지 않았다.
- 전체 실행 준비 중 `python -c …`로 `tools/run_full_regression_20261127.py --list` 출력을 집계하는 명령은 승인 대기 만료로 실행되지 않았다. 이 목록 집계는 재시도하지 않았다. 이후 별도 실행은 스크래치 파일과 `python <파일>`을 사용하고, 권한이 필요한 작업은 보류한다.
