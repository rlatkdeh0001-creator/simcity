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
- 선로 견본은 기존 검사 창에서 볼 수 있게 등록하라는 기획(`ASSET_REQUEST_RAIL_PARK_KO.md:87,112–114`)이 있다. 공원 탭에서 카드를 눌렀을 때 그 검사 창을 열어야 하는지까지는 적혀 있지 않다. 지도 배치·차감·배치 오류가 없는 동작을 확인했고 검사 창 연결은 확인 대기다.
- 정상 임포트된 프로젝트에서 기존 `transit_view.gd:47–54`가 원본 선로 띠 PNG를 읽을 때 Godot가 패키지 내보내기 경고를 출력한다. GLB 검사나 프로젝트 모드에서는 실패하지 않았다. 패키지 내보내기는 이번 범위가 아니며 확인하지 않았다.
- 전체 실행 준비 중 `python -c …`로 `tools/run_full_regression_20261127.py --list` 출력을 집계하는 명령은 승인 대기 만료로 실행되지 않았다. 이 목록 집계는 재시도하지 않았다. 이후 별도 실행은 스크래치 파일과 `python <파일>`을 사용하고, 권한이 필요한 작업은 보류한다.

## 병합 전 최종 실행 (a20bcd3)

- **새 단일 전수:** `a20bcd348b8bd2e2990dcf13cf83a6f4c9d41caa`에서 모든 214개 슬롯 완료. 헤드리스 **171/171**, 네이티브 GL **43/43**, 스위트 실패 **0**. 집계가 있는 단언은 헤드리스 **311,954개**(무집계 7개 별도), 네이티브 **2,595개**; 모드 간 중복 및 이전 실행과 합산하지 않았다.
- 처음의 헤드리스 172개에서 `test_transit_facilities_view` 1개를 네이티브 전용으로 옮겼다. 더미 디스플레이는 역의 실제 SubViewport 픽셀을 확인할 수 없다. 기존 `test_terminal_turnback_native`, `test_transit_commuting_view`도 계속 네이티브 전용이며, 헤드리스 역 모델 검사는 그대로다.
- `tools/run_full_regression_20261127.py`와 `tools/run_dotnet.py`로 별도 프로세스에서 실행했다. 과거 산출물을 자동으로 쓰는 3개 fixture는 정확한 출력 경로만 scratch로 바꿨다. `test_roads_zoning`은 외부 사본에서 시간 읽기와 소요시간 출력 두 줄만 제외했고 **18/18 기능 단언**은 유지했다. 교통·교각의 계측 플래그는 쓰지 않았다. 캡처·빌드·import 없음.
- 원시 로그와 실행 목록: 프로필 scratch `transport-premerge-a20bcd3/{run.json,results.jsonl}`. 214개 계획/실행 키 일치, 각 테스트와 원시 로그 SHA-256 일치를 확인했다. `results.jsonl` SHA-256 `a636c084974fcd716218297f0312ec6096d3f7282c24448486f7a994b573108a`. 헤드리스 시작 전의 scratch Git 옵션 오류는 Godot 실행 전이어서 전수 결과에 포함하지 않았다.
- **러너 종료 코드 1은 스위트 실패가 아니다.** 214개 종료 뒤 보존 검사에서 실행 중 외부에서 확정된 문서 4개를 감지했다: `E4_BRIEF_KO.md` 기존 파일 내용 변경 및 `ROAD_DRAWING_KO.md`, `PERFORMANCE_NOTES_KO.md`, 교통 `DECISION_KO.md`의 새 작업 사본 차이. 이 문서는 Godot fixture 입력이 아니며 건드리지 않았다. 사전 대조한 기존 변경/보호 경로 370개 중 E4 문서 외에는 원래 바이트가 유지됐다. 도로 커서·측정 HTML 및 예시 state JSON 3개는 HEAD와 바이트가 동일하다. E1 JSON은 11-18 검수 산출물, `project.godot` 차이는 실행 전 주석·공백뿐이다.
- **병합 관문 보류:** 아래에 기존 검사가 느슨해진 사례가 있다. 승인 문서 커밋·fetch·main 병합·push와 파트 A/B/C는 시작하지 않았다. 검사 실패가 없어 수정·재시험 커밋도 없다. 결과와 감사만 이 노트에 남긴다.

### `4cc7886` 기대값 감사

`8611121`→`4cc7886`에서 변경된 테스트 35개. 문서 행은 `a20bcd3`의 커밋 기준이다. 구현·카탈로그가 유일한 근거인 경우 승인 규칙과 구분했다.

| 테스트 | 바뀐 기대값 | 근거 문서:행 |
|---|---|---|
| `test_bottom_ui` | 34동·8도로와 3×에서 72게임초 상당의 수도량 유지. 실제 worker 발행, 양수 물 공급, 8×8 대향 도로를 요구. 72는 선발행된 시간에서 계량한 수도량이다. | `docs/POPULATION_TIME_KO.md:16–26,123–124`; `docs/SKILL_HANDOFF_KO.md:120–125,1273–1275,1326–1329` |
| `test_building_assets` | 도로 중심 y=20.5/9.5로 마주 보는 연석 사이 8칸 확보. 5단계 8×8·외관·폴백·RNG 유지. | `docs/design/ROAD_DRAWING_KO.md:25–29`; `docs/ZONING_DEVELOPMENT_KO.md:3–9`; `docs/design/BUILDING_GROWTH_KO.md:9–18` |
| `test_city` | 현행 도로 반폭에 맞춘 설치 좌표. 경계·겹침·직접 API 충돌 거부와 성장 및 2×2/4×4 폴백 단언 유지. | `docs/design/ROAD_DRAWING_KO.md:25–29`; `docs/BUILDING_ROAD_ADJACENCY_KO.md:3–21`; `docs/design/INITIAL_LOT_SIZE_KO.md:5–13` |
| `test_city_worker_parity` | 전체 export 사전 일치 → 기존 canonical 11개 키의 정확한 값과 존재를 비교. 5,400틱·체크포인트 유지. | `docs/SKILL_HANDOFF_KO.md:1345–1347`; 전체 키 집합 계약의 별도 문서 근거 미확인. |
| `test_facilities` | 8→19종. 기존 8종의 AABB·높이·메시 검사 유지, 신규 11종은 메시 존재 위주; 원본 GLB와 PNG 검사. | `docs/PARKS_PARKING_KO.md:8–17,35–52`; `docs/design/ASSET_REQUEST_RAIL_PARK_KO.md:37–41,87,105,112–115`; `docs/design/ASSET_REQUEST_TRANSIT_KO.md:22–28,42–49`. 19는 현행 카탈로그 값. |
| `test_growth_appearance` | 중심선 y=40→40.5, 기존 연석 보존. 양쪽 배치·성공 단언 추가, RNG·크기·단계 동일성 유지. | `docs/design/ROAD_DRAWING_KO.md:25–29`; `docs/BUILDING_ROAD_ADJACENCY_KO.md:3–17`; `docs/growth-appearance-validation/README_KO.md:80–89` |
| `test_junctions` | 2차로 X 교차 외접 2×2→3×3, 면적 `(3.8,4.0)`→`(8.9,9.0)` 제곱셀. 기존 집을 현행 도로 부지에 재배치. | `docs/design/ROAD_DRAWING_KO.md:25–29`; `docs/ROAD_JUNCTIONS_KO.md:9–20,29–43`. 면적 하한은 형상 회귀치. |
| `test_main_bottom_ui` | 카드 5장→2~8차로 7장 순서 확인. 1초·3× 즉시 `+72`→발행 전 시계 불변, 수동 발행 후 한 틱 `+48`. | `docs/design/ROAD_DRAWING_KO.md:25–29`; `docs/design/ECONOMY_LOOP_SPEC_KO.md:56–60`; `docs/SKILL_HANDOFF_KO.md:1326–1328` |
| `test_native_worker_parity` | 전체 export 키 집합→위와 같은 11개 정확 비교. Native mailbox scalar·읽기 뷰·발행 단언 유지. | `docs/SKILL_HANDOFF_KO.md:1350–1353`; 전체 키 집합 계약의 별도 문서 근거 미확인. |
| `test_play_tools` | 교통 트레이 허용 목록 `[]`→`["transit_line"]`. 금지된 시연·구형 공구 부재 유지. | `docs/concepts/transport-tabs-20261119/DECISION_KO.md:61–80,121–128` |
| `test_population` | 주거 8→4채, 목표 8가구 유지. 고용을 도로 연결 실상가·공개 철거 API에서, HUD 링을 실제 worker 발행 후 확인. | `docs/SKILL_HANDOFF_KO.md:1359–1363`; `docs/design/LABOR_BALANCE_KO.md:38–48`; `docs/POPULATION_TIME_KO.md:59–63,71–81` |
| `test_population_three_days` | 단언 유지. 두 시드 5,400틱의 동결 oracle에만 옛 청구 콜백 복원(신형 원장 동등성은 범위 밖). | `docs/POPULATION_TIME_KO.md:12–17,93–96`; `docs/csharp-population-validation/reference/city_model.gd.txt:67–80`; `2705fbf:cities_do/core/public_facilities.gd:92–94` |
| `test_public_road_snap` | 4차로 폭 5칸 추가, 6×6 중심 y=35/45→34.5/45.5. 실제 클릭·정확히 1회 차감 유지; 포착 성공 표본 가까워짐. | `docs/design/ROAD_DRAWING_KO.md:25–29,58–59`; `docs/BUILDING_ROAD_ADJACENCY_KO.md:3–17`. 2칸 임시 포착 값: `cities_do/core/public_facilities.gd:65–76`. |
| `test_road_angle_snap` | 기대·오차 유지, 동일한 호스트의 모델 교체 전 worker 종료. | `docs/design/ROAD_DRAWING_KO.md:52–56` |
| `test_road_continue` | 자유 드래그와 모션 없는 release 기대 그대로. 첫 입력 전에 창 안정화. | `docs/design/ROAD_DRAWING_KO.md:8–22`; 0.6초는 fixture 준비. |
| `test_road_cursor` | 옛 차로 비례 직경 대신 실제 3/5칸 확인. 유효 부지의 충돌과 스냅·취소 유지. | `docs/design/ROAD_DRAWING_KO.md:25–29`; `docs/concepts/road-cursor-20261112/mockups.html:8,23–31` |
| `test_road_demolition_input` | 실제 8m 드래그·press/release 단언 유지. 모델 교체 전 종료. | `docs/design/ROAD_DRAWING_KO.md:31–34` |
| `test_road_draw_modes` | 사유 건물 충돌 무조건 거부→승인된 경고와 정확 ID, 확인 전 도로·집 불변. 급회전·중복·경계 거부 유지. | `docs/design/ROAD_DRAWING_KO.md:8–10,69–79`; `docs/concepts/elevated-road-20261118/DECISION_KO.md:9–15,25` |
| `test_road_grade_flow` | 실제 카드/지도 11조합 유지, 모델 교체 전 종료. | `docs/design/ROAD_DRAWING_KO.md:25–29` |
| `test_road_grid_snap` | 그리드 on/off, 반폭 위상·4+4·길이 예외 유지. 모델 교체 전 종료. | `docs/design/ROAD_DRAWING_KO.md:25–29,44–48`; `docs/ZONING_DEVELOPMENT_KO.md:3–9` |
| `test_road_junction_spacing_input` | 4칸 간격 허용·거부 실제 입력 유지. 모델 교체 전 종료. | `docs/design/ROAD_DRAWING_KO.md:36–42,48` |
| `test_road_length_units` | 전체 경간 철거·8m/4m 단언 유지. 클릭 전 hover·좌표가 있는 press/release 준비. | `docs/design/ROAD_DRAWING_KO.md:31–34`; `docs/SKILL_HANDOFF_KO.md:112–118` |
| `test_road_midpoint_connections` | 양측 중간 접속·연장을 실제 카드와 지도 클릭으로 계속 검증. 모델 교체 전 종료. | `docs/design/ROAD_DRAWING_KO.md:8–10,44–56` |
| `test_road_parcels` | 중심선 간격 10→11칸으로 연석 사이 8칸 확보. 시공·중간 단계 성장 성공 단언 추가. | `docs/design/ROAD_DRAWING_KO.md:25–29`; `docs/ZONING_DEVELOPMENT_KO.md:3–9`; `docs/design/BUILDING_GROWTH_KO.md:13–18` |
| `test_road_preview_round` | 명시 폭으로 반원·클리핑·색·불변 결과 유지. 모델 교체 전 종료. | `docs/design/ROAD_DRAWING_KO.md:8–9,25–29,54–55` |
| `test_road_profile_connections` | 카드를 스크롤로 드러내고 실제 rect 클릭. 모드·차로·연결 판정 유지. | `docs/design/ROAD_DRAWING_KO.md:25–29,36–42`; `docs/SKILL_HANDOFF_KO.md:81–94` |
| `test_road_setback` | 중심을 0.5칸 옮겨 같은 연석 유지. 0/1.49/1.50m 허용과 1.51/4/8m 거부 유지. | `docs/BUILDING_ROAD_ADJACENCY_KO.md:3–21,59–61`; `docs/design/ROAD_DRAWING_KO.md:25–29` |
| `test_showcase` | 원래 10종·3도로·실 8×8 유지. 연석에 맞춰 앞/뒤 중심 y 60→60.5/49→48.5, null 명시 실패. | `docs/design/ROAD_DRAWING_KO.md:25–29`; `docs/BUILDING_ROAD_ADJACENCY_KO.md:46–49`; `docs/ZONING_DEVELOPMENT_KO.md:3–9`; `docs/register-30-assets-validation/README_KO.md:107–108` |
| `test_thumbnail_hud` | 공원 8→10, 총 C카드 23→25. 실 GLB·자금 거절·lot 불변 검증. 선로는 배치 불가만 검사. | `docs/design/BOTTOM_BAR_LAYOUT_V2_KO.md:3–9,55–57`; `docs/SKILL_HANDOFF_KO.md:283–287`; `docs/design/ASSET_REQUEST_RAIL_PARK_KO.md:39,87,112–114,141–149,156`. 수량은 현 카탈로그. |
| `test_traffic` | 100대·300 고정 스텝·간격과 유한 속도 유지. 시간 측정만 명시 옵션으로 이동(기존 성능 상한 단언 없음). | `docs/TRAFFIC_AI_KO.md:23–29,63–71` |
| `test_transit_facilities_fifo` | 종료 전 체크포인트 취득, 비어 있지 않음·boot·실제 복원 확인(7→9). 기존 FIFO와 ID 단언 유지. | `docs/design/ASSET_REQUEST_RAIL_PARK_KO.md:146–152`; `docs/SKILL_HANDOFF_KO.md:1405–1409` |
| `test_transit_facilities_view` | 실제 텍스처·픽셀·역 입력을 네이티브에서 유지. 파트 누락 명시 실패, 시설 철거 성공 4건 추가. | `docs/design/ASSET_REQUEST_RAIL_PARK_KO.md:41,54,105–107,152–157`; `docs/design/ASSET_REQUEST_TRANSIT_KO.md:23–25`; `AGENTS.md:158–173` |
| `test_ui` | 지정 비어 있지 않음→정확히 4셀, 성장 단계·건물 +1 유지. 유효 부지·실제 worker 준비 강화. | `docs/ZONING_DEVELOPMENT_KO.md:19–30,55–57`; `docs/design/INITIAL_LOT_SIZE_KO.md:5–13` |
| `test_vehicles` | 41→47. 기존 도로 41종 리그·접지·길이 유지. 신규 철도·화물 6종은 분류/메시 존재 위주. | `docs/vehicle-comparison/README_KO.md:8–14`; `docs/VEHICLE_FLEET_20_KO.md:15–21,27–33`; `docs/design/ASSET_REQUEST_TRANSIT_KO.md:29–32,59–65`. 수량은 현 카탈로그. |
| `test_zoning_development` | 취소·정지·3× 자동개발 단언 유지. 이전 worker 종료만 추가. | `docs/ZONING_DEVELOPMENT_KO.md:25–29,44`; `docs/POPULATION_TIME_KO.md:120–121` |

**제거·완화 목록.** 테스트 파일 삭제는 없다. `test_main_bottom_ui`는 현재 2×와 3×, 일반 프레임 자동 발행을 구분하지 못한다. `test_city_worker_parity`·`test_native_worker_parity`는 전체 export 키 집합 검사를 제거했다(기존 11개 값·누락의 정확 비교는 유지). `test_junctions`는 기존 집이 코너 경계에 닿던 표본을 0.5칸 떨어뜨렸고, `test_public_road_snap`의 성공 거리 표본은 1.6/1.5→1.1/1.0칸으로 짧아졌다(별도 1.5m 최종 접도 경계 유지). `test_facilities`·`test_vehicles`·`test_thumbnail_hud`의 raw GLB 대체 로드는 정상 엔진 import를 보증하지 않으며, 선로 견본 카드 분기는 클릭 무반응도 통과한다. `test_transit_facilities_view`의 headless 실행은 제거됐으나 native GL 픽셀 검사는 유지했다. `test_road_draw_modes`의 무조건 거부는 승인된 경고로 대체했고, 공공시설·내부 API의 거부 검사는 타 스위트에 남아 있다.

## 병합 전 검사 복원 (`3437b64`)

- 변경 스위트만 재실행: 헤드리스 **8/8**, 네이티브 GL **8/8**. 아래 단언 수는 두 모드에서 같았다. 전체 재실행·캡처·성능 계측·게임 코드 변경 없음. 복원 검사에서 실제 게임 회귀는 발견하지 않았다.

| 스위트 | 모드당 통과 | 복원 내용 |
|---|---:|---|
| `test_main_bottom_ui` | 149/149 | 일반 `_process`가 worker 결과를 발행한다. 2×는 192게임초, 3×는 288게임초(1.5배). |
| `test_city_worker_parity` | 54,010/54,010 | 5,400틱, 전체 키 19개 및 canonical 값 11개 정확 비교. |
| `test_native_worker_parity` | 86,410/86,410 | 같은 export 계약을 native mailbox에도 적용. 미등록·누락·값 불일치 거부. |
| `test_junctions` | 56/56 | 3칸 폭 교차로 `(51.25, 48.5)`에서 집 모서리가 포장 경계와 정확히 접한다. Preview와 실제 시공에 집 ID·발자국 유지. |
| `test_public_road_snap` | 26/26 | 양쪽 연석에서 커서 1.999칸 성공, 2.001칸 거부. 최종 접도 1.500m 허용·1.504m 거부 및 실제 클릭의 1회 차감 유지. |
| `test_facilities` | 125/125 | 정상 엔진 임포트 `PackedScene`과 쇼케이스 인스턴스 확인. |
| `test_vehicles` | 328/328 | 정상 엔진 임포트 `PackedScene`과 쇼케이스 인스턴스 확인. |
| `test_thumbnail_hud` | 184/184 | 정상 임포트 GLB 및 실제 카드 입력: 미배치·미차감·도구와 선택 불변·오류 없음. |

- 배속 허용 오차: 정상 프레임의 활성 시간을 모아 두 창을 각각 4.125초에서 종료한다. 마지막 프레임 크기 때문에 최대 0.125초를 허용하며, worker 대기와 이보다 큰 단일 프레임은 제외한다. 네이티브 표본은 4.139962초와 4.133187초였다. 48게임초(2시뮬레이션초 ×24) 단위 발행에서 이 오차는 4/6틱 판정을 뒤집지 않는다. 각 배속의 절대 오차는 미발행 잔여분 한 틱 미만, 발행 결과의 비율 자체는 정확히 1.5배를 요구한다. 수동 강제 발행은 없다.
- 정상 임포트: 실행용 사본의 `.godot/imported`를 `--headless --editor --import`로 새로 만들었다(1,520개 캐시 파일). 원본 작업 폴더의 임포트를 건드리거나 `.import`/`.uid`를 이번 커밋으로 추가하지 않았다. raw GLB 폴백과 캐시 주입은 제거했다. 원시 로그와 사본 DLL/소스 해시 확인. 프로필 scratch `restore-20261127-g1/{run.json,results.jsonl,normal-import.json,normal-import.log}`. `results.jsonl` SHA-256 `c506560c19d35cdc15cdbcd3c470a38faaf69d59c7bfb8ac5f72938e1c814bf6`.
- 승인된 예외 유지: 역 픽셀 검사는 네이티브 전용, 도로의 실제 충돌 경고는 승인된 동작, `test_roads_zoning`의 기능 단언 18/18은 이전 단일 전수 그대로다. 별도 작업의 미추적 `transit-operations-20261127/` 시안은 이번 실행 중 변경됐으나 검사 입력이 아니며 건드리거나 스테이징하지 않았다.
