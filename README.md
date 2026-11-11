# Anthropic 공개 스킬 · Codex 작업 공간

## 1B 공공시설 실제 배치 · 로컬 승인 대기

기존 C카드34종을 실제 도시 배치/초록·빨강 고스트/R회전/취소/불도저·CSV 비용에 연결했다.
[전체30/30·신규524/524+19/19·가격/용량표·실제1920 3장·적용/제외 범위](docs/1b-public-placement-validation/README_KO.md).
발전5·취수·하수2만 기존 공급 엔진에 연결, 수력댐 검사창 유지. 저장/쓰레기/서비스 효과·연료·대출·새 패널 없음.
feature/1b-public-placement 로컬 커밋까지만이며 main 병합·푸시 금지다.

## 이전 기록 · 승인된 부지 규칙 · main 통합

자동 신축4×4 우선/2×2 폴백, 수동 성장1~4단계 최대4×4·5단계8×8 우선, 축소/타 건물 철거 없음.
[전체28/28·부지86/86·새 실제1920 캡처3장·원본/숫자 보존](docs/growth-appearance-validation/lot-rules/README_KO.md).
행복도 자동 성장·가격/용량·새 UI는 구현하지 않았다. AGENTS.md 변경 없음. 사용자 승인 범위로 main 통합한다.

## 이전 작업 · 성장 외관42종 연결 · 로컬 승인 대기

주거14·상업14·공업14의 실제 모델을 용도/부지/단계밀도로 연결했다.
[45조합 후보ID·실측·전체27/27·신규302/302·실제1920 캡처6장](docs/growth-appearance-validation/README_KO.md).
시뮬레이션 수치·가격/용량 변경 없음. feature/growth-appearance 로컬 커밋까지만, main 병합·푸시 금지.

## 이전 기록 · 2026-11-11 30종 main 통합 승인 / 크기표 동기화

원격 크기표를 병합하고 소방/경찰6종 사용자 지정 상태·풍력4×4 부지를 반영했다.
[63종 표·30종 일치·전체26/26·30종635/635·원본 승인 필드/GLB 불변 검증](docs/register-30-assets-validation/approved-main-merge/README_KO.md).
모델/GLB 크기·발전량/가격/용량·성장 외관 연결은 변경하지 않았다. 이번 승인은 main 통합·푸시까지다.

## 이전 기록 · 2026-11-11 원본30종 검사 등록 (로컬 승인 대기)

상업10·공업8·발전6·상하수도4·쓰레기2를 실제 GLB/spec/PNG/파생 썸네일로 등록했다.
전력/수도/환경 탭에 기존 C형 카드12개를 추가했고, 상업·공업18개는 growth_enabled:false와 기존 전시 장면 옵션으로 본다.
새 메뉴/레이아웃, 도시 배치·성장·운영·가격/용량 적용은 없다. 기존 발전/취수/하수 배치 도구도 그대로다.
[전체26/26·신규635/635·30행 실측/예외·실제 렌더/캡처·전시 실행 명령](docs/register-30-assets-validation/README_KO.md).
원본209파일을 보존했다. 풍력 오버행/수력 시연틀 및 명명된 사람 출입구 미확인7종은 수정하지 않고 기록했다.
`feature/register-30-assets`의 **로컬 커밋까지만**이며 main 병합·푸시는 사용자 화면 승인 대기다.

## 이전 기록 · 2026-11-10 승인 fix-C 후속 수정

건물/시설23종에 실제 PNG C형 썸네일·아래 이름 띠를 적용하고, 선택/점선 키보드 포커스와 일시정지 중앙 정렬을 수정했다.
[전체25/25·실제 경찰/보건/공원 캡처·시안 비교·남은 아이콘 도구](docs/bottom-bar-v2-validation/fix-c/README_KO.md).
기획 문서2종을 내용 변경 없이 보존했다. 이번 수정과 기존 파트1/2의 main 통합·푸시까지 승인됐으며 1B/가격/시뮬레이션 변경은 없다.
원격 원본30종/역사 자료도 보존 병합했고 main에서 [전체25/25를 재실행](docs/bottom-bar-v2-validation/fix-c/main-merge/results.json)했다.

## 이전 기록 · 원본 7종 검사 등록 / 승인 A2 하단바 v2

소방·경찰·교도소 7종을 실제 GLB 검사창에 연결했다. [실측·차량 비교·23/23 회귀](docs/emergency-assets-validation/README_KO.md).
소형소방서 차고 높이 부족(약 0.13m)은 원본 수정 없이 사용자 결정 대기로 남겼다.
하단바는 승인 A2 기준 11분류·경찰 탭 교도소·수도·도시 이름 편집·실제 인구/자금/RCI를 사용한다.
행복도/월 수지는 아직 데이터가 없어 **—**다. [실제 24/24 회귀·1920/1280/960 캡처·A2 비교](docs/bottom-bar-v2-validation/README_KO.md).
두 결과는 각각 로컬 feature 브랜치이며 사용자 화면 승인 전 main 병합/푸시하지 않는다. 도시 서비스 배치/운영(1B)·가격 적용은 미구현이다.

## 이전 기록 · 본게임 하단 UI 통합 (1A)

기본 `main.tscn`에 공유 하단 HUD를 연결했다. 12분류와 우측 통합 불도저,
기존 구획·도로·전력·상하수도·정지/배속·실제 자금/인구/날짜를 사용한다.
소방·경찰·교정 7칸은 **이름만 있는 비활성 게임 등록 대기 슬롯**이며 가격·가짜 모델은 없다.
[변경·검증·Windows 실행법](docs/bottom-ui-main-validation/README_KO.md) ·
[기본 화면](docs/bottom-ui-main-validation/main-default-1920.png) ·
[소방](docs/bottom-ui-main-validation/main-fire-1920.png) ·
[교정](docs/bottom-ui-main-validation/main-corrections-1920.png) ·
[1280 화면](docs/bottom-ui-main-validation/main-fire-1280.png).
Godot 4.6.3 전체 22스크립트 통과. 1B 서비스 도시 배치/정면/철거는 다음 범위다.
이번 결과는 `feature/bottom-ui-main-integration`의 로컬 커밋이며 승인 전 원격 푸시하지 않는다.

**[사용자 피드백·반복하지 않을 실수](mistake.md)** — 작업 시작 때 읽고, 지적받은 결과와 재발 방지 방법을 계속 기록합니다.

**[주민·학력별 일자리·수요와 시간 규칙](docs/POPULATION_TIME_KO.md)** — 현실 1시간=게임 하루, 12일=1년. 실제 통근·학교 운영은 후속.

**[드래그 구획·자동 신축](docs/ZONING_DEVELOPMENT_KO.md)** · [색칠 화면](docs/zoning-validation/zones-painted.png) · [신축 후](docs/zoning-validation/zones-developed.png) — 임시 시간 기반이며 주민/수요 엔진은 다음 단계.

**[공공차량 3종·화장터 / 보건·교육 탭](docs/SERVICE_ASSETS_KO.md)** · [실제 Godot 화면](docs/service-assets-validation/service-assets.png) · [개발 현황·백로그](docs/DEVELOPMENT_STATUS_BACKLOG_KO.md)

보건·교육 기존 애셋은 보기 창에 연결돼 있습니다. 시설 도시 배치·서비스 운영은 미구현이며, 위 1A가 이를 구현했다는 뜻은 아닙니다.

**[X자·T자 실제 교차로 연결·차량 회전](docs/ROAD_JUNCTIONS_KO.md)** · [실제 주행 GIF](docs/screenshots/junctions-running.gif) · [교차로 확대](docs/screenshots/junctions-closeup.gif)

**[구획·도로에서만 타일 표시 / 우측 통합 불도저](docs/concepts/bottom-ui/DEMOLITION_ZONING_KO.md)** · [구획 선택 화면](docs/concepts/bottom-ui/actual-game-zoning.png)

**[우리 게임에서 실행한 하단 UI](docs/concepts/bottom-ui/actual-game-power.png)** · [상하수도 화면](docs/concepts/bottom-ui/actual-game-water.png) · [별도 검토 장면 실행법](docs/concepts/bottom-ui/ACTUAL_GAME_KO.md)

**[아이콘을 모두 하단으로 옮긴 UI 시안](docs/concepts/bottom-ui/concept.png)** · [배치 설명·도입 스킬](docs/concepts/bottom-ui/DESIGN_KO.md) — 검토용 그림, 현재 게임 UI 미변경.

**경제 수치 보관:** [통합 CSV](docs/economy-balance/ECONOMY_BALANCE.csv) · [단위·상태·수정 시 주의점](docs/economy-balance/README_KO.md)

**[수도 거래요금 적용·단가 수정 방법](docs/WATER_TARIFFS_KO.md)** — 상수 수입·수출/하수 위탁의 m³ 요금과 소수 doth 정산.

**[상하수도망 실제 도입·조작·가격/용량 제안](docs/WATER_SEWAGE_KO.md)** · [게임 GIF](docs/screenshots/water-game-running.gif) · [꿀렁이는 흐름 확대](docs/screenshots/water-flow-closeup.gif)

**새 담당자 시작점: [스킬 인계장 · 익힌 내용과 검증 범위](docs/SKILL_HANDOFF_KO.md)**

**새 게임 규칙: [네 이웃 마을과 도로·철도·전력·지하철·상하수도 교류](docs/REGIONAL_EXCHANGE_RULES_KO.md)**

**재화: [doth(도쓰), 기본 난이도 시작 자금 50,000 doth](docs/CURRENCY_RULES_KO.md)**

**[주거·상업·공업 구획 무료 규칙과 시설 가격 1차 제안](docs/PRICE_PROPOSALS_KO.md)** — 시설 가격은 검토 대기이며 실제 차감에는 미적용입니다.

**[가격에 대응하는 수용량·발전량·처리량 제안](docs/CAPACITY_PROPOSALS_KO.md)** — 단위·기본 수요·초반 500명 예시 포함, 검토 대기입니다.

**[지중 전력 실제 도입·거래단가·검사](docs/UNDERGROUND_POWER_KO.md)** ·
**[실제 게임 GIF](docs/screenshots/power-game-running.gif)** — 반경 64m/점 32m, 자동 수출입·kWh 정산 적용. 계약한도는 미적용입니다.

**[전력 공급 원칙](docs/ELECTRICITY_RULES_KO.md)** — 충분한 전력은 연결 대상에 동시에 공급하며 하얀 원의 도착과 무관합니다.

## 공원·주차 시설

[공원 4종·주차 시설 4종과 평면 주차장 결합](docs/PARKS_PARKING_KO.md) · [실제 게임 화면](docs/screenshots/facilities-8.png) · [결합 예시](docs/screenshots/parking-merged.png)

전용 `cities-do-modular-facilities` 지침을 추가했습니다. 건설 화면의 **공원·주차 시설 전시**에서 확인할 수 있습니다.

## GitHub에서 결과 보기·다운로드

**[전체 결과·다운로드 안내](docs/GITHUB_DOWNLOADS_KO.md)** ·
[주행 AI 시점 프로젝트 ZIP](https://raw.githubusercontent.com/rlatkdeh0001-creator/simcity/main/downloads/cities-do-traffic-ai.zip) ·
[도로 주행 GIF](docs/screenshots/traffic-ai-running.gif) ·
[검증 보고서](docs/TRAFFIC_AI_KO.md)

소스·애셋·제작 원본·스킬·라이선스·검증 기록은 이 저장소에 있습니다.
과거 시점 전체 ZIP과 최초 복구 백업은 [GitHub 다운로드 폴더](https://github.com/rlatkdeh0001-creator/simcity/tree/main/downloads)에서도 받을 수 있습니다.

## 2026-11-01 복구 조사

[최초 조사 시 확보된 파일·누락 범위](docs/recovery/RECOVERY_KO.md)를 기록했습니다.
이후 vehicle 스킬을 고정 커밋에서 재설치하고 [차량 20종을 새로 제작](docs/VEHICLE_FLEET_20_KO.md)했습니다.
Road Generator 0.9.5는 고정 원본에서 재설치해 [도로 주행 AI를 연결·검증](docs/TRAFFIC_AI_KO.md)했습니다.
이전 환경의 후속 건물 애셋과 도로 수정 어댑터는 아직 회수되지 않았습니다.
`python3 tools/verify_vehicle_fleet.py`로 차량 파일의 존재·구조를 검사할 수 있습니다.

Claude 자체 대신, 공식 Anthropic 스킬 중 Apache-2.0 라이선스가 확인된 스킬을 Codex 프로젝트 경로 `.agents/skills/`에 설치했습니다. Claude 로그인이나 Claude Code가 필요하지 않습니다.

출처: https://github.com/anthropics/skills
고정 출처 커밋: `ca45fc496a3436251f191354091d557da31c15b5`
각 폴더의 LICENSE.txt 및 THIRD_PARTY_NOTICES.md를 유지했습니다. 원본 스킬은 수정하지 않았습니다.

## 설치한 스킬

Anthropic 공개 스킬 13개 외에 로컬 프로젝트 스킬 `cities-do-construction`,
`cities-do-vehicles`와 MIT 원본 `vehicle`이 있습니다.
차량 원본의 고정 출처와 해시는 `.agents/skills/vehicle/UPSTREAM.json`에 있습니다.
도로 주행 개발용 `game-ai`, `godot-gdscript`, `godot-gdscript-headless-testing`도
원본·참고자료·Apache-2.0 라이선스·고정 출처와 함께 설치했습니다.

- `academy-guide`
- `algorithmic-art`
- `brand-guidelines`
- `canvas-design`
- `discernment-nudge`
- `frontend-design`
- `internal-comms`
- `mcp-builder`
- `skill-creator`
- `slack-gif-creator`
- `theme-factory`
- `web-artifacts-builder`
- `webapp-testing`

## 사용

이 저장소에서 “frontend-design 스킬로 페이지를 만들어 줘”, “web-artifacts-builder 스킬로 앱을 만들어 줘”, “webapp-testing 스킬로 확인해 줘”처럼 요청하세요. 에이전트가 해당 SKILL.md를 읽고 적용합니다. 현재 대화에서도 파일을 직접 읽어 사용할 수 있습니다. 새 세션의 자동 목록 표시는 클라이언트의 프로젝트 스킬 탐색 지원에 따라 달라집니다. AGENTS.md에도 적용 절차를 기록했습니다.

스킬 파일과 참조 자료의 존재를 검증했습니다. 각 스킬의 모든 보조 스크립트 실행이나 런타임 의존성 설치까지 완료한 것은 아닙니다. 실제 작업 시 필요한 도구만 준비합니다. 외부 서비스나 API를 사용하는 개별 작업에는 별도 인증이 필요할 수 있습니다. Claude 전용 도구 지침은 사용 가능한 도구로 적용합니다.

## 제외 항목

- docx, pdf, pptx, xlsx: 별도 라이선스의 복제·배포 제한
- doc-coauthoring: 폴더 내 라이선스 파일 없음
- claude-api: Claude API 개발 전용으로 현재 요청 범위에서 제외

이 저장소는 Claude 내부의 비공개 스킬 전체를 복제한 것이 아닙니다. 잘못 설치했던 Claude Code 의존성과 미완성 미리보기 앱은 제거했습니다.

## 실제 실행 검증

[검증 결과와 호환성 보정](validation/RESULTS.md)을 확인하세요. 웹 제작·빌드·번들·브라우저 상호작용, GIF 생성, 스킬 패키징을 실행 검증했습니다. 원본 웹 제작 스크립트는 최신 의존성과의 호환 보정이 필요했고, skill-creator의 일부 자동 평가 기능은 Claude CLI에 의존합니다.

## CITIES_DO 건설 스킬

`cities-do-construction` 스킬과 Godot MVP를 추가했습니다. [실행·조작·검증](cities_do/README.md)을 참고하세요.

## 건물 애셋 제작 스킬 조사

[CITIES_DO 건물 애셋 후보와 출처 추적](docs/asset-skills/RESEARCH_KO.md)에 Blender·픽셀 아트 제작 스킬, 라이선스·환경 조건과 원본 커밋을 정리했습니다. `python3 tools/track_asset_skills.py --check-heads`로 원본 변경을 확인할 수 있습니다. 새 후보를 설치하거나 정기 모니터링을 설정한 것은 아닙니다.

## 4층 맨션 시안

[벽돌형 / 모던형 비교 이미지](assets/mansion-study/comparison.png)와 [Blender 원본·재생성 방법](assets/mansion-study/README.md)을 추가했습니다. 두 시안 모두 4×4 부지의 4층 공동주택이며 외부 생성 API 없이 로컬 제작했습니다.

## 타일·도로 시안과 100×100 예시 맵

[왕복 2차로·4차로·잔디 타일 비교](assets/road-tile-study/comparison.png)를 제작했습니다. 1칸=4m, 2차로=2칸, 4차로=4칸(보도 포함) 제안입니다. 게임은 빈 100×100 맵에서 시작해 도로 주변 구획만 표시합니다. [범위와 재생성 방법](assets/road-tile-study/README.md)을 확인하세요.

## 소형·대형 주거 8종 시안

[8개 건물 비교](assets/residential-eight/comparison.png): 소형 2×2/4×4 각각 2개, 대형 4×4/8×8 각각 2개입니다. [개별 PNG·Blender 원본·재생성 방법](assets/residential-eight/README.md)을 제공합니다. 현재는 게임 등록 전 외관 시안입니다.

## 실제 게임에서 주거 10종 보기

[Godot 실제 게임 화면](docs/screenshots/residential-showcase.png)에서 소형 4종·중형 맨션 2종·대형 4종을 같은 축척으로 나란히 볼 수 있습니다. 건설 화면의 **주거 건물 10종 전시** 버튼 또는 `godot --path cities_do residential_showcase.tscn`으로 실행합니다. [소형·중형 확대](docs/screenshots/residential-showcase-small-medium.png) / [대형 확대](docs/screenshots/residential-showcase-large.png)도 제공합니다.

## 도로 직각 구획

[실제 게임의 직선·사선·꺾임·곡선 구획](docs/screenshots/road-perpendicular-parcels.png)을 추가했습니다. 도로별 직각 좌표계에서 건설·성장을 처리하고, 곡선은 짧은 반듯한 블록으로 나눕니다. **도로 직각 구획 예시** 버튼 또는 `godot --path cities_do road_parcel_demo.tscn`으로 확인할 수 있습니다. 회전 부지는 현재 임시 입체 건물로 표시합니다.

## 2026-11-04 회수 애셋 로컬 통합

기존 차량23종을 유지하고 원본18종을 별도 등록해 총41종, 교육·의료7종을 실제 애셋 메뉴/전시에 연결했다. 원본 버스·택시는 추가하지 않았고 최종 사용자 요청으로 관련 통합을 GitHub main에 푸시한다. [범위·재현·검증·원본 보존](docs/recovered-assets-validation/README_KO.md).

## 회수된 소방·경찰·교도소 원본 7종

[이름·ID·부지와 원본/이미지 링크](docs/recovered-emergency-assets/README_KO.md). 편집 원본·시안·규격 자료 보존이며 새 게임 등록/시설 운영 구현과 구분한다.

## 나머지 원본30종·이전 도로/도시 전시장 보존

[발전소6종을 포함한 원본 목록·이미지·규격](docs/remaining-original-assets/README_KO.md). 예전 코드/전시장은 archive 아래 역사 자료로 보존하며 현재 게임에 덮어쓰지 않는다.

## 건물·시설 부지 크기

[전체63종 크기표](docs/asset-sizes/README_KO.md) · [Excel용 CSV](docs/asset-sizes/sizes.csv). 각 항목에서 원본 metadata/spec까지 열 수 있다.

## 성장 건물14종 · 애셋 전용 브랜치

[승인 대기 시안·실측·층수](docs/growth-14/README_KO.md). assets/growth-14-20261111 브랜치에만 제작하며 게임 적용/성장 등록/main 병합은 하지 않는다. 소형·중형8×8 12종은 사용자 요청으로 제외했다.
