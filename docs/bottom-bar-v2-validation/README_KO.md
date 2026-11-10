# 하단바 v2 · 승인 A2 구현 및 실제 Windows 검증

**후속 승인 fix-C:** [공통 썸네일/포커스/일시정지 수정 · 전체25/25 · 실제 캡처](fix-c/README_KO.md).
아래는 022408b의 기존 A2 검증 기록이며 파일/수치를 보존한다. 후속 수정과 파트1/2의 main 통합·푸시가 승인됐다.

기준은 파트1 `feature/emergency-assets`의 `9c10c646c0b8925ab82dfe4deadb9cc22d3652e7`.
작업 브랜치 **`feature/bottom-bar-v2`**, 체크아웃 `D:/project/simcity`.
사용자가 승인한 [A2 원본](../concepts/bottom-ui-v2/mockup-A2.png)과
[기획자 확정 사양](../design/BOTTOM_BAR_LAYOUT_V2_KO.md)을 적용했다. 기획자의 승인 기록과 시안 폴더도 이 브랜치에 포함한다.
main 병합/푸시는 하지 않는다.

## 구현 범위

- 11개 카테고리. 교정 탭을 없애고 경찰에 **파출소·경찰서·경찰본부·교도소** 4개 실제 검사 슬롯을 둔다.
  수도 표시만 변경하며 `water` 키와 기존 수도/하수도 기능은 유지한다.
- 196px 하단 dock: 위 카테고리/오른쪽 공통 불도저, 아래 왼쪽 날짜·시간 + 일시정지/1×·3×,
  웃는 얼굴 + 행복도 **—**, 글씨 없는 주거/상업/공업 수요 막대. RCI 값은 실제 population의 demand다.
- 날짜 문자열의 실제 너비에 맞춘 VBox/HBox이므로 아래 두 버튼 합친 폭(사이 간격 포함)이 날짜 폭과 같다.
  두 버튼 높이는 32px이며 날짜 변화/해상도 변경에도 컨테이너가 다시 배치한다.
- 정중앙 기본 도시 이름 **CITIESDO**: 클릭/키보드 활성화→입력, Enter 확정, Esc/포커스 이탈 취소,
  양끝 공백 제거, 빈 이름 거부. 이름은 city model에 보관하므로 기존 construction_session 참조에도 포함된다.
  디스크 저장/불러오기는 아직 구현하지 않았다.
- 아래는 사람 아이콘 + 실제 인구, 큰 `50,000 doth` 형식의 자금, 더 작은 월 수지 **—**.
  건물 수 표시를 제거했다. 오른쪽 지도/메뉴와 기존 격자·통합 철거 규칙을 유지한다.
- 실제 경제 생산자가 없으므로 행복도/수지에 시안 예시 수치를 넣지 않았다.
  미래 `set_monthly_balance(int 또는 null)`의 `+N/월` 초록 / `−N/월` 빨강 포맷은 단위 검사에서만 검증한다.
  실제 캡처는 모두 수지 —다. `game_month_closed(day_index)` 접점만 마련했으며
  기존 게임 하루=게임 한 달 단위의 시계 일자 경계 신호를 사용한다. 세금·유지비 집계/청구를 구현한 것이 아니다.
- 프레임마다 인구/수요/자금/날짜를 조회하던 visible HUD 코드를 제거했다.
  자금 변경, 시계 분 경계, 기존 고정 society tick, 명시적 사용자 refresh 이벤트를 구독하고
  스냅샷이 같으면 반환하며 변경된 필드만 다시 쓴다. reset 시 구도시 신호를 해제하고 새 도시에 연결한다.
  clock의 배율·society 고정 틱·전력/수도 계량/청구 계산은 바꾸지 않았다.

anchors + containers를 유지하고 1080p 기본 HUD 글자는 최소 18px, 자금 34px이다.
960px 폭에서는 자금 26px 등으로 조정하되 최소 18px를 유지한다. 도구 타일 폭은 실제 문구의 최소 폭으로 정하고
기존 가로 스크롤을 유지한다. 도시 이름과 재생 버튼은 Tab/Enter/Esc, 카테고리는 기존 좌우 키 순환을 지원한다.

## 실제 검증 결과

[전체 실행 결과](results.json): **24/24 스크립트 통과, 0실패**, import 성공.
요청된 `tests/test_*.gd` 파일 목록과 JSON 결과를 프로그램으로 대조한다.

| 검사 | 최종 실제 결과 |
|---|---|
| test_hud_v2 | 72/72 |
| test_main_bottom_ui | 140/140 |
| test_bottom_ui | 43/43 |
| test_emergency_assets | 79/79 |

새 검사는 실제 Enter/Esc 입력·빈/한글 이름·현금 변경 이벤트·동일값 무갱신·정지 프레임 무갱신,
실제 입주에 따른 인구/상업/공업 수요 변화·1게임일 월 경계·미래 수지 포맷·3해상도 중앙 정렬/버튼 폭/높이/영역을 검사했다.
기존 UI 검사도 11카테고리/경찰 4슬롯/실제 인구로 확장했다. 단지 실패를 건너뛰지 않았다.

RED→GREEN 증거: [카테고리 초기 실패](red-categories.log), [상태줄 초기 실패](red-status.log),
[최초 전체 22/24](results-initial.json), [그 당시 main HUD 로그](test_main_bottom_ui-initial.log).
최초 전체 실패는 기본 HSeparator 최소 높이 때문에 dock이 196px를 넘긴 것이었다.
구분선 높이를 1px로 명시해 전체를 다시 실행했고 **최종 dock은 정확히 196px, 하단 경계 안**이다.
초기/최종 로그를 서로 덮어 쓰지 않았다. 자체 diff/정적 검토이며 독립 리뷰 에이전트는 사용하지 않았다.

## 실제 Godot 캡처

[명령·종료 코드·실제 크기·SHA-256·캡처 시 상태](captures.json).
Godot 4.6.3 표준, GL Compatibility, 실제 Windows 창/뷰포트를 `frame_post_draw` 이후 저장했다.
장치/렌더러는 각 `.log` 원문에 있다. 아래 원본 캡처는 합성/리사이즈하지 않았다.

| 파일 | 실제 해상도/내용 |
|---|---|
| [main-default-1920.png](main-default-1920.png) | 1920×1080 본게임 기본 빈 도시, 서랍 닫힘 |
| [main-police-1920.png](main-police-1920.png) | 1920×1080 경찰 4종·교도소 포함 |
| [main-zoning-1920.png](main-zoning-1920.png) | 1920×1080 구획 |
| [main-police-1280.png](main-police-1280.png) | 1280×820 경찰 |
| [main-police-960.png](main-police-960.png) | 960×640 경찰 |
| [review-fixture-1920.png](review-fixture-1920.png) | 1920×1080 기존 34건물 검토 도시; 본게임 초기 상태가 아님 |

각 `.state.json`은 해당 캡처 시 실제 선택 탭/서랍/도시명/인구/자금/viewport/dock을 별도로 기록한다.
본게임은 기존 빈 도시 시작을 유지했다. 시안의 건물·인구·행복도·현금/수지 예시를 본게임에 주입하지 않았다.

## A2와 나란히 비교

- [전체 비교 A2-comparison.png](A2-comparison.png): 3840×1124. 왼쪽 승인 시안, 오른쪽 실제 본게임.
- [하단 확대 비교 A2-hud-comparison.png](A2-hud-comparison.png): 3840×240. 각 원본에서 하단 196px만 잘라 같은 배율로 배치.

둘은 **비교용 합성**임을 표기했다. 생성형 그림이 아니며 원본 캡처를 대체하지 않는다.
원본 픽셀 크기를 그대로 사용하고 확대·축소하지 않았다. [입력/출력 해시·크기](comparison.json).

## 재현

프로젝트 루트 `D:/project/simcity`에서:

```powershell
$godot='C:/Users/wlgml/AppData/Local/hermes/profiles/cities-gpt/tools/godot/Godot_v4.6.3-stable_win64_console.exe'
python tools/validate_delivery.py --output docs/bottom-bar-v2-validation --godot $godot
python tools/capture_bottom_bar_v2.py --godot $godot
python tools/compare_bottom_bar_v2.py
```

1920 캡처는 작업영역 높이 제한을 피하려 fullscreen, 작은 창은 borderless를 사용한다.
비교 생성에는 기존 Pillow와 Windows Malgun Gothic 폰트를 사용했으며 폰트 파일을 복제/배포하지 않았다.

## 미구현·주의

1B 도시 서비스 배치·접도·정면/철거 연결, 소방/경찰 출동, 행복도 계산, 실제 월별 재정 집계,
가격·유지비 적용, 사운드 등록, 저장/불러오기, 대규모 성능/모바일/실물 게임패드는 이번 범위가 아니다.
파트1의 소형소방서 차고 높이 **3.40m < 소방차 3.53m** 한계는 수정하지 않았으며 사용자 결정 대기다.
원본 .blend·metadata·빌드 스크립트와 PRICE/CAPACITY/CSV 수치는 바꾸지 않았다.
기존 재임포트 .import churn/예전 미추적 .uid 8개는 커밋에서 제외한다.
