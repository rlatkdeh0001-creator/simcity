# 교통 트레이 탭·노선 오버레이 — 2026-11-23

- 작업 위치 `D:/project/simcity`, 브랜치 `perf/render-sim-cadence`, 기준 `3e2846e`. P5와 E2/E3 완료 커밋은 그대로 둔다.
- 0단계 `2831658`: 승인 시안 디렉터리만 19개 파일 그대로 커밋. HTML 양쪽 인라인 JS 문법, 로컬 이미지 참조 및 PNG 서명 확인. 문서에 적힌 기존 브라우저 25개 동작 시험은 이 단계에서 재실행하지 않았다.
- 남은 단계: 1 트레이 탭 → 2 경로 오버레이/목록 → 3 드래그·삭제 → 4 native 1920×1080 캡처와 독립 검토 1회. 각 단계 별도 커밋. 승인 기준 `docs/concepts/transport-tabs-20261119/DECISION_KO.md`와 `mockups-v2.html?v=C`.
- 기존 미커밋·미추적 파일 및 project.godot 기존 주석 보존. Godot/dotnet은 `python tools/run_dotnet.py`로, `execute_code` 금지. 관련 검증만 하고 사용자 게임을 종료하지 않는다.

- 1단계 `1a50de1db7120869257b87d7400cb7b6ec6eaf18` (부모 `2831658`): `cities_do/bottom_ui.gd`, `cities_do/tests/test_transport_tabs.gd`. `python tools/run_dotnet.py --timeout 45 godot --headless --path cities_do --script res://tests/test_transport_tabs.gd` → `Transport tabs: 40 passed, 0 failed`, 종료 0. 실제 Viewport 마우스 입력, 세 해상도, 카드/탭/도크 배치 및 탭 기억. diff 검사와 자체 리뷰, 독립 리뷰 없음. C HTML의 카드 열기·새 노선·탭 전환과 로컬 v2 그림을 확인했다.
- 2단계 `6ae7f54cb8070b488411e1cca7f65adc2198bfff` (부모 `1a50de1`): `cities_do/bottom_ui.gd`, `cities_do/core/route_overlay.gd`, `cities_do/core/transit_line_tool.gd`, `cities_do/tests/test_route_overlay.gd`. `python tools/run_dotnet.py --timeout 30 godot --headless --path cities_do --script res://tests/{test_route_overlay,test_transport_tabs}.gd` (각각 실행) → `Route overlay: 12 passed, 0 failed`, `Transport tabs: 40 passed, 0 failed`, 각각 종료 0. 실제 플래너, 지하 투영, C 패널의 입력/높이/스크롤, 닫힐 때 process 중단. diff 검사 및 자체 리뷰. X의 삭제 동작은 3단계.
- 3단계 `ecd623985deb6865cbae009c72e87c0cb1fd07f4` (부모 `6ae7f54`): `cities_do/bottom_ui.gd`, `cities_do/main.gd`, `cities_do/core/route_overlay.gd`, `cities_do/core/route_reset_warning.gd`, `cities_do/core/transit_line_tool.gd`, `cities_do/tests/test_route_edit.gd` (신규), `cities_do/tests/test_transit_operations_view.gd` (기존 UI 흐름·worker FIFO 회귀 이전). 실제 Viewport 입력으로 공유 정류장 A/B 소유권, 23/25px, GUI 위 release 취소, 역 우선, 지하철, X/선/정차점 삭제 확인, 움직이는 열차 취소·초기화·재운행을 검증. 기존 `guard_route_edit`/`edit_transit_line`과 `443ba4e` 동작을 재사용; 모델 규칙은 수정하지 않음. diff 검사 및 자체 리뷰 후 커밋.

## 최종 검증 로그 요약

`D:/project/simcity`에서 각 스크립트를 `python tools/run_dotnet.py --timeout 45 godot --headless --path cities_do --script res://tests/<파일>.gd`로 실행. Godot `4.6.3.stable.mono.official.7d41c59c4`, 모두 종료 0, 최종 출력:

```text
Transport tabs: 40 passed, 0 failed
Route overlay: 12 passed, 0 failed
Route edit: 25 passed, 0 failed
TRANSIT_OPERATION_SAFETY checks=15 failed=0
TRANSIT_OPERATIONS_VIEW checks=56 failed=0
```

총 148개. 기존 `BuildingViews`는 headless에서 3D 역 모델을 렌더하지 않으므로 operations-view의 원본 역 텍스처 확인만 native 전용으로 유지했다. 모의 UI가 아닌 실제 게임 장면/Viewport 이벤트 및 네이티브 worker 경계 검사. 과거 캡처용 `test_transit_commuting_view.gd`, `test_terminal_turnback_native.gd` 및 구 UI의 `test_review_fix_dialog.gd` 자체 실행은 이번 범위에서 제외했다(폐기된 카드/흐름을 참조하므로 그대로 재실행하지 말 것; 새 `test_route_edit.gd`가 새 흐름에서 열차 경고/리셋을 검증). 기존 집계 P5와 프로젝트 설정, 외부 작업은 수정/스테이징하지 않음. 설치·측정·캡처·push 없음.

## 부모 4단계: 1920×1080 native 재현

`python tools/run_dotnet.py --timeout 300 godot --path cities_do --rendering-method gl_compatibility --resolution 1920x1080 --script res://tests/test_route_edit.gd -- --route-review=tray` (아래 모드만 교체). 테스트 장면은 저장하거나 캡처하지 않고 계속 열려 있다. 출력 `Route review ready`의 Viewport 크기와 native 캡처 크기를 각각 확인. 1920×1080 창이 Windows 작업 영역에 맞지 않으면 부모가 사용하는 native 전체 화면/캡처 방식 적용.

- `tray`: 버스 기본 트레이; 실제 탭 클릭으로 버스, 지하철, 기차를 순서대로 확인. 기차에만 높이 도구.
- `bus`: 실제 왕복 도로와 두 노선이 공유하는 정류장의 분리된 점; 한 노선 점을 다른 정류장에 놓거나 빈 곳으로 이동. 목록 X → 취소도 재현 가능.
- `metro`: 실제 지하 지형과 지하철 노선. `새 노선 추가` → 두 고리 → 첫 고리를 다시 클릭해 생성.
- `freight`: 연결된 실제 철도 루프와 화물 노선의 점선, 열차 탭의 두 생성 버튼.
- `warning`: 운행 중인 열차의 A–C 사이 B역 삽입을 이미 요청한 상태. 기존 초기화 경고가 열려 있다.

5개 fixture는 위 명령에 `--headless`를 넣고 사용자 인수 `--fixture-check`를 추가해 각각 준비/정상 종료를 검증했다(패턴: `python tools/run_dotnet.py --timeout 30 godot --headless --path cities_do --script res://tests/test_route_edit.gd -- --route-review=<mode> --fixture-check`); 각 `Route review ready: <mode> (1920.0, 1080.0)`, 종료 0. Native GL에서 수정 전 `test_route_edit.gd` 25개와 1920×1080 무저장 장면 5종을 확인했다. 허용된 독립 리뷰 1회는 `ecd6239`에서 완료했다. 발견 사항: 동일 경로 겹침의 노선 ID 선택, 공유 정류장 점의 24px 기준, 창 포커스를 잃거나 화면 밖에서 놓을 때의 끌기 취소, 폐기된 카드에 의존하는 기존 시험 입력. 이 항목들을 수정한 뒤 실제 화면에서 기차 탭 마지막 카드 잘림을 추가로 발견해 고쳤다. 오버레이 겹침은 결정론적 차로 분리로 해결하고, 24px은 공유 정류장 원위치 기준으로 계산하며, 창 포커스 상실과 화면 밖 release는 취소한다.

## 4단계 최종 검증

- 관련 12개 suite, 중복 제외 **376개 통과**: transport_tabs 49, route_overlay 17, route_edit 31, transit_view 35, transit_facilities_view 49, elevated_rail_ui 25, underground_rail_ui 32, review_fix_dialog 42, terminal_turnback_native 12, transit_commuting_view 12, transit_operations_view 57, transit_operation_safety 15. 앞의 두 레이아웃/오버레이 suite와 안전 검사는 headless, 나머지는 native GL. rail chooser 이전 실패는 최종 native 57/57로 해소했다. 오류가 있던 중간 시도는 통과 수에 넣지 않았다. 세 해상도 모두 마지막 카드 전체 표시 검사 포함.
- 최종 native 캡처 7장, 1920×1080: `tray-0.png` 버스, `tray-1.png` 지하철, `tray-2.png` 기차, `bus.png` 공유 정류장, `metro.png` 지하 보기, `freight.png` 화물 점선, `warning.png` 철도 편집 경고.
- 캡처 재현: `python tools/run_dotnet.py --timeout 35 godot --path cities_do --rendering-method gl_compatibility --max-fps 30 --resolution 1920x1080 --fullscreen --script res://tests/test_route_edit.gd -- --route-review=<tray|bus|metro|freight|warning> --capture-route-review=D:/project/simcity/artifacts/transport-tabs-20261123`. `tray`는 실제 탭 3개를 순회해 저장한다.
- 목록/카드 등 조작 UI 팔레트와 별도로, 노선 식별은 승인 C 시안의 지도용 노선 색을 적용했다. 노선이 겹치는 구간은 같은 노선의 방향별 6px 간격 규칙을 유지하면서 노선별로 분리했다.
