# CITIES_DO 스킬 인계장

최종 기록: 2026-11-03 KST. 사용자의 요청으로 이후 작업에서도 계속 갱신한다.
**새 담당자는 이 문서 → AGENTS.md → [mistake.md](../mistake.md) → 관련 SKILL.md → 실제 코드와 검증 기록 순으로 확인한다.**
“배웠다”는 말은 모델에 영구 설치했다는 뜻이 아니다. Git에 보존한 지침·코드·출처와
검증 기록을 읽어 같은 작업을 이어갈 수 있다는 뜻이다. 자동 스킬 탐색 여부와
원본 파이프라인 전체 실행 여부도 구분한다.

## 최신 작업: 사용자 피드백 재발 방지 기록 (2026-11-03 KST)

사용자 요청으로 저장소 루트 [mistake.md](../mistake.md)를 신설했다. 과거 확인된 접도/
정면/교차로/횡단보도/HUD 지적과 미해결 원형 내부 노면 문제를 기존 문서에서 옮겼다.
원인·재발 방지·확인 방법·상태/근거를 구분하고, 새 기능 요청과 작업 선호를 과거 실수로
꾸며 기록하지 않도록 했다. AGENTS.md에서 모든 작업 시작 시 읽기와 피드백 발생 시
같은 작업에서 갱신하기를 지시하고 README에도 연결했다. 새 스킬/애셋/제품 코드 변경은 없다.
검증은 문서 링크·Git diff 확인만 수행하며 게임 검사를 재실행했다고 주장하지 않는다.
관련 문서를 함께 main에 커밋·푸시하고 원격 SHA를 확인한다.

## 최신 작업: 주민·5학력 취업·수요·12일 달력 (2026-11-03 KST)

시작 `/workspace/simcity`, main 9ecfa41 깨끗한 상태. 사용자가 주거만 초기 수요,
입주 후 상업/공업 수요, 5단계 학력별 정원과 ±1 취업, 외부 랜덤 학력/지역 출생 교육,
현실 1시간=1게임일·12일=1년을 확정했다. [구현·임시 기본값·재현·한계](POPULATION_TIME_KO.md),
[이번 실행 증거](population-validation/)를 참고한다. 05~09시는 1배속 현실 10분이다.

프로젝트 자체 cities-do-construction/SKILL.md와 기존 godot-gdscript/SKILL.md,
godot-gdscript-headless-testing/SKILL.md 지침을 적용했다. 전력/수도/요금 규칙도 읽었다.
자체 construction 지침을 현재 API로 갱신했고 외부 스킬·고정 출처·Apache-2.0 라이선스는
변경하지 않았다. 새 외부 설치/애셋 제작·기존 차량/화장터 변경은 없다.

변경: core/city_clock.gd, population.gd, population_config.json, city_model의 수요 허가/
고정 society 틱/철거 정리, main의 통합 시간과 utility 단위 환산, labor_rings.gd의 5개
학력별 충원/정원 표시, bottom_ui_preview의 실제 인구/취업/수요/날짜. 테스트 population과
기존 UI/구획 fixture, tools/validate_population.py·capture_population.gd.
가격 차감은 추가하지 않았고 임시 정원/확률/비율은 경제 CSV와 문서에 동기화했다.

같은 학력 우선/±1 취업·중복 고용 방지·미성년 취업 금지·지역 출생/교육 이수 API·
철거 시 실직/무주택 가구 보존을 구현했다. 학교 메뉴/출석/졸업 엔진·실제 통근·물류/
소비/생산·월 과금·저장 파일은 구현하지 않았다. 교육 이수 API가 실제 학교 운영이라는
뜻은 아니다. 전력/수도는 기존 시험 건물 부하이며 아직 주민 소비량으로 대체하지 않았다.

최종 전체 20개 스크립트 통과·주민/시간/취업 52/52. 전체 회귀 후 기하 전용 fixture와
추가 출생/나이 검사를 선택 재실행했으며 results.json은 합본이다. 캡처 해시는
population-validation/evidence.json에 보존했다. Godot 4.6.3 headless 재임포트와 전체 회귀, 별도 실제 GL Compatibility/Xvfb :99 캡처를
실행했다. 명령 python3 tools/validate_population.py; DISPLAY=:99 godot --path cities_do
--audio-driver Dummy --rendering-method gl_compatibility --script /workspace/simcity/tools/capture_population.gd.
XDG 3경로는 /tmp/cities-do-{data,config,cache}. 실제 화면은 주거4/상업2/공업2,
8가구·16명·취업16, 자금50,000, 게임02:24를 확인했다. 초기 구획 자료는 이전 증거로 유지한다.
초기 검사에서 typed Array 대입 fixture를 append로 수정했고, 기존 대형 주택 성장 이후
신축 검사는 수요와 독립인 기하 fixture임을 명시했다. 스크립트 오류와 종료 코드를 함께
검사한다. 런타임/학교/대규모 성능의 미검증 범위를 보고서에 명시했다. 코드·문서·화면을
같은 작업으로 main에 커밋·푸시하고 원격 SHA를 확인한다.

## 최신 작업: 드래그 구획 지정·해제와 자동 신축 (2026-11-03 KST)

사용자가 주거/상업/공업 드래그 지정 후 자동 신축을 승인했다. `/workspace/simcity`,
main 60dd5aa, 깨끗한 Git 상태에서 시작했다. [규칙·구현·한계·명령](ZONING_DEVELOPMENT_KO.md),
[이번 검사/실제 화면](zoning-validation/)을 확인한다. 앞선 차량·화장터 애셋은 수정/재생성하지 않았다.

기존 `.agents/skills/cities-do-construction/SKILL.md`와 `references/RULES_KO.md`,
`godot-gdscript/SKILL.md`, `godot-gdscript-headless-testing/SKILL.md` 지침을 적용했다.
construction은 프로젝트 자체 작성 지침이므로 이번 API/조작 규칙으로 갱신했다.
외부 GDScript 스킬 원본·고정 출처·Apache-2.0 라이선스는 그대로이며 새 스킬 설치는 없다.
플랫폼 환경 지침은 같은 세션 앞선 작업에서 읽은 것을 재사용했고 새 환경 설정은 하지 않았다.

변경: `city_model.gd`의 zone_designations/paint_zones/advance_development 및 자동 신축
건물의 성장 부지 용도 검사, `growth_config.gd`의 임시 2초/8틱/256검사 상한,
`main.gd`의 드래그 입력·미리보기·시뮬레이션·용도 색, `bottom_ui_preview.gd`의 구획 해제와
취소 연계, 신규 test_zoning_development 및 변경된 test_ui, tools/validate_zoning.py와
capture_zoning.gd. AGENTS/로컬 construction 지침/경제 CSV/README/개발 현황을 동기화했다.

기존 1.5m 공통 접도·정면·충돌 검사로 같은 용도 2×2를 신축한다. 덧칠/해제는 기존
건물을 변경하지 않고 도로 재생성은 살아 있는 안정 격자 ID의 지정만 유지한다.
시간 누적 신축은 실제 수요/주민/일자리/입주/자동 밀도 성장이 아니다. 저장은 메모리뿐이며
파일 저장/불러오기는 만들지 않았다. 2×2 주거 시안 growth_enabled:false를 그대로 유지하고
실제 신축은 기존 용도별 임시 입체 외형을 사용한다. 새로운 애셋·가격 제안은 없다.
구획/민간 신축 무료 수치를 바꾸지 않고 CSV의 적용 범위 설명만 갱신했다.

Godot 4.6.3 재임포트 후 전체 19개 스크립트 통과, 신규 구획 37/37,
도로 간격 49/49·정면 138/138을 이번 실행으로 확인했다. 실제 캡처 204칸 지정·
주거/상업/공업 각 4동 신축·50,000 doth 유지. 결과/캡처 해시는 zoning-validation/evidence.json.
전체 검사 후 입력 취소 검사를 보강해 신규 구획만 선택 재실행했으며 results.json은 그 합본이다.
`python3 tools/validate_zoning.py`는 각 종료 코드와 SCRIPT ERROR/ERROR/FAIL을 함께 검사한다.
실제 그래픽은 같은 세션의 Xvfb :99/Mesa llvmpipe로 실행하며 생성형 이미지를 사용하지 않았다.
`DISPLAY=:99 godot --path cities_do --audio-driver Dummy --rendering-method gl_compatibility --script /workspace/simcity/tools/capture_zoning.gd`
는 실제 지도 드래그로 색칠한 뒤 같은 도시의 신축 시간을 진행해 전/후를 캡처한다.
XDG 경로는 /tmp/cities-do-{data,config,cache}다. 이전 service-assets/adjacent-lot 검사와 구분한다.

초기 검사에서 화면 사각형과 월드 대각선 선택을 혼동한 입력 fixture를 고쳤다. 주거 2×2
시안의 growth_enabled:false도 실제 카탈로그로 확인해 강제 등록하지 않았다.
캡처 전용 임시 도시로 바꾼 후 utility 자식의 이전 draw cache를 명시적으로 갱신했다.
대형 도시/모바일/오프라인 신축·수요 기반 경제 운영은 미검증이다. 관련 코드·화면·
이 인계장을 함께 main에 커밋·푸시하고 원격 SHA를 확인한다.

## 최신 작업: 공공차량 3종·화장터와 보건·교육 (2026-11-03 KST)

실제 `/workspace/simcity`, 로컬 `work`의 깨끗한 상태에서 시작했다. fetch 후 origin/main은
사용자 기준 cdca2de와 동일했다. [작업 보고서·재현](SERVICE_ASSETS_KO.md),
[이번 환경 증거](service-assets-validation/), [코드 대조 개발 백로그](DEVELOPMENT_STATUS_BACKLOG_KO.md)를 참고한다.
‘기타’는 실제로 빈 탭이었다. 병원·진료소·학교는 제안 문서에만 있어 애셋/엔진 부재를 확인했다.

읽고 적용한 로컬 지침: `.agents/skills/cities-do-vehicles/SKILL.md`,
`vehicle/SKILL.md`와 `vehicle/reference/rig-contract.md`, `cities-do-construction/SKILL.md`,
`godot-gdscript/SKILL.md`, `godot-gdscript-headless-testing/SKILL.md`.
`cities-do-modular-facilities/SKILL.md`의 미터/독립 부지 치수·원본/GLB/PNG/spec 보존 규약도
적용했다. 이는 주차 결합 파이프라인을 재실행했다는 뜻이 아니다.
플랫폼 `cloud-environment:cloud-environment-runtime`의 상태/네트워크 지침도 적용했다.
이 환경은 연결됨·정책 unrestricted/enforced, 설정된 secrets/outbound identities 없음이었다.

vehicle 원본 https://github.com/duolahypercho/zstack 의
74f7786e9931b9ced858a0e2df880f23e4c2430e, MIT와 UPSTREAM/LICENSE를 그대로 유지한다.
새 외부 스킬 설치나 원본 수정은 없다. `tools/build_vehicle_fleet.py`에 서비스 형상을 추가해
실제 common.py empty/parent_keep/rounded_box/revolve/tri_count 등을 호출했다.
원본 참조 이미지·cage·IoU·문 개폐·충돌 변형은 실행하지 않았다.

변경/제작: 위 차량 생성기·verify_vehicle_fleet/sources, 새 `tools/build_service_facility.py`,
`assets/vehicle-fleet/{fire-engine-01,police-car-01,hearse-01}`의 blend/spec,
`cities_do/assets/vehicles`의 GLB·8방향 PNG·catalog/manifest,
`assets/service-facilities/crematorium-4x4`의 blend/spec와 `cities_do/assets/services`의 GLB/PNG/catalog.
기존 20종 모델은 재제작하지 않았다. 차량 --only 병합은 ID 순서를 유지하며 순차 실행한다.
`build_facilities.py`/facility_layout/export_building_models는 읽어 비교했으나 전체 재생성하지 않았다.

`bottom_ui_preview.gd`의 빈 기타 탭과 가짜 설정 진입을 제거하고 보건·교육 9분류와
키보드 순환/좁은 화면 높이를 수정했다. 병원·진료소/교육 4종은 준비 중·비활성,
화장터는 `service_asset_preview.gd`의 실제 GLB 창이다. `service_assets_showcase.tscn`에서
신규 네 모델을 함께 보며 차량 전시는 23종이다. 서비스 출동·진료·화장 처리·시설 도시 배치·
주거 성장/공급 소비 등록과 메인 하단 UI 통합은 미구현이다. 기존 1.5m 접도·축척·도시를 유지했다.

가격/유지비/용량/자체 소비는 SERVICE_ASSETS_KO와 PRICE/CAPACITY 문서 및 경제 CSV에
제안·미적용으로 기록했다. 승인된 과금으로 전환하지 않았다.
이번 Godot 4.6.3 신규 임포트·Blender 4.3.2 제작/원본 열기·미터 검사·PNG 구조 검사·
실제 GL Compatibility/llvmpipe 캡처를 실행했다. Xvfb를 Debian 패키지에서 `/tmp`에 풀어
사용했고 시스템 설정은 바꾸지 않았다. XDG 3경로는 /tmp/cities-do-{data,config,cache}다.

이번 결과: 전체 18개 스크립트 통과, 차량 177/177, 하단 UI 36/36, 신규 서비스 애셋 9/9.
원본 23개 열기·파일 구조 blend23/GLB23/PNG184 통과. 이전 환경 17개 통과를 재사용한 수치가 아니다.
초기 하단 UI 34/36에서 960px 높이와 검사 창 식별을 수정했다. 초기 시설 정면 검사는
GLB 노드 원점을 측정해 실패했으므로 실제 메시 AABB 중심이 +Z에 있는지 검사하도록 고쳤다.
각 초기 실패 로그/results-initial도 남겼고 수정된 검사와 영향을 받은 차량/UI를 재검사했다.
전체 회귀를 무조건 반복하지 않았으며 최종 results.json은 같은 작업의 검사/선택 재검사 합본이다.
첫 그래픽 실행의 ALSA 오류는 음성 장치 부재였고 --audio-driver Dummy로 다시 캡처했다.
VSync 미지원 및 기존 Road Generator UID 경고는 남아 있지만 최종 SCRIPT ERROR/ERROR는 없다.

재현 명령은 보고서와 tools/validate_service_assets.py에 있다. 대규모 도시/모바일/배포·
차량 출동·실차 IoU·실내/건축 법규는 미검증이다. 새 애셋·경제 제안·백로그·이 인계장을
같은 작업으로 커밋하고 origin/main에 푸시하며 실제 성공 여부는 원격 SHA로 확인한다.

## 최신 작업: 도로 바로 옆 격자·최대 1.5m 적용 (2026-11-02)

사용자가 도로 바로 옆 격자 배치와 최대 1.5m를 확정했다.
[최신 규칙과 화면](BUILDING_ROAD_ADJACENCY_KO.md)을 따른다. 이전 2.5셀=10m 허용은 폐기됐다.
거리 기준은 보도를 포함한 도로 바깥 경계→부지 앞면이며 모델 안 앞마당은 유지한다.

기존 construction / godot-gdscript / godot-gdscript-headless-testing 지침을 적용했다.
새 스킬·외부 애셋·라이선스 도입은 없다. growth_config 한도를 0.375셀로 바꾸고
building_frontage의 면별 후보(양 끝·중간) 판정을 city_model의 신축·성장·방향에 공유했다.
같은 면은 방향 벡터도 재사용해 성장 후 부동소수점 방향 흔들림을 막는다.

실제 예시도 수정했다: 주거 10종 전시, 34건물 bottom UI, power/water demo,
방향/수도 캡처 배치와 해당 공급원 전선·배관 시작점. 모형 크기·경제·수요량은 유지했다.
기존 검사 예시의 4m 이상 간격과 UI 뒤쪽 클릭을 새 규칙에 맞췄고 한도를 완화하지 않았다.
[전체 17개 스크립트](adjacent-lot-validation/results.json),
[신규 간격 49/49](adjacent-lot-validation/test_road_setback.log),
[정면 138/138](adjacent-lot-validation/test_building_frontage.log) 통과.
실제 네 방향+대각선 양쪽 화면에서 부지 간격은 사실상 0m이며 알파 영역 클릭도 확인했다.

`tools/audit_building_road_gaps.gd`는 이제 현재 규칙과 현재 예시를 측정한다.
기존 road-gap-validation 결과는 과거 진단으로 남기고 최신 결과는 adjacent-lot-validation이다.
`tools/capture_asset_scale.gd`의 주차 기준도 변경된 수평 전시 도로에 맞췄다.
기존 도시 일괄 이동·저장 마이그레이션·모바일/대형 도시 성능 검증은 하지 않았다.
규칙·스킬 적응 지침·코드·검사·실제 이미지를 같은 작업으로 Git main에 커밋·푸시한다.

## 최신 작업: 도로와 건물 사이 빈 공간 원인 조사 (2026-11-02)

사용자는 건물이 도로에서 떨어진 이유를 요청했다. 기존 construction 지침·기하/접근
규칙과 실제 배치를 조사했으며 새 스킬이나 외부 애셋은 도입하지 않았다.
[원인 보고서](BUILDING_ROAD_GAPS_KO.md), `tools/audit_building_road_gaps.gd`와
[실행 결과](road-gap-validation/gaps.json)를 확인한다.

이번 실행: 수평·수직·대각선 양쪽의 깊이 0~3, 총 24사례에서 0/4/8m는 건설 허용,
12m는 거부됐다. `road_access_distance=2.5`셀=10m 근접 허용이며 실제 접도를 검사하지 않는다.
기존 방향 비교 장면의 축 방향 4개 부지는 보도에서 각 4m, 주거 전시 10종은 각 약 3.314m
떨어져 있음을 재생성해 측정했다. 이전의 방향 수정은 접도 구현이 아니다.
모델 안 앞마당 1.9~5.75m는 이전 Blender 측정값을 재사용해 계산했으며 이번에 Blender를
다시 실행한 결과로 표현하지 않는다. 링크한 화면도 이전 캡처다.

이번 작업은 진단이며 제품 코드·허용 거리·성장 조건·모델·기존 도시 위치를 바꾸지 않았다.
권장 후속은 부지 정면의 실제 보도 접도 검증과 비교 장면 갱신이다. v=0 강제·전체 모델
확대·기존 도시 일괄 이동으로 대체하지 않는다. 전체 회귀 검사는 재실행하지 않았다.
규칙 변경 승인/구현 완료로 이 진단을 해석하지 않는다. 보고서·도구·인계 기록을 함께
Git main에 커밋·푸시한다.

## 최신 작업: 건물 정면을 출입 도로로 향하게 연결 (2026-11-02)

사용자 확정: 모든 건물의 정면·주출입구는 그 건물에 접근 가능한 일반도로 쪽이다.
AGENTS.md와 construction 스킬/참조 규칙에 보존했다. 최신 구현과 남은 범위는
[건물 정면 규칙](BUILDING_FRONTAGE_KO.md)에 있다.

기존 `.agents/skills/cities-do-construction/SKILL.md`, `godot-gdscript/SKILL.md`,
`godot-gdscript-headless-testing/SKILL.md`를 적용했다. 새 외부 스킬·애셋 설치는 없다.
자체 구현은 `core/building_frontage.gd`, `core/building_views.gd`, city_model/main 연결,
`tools/export_building_models.py`, `tools/capture_building_frontage.gd`다.
기존 자체 제작 .blend 10개를 GLB로 내보냈으며 원본은 수정하지 않았다.
Blender 절차형 벽돌은 GLB 복사본에서 원래 기본색으로 근사하며 원본 PNG·셰이더는 보존한다.
외부 다운로드나 새 모델 유형이 아니므로 새 가격·수용량·경제 항목을 만들지 않았다.

이번 검사: [정면 138/138](frontage-validation/test_building_frontage.log),
[전체 16개 스크립트 통과](frontage-validation/results.json). UI 검사에서 새 helper 노드로
드러난 자식 순서 의존 접근을 명시적 controls_panel 참조로 고친 뒤 UI도 재검사했다.
[실제 화면](frontage-validation/road-facing.png)은 4방향+대각선 양쪽, GLB 알파 영역 선택을
확인했다. headless 검사와 실제 그래픽 캡처를 구분한다. 명령·로그·제한은 해당 문서에 있다.

주거 카탈로그와 프로토타입 블록에 적용했다. 별도 공원/주차 전시·절차형 utility 임시
시설까지 같은 렌더러로 바꾼 것은 아니다. 보행자·차량 출입 경로와 대도시·모바일 성능은
미검증이며 새 저장 시스템도 만들지 않았다. 향후 저장에는 front_direction/front_road_id를
포함한다. 관련 코드·GLB·규칙·검증 자료를 함께 Git main에 커밋·푸시한다.

## 최신 작업: 자동차 대비 건물 비율 실측 (2026-11-02)

사용자가 횡단보도 배치 규칙의 지속 보존을 재확인했다. 교차 도로의 가장자리 기준으로
진입로마다 횡단보도를 배치하는 규칙은 AGENTS.md / construction 스킬 /
ROAD_JUNCTIONS_KO.md에 이미 저장돼 있으며 이번에도 그대로 유지했다.

기존 `.agents/skills/cities-do-vehicles/SKILL.md`, 원본 vehicle의 단위·rig 계약을
읽고 미터 기준으로 비교했다. 원본은 https://github.com/duolahypercho/zstack 의
`74f7786e9931b9ced858a0e2df880f23e4c2430e`, MIT이며 새 설치·원본 변경은 없다.
적응 지침에 건물과의 공통 축척 확인 항목을 추가했다.

[비율 검토 보고서](ASSET_SCALE_REVIEW_KO.md), [실측 및 화면](scale-validation/)을 확인한다.
`tools/audit_asset_scale_blender.py`로 주거 10·차량 20·공원/주차 시설 8개의 원본을
읽기 전용으로 열어 측정했다. `tools/analyze_asset_scale.py`는 표시 축척과 차량 PNG
160장을 비교한다. 주거/차량 표시 축척 오차 최대 약 0.00014%, PNG 경계 차이 최대 1.96px.
`tools/capture_asset_scale.gd`는 실제 main.tscn과 렌더러로 같은 세단·버스를 배치한
1920×1000, 줌 2.2 화면 3장을 만들었다. 캡처 전용 임시 도시이며 저장 게임을 바꾸지 않는다.
재현 명령과 이번 실행 기록은 보고서 및 scale-validation의 로그에 있다.

전체 축척은 맞으며 작은 2×2 집의 본체는 실제로 약 23㎡의 작은 평면이다.
일괄 확대 대신 소형 주택의 의도 검토를 권했다. 5m 주차선은 4.85m 세단의 길이 여유가
작고 5.05m SUV에는 짧다는 점도 기록했다. 모델·축척·주차 수용량·경제 수치는 변경하지 않았다.
건축 법규/실내 동선/차량 회전 반경, 원본 vehicle 전체 제작·IoU 파이프라인은 검증하지 않았다.
제품 구현 변경이 없어 전체 게임 회귀 검사는 재실행하지 않았다. 이 기록은 과거의 검사 수치와
구분되는 이번 측정 결과다. 관련 파일과 함께 Git main에 커밋·푸시한다.

## 최신 작업: 혼합 차로 횡단보도 간격 축소 (2026-11-02 KST)

사용자는 2/4차로가 만날 때 4차로 횡단보도가 한 격자쯤 밖으로 밀린 이유를 묻고
더 가까이 모으라고 했다. 원인은 main.gd가 모든 방향에 최대 도로 기준 반경을 쓴 것이다.
`core/road_junctions.gd`에 진입로별 `crosswalk_distance()`를 두고 교차 도로의 폭과
횡단보도 반길이/작은 가장자리 간격으로 표시 위치를 계산한다.
`main.gd`의 횡단보도만 이 값을 사용하며 차량 제어 반경/예약과 사각 구획 경계는 유지했다.

기존 construction/GDScript/headless-testing 지침을 적용했고 새 스킬 설치는 없다.
교차로 **52/52**, 전체 **15개 스크립트 통과**. [최신 로그](junction-validation/).
추가 6개 검사는 혼합 차로 양 방향/같은 가장자리 간격/T자/순서 독립/회전 교차로를 확인했다.
[구획 화면](screenshots/junctions-square-zoning.png)과 실제 주행/확대 GIF·해시도 갱신했다.
현재 기준은 [교차로 문서](ROAD_JUNCTIONS_KO.md)의 최신 수정이다.
설명 문구를 게임 HUD에 추가하지 않았고 경제 CSV/단가도 변경하지 않았다.

## 최신 작업: 구획 모서리를 남기는 직각 교차로 (2026-11-02 KST)

사용자는 교차로가 구획을 잘라먹지 않도록 네모반듯하게 수정하라고 했다.
`core/road_junctions.gd`의 convex hull을 도로 폭 직사각 띠의 합집합으로 바꾸고
렌더/충돌/구획 제외가 같은 형태를 사용하게 했다. 형상은 교차로 생성 때 캐시한다.
`core/traffic_network.gd`는 회전 제어점을 접선 교점에 맞춰 줄어든 노면 안으로 조정했다.
기존 예약/통행 제어·도로 ID·경제 수치는 변경하지 않았다.

기존 construction/GDScript/headless-testing 지침을 적용했고 새 스킬 설치/원본 변경은 없다.
기존 도입 검사의 '교차로 바깥 모서리 집 거부'는 최신 사용자 요구에 맞춰
'네 모서리의 실제 road-local 2×2 건설/나중 교차 도로 추가 시 집 보존' 검사로 바꿨다.
노면 점유 거부, 직각 경계/면적, 혼합 차로의 노면 내 회전 경로 검사도 함께 확인했다.
교차로 **46/46**, 전체 **15개 스크립트 통과**. [최신 결과](junction-validation/results.json).
[구획 표시 실제 화면](screenshots/junctions-square-zoning.png)과 기존 주행/확대 GIF를
생성형 이미지 없이 Godot 뷰포트에서 다시 기록했다. `junction_demo`는 이제
`--bottom-tab=build`를 유지해 구획 상태를 직접 캡처할 수 있다.
현재 기준은 [교차로 문서의 최신 수정](ROAD_JUNCTIONS_KO.md)이며 이전 팔각 확장 포장은 재도입하지 않는다.

## 최신 작업: 실제 도로 교차로·회전 경로·통행 제어 (2026-11-02 KST)

사용자가 가로지르는 도로에 실제 교차로를 요구했다.
[현재 동작/제한/실제 영상](ROAD_JUNCTIONS_KO.md)이 기준이다.
`core/road_junctions.gd`에서 중심선 교차를 파생 구간/공유 노드로 만들고,
CityModel의 교차로 캐시·노면 충돌/구획 제외, main의 노면/횡단보도를 연결했다.
traffic_network는 직진/좌·우회전 곡선을 A*에 연결하고, traffic_simulation은
앞차 대기 순서/출구 공간/차체 후미를 고려한 교차로 단독 예약을 구현했다.
모든 도로가 현재 같은 지면이며 입체교차/신호 주기/동시 비충돌 통행은 후속이다.

기존 game-ai/GDScript/headless-testing/construction 지침을 읽어 적용했다.
경로 탐색·의사결정·이동·렌더를 분리했고 캐시된 경로와 30Hz 상태를 유지했다.
추가 외부 스킬/애드온 설치나 원본 코드 수정은 없다. 기존 원본 RoadLane/RoadLaneAgent
어댑터에 실제 회전 곡선을 연결하고 좌표 일치를 검사했다. 출처/SHA/라이선스는 아래 기록과 같다.
기존 교통 검사의 교차로 거부 항목만 새 연결 요구에 맞춰 바꾸고, 중복 도로 거부는 보존했다.

이번 실행: Godot 4.6.3 교차로 **41/41**, 교통 **43/43**, 전체 **15개 스크립트 통과**.
[최신 검사 로그](junction-validation/), [실제 주행 GIF](screenshots/junctions-running.gif),
[확대 GIF](screenshots/junctions-closeup.gif), [증거 메타데이터](screenshots/junctions-evidence.json).
`junction_demo.gd/.tscn`, `tools/build_junction_evidence.py`,
`tools/validate_junction_update.py`로 재현한다.
이미지 생성 없이 실제 뷰포트 약 18초를 기록하고 Pillow로 GIF를 만들었다.
교차로 추가 요금/경제 수치 변경은 없다. 짧은 수용 차로·무한 수요·대규모 성능·
차종별 물리 회전 반경은 검증 범위 밖이며 문서에 구체적 한계를 적었다.

## 최신 작업: 통합 불도저·구획 탭·타일 표시 조건 (2026-11-02 KST)

사용자는 건설을 구획으로 바꾸고 맨 우측 불도저 하나로 철거하며,
도로 옆 배치 타일은 도로/구획 메뉴에서만 보이라고 했다.
[현재 동작·제한·실행 화면](concepts/bottom-ui/DEMOLITION_ZONING_KO.md)을 먼저 확인한다.
기본 모드를 select로 바꾸고 표시 게이트를 추가했다. 타일 데이터는 보존한다.
하단 우측 불도저는 건물/도로/전원/전력선/수도 시설/두 관을 공통 API로 철거한다.
중복된 전력/수도 철거 버튼은 제거했고, 숨겨진 지하 망은 클릭하지 않는다.
도로 삭제 때 남은 도로의 구획 프레임이 뒤바뀌지 않도록 parcel_id를 안정화했다.

기존 construction/game-ui-ux/GDScript/headless-testing 지침을 적용했고 새 스킬 설치는 없다.
주요 변경: `main.gd`, `core/city_model.gd`, `bottom_ui_preview.gd`,
`core/power_overlay.gd`, `core/water_overlay.gd`, `tests/test_demolition.gd`.
Godot 4.6.3 철거/표시 **47/47**, 기존 하단 UI **24/24**, 전체 **14개 스크립트 통과**.
[최신 로그](bottom-ui-validation/), 실제 전력/수도/구획/1280 캡처를 보존했다.
새 경제 수치를 정한 작업이 아니므로 CSV는 변경하지 않았다. 철거 수수료/환급 엔진은 없고
도로/선은 현재 한 건설 경로 단위로 제거한다. 기본 게임은 공통 동작을 공유하지만
하단 메뉴 전체는 아직 별도 검토 장면이다. 미통합 공원·주차 전시까지 철거를 확장하지 않았다.

## 최신 작업: 시티즈 참고 하단 UI·설명 문구 제거 (2026-11-02 KST)

사용자는 Cities: Skylines를 참고하고 반경/간격 같은 게임 내 설명을 모두 지우라고 했다.
[참고 자료·적용 범위](concepts/bottom-ui/SKYLINES_REFERENCE_KO.md)가 최신 기준이다.
Steam 커뮤니티 가이드의 실제 HUD를 읽어 하단 분류/최하단 상태 구조를 확인했다.
타 게임 애셋/아이콘을 복사하지 않고 기존 자체 SVG와 우리 도시 렌더러를 사용했다.
카테고리를 가운데 작은 모음으로, 상태/시간을 최하단으로, 시설 타일을 그 위로 정리했다.
일반 게임 전력/수도 패널과 실습장의 거리·개발용 설명, 메인 상시 디버그 문단도 제거했다.
도구 이름/실제 값/실패·완료 피드백은 남겼다. 설명 삭제는 공급 규칙 변경을 뜻하지 않는다.

기존 game-ui-ux/GDScript/headless-testing과 프로젝트 construction 지침을 적용했다.
후속 담당자가 설명 문구를 HUD에 재삽입하지 않도록 AGENTS/건설 지침에 기록했다.
새 외부 스킬/런타임 설치나 경제 CSV 수정은 없다. 이미지 생성 없이 실제 Godot 캡처를 갱신했다.
Godot 4.6.3에서 하단 UI **24/24**, 전력 **41/41**, 상하수도 **80/80**,
전체 **13개 스크립트 통과**. [현재 결과](bottom-ui-validation/results.json), [로그](bottom-ui-validation/).
1920 전력/수도와 1280 화면도 다시 캡처했다. 하단 레이아웃은 아직 별도 검토 장면이며
기본 main의 전체 메뉴를 교체한 작업은 아니다. 기존 미완성 기능 범위는 앞 기록을 따른다.

## 최신 작업: 실제 게임 배경의 하단 UI 검토 장면 (2026-11-02 KST)

사용자가 가상 도시 그림 대신 우리 게임 바탕을 요청했다.
`cities_do/bottom_ui_preview.gd/.tscn`에 기존 main.gd/CityModel/카탈로그 렌더러를
사용하는 별도 검토 장면을 만들었다. 검증된 배치 API로 주거 34개·도로 6개와 실제
전력/상하수도망을 배치한다. 일반 main UI는 바꾸지 않았다.
[실제 실행 화면·동작 범위·재현](concepts/bottom-ui/ACTUAL_GAME_KO.md)이 현재 검토 기준이다.
이전 concept.png는 생성형 이미지 비교본으로 남긴다.

기존 game-ui-ux, godot-gdscript, godot-gdscript-headless-testing 지침을 적용했다.
하단 anchor/container, 실제 Button, 포커스 이웃, 선택 메뉴별 도구, 명시적 실패 집계를 사용했다.
원본 스킬 파일/출처/SHA/라이선스는 변경하지 않았다. 신규 스킬 설치는 없다.
실루엣 아이콘은 장면 안에 자체 SVG 경로로 정의해 Godot 텍스처로 표시한다.
생성형 이미지 편집 없이 실제 OpenGL 뷰포트에서 1920 전력/수도 및 1280 화면을 캡처했다.

전용 `tests/test_bottom_ui.gd` **23/23**, 기존 `tests/test_ui.gd` 통과.
[로그](bottom-ui-validation/) 보존. 1920×1080/1280×820/960×640 배치,
실제 관로 모드/오버레이 전환, 시뮬레이션 일시정지/3배속, 포커스/접힘을 검사했다.
물리 게임패드·세로 휴대폰·전체 메뉴 구현은 미검증/미완료다.
기존 모델은 이벤트형 HUD가 아니므로 자금/건물 수 변경 확인 방식은 그대로다.
인구/만족도는 가짜 수치 대신 — 표시, 시설/요금/경제 CSV의 가격은 변경하지 않았다.

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
| game-ui-ux | 게임 HUD·메뉴·안전 영역·포커스 설계 | 하단 시안과 실제 Godot 검토 장면에 적용. 데스크톱 3해상도/입력·포커스 검사; 물리 게임패드·휴대폰 미검증 |
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
