# 독립 검토 수정 (review-fix-20261119)

브랜치 perf/render-sim-cadence. 바탕은 eee20fc(E3b)다. 검토 기록은 deleg_e1197e88에 있다.
- 수정 2: `5404974`
- 수정 1: `b9578aa`
- 수정 3: `443ba4e`

## 고친 것

### 1. 불도저 선택이 높이를 무시함 (BLOCK)
위치: `transit_view.pick_drawn`, `main.demolition_target`, `main.set_demolition_view`

**규칙** (사용자 확정 2026-11-19, `ASSET_REQUEST_ELEVATED_TUNNEL_KO.md` 5절 8번)
- 불도저는 지상 보기로 시작한다. 지상 보기는 지상 물체만 잡는다.
  - 지면 도로·철도, 고가 상판(경사로 포함), 트렌치, 입구
- PgDn을 누르면 지하 보기가 된다. 불도저에는 높이 단계가 없어서 PgDn이 곧 지하 보기다.
  - 지하 보기는 지하 물체만 잡는다. 덮개 구간의 도로·철도와 metro다.
  - 아무것도 잡히지 않아도 지상 도로·철도·상판으로 넘어가지 않는다.
  - PgDn을 다시 눌러도 지하 보기 그대로다.
- PgUp을 누르면 지상 보기로 돌아온다.
- 트렌치와 입구는 두 보기 모두에서 잡힌다.
- 철도도 도로와 같은 규칙이다. 원래 결함은 철도 판정에 덮개 필터가 없던 것이다(옛 `main.gd` 653행 부근).
- 정류장·역·건물·구역 선택은 바꾸지 않았다. 두 보기 모두 예전 순서 그대로다.

**투영 방식** (예전 안 그대로)
- 도로와 철도를 가리지 않고, 각 구조물을 그려진 높이로 투영해 판정한다.
- 올림 식은 그리기 코드와 같다.
  - 화면에서는 `h·tile.x/4·√1.5` px만큼 올린다(`transit_view.project_point`, `elevated_road_renderer` 43행, `road_drawing` 242행과 같은 식).
  - 지면 기준으로는 (1,1) 방향으로 `h·tile.x/4·√1.5/(2·tile.y)` 칸이다.
  - 선분을 따라 높이가 선형으로 변하는 리본을 정확히 역투영한다. 경사 구간도 포함한다.
- 구조물 하나를 세 층으로 나눈다(`drawn_pieces`의 layer).
  - surface: 지면 구간(평평하게)과 고가·경사로(그 높이). 지상 보기에서만 본다.
  - open: 트렌치와 입구. 지면 개구부에서 잡는다. 트렌치 안의 내용물이 개구부에서 잘려 그려지기 때문이다. 두 보기 모두에서 본다.
  - covered: 덮개 구간(도로 `portal_for` 이하, 철도 `RAIL_PORTAL_M` 이하)과 metro. 그려진 깊이에서 잡는다. 지하 보기에서만 본다.

**판정 순서** (`demolition_target`)
- 지상 보기: 공공시설 → 전력·수도 → 건물 → surface·open
- 지하 보기: covered → 공공시설 → 전력·수도 → 건물 → open
  - 지하 층은 월드 위에 그려지므로 먼저 본다.
  - 마지막 단계에 surface가 없다. 그래서 지상 도로·철도·상판으로 넘어가지 않는다.

**여러 개가 잡힐 때** (예전 안 그대로)
- 높이가 높은 것이 이긴다. 고가 상판과 밑의 도로가 겹쳐 보이는 곳에서는 상판이 잡히고, 상판 밖에서는 밑의 도로가 잡힌다.
- 높이가 같으면 위에 그려지는 층이 이긴다.
- 그래도 같으면 기존 순서를 따른다. 철도는 뒤 노선, 도로는 앞 번호가 이긴다.

**PgDn/PgUp** (`main._unhandled_input`, `main.set_demolition_view`)
- 불도저 모드에서만 받는다. 도로·철도 도구의 높이(`target_height_m`)는 바꾸지 않는다.
- 보기를 바꾸면 누르고 있던 철거 선택을 취소하고, 마우스 위치의 강조를 새 보기 기준으로 다시 고른다.
- 불도저를 끄면 지상 보기로 돌아간다(기존 `toggle_demolition`).

**E1 고가도로**
- 같은 결함이 있었다. 상판을 누르면 아무것도 잡히지 않았고, 상판이 덮는 곳에서는 밑의 도로가 잡혔다.
- 같은 함수로 고쳤다. E1은 지피티 코드다.

**강조 표시**
- 마우스를 올렸을 때의 노선 강조 폴리곤도 그려진 높이로 만든다. 지상 보기는 surface·open을, 지하 보기는 covered까지 칠한다.

**예전 안에서 바꾼 것**
- 예전 안은 지하 보기에서 덮개 구간·metro가 잡히지 않으면 지상 규칙으로 넘어갔다. 이제는 넘어가지 않고 트렌치·입구만 본다.
- 불도저에는 PgDn/PgUp 처리가 없었다. 새로 만들었다.

**커밋**
- `b9578aa` fix: bulldozer picks only objects in the current ground/underground view (by cities-claude)
- 파일 4개: `core/transit_view.gd`, `main.gd`, `tests/test_underground_road_ui.gd`, 새 `tests/test_review_fix_ui.gd`
- 범위 밖 파일은 0개다(`git show --name-only`로 확인).

**테스트 (본 작업 트리, headless)**
- test_review_fix_ui 53/53, test_underground_road_ui (PASS 66), test_underground_rail_ui (PASS 32), test_elevated_road_ui (PASS 60), test_elevated_rail_ui (PASS 25), test_transit_view 35/35
- demolition_target를 쓰는 기존 테스트: test_demolition 48/48, test_road_length_units 42/42
- test_road_length_units는 끝날 때 `ERROR: 3 resources still in use at exit`를 찍는다. 5404974에서도 똑같이 찍으며, 단정 실패는 아니다.
- 렌더링 장치가 필요한 실패는 없었다. 그래서 native로는 돌리지 않았다.
- RED: 새 test_review_fix_ui를 5404974에서 돌리면 53개 중 21개가 실패한다.
  - 터널 위 도로를 누르면 철도 터널이 잡힘, 상판이 안 잡힘, 상판이 덮는 곳에서 밑 도로가 잡힘, PgDn 무반응, 지하 보기에서 지상 물체가 잡힘 등이다.

**단독 검증**
- 깨끗한 worktree `D:/project/simcity-e3a-red`를 b9578aa로 옮겨 위 8개 테스트를 headless로 돌렸다. 모두 통과했다.
- 끝난 뒤 eee20fc로 되돌렸다. 그 worktree의 `tests/review_tmp_*.gd`는 검토자가 남긴 것이며 건드리지 않았다.

**범위 밖으로 남긴 것 (작업 트리에 그대로 있음)**
- 수정 3(편성): `tests/test_review_fix_regen.gd` (그 뒤 `443ba4e`로 커밋했다. 3절)
- 마지막 커밋에 넣을 것: `tools/verify_review_fix.py`, `tools/manifest_review_fix.py`, 이 폴더
  - 이번 실행으로 6개 테스트(test_review_fix_ui, 위 E-단계 UI 4개, test_transit_view)의 로그와 `test-results.json`이 갱신됐다.
  - `test_review_fix_ui-native.log`와 캡처는 예전 판 테스트로 찍은 것이다. 캡처 장면(수정 2) 코드는 바꾸지 않았다.
- 커밋하지 않는 것: `project.godot` 머리 주석, docs/**, mistake.md, .import/.uid, visible_sample.*

### 1-2. 지하 보기 표시 (사용자 규칙 2026-11-19)
원문: "지하보기에서는 지하에있는 도로,철도,지하철만 보여야해". 기획서 `docs/design/ASSET_REQUEST_ELEVATED_TUNNEL_KO.md` 8항.

**규칙**
- 지하 보기에 보이는 것
  - 덮개 구간(도로·철도), 지하철 터널, 승강장 실루엣
  - 그 안의 지하철·터널 열차, 덮개 구간 자동차
  - 트렌치와 입구(두 보기 모두)
- 지하 보기에서 숨기는 것
  - 건물, 공공시설, 구획 색·격자, 지상 도로(차선 표시 포함)·철도, 고가 상판·교각, 전차선·전주
  - 지상 차량·열차, 정류장, 지상 역, 전력·수도
- 지형: 숨기지 않는다. `7e9275` → `9a9e97`로 바꾼다.
  - 채도는 0.20 → 0.03이고, 밝기(L)는 0.263 → 0.336이다. 어둡게 하지 않았다.
- 불도저(지하 보기): 덮개 구간·지하철 → 지하철역(승강장 실루엣) → 트렌치·입구 순서로 판정한다.
  - 건물·공공시설·전력·수도·지상 역은 잡히지 않는다.
  - 지상 보기 동작은 그대로다.

**구현**
- 진입 경로 4개는 모두 `transit_view.underground`를 바꾸고 `sync_visibility()`를 거친다: 도로 도구 음수 높이, 철도 도구 음수 높이, 지하철 도구, 불도저 PgDn.
  - 지하철 도구는 렌더러가 매 프레임 부르는 `sync_visibility()`로 들어온다.
  - `road_drawing.gd`는 이미 `sync_visibility()`를 부르므로 고치지 않았다.
- `sync_visibility()`는 지상 선로 층(`rail_layer`)을 숨기고, 렌더러의 `sync_view_layers()`를 부른다.
  - `sync_view_layers()`는 부모 노드 단위로 숨긴다: zones·grid, roads, marks, WorldActors, power_overlay, water_overlay.
  - 지형은 색만 바꿔 다시 그린다. 길가 풀밭·건물 진입로 포장은 지상 도로·부지에 딸린 것이어서 지하 보기에서는 그리지 않는다.
- 지하 보기 중에 생긴 건물·차량도 숨겨진 WorldActors 밑에 생기므로 보이지 않는다.
- 트렌치 방호벽과 입구 윗면은 WorldActors 안에 있었다.
  - 새 노드 `TrenchBarriers`로 옮겼다. WorldActors와 함께 y-sort 부모 `ActorSort`(z 9) 밑에 둔다.
  - Godot의 중첩 y-sort가 두 노드의 자식을 예전처럼 함께 정렬한다.
- 덮개 구간 자동차는 지금까지 숨겼다. 이제는 그 깊이만큼 내려 지하 층(metro_layer)에 넣는다.
  - 터널 열차와 같은 방식이다. 그래서 지상 보기에서는 지하 층과 함께 숨는다. 구간별 판정은 기존 `covered_at`을 그대로 썼다.
- 불도저: 지하 보기의 판정 순서를 바꿨다(`main.demolition_target`, 새 `pick_metro_station`).
  - 지하철역이 가진 승강장 선로를 누르면 역이 잡힌다. 그 선로는 혼자 철거할 수 없기 때문이다("역과 함께 변경하거나 철거하세요").

**커밋**
- ① `d67a816` fix: bulldozer in underground view picks only underground roads, rails and metro (by cities-claude)
  - 파일 2개: `main.gd`, 새 `tests/test_review_fix_underground_view.gd`(불도저 부분)
- ② `3e2846e` feat: underground view shows only underground roads, rails and metro (by cities-claude)
  - 파일 5개: `core/cached_world_renderer.gd`, `core/transit_view.gd`, `core/underground_road_renderer.gd`, `tests/test_underground_road_ui.gd`, `tests/test_review_fix_underground_view.gd`(표시 부분)
- 두 커밋 모두 범위 밖 파일은 0개다(`git show --stat`).

**테스트**
- 새 `test_review_fix_underground_view`. 실제 main 장면에서 실제 PgDn/PgUp 키와 클릭을 쓴다.
  - 장면: 건물 2채(1채는 덮개 도로 위), 지상 도로 2개, 지상 철도와 지상 역, 정류장, 발전소, E1 고가, E2 도로 터널(트렌치·입구·덮개 구간), 지하철 노선, 지하철역
  - 진입 경로 4개마다 다음을 확인한다.
    - 숨길 층 15개가 `is_visible_in_tree()` false다.
    - 지하 층, 트렌치, 방호벽, 실루엣, 지형은 보인다.
    - 전차선은 하나도 보이지 않는다.
    - 지형은 채도가 낮아지고, 어두워지지 않으며, `15181a`와 명암비 3:1 이상이다.
  - 지상 보기로 돌아오면 모든 층이 들어가기 전과 같고, 지형 색도 원래대로다.
  - 지하 보기 중에 지은 건물은 지하 보기에서 숨고, 돌아오면 보인다.
  - 자동차
    - 지상 도로의 차는 지하 보기에서 숨는다.
    - 덮개 구간의 차는 지하 보기에서만, 지하 층에서 보인다.
  - 불도저(지하 보기)
    - 아무것도 잡히지 않는 자리: 건물 2채, 지상 역, 정류장, 발전소, 지상 도로·철도, E1 상판
    - 잡히는 것: 덮개 도로(건물 밑 포함), 지하철, 실루엣(가운데·모서리), 트렌치
    - 클릭
      - 건물 등 5곳을 눌러도 아무것도 지워지지 않는다.
      - 실루엣을 누르면 지하철역만 지워지고 지하철 노선은 남는다.
  - 결과
    - ①(`d67a816`, 깨끗한 worktree, headless): 29/29
    - ②(`3e2846e`, 깨끗한 worktree, headless): 69/69
    - ② native 캡처 실행: 74/74
    - RED: `da6c8b0`에서 69개 중 21개가 실패한다. 진입 경로 4개 모두 지상 층이 보이고 지형이 그대로이며, 불도저가 건물·역·정류장·발전소를 잡는다.
- 바꾼 기존 테스트: `test_underground_road_ui` 3곳
  - 트렌치의 z 비교 대상을 `actors.z_index`에서 `actor_sort.z_index`로 바꿨다. WorldActors가 ActorSort 밑으로 들어갔기 때문이다.
  - 방호벽 부모를 WorldActors에서 `TrenchBarriers`로 바꿨다. TrenchBarriers는 y-sort이고 WorldActors와 부모가 같다.
  - 덮개 구간 차
    - 바꾸기 전: `sprite.visible`로 "지상 보기에서 숨음"을 확인했다. 실제로는 앞 시험이 남긴 지하 보기 상태였다.
    - 바꾼 뒤: 지상 보기로 돌린 다음 `is_visible_in_tree()`로 확인한다.
    - 더한 단정: 지하 층에 있음, 지하 보기에서 보임
- 회귀(깨끗한 worktree `D:/project/simcity-e3a-red`를 `3e2846e`로 옮겨 headless로 돌림)
  - test_review_fix_ui 53/53, test_underground_road_ui 68/68, test_underground_rail_ui 32/32, test_elevated_road_ui 60/60, test_elevated_rail_ui 25/25
  - test_transit_view 35/35, test_demolition 48/48, test_review_fix_dialog 42/42
  - test_rail_catenary 87/87, test_rail_catenary_render 48/48, test_transit_geometry 227/227, test_underground_rail 100/100, test_underground_roads 90/90, test_registered_30_assets 632/632
  - WorldActors·지형 층을 쓰는 테스트: test_cached_world_render 26/26, test_facility_depth 16/16, test_roadside_verges 14/14, test_entrance_accessways 51/51
  - test_transit_facilities_view와 test_transit_operations_view
    - headless에서는 GLB·역 그림 단정이 실패한다("split GLB rendered", "actual original station parts loaded").
    - `da6c8b0`에서도 같은 단정이 같게 실패한다. 렌더링 장치가 필요한 단정이다.
    - native(캡처 없음)로 돌렸다: 49/49, 54/54.
  - ①에서도 test_review_fix_ui 53/53, test_transit_view 35/35를 깨끗한 worktree에서 확인했다.
  - 끝난 뒤 worktree를 `eee20fc`로 되돌렸다.
- 로그: `underground-view/`(②에서 돌린 최종 로그와 native 캡처 실행 로그)

**명암비 (캡처 픽셀, WCAG)**
- 고친 뒤: 가장 어두운 지하 띠 `#15181a`, 지형 `#9a9e97` → **6.55:1**
- 고치기 전: `#15181a`, `#7e9275` → 5.31:1
- 표본: 덮개 도로 띠 2점과 지하철 띠 1점 중 가장 어두운 픽셀, 그리고 빈 지형 1점

**캡처 (native 1920×1080, 같은 장면)**
- 지하 보기는 불도저 PgDn으로 열었다.
- `underground-before.png`: da6c8b0의 지하 보기
- `underground-after.png`: 고친 뒤 지하 보기
- `underground-after-ground.png`: 고친 뒤 지상 보기로 돌아온 모습
- 직접 열어 확인했다.
  - 고친 뒤 지하 보기에는 흐린 회색 지형 위에 다음만 있다: 트렌치(방호벽 포함), 덮개 도로 띠와 그 위 자동차, 지하철 띠, 지하철역 실루엣
  - 지상 보기로 돌아오면 다음이 다시 보인다: 건물 3채(지하 보기 중 지은 것 포함), 도로, 선로·전차선, 고가·교각, 역, 정류장, 발전소

**남은 것**
- 선택한 건물의 흰 윤곽선(`main._draw`)이 지하 보기에서도 그려지는지 확인하지 않았다.
- 판정 순서 때문에, 독립 지하철 노선의 띠가 실루엣 위를 지나는 곳에서는 노선이 잡힌다. 지하철역 자신의 승강장 선로는 역으로 잡힌다.
- 트렌치 안 전차선은 예전처럼 지하 보기에서 숨는다. 규칙의 '전차선·전주 숨김'을 따랐다.
- 지상 보기에서 방호벽과 차량·건물이 앞뒤로 맞게 그려지는지는 캡처로만 봤다. 이것을 단정하는 테스트는 없다(중첩 y-sort).

### 2. `rail_deck_at`이 다른 노선의 열차를 숨기거나 띄움 (MAJOR)
위치: `transit_line_planner`, `cached_world_renderer.rail_deck_at`

**노선 id 싣기**
- 운행 plan의 선분마다 그 선분이 지나는 노선 id를 싣는다(`routes`). 순환 노선과 turnback 두 leg 모두 해당한다.
- turnback의 X 건넘선 구간은 그 구간이 따라가는 중심 선분의 노선을 쓴다.
- `sample_leg`이 pose에 `route_id`를 넣는다.

**높이 결정**
- `rail_deck_at`은 그 노선의 structure만 쓴다.
  - 사전 조회 1회로 끝난다. 사전은 generation마다 캐시한다.
  - id가 없으면 0m이다.
- id는 차량마다 자기 위치의 선분에서 정해진다. 그래서 한 편성이 여러 노선을 이어 달려도 각 차량이 제 노선을 따른다.
- 계수기 `rail_deck_checks`로 호출당 1회임을 단정한다. 노선이 2개일 때와 8개일 때 같다.

**커밋**
- `5404974` fix: keep each train on its own route height near crossings (by cities-claude)
- 파일 3개: `core/cached_world_renderer.gd`, `core/transit_line_planner.gd`, 새 `tests/test_review_fix_lift.gd`
- `transit_line_planner.gd`의 hunk 5개는 모두 노선 id 관련이었다. 편성 재생성(수정 3) hunk가 섞여 있지 않아서 파일 전체를 커밋했다.
  - rail_plan의 `routes`, `_open_path`의 edge_hosts, `_turnback_leg`의 건넘선 id, `sample_leg`의 route_id
- 커밋한 코드는 eee20fc에 이미 있는 것에만 기댄다.
  - `transit_view.generation`
  - `transit_operations`의 `pose.merge`. 이 merge가 route_id를 보존한다.

**테스트 (본 작업 트리)**
- headless에서 모두 통과했다.
  - test_review_fix_lift 32/32
  - test_elevated_rail (PASS 92)
  - test_rail_catenary_render 48/48
  - test_transit_geometry 227/227
  - test_transit_view (PASS 35)
  - test_transit_render (PASS 28)
  - test_terminal_turnback 65/65, test_terminal_turnback_edit 19/19, test_terminal_turnback_catenary 23/23
  - test_transit_operations 39/39, test_transit_operation_safety 15/15
  - test_elevated_rail_ui (PASS 25), test_underground_rail_ui (PASS 32)
- native(캡처 없음)에서 통과했다.
  - test_terminal_turnback_native 11/11
  - test_transit_operations_view 54/54
- test_transit_operations_view는 headless에서 1건 실패한다.
  - 실패 항목은 역 스프라이트 로드이고, eee20fc에서도 똑같이 실패한다.
  - 렌더링 장치가 필요한 단정이라서 native로 돌렸다.

**단독 검증**
- 깨끗한 worktree `D:/project/simcity-e3a-red`를 5404974로 옮겨 돌렸다. 끝난 뒤 eee20fc로 되돌렸다.
- 범위 밖 변경이 없는 상태에서 모두 통과했다.
  - headless: test_review_fix_lift 32/32, test_transit_view, test_elevated_rail, test_rail_catenary_render, test_terminal_turnback, test_terminal_turnback_edit, test_transit_operations, test_transit_geometry
  - native: test_transit_operations_view 54/54, test_transit_commuting_view 11/11
- test_transit_commuting_view는 캡처를 한 번만 찍도록 막혀 있어서 본 트리에서는 돌리지 않았다.
  - worktree에서 기존 캡처를 잠시 옮겨 두고 돌렸다.
  - 끝난 뒤 원래 파일로 되돌렸다.

**범위 밖으로 남긴 것 (작업 트리에 그대로 있음)**
- 수정 1(불도저): `b9578aa`로 커밋했다(1절).
- 수정 3(편성): `tests/test_review_fix_regen.gd` (그 뒤 `443ba4e`로 커밋했다. 3절)
  - 그때는 `transit_operations.gd`와 `test_terminal_turnback_edit.gd`에 변경이 없었다.
- 마지막 커밋에 넣을 것: `tools/verify_review_fix.py`, `tools/manifest_review_fix.py`, 이 폴더
  - 이번 실행으로 이 폴더의 로그와 결과 json이 갱신됐다.
  - 새 로그 `test_transit_operations_view-native-no-capture.log`가 생겼다.
- 커밋하지 않는 것: `project.godot` 머리 주석, docs/**, mistake.md, .import/.uid, visible_sample.*

### 3. 노선 경로가 바뀌면 편성이 영구 동결됨 (MAJOR, P5)
위치: `transit_operations.advance`

**규칙** (사용자 확정 2026-11-19, `ASSET_REQUEST_RAIL_PARK_KO.md` 5절 12번 205~212행. 기존 P3의 '동결'을 대신한다)
- 철도·지하철·화물 노선의 plan이 운행 중 편성의 plan과 다르면 경로가 바뀐 것으로 본다.
  - 이유는 따지지 않는다. 정차 역 변경, 선로 철거·재건설 등이 모두 해당한다.
  - 3-2절에서 바뀌었다. 지나는 선과 정차 역이 같으면 plan이 달라도 경로 변경이 아니다(`route_changed`).
- 경로가 바뀌면 같은 편성을 새 경로의 첫 정차역(distance 0)으로 옮긴다. 편성을 없애지 않는다.
  - 같은 train 사전을 그 자리에서 고친다. 바꾸는 값은 경로와 위치뿐이다(plan, distance, speed, next_stop, target, departure_pending, visible).
  - 나머지 값은 그대로 둔다. departures, last_departure, kind가 여기에 들고, 앞으로 생길 승객·화물 값도 그대로 간다.
- 옮긴 편성은 새 편성과 같은 출발 규칙을 따른다.
  - 첫 역 `clear()` 검사를 통과해야 그 자리에 놓인다.
  - 통과하지 못하면 waiting이다. 놓이기 전에는 그리지 않는다(visible이 빈 배열이다). 그래서 같은 자리에 겹쳐 그리지 않는다.
  - 놓일 때 출발 시각은 첫 역 도착 규칙과 같다. `max(지금+정차 시간, 다음 배차 시각)`이다.
- 경로가 끊겨 plan이 막히면(ok=false) 편성은 그 자리에 멈춘다. 상태는 blocked이고 계속 그려진다.
  - 이때 편성에 `restart` 표시를 남긴다. 다시 달릴 수 있게 되면 plan이 예전과 같아도 시작점으로 옮긴다.
- 정차 시간·배차 간격만 바뀐 수정은 plan을 다시 짜지 않는다(87bc12e). 그래서 편성이 그대로 달린다.
- 버스는 대상이 아니다. `advance_buses`는 바꾸지 않았다.
- 한 노선에는 편성이 하나뿐이다(`transit_operation_config.json`의 "One reusable vehicle per line").
  - 그래서 '같은 노선의 여러 편성'은 첫 역이 같은 두 노선으로 시험했다.
- 이번에는 운행 동작만 고쳤다. 편집 전에 띄우는 경고창("수정사항이 있는 모든 열차가 초기화됩니다!")은 3-2절에서 구현했다.

**승객·화물**
- 편성에는 아직 탑승 승객 수나 화물 양 값이 없다(확인 대기 4). 화물 편성의 컨테이너는 그림(pose)뿐이다.
- 그래서 테스트는 편성에 승객 37명과 화물 12.5t 값을 직접 넣는다. 옮긴 뒤 같은 사전에 그 값이 그대로 있는지 본다.
- 화물 편성은 컨테이너 그림 수도 그대로인지 본다.

**테스트 갱신**
- `test_terminal_turnback_edit`의 `test_stop_change`
  - 예전 단정: 정차 역을 바꾸면 제자리에 멈춘다(blocked). 원래 순서로 되돌리면 그 자리에서 다시 달린다.
  - 바꾼 단정: 정차 역을 바꾸면 같은 편성이 새 경로 시작점으로 옮겨져 달린다. 원래 순서로 되돌리면 다시 시작점으로 옮겨져 달린다.
  - worker 상태는 복사되어 오므로, 같은 편성인지는 계수기(departures, last_departure)로 본다.
- `test_schedule_only`는 그대로 두었다.

**커밋**
- `443ba4e` fix: move trains to the line start when their route path changes (by cities-claude)
- 파일 3개: `core/transit_operations.gd`, `tests/test_terminal_turnback_edit.gd`, 새 `tests/test_review_fix_regen.gd`
- 범위 밖 파일은 0개다(`git show --stat`로 확인). 커밋 뒤 `git status --short`에서는 이 3개만 빠졌다.

**테스트 (본 작업 트리)**
- headless에서 모두 통과했다.
  - test_review_fix_regen 50/50, test_terminal_turnback_edit 20/20, test_terminal_turnback 65/65, test_terminal_turnback_catenary 23/23
  - test_transit_operations 39/39, test_transit_operation_safety 15/15, test_review_fix_lift 32/32
  - 버스 운행: test_scheduled_buses 121/121, test_transit_operations_fifo 20/20
- native(캡처 없음): test_transit_operations_view 54/54
  - headless에서는 역 스프라이트 단정 1건이 실패한다. 2절에 적은 기존 실패(eee20fc에서도 같음)라서 처음부터 native로 돌렸다.
- RED: 새 test_review_fix_regen을 b9578aa에서 돌리면 46개 중 12개가 실패한다. 공유 시작점 시험은 첫 단정에서 멈춘다.
  - 실패 내용: 편성이 시작점으로 옮겨지지 않음, 노선이 blocked로 남음, 다시 달리지 않음(철도·지하철·화물), 두 편성이 모두 그대로 그려짐

**단독 검증**
- 깨끗한 worktree `D:/project/simcity-e3a-red`를 443ba4e로 옮겨 돌렸다. 범위 밖 변경이 없는 상태에서 모두 통과했다.
  - headless: 위 9개
  - native(캡처 없음): test_transit_operations_view 54/54
- 끝난 뒤 eee20fc로 되돌렸다. 검토자가 남긴 `tests/review_tmp_*.gd`는 건드리지 않았다.

**범위 밖으로 남긴 것 (작업 트리에 그대로 있음)**
- 마지막 커밋에 넣을 것: `tools/verify_review_fix.py`, `tools/manifest_review_fix.py`, 이 폴더
  - 이번 실행으로 위 9개의 로그와 `test_transit_operations_view-native-no-capture.log`, `test-results.json`, `native-no-capture-results.json`이 갱신됐다.
  - 버스 테스트 2개의 로그(`test_scheduled_buses.log`, `test_transit_operations_fifo.log`)는 새로 생겼다.
  - 두 스크립트는 고치지 않았다. 버스 테스트와 native 운행 화면은 스크립트 목록에 없다. 그래서 스크립트의 `run()`을 불러 같은 형식으로 기록했다.
  - manifest.json은 아직 만들지 않았다.
- 커밋하지 않는 것: `project.godot` 머리 주석, docs/**, mistake.md, .import/.uid, visible_sample.*

### 3-2. 편집 전 경고창
위치: `main.gd guard_route_edit`, 새 `core/route_reset_warning.gd`, `transit_operations.route_changed`

**규칙** (사용자 확정 2026-11-19, `ASSET_REQUEST_RAIL_PARK_KO.md` 205~212행)
- 노선 경로를 바꾸는 편집은 적용 전에 경고 "수정사항이 있는 모든 열차가 초기화됩니다!"를 띄운다. 확인을 눌러야 적용한다.
- 취소하면 선로·정차 역·편성이 편집 전과 완전히 같다. 편집은 확인한 뒤에야 city에 들어간다.
- 대상: 운행 중인 편성이 있는 철도·지하철·화물 노선의 경로를 바꾸는 편집
  - 정차 역 추가·삭제·순서 변경(새 '노선 수정' 카드)
  - 노선이 쓰는 선로나, 노선 선로를 가진 역을 불도저로 철거
  - 선로 건설·재건설로 경로가 바뀌는 경우(끊긴 노선이 다시 이어짐, 더 짧은 길)
- 띄우지 않는 것: 버스 노선, 정차 시간·배차 간격만 바꾸는 편집, 편성이 없는 노선, 경로가 그대로인 공사(분기 등)
- 끌어서 그리는 선로 도구는 확정 클릭에서 한 번만 띄운다. 미리보기 중에는 띄우지 않는다.
- 한 편집이 여러 노선에 영향을 주어도 한 번만 띄운다. 편집 하나에 `guard_route_edit`를 한 번 부른다.
- 경로가 바뀐 편성을 시작점으로 옮기는 동작은 3절(443ba4e) 그대로다.

**경로 변경의 정의** (cities-claude 결정)
- `Operations.route_changed(before, after)` 하나로 판정한다. `advance()`와 경고창(`Operations.reset_lines`)이 같은 함수를 쓴다.
- 경로 변경인 것
  - plan이 막힘(ok=false), 또는 막혔던 plan이 다시 달릴 수 있게 됨
  - 종류나 turnback 방식이 바뀜
  - 정차 역 순서나 정차 지점 거리가 바뀜(허용 오차 `PATH_EPS` 0.01)
  - 편성이 지나는 선이 바뀜. 구간(turnback이면 leg)마다 꺾이는 점(`corners`)을 비교한다. 같은 직선 위의 중간 점과 겹친 점은 빼고 본다.
- 경로 변경이 아닌 것: 같은 선 아래에서 선로 조각이 쪼개지거나 합쳐짐(예: 노선 선로에 분기를 놓음)
  - 이때 편성은 그 자리에서 새 plan(새 조각 id)만 받아 계속 달린다. 경고창도 띄우지 않는다.

**경고창** (cities-claude 지정)
- 게임 안에 확인창이 없어서 새로 만들었다(`core/route_reset_warning.gd`). 경제 창 팔레트를 따른다.
  - 바탕 #142b37, 테두리 #38515e, 글자 #edf4f5, 확인 버튼 #36b7ff, 취소 버튼 #38515e
  - 문구 22px, 버튼 20px
- 화면 가운데 모달이다(전체 화면 45% 그늘, CanvasLayer 100). 문구 한 줄과 확인·취소 버튼만 있다.
- Enter는 확인, Esc는 취소다. 열려 있는 동안 다른 키·클릭·휠은 막는다(`bottom_ui._input`).

**커밋**
- ① `315912a` fix: count a route as changed only when its path or stops change (by cities-claude)
  - `core/transit_operations.gd`(route_changed, advance), `tests/test_review_fix_regen.gd`(test_branch)
- ② `da6c8b0` feat: confirm before edits that reset trains (by cities-claude)
  - `main.gd`, `bottom_ui.gd`, `core/transit_view.gd`, `core/transit_line_tool.gd`, `core/transit_operations.gd`(draft, reset_lines, line_edit_draft), 새 `core/route_reset_warning.gd`, 새 `tests/test_review_fix_dialog.gd`
  - 지정 범위 밖에서 고친 파일과 이유
    - `bottom_ui.gd`: '노선 수정' 카드를 교통 도구에 넣고, 경고창이 열린 동안 입력을 막는다.
    - `core/transit_view.gd`: 선로 그리기 도구가 확정하는 지점이 여기다.
- 두 커밋 모두 범위 밖 파일이 0개다(`git show --stat`).

**테스트**
- 새 `test_review_fix_dialog`: 실제 main 장면과 worker에서 실제 클릭과 키를 쓴다.
  - headless 42/42, native 44/44(캡처 포함)
  - 확인한 것
    - 편성 없는 노선의 정차 역 편집: 경고 없이 바로 적용
    - 정차 역 추가: 정확한 문구로 뜬다. 열린 동안 상태가 그대로이고 휠·카메라 키·지도 클릭이 막힌다.
    - 모양: 문구 한 줄과 버튼 2개, 팔레트, 18px 이상, 화면 가운데
    - Esc: 닫히고 선로·정차 역·편성 상태가 바이트 단위로 같다. 편성은 계속 달린다.
    - 확인 클릭: 적용되고 같은 편성이 시작점으로 옮겨진다. Enter: 정차 역 삭제가 적용되고 시작점으로 옮겨진다.
    - 역 B 불도저: 경고, Esc로 역 유지. B-C 선로 불도저: 경고, Enter로 철거, 편성이 그 자리에 멈춤(blocked)
    - 철도 도구로 B-C 재건설: 미리보기 중에는 경고 없음, 확정 클릭에서 경고, 확인하면 시작점에서 다시 달림
    - 분기: 경고 없음, 편성이 그 자리에서 계속 달림
    - 정차 시간만 바꾼 편집, 버스 노선 편집: 경고 없이 바로 적용
  - 443ba4e(RED): 17개 중 6개 실패. 노선 수정 카드가 없고, 불도저·재건설에서 경고가 뜨지 않는다.
- `test_review_fix_regen` 58/58. test_branch를 더했다(A-B 선로에 분기를 놓아도 같은 편성이 승객·화물 값과 함께 그 자리에서 계속 달림).
  - 443ba4e(RED, route_changed 호출만 뺀 사본): 57개 중 2개 실패. 편성이 시작점으로 옮겨진다.
- 기존 테스트(현재 작업 트리, headless): test_review_fix_ui 53/53, test_review_fix_lift 32/32, test_terminal_turnback_edit 20/20, test_terminal_turnback 65/65, test_transit_operations 39/39, test_transit_operation_safety 15/15, test_scheduled_buses 121/121, test_transit_operations_fifo 20/20, test_demolition(PASS 48줄, exit 0), test_transit_view(PASS 35줄, exit 0), test_elevated_rail_ui 25/25, test_underground_rail_ui 32/32
- native(캡처 없음): test_transit_operations_view 54/54, test_transit_facilities_view 49/49, test_terminal_turnback_native 11/11
  - 두 view 테스트는 headless에서 렌더링 장치가 필요한 단정만 실패한다(역 스프라이트, split GLB). 443ba4e에서도 같아서 native로 돌렸다.
- 단독 검증(worktree `D:/project/simcity-e3a-red`)
  - 315912a: test_review_fix_regen 58/58, test_terminal_turnback_edit 20/20
  - da6c8b0: test_review_fix_dialog 42/42, test_review_fix_regen 58/58, test_review_fix_ui 53/53, test_terminal_turnback_edit 20/20, test_elevated_rail_ui 25/25
  - 끝난 뒤 eee20fc로 되돌렸다. RED 사본(`review_tmp_dialog.gd`, `review_tmp_regen_red.gd`, `review_tmp_regen_new.gd`)은 돌린 뒤 지웠다.
- 돌리지 못한 것: test_transit_commuting_view. 한 번만 찍는 docs 캡처(`docs/transit-commuting-validation/p4-native-1920.png`)가 이미 있으면 스스로 멈춘다. docs는 건드리지 않았다.

**캡처**
- `artifacts/review-fix-20261119/warning-dialog.png`(1920×1080, native Windows). 정차 역 B를 다시 넣는 편집에서 뜬 실제 경고창이다.
- 직접 열어 확인했다. 픽셀 값도 확인했다(패널 #142b37, 확인 버튼 #36b7ff).

**범위 밖으로 남긴 것 (작업 트리에 그대로 있음)**
- 커밋하지 않음(마지막 커밋 때 넣을 것)
  - `tools/verify_review_fix.py`: TESTS에 test_review_fix_dialog와 EDIT_REGRESSION, NATIVE에 view 테스트 2개, CAPTURES에 warning-dialog, `--native-dialog`
  - `tools/manifest_review_fix.py`: stage 3(새 소스 4개, dialog native 실행)
  - 이 폴더의 로그, 결과 JSON, 캡처
- manifest 스크립트가 stage 3으로 통과하는 것을 확인했다(headless 26개, native 3개). 출력은 scratch에만 두었고 manifest.json은 아직 만들지 않았다.
- headless 결과에 잘못 넣었던 view 테스트 3개의 로그와 행은 지웠다.

**남은 것**
- 분기 시험은 곡선 분기를 실제 클릭으로 그리지 않았다. 선로 도구의 확정 함수(`transit_view.commit`)를 불렀다.
- 정차 시간만 바꾸는 편집과 버스 편집은 `main.edit_transit_line`(노선 수정 도구가 부르는 함수)을 직접 불렀다.
- 한 편집이 두 노선의 경로를 바꾸는 경우는 따로 시험하지 않았다. 경고는 편집마다 한 번 부른다.
- '노선 수정' 카드는 역을 처음 클릭하면 그 역을 지나는 첫 노선을 고른다. 여러 노선이 지나는 역에서 노선을 고르는 UI는 없다.

## 확인 대기 (기획 결정. 브리프대로 구현했고, 세부는 되돌리기 쉬운 쪽으로 정했다)

1. **불도저 선택 규칙의 세부** (규칙은 사용자 확정 2026-11-19. 아래는 cities-claude가 정한 것)
   - PgUp으로 지상 보기에 돌아오는 것, 트렌치·입구를 두 보기에서 잡는 것은 기획서 5절 8번의 'cities-claude 해석'을 따랐다.
   - metro 도구처럼 지하 보기인 도구에서 불도저로 바꾸면 지하 보기가 유지된다.
     - 기존 P1 테스트(`test_transit_view` "bulldozer preserves underground view")를 따랐다.
     - 그 밖에는 지상 보기로 시작한다.
   - 지하 보기에서 건물·역·공공시설이 잡히던 것은 1-2절에서 바꿨다. 이제 건물·공공시설·전력·수도·지상 역은 잡히지 않고, 지하철역은 승강장 실루엣으로 잡힌다(사용자 승인 2026-11-19).
   - 높이가 같을 때의 순서
     - 지상: 철도가 도로를 이긴다. 기존 판정 순서를 유지한 것이다.
     - 지하: 도로 터널이 철도 터널을 이긴다.
   - 같은 깊이에서 철도 터널과 도로 터널이 교차하는 경우는 건설 규칙에서 막힌다.
2. **트렌치 판정 폭**
   - 철도 트렌치·고가는 구조물 폭(`STRUCTURE_WIDTH`, 10m)으로 판정한다.
   - 지상 철도는 노선 폭으로 판정한다.
3. **경로 변경 처리의 세부** (규칙은 사용자 확정 2026-11-19. 아래는 cities-claude가 정한 것)
   - 운행 수(departures)와 마지막 출발 시각은 옮긴 뒤에도 이어서 센다. 같은 편성이기 때문이다.
   - 시작점에서 기다리는 편성은 그리지 않는다. 기존 생성 대기와 같은 처리다.
     - 옛 자리에 남겨 그리는 안은 쓰지 않았다. 그 자리가 철거된 선로일 수 있고, 다른 편성의 길을 막을 수 있다.
   - 놓일 때 출발 시각을 배차 간격에 맞춘다(첫 역 도착 규칙). 새로 생기는 편성은 예전처럼 정차 시간만 기다린다.
   - plan이 막혔다가 같은 plan으로 풀려도 시작점으로 옮긴다. 사용자 규칙("다시 이어지면 그때 시작점으로")을 글자 그대로 따랐다.
     - 선로를 다시 놓으면 노선 id가 바뀌므로 보통은 plan도 달라진다.
   - plan은 노선 편집이 아닌 선로 공사로도 달라질 수 있다(예: 분기를 놓아 경로가 갈리는 경우). 이유를 따지지 않는 규칙이라 이때도 시작점으로 옮긴다. 예전에는 이런 편성이 영구히 멈췄다.
     - 3-2절에서 정했다. 지나는 선과 정차 역이 같으면 경로 변경이 아니다. 분기를 놓아도 편성은 그 자리에서 계속 달리고 경고창도 뜨지 않는다.
4. **편성의 승객·화물**
   - 편성에는 탑승 승객 상태가 없다. train에는 plan, distance, speed, departures 등만 있고 occupancy가 없다.
   - P4 통근(`transit_commuting.gd`)은 매 단계 노선 그래프로 통근을 배정한다. 편성 plan이 노선 plan과 다른 동안에는 그 노선을 그래프에서 뺀다(56행).
     - 이제는 다음 운행 단계에서 편성 plan이 노선 plan으로 맞춰진다. 그래서 빠지는 시간은 길어야 한 단계다.
   - 옮길 때 사전을 그대로 두므로, 나중에 승객·화물 값이 생기면 그 값도 함께 간다.
5. **저장**
   - 게임 저장 파일 기능은 아직 없다. 상태는 `transit_lines`와 `transit_state`(worker checkpoint)로만 이어진다.
   - 확인 방법: 편집 직후 상태를 `var_to_bytes`로 왕복하고 새 Operations 런타임으로 돌렸다. 저장하지 않은 진행과 같은 편성이 나왔다.
   - 옛 코드로 동결된 편성이 든 상태를 불러와도 다음 단계에 시작점으로 옮겨진다.
   - 옛 상태의 visible pose에는 `route_id`가 없다. 그래서 첫 동기화 한 번은 0m에 그려지고, 다음 운행 단계부터 제 높이로 그려진다.

6. **지하 보기 표시의 세부** (cities-claude 결정, 1-2절)
   - 지형 색은 `9a9e97`로 정했다. 채도를 낮추고 조금 밝혔다. 명암비 기준(3:1)은 cities-claude의 해석이다.
   - 길가 풀밭과 건물 진입로 포장도 숨겼다. 남겨 두면 지상 도로와 부지의 자리가 드러나기 때문이다.
   - 지하철역이 가진 승강장 선로를 누르면 역이 잡힌다. 그 선로는 혼자 철거할 수 없다.

## 검증
- 자세한 결과는 manifest.json과 각 로그를 본다. RED 로그는 남기지 않았다.
- 새 테스트(RED 확인 뒤 구현)
  - `test_review_fix_ui`
    - 실제 main 장면에서 실제 PgDn/PgUp 키와 클릭으로 다음을 확인한다.
      - 지상 보기: 터널 위 도로, 덮개 철도·도로와 metro가 안 잡힘(지면 위치와 그려진 깊이 위치 모두), 지면 도로·철도, 철교·E1 상판과 밑 도로, 상판이 덮는 곳
      - 지하 보기: 덮개 철도·도로와 metro를 그려진 깊이에서 잡음, 지면 도로·철도·상판·밑 도로가 안 잡힘
      - 트렌치·입구: 철도와 도로 모두 두 보기에서 잡힘
      - PgDn/PgUp 전환과 반복 입력, 클릭 철거(지상: 터널 위 도로만 지움, 지하: 터널만 지움)
      - 15° 터널 위 지상 열차(수정 2)
    - 5404974에서 돌린 결과: 53개 중 21개 실패
  - `test_review_fix_lift`
    - 다음을 확인한다.
      - 교차부 ±100m에서 지상 pose의 lift가 0인지: 터널 5°·15°, 철교 19°·20°·21°
      - 거리 경계: 0.74칸, 0.76칸
      - id 없는 pose
      - 자기 노선 열차의 높이
      - 계수기
      - 순환·turnback 편성의 차량별 노선 id
    - 구현 전 결과: 15개 실패
  - `test_review_fix_regen`
    - 다음을 확인한다.
      - 정차 시간만 바꾼 수정: 같은 편성이 그대로 달림
      - 정차 역 삭제·추가: 같은 편성(같은 객체, 넣어 둔 승객·화물 값 유지)이 새 경로 첫 역으로 옮겨져 다시 달림
      - 지하철·화물: 같은 규칙, 화물 컨테이너 그림 유지
      - 버스: 옮겨지지 않음
      - 저장 왕복
      - 선로 철거: 그 자리에 멈춤(blocked, 계속 그려짐). 다시 이으면 시작점으로 옮겨져 다시 달림. 같은 plan으로 풀려도 시작점으로 옮김
      - 첫 역이 같은 두 노선: 하나만 놓이고 다른 하나는 그리지 않고 기다림, 겹쳐 그리지 않음, 차례로 출발
    - b9578aa에서 돌린 결과: 46개 중 12개 실패
- 회귀 테스트
  - E3b manifest의 회귀 목록 전부
  - `test_terminal_turnback*`(native 포함), `test_underground_road_ui`, `test_elevated_road_ui`, `test_transit_view`
  - 수정 3은 3절의 목록만 돌렸다(버스 운행 테스트 2개 포함).
  - 전체 회귀는 하지 않았다.
  - `test_terminal_turnback_native`는 실제 역 스프라이트(building_views)가 있어야 한다. headless에서는 원래부터 실패하며, E3b 목록에도 없었다. 그래서 native(캡처 없음)로 돌렸고 통과했다.
- 바꾼 기존 테스트 단정
  - `test_underground_road_ui`(E2)
    - 바꾸기 전: 지하 보기에서 덮개 도로를 지면 화면 위치에서 잡는다고 단정했다.
    - 바꾼 뒤: 그려진 깊이 위치(-10m)에서 잡는다고 단정한다.
    - 더한 단정: 지하 보기에서도 트렌치가 잡히고, 지면 진입 도로는 잡히지 않는다.
    - 이유: 사용자 규칙(지하 보기는 지하 물체를 그려진 곳에서 잡고, 지상 물체로 넘어가지 않는다).
- 캡처(1920)
  - 15° 각도로 덮개 터널 위를 지나는 지상 선로의 열차가 지상에 그려진 장면이다.
  - 직접 열어 확인했다.

## 남은 것 (다음 작업)
- 경고창은 3-2절에서 구현했다. 남은 세부는 3-2절 '남은 것'을 본다.
- 검토의 다른 항목
  - 건널목 건설 순서
  - 교각 관통
  - 전주 간격
  - support_clear 성능
- 재편집할 때 높이를 보존하는 것
