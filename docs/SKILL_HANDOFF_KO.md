# CITIES_DO 스킬 인계장

최종 기록: 2026-11-02 KST. 사용자의 요청으로 이후 작업에서도 계속 갱신한다.
**새 담당자는 이 문서 → AGENTS.md → 관련 SKILL.md → 실제 코드와 검증 기록 순으로 확인한다.**
“배웠다”는 말은 모델에 영구 설치했다는 뜻이 아니다. Git에 보존한 지침·코드·출처와
검증 기록을 읽어 같은 작업을 이어갈 수 있다는 뜻이다. 자동 스킬 탐색 여부와
원본 파이프라인 전체 실행 여부도 구분한다.

## 최신 작업: 하단 통합 UI 시안·game-ui-ux 도입 (2026-11-02 KST)

사용자는 기존 실루엣 아이콘을 좋아하며 모든 아이콘을 하단에 배치한 UI 시안과
적합한 스킬 검색·도입을 요청했다. [시안/배치 계획](concepts/bottom-ui/DESIGN_KO.md),
[그림](concepts/bottom-ui/concept.png), [검색 범위·도입 기록](concepts/bottom-ui/SKILL_RESEARCH_KO.md)을 보존했다.
도시 지도는 위로 넓게 두고 8개 카테고리, 상태·자금·인구, 시간·지도·설정을 모두 하단에 모았다.
전력 도구는 선택한 메뉴 위에 얕게 펼친 상태를 그렸다. 실제 Godot UI를 바꾼 것은 아니다.

신규 `.agents/skills/game-ui-ux/SKILL.md`와 references/layout-and-flow.md를 읽어
하단 고정·가변 배치·안전 여백·포커스 및 상태별 도구 흐름의 설계 원칙을 적용했다.
원본 URL/고정 SHA/Apache-2.0/NOTICE는 아래 게임 개발 스킬 출처와 같고
새 폴더의 UPSTREAM.json에 원본 경로와 SHA-256을 저장했다.
원본 파일 4개 해시 일치 확인. frontend-design의 기존 시각 설계 지침도 참고했고,
이미지는 image_gen으로 편집 생성했다. 그림 생성 도구를 로컬 스킬로 세지 않는다.
도시 건설 전용 그림 생성 스킬을 확인했다고 주장하지 않는다. 설치한 것은 범용 게임 HUD 설계 지침이다.

1672×941 PNG를 열어 아이콘/상태의 하단 배치, 도시 지도 영역 확보, 옛 거리 표기 제거를 확인했다.
정적 시안이므로 반응형/게임패드/키보드·실제 버튼 동작은 아직 미구현/미검증이며
게임 변경이 없어 회귀 검사는 재실행하지 않았다. 이후 Godot 구현 시 현재 4.6.3에서 검증한다.

## 최신 작업: 경제 수치 통합 CSV 보관 (2026-11-02 KST)

사용자는 파일을 지금 전달할 필요 없이 저장해두라고 명확히 했다.
`docs/economy-balance/ECONOMY_BALANCE.csv` 한 파일에 재화·시작 자금·무료 구획/민간 건물,
50종 시설/노선의 건설비·유지비 제안, 상하수관 한 쌍, 실제 전기/수도 거래요금,
미정 세율/주민 사용료 및 보류 계약한도를 정리했다.
UTF-8 BOM, 한국어 9열, 141개 항목. 단위·상태·대상·현재 근거·메모를 보존했다.
미정은 빈칸이며 0이 아니다. 사용자 보관 요청 범위에 맞춰 CSV를 직접 읽는 런타임
리팩터링은 하지 않았다. 실제 코드/JSON의 현재 설정 위치는 CSV의 현재근거 열에 있다.
향후 경제 수치 편집은 이 CSV에 먼저 기록하고 적용중 항목은 코드/JSON과 동기화해 검사한다.

Python 표준 csv/json으로 원본 가격표 50종의 누락 없음, 제안 104행,
현재 전기 6/수도 9요금 일치, 중복 ID 없음, 미정 공란 및 CSV 재읽기 동일성을 확인했다.
새 스킬을 설치하지 않았고 외부 원본 지침/라이선스는 바꾸지 않았다.
프로젝트 construction 지침과 AGENTS.md에 CSV 동기화 규칙을 추가했다.
게임 코드·가격·정산 동작은 변경하지 않았으므로 기존 게임 검사를 재실행했다고 기록하지 않는다.
자세한 상태 구분은 `docs/economy-balance/README_KO.md`에 있다.

## 최신 작업: 수도 거래단가 책정·적용 (2026-11-02 KST)

사용자가 요금 책정·적용을 위임했다. [요금표/수정법](WATER_TARIFFS_KO.md),
`cities_do/core/water_tariffs.json`을 먼저 확인한다. 상수 수입/수출·하수 외부 처리의
발전도별 doth/m³ 단가를 적용했으며 주민 청구 요금·시설 공사비/유지비는 별도 미적용이다.
물량×단가, 소수 이월, 정수 자금 정산, 최적 이웃 선택과 실제 흐름 방향을 연결했다.
`city.utility_balance()`가 전기/수도 미정산액을 합산해 중복 지출을 막는다.
흐름 원의 도착과 가격/공급은 계속 독립이다.

적용 지침은 기존 construction/GDScript/headless-testing 스킬이며 새 스킬/외부 코드를 설치하지 않았다.
원본 URL·SHA·라이선스는 아래 항목과 설치 폴더를 그대로 따른다.
변경: `core/water_tariffs.json`, `core/water_grid.gd`, `core/city_model.gd`,
`core/water_overlay.gd`, `tests/test_water.gd`. 건설 스킬의 수도 단가 상태도 갱신했다.
이번 실행: `python tools/validate_water_update.py`, Godot 4.6.3에서 전용 **80/80**,
전체 **12/12 스크립트 통과**. [현재 로그](water-validation/)와 [실제 요금 화면](screenshots/water-tariffs-ui.png).
기존 GIF는 요금 도입 전 캡처이며 흐름 시연용이다. 현재 가격 상태는 새 요금 화면/문서를 따른다.
단가 JSON 수정은 게임 재시작 후 새 모델에 적용된다. 큰 시간 도약/분리 계통의 유한 예산
배분은 전 도시 최적화가 아닌 시험 정책이며 상세 한계는 요금 문서에 있다.

## 최신 작업: 상하수도망 통합 (2026-11-02 KST)

[상하수도 동작·가격/용량 제안·한계](WATER_SEWAGE_KO.md)를 읽는다.
한 번에 푸른 상수관·갈색 하수관 설치/철거, 64m/32m, 독립 공급·처리 상태,
푸른/갈색 원의 반대 흐름과 꿀렁이는 윤곽 효과를 구현했다.
원 도착·변형·표시 토글은 실제 물량과 무관하다. 부족 상수 수입, 잉여 상수 수출,
초과 하수 외부 위탁을 연결 이웃에서 처리한다. 당시 수도 단가/건설비/유지비는 미적용이었다. 이후 위 수도 요금 작업에서 거래단가를 적용했다.

이번에도 `.agents/skills/cities-do-construction/SKILL.md`,
`godot-gdscript/SKILL.md`, `godot-gdscript-headless-testing/SKILL.md`를 읽어 적용했다.
새 외부 스킬을 설치한 것이 아니며 아래 고정 SHA·출처·LICENSE·NOTICE를 그대로 보존했다.
미터 단위 그래프 재사용, 공급/표시 분리, 명시적 실패 집계를 적용했다.
전기 단가나 전력 정산을 물에 재사용하지 않았다.
변경: `core/water_{grid,flow,overlay}.gd`, `core/city_model.gd`, `main.gd`,
`water_demo.gd/.tscn`, `tests/test_water.gd`, `tools/capture_water_main.gd`,
`tools/build_water_evidence.py`, `tools/validate_water_update.py`.
건설 스킬에 현재 수도 API와 시각/실제 물량 분리 규칙을 추가했다.

이번 실행: Godot 4.6.3 상하수도 **60/60**, 전체 **12/12 스크립트 통과**.
명령 `godot --headless --path cities_do --script tests/test_water.gd`,
전체 `tests/test_*.gd` 각각 실행, 75초 제한과 종료 코드/오류 로그 검사를 적용했다.
[이번 결과](water-validation/results.json), [원본 로그](water-validation/),
[실제 게임 GIF](screenshots/water-game-running.gif), [흐름 확대](screenshots/water-flow-closeup.gif),
[일반 건설 화면](screenshots/water-main-ui.png)을 보존했다.
이번 GIF는 실제 Godot 뷰포트→Pillow이며 slack-gif-creator의 자동 파이프라인을 실행했다는 뜻이 아니다.
시설/부하/하수 80%는 시험 수치다. 수원·전원·수압·관경·오염·역류·장기 경제는 미완성이다.

## 최신 작업: 지중 전력 실제 통합 (2026-11-02)

[현재 동작·임시 수치·한계·실행법](UNDERGROUND_POWER_KO.md)을 먼저 읽는다.
64m/32m 전력망, 동시 공급, 순수 표시 흐름, 자동 수출입과 발전도별 kWh 단가를 실제 도입했다.
최신 사용자 요청으로 **거래단가 승인/적용, 계약한도 보류/미적용**이다.
발전소 외관·출력과 건물 수요는 시험값, 공사비/유지비는 승인 전이므로 미차감이다.

적용한 스킬은 `.agents/skills/cities-do-construction/SKILL.md`,
`godot-gdscript/SKILL.md`, `godot-gdscript-headless-testing/SKILL.md`다.
기존 원본 URL·고정 SHA·LICENSE/NOTICE는 아래 출처 항목과 각 폴더 그대로 보존했다.
새 외부 스킬을 추가하지 않았다. 프로젝트 construction 지침에 전력 API와 구분을 갱신했다.
공급/시간 정산/렌더 분리와 명시적 실패 집계를 실제 코드에 적용했다.
변경: `cities_do/core/power_{grid,flow,overlay}.gd`, `core/city_model.gd`,
`main.gd`, `power_demo.gd/.tscn`, `tests/test_power.gd`.

이번 실행 근거: Godot 4.6.3에서 전력 41/41, 전체 테스트 스크립트 11/11 통과.
`godot --headless --path cities_do --script tests/test_power.gd` 및 모든 tests/test_*.gd를
개별 실행했고 종료 코드와 SCRIPT ERROR/ERROR/FAIL 로그를 검사했다.
[결과/원본 로그](power-validation/results.json), [실제 GPU 화면](screenshots/power-game-export.png),
[실행 GIF](screenshots/power-game-running.gif) 보존. GIF는 실제 Godot 뷰포트→Pillow이며
slack-gif-creator 파이프라인을 이번에 재검증했다는 뜻이 아니다.
클라우드 runtime 스킬의 환경상태/네트워크 지침도 확인했다. 별도 온보딩/컨테이너 설치 작업은 하지 않았다.
인구 기반 수요, 발전소 종류별 애셋/연료, 최적 계통 배분, 장기 경제 밸런스는 후속 작업이다.

## 현재 설치 목록: 로컬 21종

아래 경로는 모두 `.agents/skills/<이름>/SKILL.md`다.
설치만 한 스킬을 실제 제작에 적용했다고 간주하지 않는다.

| 이름 | 용도 | 실제 적용·검증 상태 |
|---|---|---|
| academy-guide | Claude 학습 자료 안내 | 설치 확인. 개별 작업 실행 검증 기록 없음 |
| algorithmic-art | p5.js 생성 예술 | 설치 확인. 작품 제작 실행 미검증 |
| brand-guidelines | 브랜드 스타일 지침 | 설치 확인. 개별 적용 품질 미검증 |
| canvas-design | 정적 시각 디자인 | 2026-11-02 디자인 원칙을 지중 전력망 설명 시안에 적용. 실제 이미지는 image_gen으로 생성, Godot 캡처나 원본 자동 파이프라인 검증 아님 |
| discernment-nudge | 판단·검토 지침 | 설치 확인. 개별 적용 품질 미검증 |
| frontend-design | 웹 화면 설계 | 이전 공원 예제와 2차 지중 전력 HTML/SVG 시안에 적용. 실제 게임 UI 통합 아님 |
| internal-comms | 내부 문서 작성 | 설치 확인. 개별 적용 품질 미검증 |
| mcp-builder | MCP 서버 제작 | 설치 확인. 실제 서버/API 실행 미검증 |
| skill-creator | 스킬 작성·검사·패키징 | 이전 작업에서 메타데이터 검사·패키징 성공. 자동 평가/개선은 Claude CLI 의존 |
| slack-gif-creator | GIF 생성·검사 | 이전 작업에서 공식 도우미로 12프레임 GIF 검사 성공. 이번 주행 GIF는 Godot 캡처/Pillow 경로 |
| theme-factory | 테마 적용 | 설치 확인. 개별 작업 실행 미검증 |
| web-artifacts-builder | 웹 초기화·빌드·단일 HTML | 이전 작업에서 Vite/TypeScript/Parcel 실행 기록. 최신 의존성 보정 필요 |
| webapp-testing | Playwright 웹 테스트 | 이전 웹 검사에 더해 2차 전력 시안의 흐름/소멸/모드/모바일/동작 줄이기/JS 오류를 Chromium으로 검사 |
| cities-do-construction | 이 게임의 건설·성장·구획 | 로컬 프로젝트 지침. 기존 Godot 도시·UI·애셋·도로·구획·전시 검사에 적용 |
| cities-do-modular-facilities | 공원·직사각형 주차 시설·연결 단지 | 자체 작성. 평면 주차장 결합/내부 경계 제거/철거 분리/한 결합 메시를 69개 검사로 검증 |
| vehicle | Blender 차량 모델링·리그 | 원본 재설치. common.py의 도형·피벗 헬퍼를 차량 20종 생성기에 실제 사용 |
| cities-do-vehicles | 차량 원본 스킬의 게임용 적응 | 이번 대화에서 새로 작성. 미터 단위·좌표계·우측통행·출력·출처·검증 규약 적용 |
| game-ui-ux | 게임 HUD·메뉴·안전 영역·포커스 설계 | 이번 하단 통합 UI 시안에 배치 원칙 적용. 정적 그림이며 Godot 반응형/입력 동작은 미검증 |
| game-ai | 상태·경로·이동 분리, A* | 차선 그래프/교통 상태/렌더 어댑터 분리와 경로 재사용에 적용 |
| godot-gdscript | GDScript 구현 지침 | 교통 모듈·장면·버튼 구현에 적용. 원본 4.7 예시를 현재 4.6.3에서 검증 |
| godot-gdscript-headless-testing | 명시적 종료 코드·헤드리스 검사 | 주행 검사에서 실패 집계·비정상 종료·로그 확인·시간 제한을 적용 |

Anthropic 13종의 과거 실행 근거는 [validation/RESULTS.md](../validation/RESULTS.md)다.
새 환경에서 그 13종의 런타임을 전부 재실행한 결과가 아니다. 당시 `/workspace/skill-validation`
임시 출력이 현재도 존재한다고 가정하지 않는다. 메타데이터 검사를 작업 품질 검증으로 확대하지 않는다.

## 출처·라이선스와 실제로 익힌 내용

### Anthropic 공개 스킬 13종

위 표의 academy-guide부터 webapp-testing까지다.
출처: https://github.com/anthropics/skills

고정 SHA: `ca45fc496a3436251f191354091d557da31c15b5`, Apache-2.0.
각 폴더의 LICENSE.txt 등 제공된 출처 파일을 보존한다.
TypeScript 7의 baseUrl 제거, UI 라이브러리 API, pnpm 네이티브 빌드 승인,
Parcel 리소스 처리 등 보정 기록은 validation/RESULTS.md에 있다.
Claude 로그인 없는 문서 읽기·로컬 실행 경로와 Claude CLI 전용 자동 평가를 구분한다.
docx/pdf/pptx/xlsx 같은 별도 라이선스 스킬은 설치 목록에 없다.

### CITIES_DO 프로젝트 스킬 3종

- [cities-do-construction](../.agents/skills/cities-do-construction/SKILL.md): 기존 저장소의 자체 지침.
  건설/성장 로직과 렌더 분리, 회전 부지, 난수 분리, 기존 검사 보존을 다룬다.
  별도 LICENSE 파일은 없으며 외부 라이선스를 임의로 부여하지 않는다.
  오래된 기획·임시 수치보다 최신 사용자 합의와 실제 코드 상태를 우선한다.
- [cities-do-vehicles](../.agents/skills/cities-do-vehicles/SKILL.md): 2026-11-01 재작성본.
  이전 환경의 수정본을 회수한 것이 아니다. 새 스킬을 작성했다는 사실과 원본 재설치를 구분한다.

- [cities-do-modular-facilities](../.agents/skills/cities-do-modular-facilities/SKILL.md): 이번 요청으로 자체 작성. procedural-gen/godot-tilemap은 검토한 참고 지침이며 설치하지 않았다. [제작·69개 시설 검사·한계](PARKS_PARKING_KO.md), [검색 출처](design/MODULAR_FACILITY_RESEARCH_KO.md)를 따른다. skill-creator는 작성 원칙만 참고했고 자동 에이전트 평가를 실행하지 않았다.

### vehicle: 로컬 Blender로 차량 20종

출처: https://github.com/duolahypercho/zstack/tree/74f7786e9931b9ced858a0e2df880f23e4c2430e/skills/vehicle

MIT, Copyright 2026 duolahypercho. 원본 SKILL.md·스크립트·템플릿·참고자료·LICENSE와
[UPSTREAM.json](../.agents/skills/vehicle/UPSTREAM.json)의 파일 해시를 보존한다.

실제 사용: common.py의 `empty`, `parent_keep`, `rounded_box`, `revolve`, `tube`, `tri_count`.
Blender -Y 전방/+X 왼쪽/+Z 위 → GLB +Z 전방/+X 왼쪽/+Y 위.
운전석은 +X, 버스 승객 문은 -X. 차체·바퀴 조향/회전·적재 장치 피벗을 분리했다.

구현: [생성기](../tools/build_vehicle_fleet.py), [제작 원본·재현](../assets/vehicle-fleet/README.md),
[제작 기록](../assets/vehicle-fleet/production_log.md), [결과 보고서](VEHICLE_FLEET_20_KO.md).
20개 .blend/GLB, spec, 160장 PNG와 catalog/render_manifest를 Git에 보존했다.
가상 로우폴리 설계이며 실사 레퍼런스 IoU·문 개폐·충돌 변형 전체 검증은 하지 않았다.
원본의 모든 기능을 배웠거나 통과했다고 주장하지 않는다.

### 게임 AI/GDScript/검사/UI 스킬 4종

출처: https://github.com/gamedev-skills/awesome-gamedev-agent-skills/tree/19d93f97c9c1ea0f8b306e77aa81e0d3e352d3e9

Apache-2.0. 각 설치 폴더의 SKILL.md·하위 참고자료·LICENSE·NOTICE·UPSTREAM.json을 보존한다.
경로/의사결정/이동을 분리하고, AStar2D 차선 탐색과 30Hz 고정 시뮬레이션을 구현했다.
실제 구현·검증·제약은 [도로 주행 보고서](TRAFFIC_AI_KO.md)를 따른다.

## 스킬과 구분해야 할 도구·참고 코드

| 항목 | 설치·출처 | 실제 활용과 한계 |
|---|---|---|
| Godot Road Generator 0.9.5 | `cities_do/addons/road-generator/`, TheDuckCow/godot-road-generator, `7cbefde04e57a84499c5d8ba636c9cb4fd7d22c0`, MIT | 실제 RoadLane/RoadLaneAgent/RoadManager로 주행 위치 계산. 원본 코드 보존, Godot가 재생성한 21개 .import 변경은 UPSTREAM.json에 별도 기록. 스킬 자체가 아님 |
| city-traffic-sim | `third_party/city-traffic-sim/`, kristofsw/city-traffic-sim, `cd0e2b82f74851821d33d93e17b05b8d9754c84b`, MIT | 앞차 속도·차체 간격 기반 ACC 공식을 미터 단위로 적응. 전체 프로젝트 실행·통합으로 간주하지 않음 |
| Blender 4.3.2 / Godot 4.6.3 | 실행 도구 | 모델 생성/원본 열기와 게임 임포트/테스트/실제 OpenGL 캡처에 사용. 새 환경에서 설치·버전 재확인 |
| 건물 애셋 제작 | `assets/mansion-study/build_mansions.py`, `assets/residential-eight/build_residentials.py` | 로컬 Blender Python 경로가 확인됨. 외부 건물 전용 스킬을 도입했다고 지어내지 말 것. 후보 조사는 docs/asset-skills/RESEARCH_KO.md |

cloud-environment:cloud-environment-runtime과 cloud-environment-onboarding:setup은 플랫폼에서
제공되는 환경 스킬이다. Git의 로컬 21종에 포함하지 않는다. 이번 대화에서는 runtime의
네트워크·연결 진단 지침을 사용했다. setup의 과거 사용 기록이 있지만 이번에 환경 설정을
저장/게시한 것은 아니다. 새 채팅에서 제공 여부를 다시 확인하고 읽는다.

## 공원·주차 시설 후속 작업

공원 4종과 주차 시설 4종, 평면 주차장 결합 로직·전시를 새로 제작했다. Blender/GLB/PNG/생성기/시설 검사를 Git에 보존했다. 일반 도시의 시설 배치·도로 접면·주차 수요·차량 입출고 AI는 아직 연결하지 않았다. 기존 ZIP은 과거 스냅샷이며 새 제작 묶음과 최신 main을 확인한다.

## 검증 상태와 다음 작업

2026-11-02 사용자 명확화: **전력이 충분한 연결 범위에는 동시에 공급**한다.
하얀 흐름 원은 방향을 보여줄 뿐 도착을 기다려 공급하면 안 된다. 생성/도착/소멸/개수/
속도/표시 유무가 실제 공급·소비·수출입·요금에 영향을 주면 안 된다.
[전력 공급/표시 분리 규칙](ELECTRICITY_RULES_KO.md)에 확정 내용과 미래 검사 기준을 기록했다.
현재는 여전히 시안 단계이며 이 원칙이 공급 엔진으로 구현/검증됐다는 뜻이 아니다.

2026-11-02 지중 전력 시안 수정: 반경 **64m**, 접속점 간격 **32m**, 파란 선 위에
간헐적으로 이동하는 하얀 원. 내부 말단/수출 이웃 접속부에서 소멸하며 수입 방향도 표시한다.
[2차 독립 시안](concepts/underground-power-v2/DESIGN_KO.md)과 GIF/HTML/검사 스크립트를 Git에 보존한다.
frontend-design/webapp-testing을 실제 적용해 브라우저 동작을 검사했다. 게임에는 도입하지 않았고
발전/공급/가격 밸런스도 바꾸지 않았다. 아래 1차의 16m/8m 가정은 이번 시각 규칙으로 대체된다.


2026-11-02 사용자가 지중 전력망을 요청했으나 **바로 도입하지 말고 예시부터 보자고 명시**했다.
[시안 PNG·가정](concepts/underground-power/DESIGN_KO.md)과
[kWh 수입/수출 가격 제안](ELECTRICITY_TARIFF_PROPOSAL_KO.md)을 Git에 보존했다.
발전소의 파란 원 시작점, 8m 간격 지중 공급점, 깊이 미지정·설비 중첩 허용,
종단 시설 불필요, 이웃 전력 부족/잉여 교류가 사용자 요청이다.
16m는 시안에서 반경으로 가정했으며 지름 여부는 아직 미확정이다.
단가/초기 거래 상한은 모두 검토 대기이며 실제 전력 건설·공급·교역 코드에 적용하지 않았다.
시안은 생성형 이미지이며 실제 캡처·정밀 축척도와 구분한다. 이미지 생성 도구 자체를
로컬에 설치된 스킬로 세지 않는다. 게임 소스 미변경이므로 기존 검사를 재실행하지 않았다.

2026-11-02 [시설 용량·생산·처리량 제안](CAPACITY_PROPOSALS_KO.md)을 추가했다.
가격과 함께 검토 대기이며 실제 경제/공급/입주 계산에 미적용이다. 급수탑 저장과 생산,
재활용/소각 잔재, 직렬 네트워크 병목을 구분했고 주민 500명 예시의 산술만 확인했다.
기존 주차 모델의 4/8/16/16면은 바꾸지 않았다. 새 애셋에는 가격과 용량·자체 소비·단위를
함께 제안하도록 AGENTS.md에 기록했다. 승인 전 임의의 밸런스 수치로 구현하지 않는다.

2026-11-02 가격 논의: 주거/상업/공업 구획은 무료, 드래그 지정 후 자동 신축이 확정 설계다.
현재 수동 배치 프로토타입을 이 기능의 완성으로 간주하지 않는다.
[가격 제안 1차](PRICE_PROPOSALS_KO.md)는 검토 대기이며 차감 코드에 적용하지 않았다.
앞으로 새 애셋마다 건설비·유지비·근거를 추론해 사용자에게 제시하고 승인 상태를 기록한다.

2026-11-02 재화 규칙: **doth(도쓰)**, 기본 난이도 시작 자금 **50,000 doth**.
`core/economy_config.gd`와 도시 자금 상태·화면 표시·초기화에 적용했다.
[확정 범위](CURRENCY_RULES_KO.md)와 [이번 검사 결과](currency-validation/results.json)를 확인한다.
건설비·유지비·세금·무역 가격은 아직 미정이며 임의로 차감/지급하지 않는다.

2026-11-02에는 기존 cities-do-construction 지침을 적용해
[네 이웃 마을 교류 규칙](REGIONAL_EXCHANGE_RULES_KO.md)을 기록하고 경계 접속 상태를 구현했다.
`region_neighbors.json`의 변별 발전 수준 배치는 임시이며 수치화한 경제 효과는 없다.
도로 데이터 자동 판정, 나머지 다섯 시설의 등록/삭제 API, 독립 채널과 마지막 연결 해제를
검증했다. [새 지역 연결 검사 38/38](region-validation/test_regional_exchange.log),
[회귀 검사 결과](region-validation/results.json)를 참고한다. 이는 아직 철도·전력·상하수도
건설 UI나 실제 공급·교역이 아니며, 다음 담당자가 경계 접속과 서비스 공급을 혼동하지 않게 한다.

2026-11-01의 실제 저장 결과: [8종 검사 모두 통과](traffic-validation/results.json),
[주행 43/43](traffic-validation/test_traffic.log), [차량 외형 156/156](traffic-validation/test_vehicles.log).
원본 .blend 열기·PNG 160장 검사와 실제 주행 GIF도 해당 제작/주행 보고서에 있다.
이 수치는 이후 수정본이나 새 환경을 자동으로 검증한 결과가 아니다.

새 세션에서는 리소스를 임포트하고 관련 검사를 다시 실행한다.

```sh
godot --headless --editor --import --path cities_do --quit
godot --headless --path cities_do --script tests/test_traffic.gd
godot --headless --path cities_do --script tests/test_vehicles.gd
```

사용자와 마지막으로 확인한 미완료 사항:

- 원형 시험장의 원 안쪽이 전부 아스팔트로 채워지는 표시 문제. **아직 수정하지 않았다.**
  최종 의도는 도로 띠만 아스팔트, 내부는 지형/건설 공간이다.
- 교차로 전체 제어·안전한 차선 변경·합류·통근/물류/버스 노선·대형 도시 성능은 미완료.
- 이전 환경의 후속 건물 애셋·도로 수정 어댑터는 미회수. 원본 Road Generator 재설치와
  이전 C2 어댑터 복구를 혼동하지 않는다. [최초 인계문](recovery/ORIGINAL_HANDOFF_KO.txt) 참고.

현재 결과는 [GitHub 자료 안내](GITHUB_DOWNLOADS_KO.md)에서 확인한다.
ZIP은 특정 커밋의 스냅샷이며 이후 인계장 변경이 자동 반영되지 않는다. 최신 내용은 Git main이다.
개인 토큰·인증 헤더는 기록하지 않는다. GitHub 인증 실패 시 완료/미전송 범위를 나눠 보고한다.

## 앞으로 갱신할 양식

스킬/도구를 새로 도입·사용·수정·검증할 때 같은 작업의 커밋에 아래 내용을 추가한다.

1. 날짜, 정확한 이름, 로컬 경로, 스킬/애드온/참고 코드 구분.
2. 원본 URL·고정 SHA·LICENSE/NOTICE, 재설치인지 자체 재작성인지.
3. 실제로 읽고 적용한 기능, 변경한 구현/애셋 파일과 재현 명령.
4. 실행한 검사와 결과 파일, 상속한 과거 기록과 새 실행 결과의 구분.
5. 실행하지 않은 기능·한계·다음 담당자가 이어갈 작업.
6. Git 커밋·푸시 상태. 최종 사용자 안내에는 GitHub 링크 사용.

원본 지침을 임의로 수정해 검증 범위를 넓혀 적지 않는다. 목록을 갱신하고도
스킬 파일·보조 스크립트·라이선스를 Git에서 누락하지 않도록 실제 파일을 대조한다.
