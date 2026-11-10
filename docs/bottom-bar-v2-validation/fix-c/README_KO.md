# 승인 fix-C · 건물 카드 / 포커스 / 일시정지 정렬

기준 `feature/bottom-bar-v2`의 `022408b`, 체크아웃 `D:/project/simcity`.
승인 사양은 [기획 문서](../../design/BOTTOM_BAR_LAYOUT_V2_KO.md)와 [fix-C 시안](../../concepts/bottom-ui-v2/fix-C.png)이다.
이번 수정과 기존 파트1/2의 main 통합·푸시까지 사용자 승인됐다. 1B는 포함하지 않는다.
이전 A2 결과/캡처/로그는 덮어 쓰지 않고 **fix-c 하위 폴더**에 증거를 추가했다.

## 적용

- 기존 PNG가 연결된 **23개** 건물/시설을 공통 `core/asset_thumbnail_button.gd` C형 버튼으로 표시한다.
  소방 3, 경찰/교도소 4, 보건/화장터 4, 교육 4, 공원/주차 8개다.
- 기존 PNG의 투명 여백을 정리하고 중심 기준 aspect-cover로 256×192 파생 썸네일을 만들었다.
  원본 PNG/GLB/.blend/metadata는 수정하지 않았다. UI 표시는 비율 유지 cover이며 원본 모델 축척과 무관한 썸네일 표현이다.
  파생 이미지의 둥근 알파 모서리, 최소 128×96 버튼, 아래 반투명 이름 띠/흰색 18px 이름/말줄임/전체 이름 툴팁을 적용했다.
  실제 입력 픽셀/크롭/원본·파생 해시는 `cities_do/assets/ui/thumbnails/manifest.json`에 있다.
- 모든 카드는 **애셋 검사만** 한다. 공원 8종에도 같은 읽기 전용 검사 버튼을 추가하고 기존 공원·주차 전시는 유지했다.
  공원 데이터에는 height_m가 없어 검사창은 실제 GLB 메시 AABB 높이를 사용한다. 모델/카탈로그를 덮어쓰지 않는다.
  현재 ready 상태는 유지하고, pending은 비활성/fail-closed, 비활성 카드는 직접 pressed를 보내도 검사창을 열지 않는다.
- 카테고리 활성화 시 그 카테고리로 키보드 포커스를 옮긴다. 초기 CLI 선택 탭도 맞는 포커스를 받는다.
  **선택=파란 실선/배경, 키보드 포커스=밝은 점선**으로 다르게 표시한다.
  시작 상태에는 선택된 카테고리가 없으며 첫 구획은 파란 선택 테두리가 아니다. 기존 11개 좌우 순환을 유지한다.
- 일시정지 아이콘의 native Button icon_alignment를 CENTER로 명시했다. 배속의 가운데 텍스트와 같은 기준이다.

## 실제 검사

[전체 결과](results.json): **25/25 스크립트 통과, 0실패**, import 성공.
새 thumbnail HUD **143/143**, 본게임 HUD **140/140**, 검토 HUD **43/43**, 기존 v2 **72/72** 통과.

첫 RED는 경찰 카드 부재([red-thumbnails.log](red-thumbnails.log))였고,
카드 구현 후 포커스 이동/포커스와 선택의 모양 구분/일시정지 정렬 3개의 RED를 별도로 확인했다
([red-focus-pause.log](red-focus-pause.log)). 같은 검사를 GREEN으로 바꾸고 전체를 실행했다.
23개 카드를 각각 눌러 실제 메시 검사창/도시·자금 불변을 확인했다. 비활성 강제 클릭, 점선 텍스처의 실제 빈 간격,
3해상도 경찰 4카드의 전체 영역, 기존 카테고리 키보드 순환도 검사했다.
자체 diff·정적 검토이며 독립 리뷰 에이전트는 사용하지 않는다.

## 실제 Godot 캡처

각 파일은 GL Compatibility 실제 Windows 뷰포트이며 원본을 확대·축소/합성하지 않았다.
[명령·원본 로그·해상도·SHA-256·캡처 상태](captures.json).

| 파일 | 실제 해상도 |
|---|---|
| [fix-police-1920.png](fix-police-1920.png) | 1920×1080 경찰·교도소 |
| [fix-health-1920.png](fix-health-1920.png) | 1920×1080 보건·화장터 |
| [fix-park-1920.png](fix-park-1920.png) | 1920×1080 공원/주차 8종 |
| [fix-police-1280.png](fix-police-1280.png) | 1280×820 경찰 |
| [fix-police-960.png](fix-police-960.png) | 960×640 경찰 |
| [fix-default-1920.png](fix-default-1920.png) | 1920×1080 시작 화면·선택 없음 |

[fix-C-comparison.png](fix-C-comparison.png)는 승인 시안과 실제 경찰 캡처를 나란히 둔 **비교용 합성본**이다.
두 원본은 각 1920×1080 그대로이며 위에 구분 제목만 추가했다(3840×1124).
생성형 그림/리사이즈가 아니며 원본 캡처를 대체하지 않는다. [비교 입력·출력 해시](comparison.json).

## PNG가 연결되지 않아 아이콘으로 유지한 도구 (27개)

아래는 실제 런타임을 순회한 [button-inventory.json](button-inventory.json)의 목록이다.
카테고리 아이콘/공통 불도저/지도·메뉴·시간·닫기 같은 일반 조작 버튼도 계속 기존 아이콘/문자를 쓴다.
이 목록은 디스크 전체에 그림이 없다는 주장이 아니라 **개별 건물 PNG와 연결된 선택 항목이 아닌 순수 도구/전시 진입점**이라는 뜻이다.

| 탭 | 아이콘 유지 버튼 |
|---|---|
| 구획 | 주거, 상업, 공업, 구획 해제, 건물 선택, 건물 성장, 성장 수치 +100, 주거 전시, 도시 초기화 |
| 도로 | 도로 그리기, 건물 선택, 도로 구획 예시 |
| 전력 | 지중 전력선, 발전시설, 시설 선택, 전력 설정, 전력 실습 |
| 수도 | 상하수관 함께, 취수장, 하수처리장, 시설 선택, 상하수도 설정, 상하수도 실습 |
| 공원 | 공원·주차 전시 (그 옆 개별 시설 8개는 C형) |
| 교통 | 차량 전시, 도로 주행, 주행 시험장 |

## 재현

루트 `D:/project/simcity`에서:

```powershell
$godot='C:/Users/wlgml/AppData/Local/hermes/profiles/cities-gpt/tools/godot/Godot_v4.6.3-stable_win64_console.exe'
python tools/derive_asset_thumbnails.py
python tools/validate_delivery.py --output docs/bottom-bar-v2-validation/fix-c --godot $godot
& $godot --headless --path D:/project/simcity/cities_do --script D:/project/simcity/tools/audit_hud_buttons.gd -- --output=D:/project/simcity/docs/bottom-bar-v2-validation/fix-c/button-inventory.json
python tools/capture_bottom_bar_fixes.py --godot $godot
```

감사 스크립트가 프로젝트 바깥 tools/에 있으므로 위 실행은 절대경로를 사용한다.
실제 실행 명령은 캡처/검사 JSON에 있다. 합성에는 기존 Pillow와 Windows 폰트를 사용하며 폰트 파일을 배포하지 않는다.

## 기획 문서·미구현

`MAP_SIZE_KO.md`, `VEHICLE_SPAWN_DESPAWN_KO.md`는 **내용 수정 없이** docs 커밋 `d8db5d56afdc0211d8567d8303e8fa929a238c52`에 넣었다.
[원문 보존 해시](planning-documents.json). 10km 맵·차량 출입/주차/표현 비율을 구현한 것이 아니다.
새 차량 기획에 따라 소형소방서의 3.40m 문/3.53m 차량 차이는 원본 그대로 두고 건물 안 출입을 하지 않는 향후 규칙으로 정리됐다.
이번에도 원본이나 차량/서비스/가격/시간/시뮬레이션 규칙을 변경하지 않았다. 1B·경제·사운드·대형 도시 성능은 범위 밖이다.
기존 재임포트 .import churn/예전 미추적 .uid 8개는 제외하고 새 스크립트에 필요한 .uid만 포함한다.
