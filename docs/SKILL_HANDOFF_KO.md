# CITIES_DO 스킬 인계장

최종 기록: 2026-11-11 KST. 사용자의 요청으로 이후 작업에서도 계속 갱신한다.
**새 담당자는 이 문서 → AGENTS.md → [mistake.md](../mistake.md) → 관련 SKILL.md → 실제 코드와 검증 기록 순으로 확인한다.**
“배웠다”는 말은 모델에 영구 설치했다는 뜻이 아니다. Git에 보존한 지침·코드·출처와
검증 기록을 읽어 같은 작업을 이어갈 수 있다는 뜻이다. 자동 스킬 탐색 여부와
원본 파이프라인 전체 실행 여부도 구분한다.

## 구급차 한국 승합형 레퍼런스 재제작 · 미러 연결 수정

브랜치 assets/service-vehicles-2-20261111. 사용자 미러 부유 지적과 제공 사진에 따라 구급차만 재제작했다.
[수정 전후·미러 확대·이번 검증](service-vehicles-2/ambulance-revision/README_KO.md). 사진은 Git에 보관하지 않는다.
기존 cities-do-vehicles 및 vehicle rig-contract, zstack MIT/고정판74f7786e9931b9ced858a0e2df880f23e4c2430e를 계속 사용했다.
새 upstream/라이선스/패키지/독립 에이전트 없음. 원본 common/fleet 제작기는 수정하지 않았다.
build_service_vehicles_2.py의 ambulance만 연속 loft 승합 차체·휠 아치·높인 지붕·미러 받침/암으로 바꿨다.
외부 모델/텍스처/생성형 이미지 없음. 명목5.9×2.1×2.6m, 전체6.0175×2.68×2.6m, 3,326삼각형.
verify_service_vehicles_2.py는 양쪽 미러 접촉6개와 차체/높인 지붕 검사를 추가해 이번39/39 통과했다.
Blender4.3.2 CPU Cycles로 앞/뒤 및 새 render_ambulance_mirror_review.py의 확대와 동일 축척 비교를 실제 렌더했다.
PNG4장의 투명·프레임·해시를 갱신했다. 쓰레기차/기존 차량 원본과 게임 파일은 보존했다.
미승인 비용·용량 제안은 그대로다. GLB/8방향 스프라이트/게임 적용/main 병합 없음.
과거31검사/2,720삼각형 기록은 최초 버전 근거이며 현재 구급차에는 이번 수정값을 쓴다. 문 개폐/AI/실차 IoU/성능 미검증.
수정 원본·검증·mistake M-013을 기존 별도 애셋 브랜치에 커밋·푸시한다.

## 서비스 차량2종 · 원본 전용 애셋 브랜치 (2026-11-11 KST)

브랜치 `assets/service-vehicles-2-20261111`. 쓰레기차 → 구급차 순으로 제작했다.
[미리보기·실측·재현·비용/용량 제안](service-vehicles-2/README_KO.md).
`.agents/skills/cities-do-vehicles/SKILL.md`와 기존 vehicle rig-contract를 적용했다.
상류 https://github.com/duolahypercho/zstack 고정판74f7786e9931b9ced858a0e2df880f23e4c2430e, MIT;
각 원본 폴더에 ZSTACK_LICENSE.txt를 보존했다. 상류 파일과 기존 제작기는 수정하지 않았다.
새 tools/build_service_vehicles_2.py에서 기존 build_vehicle_fleet.py의 매스/차륜/좌측 운전석 및
common.py의 empty/parent_keep/rounded_box/revolve를 재사용했다. 의료/재활용 표식도 직접 기하로 만들었다.
외부 모델·텍스처·생성 API 없음. Blender4.3.2 CPU Cycles로 앞/뒤 PNG4장을 실제 렌더했다.
쓰레기차 부속품 포함8.114×2.700×3.145m/3,186삼각형, 구급차6.0625×2.350×2.600m/2,720삼각형.
명목 차체 치수와 미러/램프 포함 전체 실측을 spec.json에서 구분한다. 바퀴 접지z=0, 전방-Y/왼쪽+X/위+Z.
이번 실행 tools/verify_service_vehicles_2.py의 실제 재개방 기하 검사31개와 PNG 투명/프레임 검사를 통과했다.
쓰레기차3.3m/구급차3.4m 전체 높이 제한을 만족한다. tools/render_service_vehicle_scale.py로
기존 세단·소방차를 확대/축소하지 않은 동일 미터 비교도 실제 렌더했다.
vehicle.blend/spec/PNG와 생성·검증 스크립트만 추가한다. GLB/8방향 스프라이트/게임 등록/main 병합 없음.
문 개폐·리프트 작동·충돌·교통AI·대량 성능은 미검증이다. 비용/용량은 미승인 제안이며 실행 수치 변경 없음.
별도 애셋 브랜치에 원본·검증·인계 기록을 함께 커밋·푸시한다. 독립/병렬 에이전트 사용 없음.

## 최신 승인: 결정적 신축·성장 부지 규칙 / main 통합

성장 외관4077e44 사용자 승인 후 같은 feature/growth-appearance에서 부지 규칙2개를 구현했다.
기획4파일은 원문 보존, 실제 변경2파일은02f505c docs 커밋이며 이미 추적된 의미 불변2파일은 그대로다.
자동 신축은4×4 우선/2×2 폴백/둘 다 불가 시 미건설이다. 한 블록·같은 용도·접도·정면·충돌 공통 판정.
수동 성장은1~4단계 최대4×4, 5단계8×8 우선, 불가 시4×4/현재 부지 유지다. 축소·타 건물 철거 없음.
단계5가 최종이며 기존 조기8×8 저장 데이터의 large 외관은 유지한다. 무작위 부지 추첨 함수는 삭제했다.
기존 가구/일자리 면적 비례와 수요·가격·용량·행복도·연쇄 수치는 그대로다. 행복도 자동 성장/새 UI 없음.
[전체28/28·신규86/86·원본/수치 보존·실제1920 3장·기존 동수 기반 수요식 한계](growth-appearance-validation/lot-rules/README_KO.md).
기존8×8 소형/중형6셀은 현재 후보 표에서 도달 불가로 표시하고 legacy 후보만 남겼다.
도구 tools/capture_lot_rules.py/.gd와 audit_lot_rules.py는 기존 validator/실제 게임·HUD를 재사용한다.
프로필 TDD/Windows validation/GitHub 통합/자체 리뷰 절차 적용, 추가 패키지·라이선스·에이전트 없음.
AGENTS.md는 수정하지 않는다. 전부 통과한 현재 트리를 main 통합·origin/main 푸시하도록 사용자 승인받았다.
아래 로컬 전용 제한은 이전 단계의 기록이며 이번 명시적 main 통합 승인으로 대체된다.

## 이전 작업: 성장 외관42종 연결 · 로컬 승인 대기

현재 범위는 feature/growth-appearance의 외관 연결이다. 이전 main 통합3건과 구별한다.
풍력 A안 문서 원문은 f660b94, 원격 성장14종 afe0bfe 병합은 3d6a4d9에 보존했다.
신규14 GLB/spec/PNG/썸네일과 기존28을 합쳐 주거14·상업14·공업14를 활성화했다.
용도/동일 부지/단계밀도(1·2 small,3·4 medium,5 large)로 매칭하며 같은 부지 최근접 밀도, 동률 낮은 밀도를 쓴다.
맨션4×4/4층/min_level2 보존. 8×8 small/medium의6밀도셀은 large로 대체한다. 새 성장/신축 규칙은 구현하지 않았다.
city_model에는 최초 외관 assign2줄만 추가했다. 행복도·경험치·부지 확률·수요·가격/용량 수치는 그대로다.
[45조합 후보ID·실측·27/27·신규302/302·실제1920 캡처6장·검토 fixture 경계](growth-appearance-validation/README_KO.md).
중간 범위 혼동으로 scratch 격리했던 산출물을 이번 사용자 재개 승인으로 선별 복원했다.
캡처6장은 이전 실제 framebuffer와 상태 JSON을 그대로 복원하고 해시/현재 후보를 재검증했다. 이번 재개에서는 import와 전체27개를 두 배치로 새로 실행했다.
도구: tools/export_growth_14.py, capture_growth_appearance.py/.gd, audit_growth_appearance.py.
기존 emergency exporter/validator/Pillow/Blender4.3.2/Godot4.6.3, construction 규약 및 프로필 godot-windows-validation을 재사용했다.
신규 외부 패키지/업스트림/라이선스/에이전트 없음. 기존 도구 출처·고정판·라이선스 기록은 아래 그대로 보존한다. 자체 리뷰다.
AGENTS.md는 이번 지시대로 수정하지 않는다. 최신 사용자 승인 범위가 과거 비활성 서술보다 우선한다.
**로컬 커밋까지만. main 병합·푸시 및 후속 범위 금지.**

## 이전 승인 반영: 원본30종·크기표 main 통합 (2026-11-11 KST)

사용자 승인으로 원격12d714e 크기표를 병합했다. 인계장 충돌1건은 양쪽 본문을 보존했다.
기획9파일 원문을 보존했고 신규/변경6파일을 f3913d2에 별도 커밋했다. 기존 추적3파일은 그대로다.
소방/경찰6개 metadata는 footprint_status만 사용자 지정으로, 풍력은 지정3필드로4×4/16×16m를 반영했다.
등록 spec/카탈로그/30종 인덱스를 동기화했으나 모델/GLB104개는 바이트 불변이다. 발전량/가격/용량과 성장 외관은 변경하지 않았다.
기존 tools/build_asset_size_index.py 머리말을 지정 문장으로 교체하고 Windows에서도 기존 '/' 링크를 유지했다.
[이번63종 크기표/30종 일치·7행 diff·전체26/26·신규635/635·승인 필드/해시](register-30-assets-validation/approved-main-merge/README_KO.md).
기존 감사 도구는 승인 metadata before/after 해시를 엄격히 대조하고 --output=로 별도 증거를 저장하도록 보완했다.
원래209파일 불변 기록·PNG/렌더/로그는 과거 단계 그대로 보존했다. 프로필 Windows validation/자체 리뷰 절차를 적용했으며 외부 도구/에이전트 추가 없음.
이번 승인은 main 통합·origin/main 푸시까지이며 이후 추가 작업은 하지 않는다.

## 이전 작업: 원본30종 검사 등록 · 로컬 승인 대기 (2026-11-11 KST)

`main 12dbc38`에서 `feature/register-30-assets`를 만들었다. [검증/실측/예외/실제 이미지/재현 명령](register-30-assets-validation/README_KO.md).
상업10·공업8·발전6·상하수도4·쓰레기2를 실제 GLB/spec/기존 PNG 복사/파생 썸네일로 30/30 등록했다.
전력6·수도4·환경2는 기존 C카드/검사창, 상업·공업18은 growth_enabled:false인 건물 카탈로그와 기존 vehicle_showcase의
`--asset-group=commercial_industrial` 데이터 옵션을 쓴다. 새 메뉴/레이아웃·도시 배치·자동 성장/가격/용량 적용은 없다.
이번 import/전체26/26와 신규635/635, 실제 Blender4장/Godot HUD4장/기존 전시2장, 원본209파일 해시 불변을 검증했다.
풍력 로터 오버행·수력 null 고정부지/60×32m 시연틀·석탄/해안 지하부는 원형을 유지했다.
발전6+급수탑은 명명된 사람 출입구를 확인 못 해 +Z 검사 규약만 기록했다. 실제 접도/차량 통과 검증으로 간주하지 않는다.
`tools/audit_remaining_asset_sources.py`, `export_remaining_assets.py`, `render_remaining_assets.py`,
`capture_registered_assets.py`, `capture_registered_gallery.gd`, `audit_registered_delivery.py`를 추가했다.
기존 emergency export/render/validator/썸네일 도구를 재사용했다. 원본 제작기나 archive 코드는 실행/덮어쓰기하지 않았다.
외부 설치/새 upstream·라이선스 추가 없음: 프로젝트 내부 도구이며 기존 인계의 Blender4.3.2/Godot4.6.3/Pillow와
modular-facilities/vehicles 규약, 프로필 godot-windows-validation·TDD·systematic-debugging·requesting-code-review(MIT)를 적용했다.
이들의 기존 고정 출처/라이선스/NOTICE 기록은 아래에서 보존한다. 새 독립/병렬 에이전트는 없고 자체 리뷰다.
CUDA 타임아웃은 로그를 보존하고 실제 EEVEE Next 렌더로 대체했다. 큰 장면 카메라 far/프러스텀 검사를 보완했다.
프로필 Godot 검증 스킬의 references/derived-asset-validation.md에 원본 지면 기준/미검증 출입구 구분/렌더 클리핑·백엔드 검증 교훈을 기록했다.
**승인은 로컬 커밋까지만. main 병합/푸시 금지.** 재임포트 churn·기존 uid8·병행 기획/mistake 변경은 제외한다.

## 애셋 브랜치 부분 수정: 공업 간판10·13·14 (2026-11-11 KST)

사용자 요청대로 MICRO LAB 출입구 가림, LOGISTICS의 낮은 대비, METAL WORKS 차양 가림만 수정했다.
기존 생성기 industrial의 electronics/logistics/metalshop 분기만 고치고 세 모델·PNG만 재생성했다.
[전후 가시율/대비/보존·검증](growth-14/SIGN_FIX_KO.md). 간판 외 평가 메시 해시 일치,
다른11종36파일 바이트 보존, 기존182기하 검사 및 PNG 재검사를 통과했다.
Blender CPU Cycles로 실제 재렌더했고 3개 수정 PNG와 갱신 공업 검토 이미지를 확인했다.
새 외부 스킬/출처·가격·규격·게임 적용·main 병합은 없다. 기존 제작 방식은 유지하고
전후 ray cast/재질 명도/형상 보존은 tools/verify_growth_signs.py로 재현한다.
assets/growth-14-20261111에 부분 수정과 검증/인계 기록을 함께 커밋·푸시한다.

## 애셋 브랜치 작업: 성장 건물14종 시안 (2026-11-11 KST)

브랜치 assets/growth-14-20261111. 사용자 요청은 게임 미적용 상태에서 별도 애셋 브랜치에 즉시 업로드다.
외부 AI의26종 요청 중 소형/중형8×8 12종은 사용자가 취소했다. 8×8은 성장5단계 최종 테크 전용이며
기존 대형8×8은 유지한다. 주거4·상업4·공업6만 생성했다. [14개 이미지·실측·층수·원본](growth-14/README_KO.md).

기존 cities-do-construction/SKILL.md의 단위/성장과 외관 분리/정면 지침, 원래 study 스크립트의
저채도 팔레트·Blender(-Y정면/+Z위)·Godot(+Z정면)·층고3.05m·바닥판±0.12m·30도 정투영을 적용했다.
새 외부 스킬/모델/텍스처/생성 API는 사용하지 않았다. 이전 제작 코드를 참고해 tools/build_growth_14.py에
직접 지오메트리를 작성했으며 시스템 DejaVu 폰트 라이선스를 각 growth 폴더에 보존했다.
metadata의 front는 Godot 좌표계이며 front_blender/up_blender를 함께 기록한다.

Blender4.3.2 CPU Cycles48샘플로 900×1100 투명 PNG14장을 렌더했다. 소스 .blend14개를 다시 열어
평가된 메시/폰트 전체의 부지/경계·실측·층수·정면·카메라·외부 텍스처 부재를 검증한다.
검사결과는 growth-14/geometry-validation.json·image-validation.json. 실제 렌더3장에 번호·크기·층수를 합쳤다.
초기 기본 폰트 pack 오류를 실제 폰트 파일만 pack하도록 고쳤고, 필로티에 떨어져 보이던 문과
옥상 출입 높이를 수정했다. 간판 측정은 회전 전 로컬 XY 치수를 사용하도록 수정해 재렌더했다.
금속가공/물류는 단층 높은 작업장, 사일로/증류탑은 거주층0인 설비이며 높이는 별도 보고한다.

게임 코드/자산 카탈로그·밀도/성장 로직·메뉴는 수정하지 않았다. main 병합과 자동 성장 적용도 없다.
기존 게임 회귀를 재실행한 결과로 주장하지 않는다. 신규 원본/PNG/metadata·제작/검증 스크립트·검토 문서만
이 브랜치에 커밋·푸시하고 원격 SHA를 확인한다. 실내/LOD/충돌·건축 구조 검증은 별도 미검증이다.
민간 자동 신축 시정부0doth 규칙을 유지하며, 용량/민간운영 제안은 growth-14/BALANCE_PROPOSALS_KO.md에
미적용으로 분리했다. 외형 제작과 별개로 승인이 필요하며 신규 시정부 과금은 넣지 않았다.

## 최신 작업: 건물·시설 크기 통합표 (2026-11-11 KST)

사용자가 2×2/4×4 등의 크기를 어디 기록했는지와 GitHub 업로드를 요청했다.
[63종 크기표·원본 규격 링크](asset-sizes/README_KO.md), CSV/JSON을 추가했다.
tools/build_asset_size_index.py가 주거·각 study metadata의 footprint_cells와
공원/주차/화장터 spec의 width/depth를 읽는다. 기존 게임 등록 카탈로그와
치수 일치, 모든 등록 항목의 원본 존재, ID 중복 없음, 1칸=4m를 확인했다.
6×6·직사각형·수력댐 가변 크기를 원본대로 표시하며 시안과 사용자 지정 상태를 구분한다.
이 표는 런타임 로더/새 규칙 승인이 아니다. 원본·게임 코드·카탈로그·경제 수치는 수정하지 않았다.
새 스킬/외부 출처/애셋을 도입하지 않았다. Python 생성과 원본 대조 및 문서 링크 검증만
실행하며 전체 게임 테스트·Blender 재제작을 실행한 결과로 주장하지 않는다.
관련 표·생성기·README·인계장을 함께 커밋·푸시한다.

## 이전 작업: 승인 fix-C 썸네일/포커스/정렬과 main 통합 승인 (2026-11-10 KST)

feature/bottom-bar-v2 022408b에서 이어서 사용자 승인 fix-C를 적용했다.
[실제 25/25·새 HUD143/143·3해상도 캡처·시안 비교·원본 보존·남은 아이콘 목록](bottom-bar-v2-validation/fix-c/README_KO.md).
기존 PNG23개에서 축소/중심 cover/둥근 알파 썸네일을 파생했으며 공통 C형 카드·18px 이름 띠로 표시한다.
공원/주차8개도 읽기 전용 검사창으로 연결했다. 선택/점선 키보드 포커스를 구분하고 일시정지 아이콘을 중앙으로 맞췄다.
core/asset_thumbnail_button.gd, bottom_ui.gd, service_asset_preview.gd의 검사 높이 fallback과 관련 검사/도구만 변경했다.
기존 모델/원본/카탈로그/가격/시뮬레이션 규칙과 이전 A2 원본 캡처·로그는 보존한다. 1B는 하지 않았다.
MAP_SIZE_KO.md와 VEHICLE_SPAWN_DESPAWN_KO.md는 내용 수정 없이 별도 docs 커밋 d8db5d5에 넣었다.
game-ui-ux/프로필 TDD/Windows validation/자체 리뷰/GitHub 절차를 적용했다(정확한 경로·고정 출처/라이선스는 아래 기존 기록).
개인 godot-windows-validation(MIT)에는 실제 마우스 press/release·선택과 포커스 모양 분리·빈 텍스트 아이콘 정렬 검증 규칙을 보완했다.
새 외부 스킬/의존성 설치나 병렬 리뷰 에이전트는 없다. 원본 보존 파생 PNG/실제 버튼 인벤토리/추가 캡처·증거 도구를 레포에 기록했다.
사용자 피드백 원인은 mistake.md M-009에 확인된 코드/RED/실제 캡처로 기록했다.
수정 e7f8cab에 원격 abd0cc1 원본30종/역사 자료를 보존 병합했다(6d661cc). 인계장/mistake 충돌2개는 양쪽 본문을 보존했다.
현재 게임 코드는 수정 커밋과 같으며 archive 속 코드를 실행하거나 원본30종을 게임에 새로 등록하지 않았다.
main fast-forward 후 import/전체25/25를 새로 실행했다: [별도 main 검증](bottom-bar-v2-validation/fix-c/main-merge/results.json).
현재 승인은 main 통합·origin/main 푸시까지다. .import churn과 기존 미추적 .uid8개는 제외한다.

## 병행 원격 작업: 나머지 원본30종·도로/도시 전시장 역사 보존 (2026-11-11 KST)

사용자가 어제 누락 조회 후 업로드를 끝내지 않은 점을 지적했다. 최신 원격을 확인하고
이전 stash의 untracked/변경 tracked 버전을 현재 main의 Git blob과 비교했다.
상업10·공업8·발전6·상하수도4·쓰레기2의 편집 원본/PNG/metadata/제작코드를 원래 assets 경로로,
나머지 동일 바이트가 없는 과거 코드·도로/나들목/54종 도시 전시장/문서/시안은
archive/cloud-work-2026-10-31로 보존했다. 기존 버스·택시 모델 제외는 유지한다.
[전체 목록·해시·원본 링크](remaining-original-assets/README_KO.md).

새 스킬·새 모델·출처·가격·운영 변경은 없다. 현재 게임 파일/카탈로그는 수정하지 않았다.
기존 원본을 Blender에서 읽기 전용으로 열어 30/30 메시·유한 좌표, Pillow에서 PNG60장을
검사했다. 전체 게임 테스트·새 렌더·옛 코드의 최신 호환 검증을 실행했다는 뜻은 아니다.
과거 스킬/규칙은 archive 안의 역사 자료이며 현재 지침으로 적용하지 않는다.
이전 전체 백업·stash는 보존하고, 이 회수 파일과 인덱스/검증/인계장을 함께 커밋·푸시한다.

## 이전 작업: 승인 A2 하단바 v2 (2026-11-10 KST)

파트1 feature/emergency-assets 9c10c646c0b8925ab82dfe4deadb9cc22d3652e7에서 feature/bottom-bar-v2로 분기했다.
기획자 A2 승인 기록/시안 폴더를 그대로 포함하며 [구현·명령·실제 검증·한계](bottom-bar-v2-validation/README_KO.md)를 확인한다.
11분류/수도/경찰 내 교도소, 날짜 너비와 같은 재생 버튼, 중앙 도시명 편집/실제 인구·자금·수요를 연결했다.
city_model과 city_clock에는 HUD용 신호·도시명만 더했으며 계산식/시간 배율/가격/원본 애셋은 바꾸지 않았다.
행복도/수지는 미구현 상태인 —를 유지하고 미래 월 집계 연결점만 만들었다. 도시명은 기존 세션 모델 참조로 보존한다.
기존 `.agents/skills/game-ui-ux/SKILL.md`(고정 출처/Apache-2.0는 아래 1A 기록)와 개인 프로필 TDD/Windows validation/자체 리뷰 지침을 적용했다.
개인 스킬 경로는 `C:/Users/wlgml/AppData/Local/hermes/profiles/cities-gpt/skills/software-development/` 아래
`{test-driven-development,godot-windows-validation,requesting-code-review}/SKILL.md`다.
개인 godot-windows-validation(MIT, 별도 고정 SHA 미제공)의 windows-capture 참고문서에
테마 구분선 최소 높이 진단/원본 캡처와 별도 상태 JSON 검증/비교본 해시 분리 규칙을 보완했다. 외부 원본 스킬 변경/새 설치는 없다.
실제 전체 24/24, HUD v2 72/72, 본게임 140/140, 검토 HUD43/43, emergency79/79 통과.
실제 Godot 원본 캡처 6장(필수 5장+기존 검토 도시 1장), A2 비교본 2장을 구분해 저장했다.
최초 22/24 실패는 구분선 기본 최소 높이로 dock이 화면 밖으로 넘친 것이며 1px divider로 고친 뒤 전체 재실행했다.
1B/가격/사운드/실제 행복도·월별 재정은 미구현, 원본 소형소방서 높이 한계는 사용자 결정 대기다.
변경 목록은 각 validation 폴더 changed-files.txt다. 로컬 커밋까지만이며 main 푸시하지 않는다.

## 이전 작업: 응급·치안·교정 7종 검사창 등록 (2026-11-10 KST)

main 21d36db에서 feature/emergency-assets로 분기했다. 원본 51파일 해시 보존,
7개 GLB/원본 PNG/spec/카탈로그와 ready 슬롯을 연결했다. 도시 건설/운영/가격 적용은 없다.
[실측·실제 공통 축척 렌더·전체 23/23 및 신규 79/79](emergency-assets-validation/README_KO.md).
소형소방서 문 높이 3.40m < 기존 소방차 3.53m(약 −0.13m)은 원본 한계로 남기며 사용자 결정 대기다.
원본 .blend/metadata/빌드 스크립트를 수정하거나 빌드 스크립트를 재실행하지 않았다.
기존 recovered exporter는 metadata 쓰기가 있어 실행하지 않고 새 읽기 전용 파생 exporter를 사용했다.
개인 프로필 godot-windows-validation/test-driven-development/requesting-code-review(MIT, 별도 고정 SHA 미제공)와
기존 저장소 facilities/vehicles/게임 UI 스킬의 단위·검증 범위를 적용했다. 외부 스킬/라이선스 변경 없음.
검토는 자체 diff/정적 검사이며 독립 에이전트 리뷰가 아니다. 파생 도구와 실제 명령/로그는 위 보고서에 있다.
로컬 커밋만 승인됐으며 main 푸시는 하지 않는다. 하단바 v2 승인 문서/시안은 다음 브랜치에 분리한다.

## 이전 작업: 승인된 1A와 원본 회수 병합·main 반영 (2026-11-10 KST)


현재 체크아웃 `D:/project/simcity`(사용자 요청으로 이동, 이전 경로 `C:/Users/wlgml/projects/simcity`).
사용자 승인으로 1A a367fac와 origin/main a4913a2를 병합했다. 인계장 충돌 1개는 UI 기록과 원본 회수 기록을 모두 보존해 해결했다.
기획자가 작성한 AGENTS/mistake/하단바v2/경제루프 문서는 내용 수정 없이 별도 docs 커밋했다.
GitHub 병합 절차와 개인 프로필 godot-windows-validation 지침(자체 MIT)을 적용했으며 새 스킬 설치/수정은 없다.
Godot 4.6.3 임포트 후 전체 22개 스크립트를 이 경로에서 새로 실행해 22/22 통과했다.
[이번 실행·명령·원본 로그](1a-main-merge-validation/results.json). 이전 검증 수치/로그는 보존했다.
이제 main fast-forward 및 원격 푸시가 승인된 범위다. pending 7슬롯·게임 코드·서비스 카탈로그는 변경하지 않는다.
하단바 v2 구현·건물 변환/등록·사운드 등록·가격 적용은 하지 않으며 .import churn/기존 미추적 .uid8개를 제외한다.

## 이전 작업: 본게임 하단 HUD 통합·소방/경찰/교정 빈 슬롯 1A (2026-11-10 KST)

실제 Windows 공용 체크아웃은 현재 `D:/project/simcity`(사용자 요청으로 이동, 이전 경로 `C:/Users/wlgml/projects/simcity`), main/origin/main e8fff35에서
`feature/bottom-ui-main-integration`로 작업했다. [범위·재현·실패/최종 로그·화면](bottom-ui-main-validation/README_KO.md).
현재 지시는 로컬 브랜치 커밋까지만이며 원격 푸시/머지는 하지 않는다.
마무리 fetch에서 origin/main a4913a2의 원본 7종 회수를 확인했다. 이 브랜치에는 병합하지 않았으며
슬롯의 pending_asset은 게임 연결 대기를 뜻한다. 원본 부재로 간주하거나 재제작하지 않는다.
`ECONOMY_LOOP_SPEC_KO.md`는 수정/포함하지 않고 기획자가 준 FIRE_POLICE 슬롯 문서는 근거로 포함한다.

읽고 적용한 저장소 스킬: `.agents/skills/{cities-do-construction,game-ui-ux,godot-gdscript,godot-gdscript-headless-testing}/SKILL.md`.
construction은 프로젝트 자체 지침이며 별도 외부 SHA/라이선스를 부여하지 않는다.
나머지 세 원본은 https://github.com/gamedev-skills/awesome-gamedev-agent-skills,
고정 `19d93f97c9c1ea0f8b306e77aa81e0d3e352d3e9`, Apache-2.0이며 기존 LICENSE/NOTICE/UPSTREAM을 보존했다.
anchor/container·포커스 추적·명시적 실패 집계·종료 코드+오류 로그 검사를 적용했다.
환경 프로필의 `software-development/{test-driven-development,systematic-debugging,requesting-code-review}/SKILL.md`도
읽어 실패→구현→재검사/원인 추적/자체 diff·정적 점검에 사용했다. 해당 제공본은 MIT이며 별도 upstream 고정 SHA는
제공되지 않았다. 레포에 새로 설치하거나 원본을 변경하지 않았으며 독립/병렬 리뷰 에이전트를 실행했다고 주장하지 않는다.

변경: main의 UI 생성 메서드 분리와 `main.tscn`의 공유 `bottom_ui.gd` 연결,
검토 장면에는 예제 도시만 유지, pending_slots.json의 7칸·12분류·기존 기능 하단 경로,
test_main_bottom_ui와 기존 UI/전력/수도/전시/차량/구획 검사 진입 경로, Python 검증기·README/백로그·경제 CSV 상태 설명.
서비스 카탈로그·기존 원본/GLB/PNG·시뮬레이션 규칙·가격 수치는 변경하지 않았다.
빈 경로/pending 상태는 직접 신호를 보내도 비활성이며 ready+실제 spec 경로만 애셋 보기로 활성화한다.
이 활성화는 도시 배치를 뜻하지 않는다. 기존 보건·교육 모델도 계속 애셋 보기이며 1B 도시 배치는 미구현이다.

이번 실제 Windows 실행: Godot 4.6.3 표준, 전체 22스크립트 통과·본게임 HUD146/146·검토 HUD46/46.
초기 전체18/22와 실패4개 로그는 보존했고 지연 포커스/구획 도구 수 검사를 수정한 뒤 전체를 새로 실행했다.
1920×1080 네 장과 1280×820 한 장은 실제 GL Compatibility / RTX 2070 SUPER 창의 뷰포트다.
Windows borderless 작업영역 제한은 fullscreen 재촬영으로 해결했으며 이미지 확대/합성을 하지 않았다.
Blender 4.3.2 공식 ZIP 포터블은 앞 환경 검증에서 설치·버전 확인했지만 이번 1A에는 Blender 제작을 실행하지 않았다.
실행 도구 경로·명령은 보고서, tests/captures JSON에 있다. 설치는 개인 프로필 tools 아래이며 시스템 PATH를 변경하지 않았다.
재임포트 .import churn과 이전 .uid8개는 커밋에서 제외하고 이번 새 .gd2개의 .uid만 포함한다.
Git 작성자 기본 설정은 없으므로 현재 인증 GitHub 계정/ID 기반 noreply를 명령 한정 `git -c`로 사용한다.
전역/저장소 작성자 설정이나 시스템 PATH를 바꾸지 않았다.
대규모 성능/모바일/물리 게임패드·시설 배치/출동·경제 운영·사용자 건물 인수는 하지 않았다.

## 최신 작업: 소방·경찰·교도소 7종 원본 업로드 (2026-11-10 KST)

환경 복구 후 사용자가 이전에 요청한 GitHub 업로드를 재개했다. fetch로 main e8fff35를 확인하고
기존 체크아웃을 fast-forward했다. GitHub에는 해당 원본 폴더가 없었으며 이전 stash의 untracked
트리에서 assets/fire-study·police-study·prison-study 51파일을 바이트 그대로 회수했다.
[7종 이름/ID/부지/원본·이미지/검증](recovered-emergency-assets/README_KO.md).

cloud-environment-runtime 지침으로 환경/네트워크를 조회했다. 새 제작 스킬·외부 모델·스킬 변경은 없다.
원본 직접 제작/DejaVu FONT_LICENSE와 편집 Blend·PNG·metadata·생성 스크립트를 보존했다.
이번에는 Blender 4.3.2로 원본7개를 읽어 유한 메시/metadata 경계, Pillow로 PNG14장,
51파일 SHA/원본 바이트 일치를 검사했다. tools/verify_emergency_sources.py로 재현한다.
전체 게임 회귀/새 렌더/시설 운영·배치·가격 적용은 수행하지 않았다. 게임 코드와 기존 차량·보건/교육
등록은 수정하지 않고 관련 원본/인덱스/검증/이 인계장만 커밋·푸시한다.

## 최신 작업: 병원·진료소와 기존 공공 애셋/탭 재확인 (2026-11-04 KST)

사용자가 이미 된 작업을 먼저 확인하라고 정정했다. 로컬 cdca2de와 원격 4651283을
비교하고 fetch/fast-forward하여 기존 모델·보건/교육 탭을 보존했다.
[이번 현재 상태·화면·명령](service-recheck-validation/README_KO.md)을 확인한다.
미리보기는 도시 건설/의료·교육/출동 운영이 아니다. 기존 기타 탭에는 항목이 없었고 현재 제거돼 있다.

기존 cities-do-vehicles(원본 zstack 74f7786e9931b9ced858a0e2df880f23e4c2430e, MIT)의
단위·검증 범위와 construction/GDScript/headless-testing 지침을 읽고 적용했다.
새 외부 스킬/애셋·가격 도입, 원본 모델 재제작·Blender 전체 제작 파이프라인 실행은 없다.
제품 코드와 기존 모델을 변경하지 않았다. 검사에서 버튼 부재를 건너뛰던 경로를 없애고
교육/보건 각 4개 버튼·대응 창 제목·실제 메시를 모두 검사하도록 보강했다.
AGENTS에 새 환경에서 원격 비교 후 미구현 여부를 판단하는 지침도 남겼다.

이번 실행은 전체 21스크립트 통과, 회수/메뉴59/59·서비스9/9·차량308/308·하단UI36/36이다.
공공차량 3종의 PNG24장 알파/크기를 확인했다. tools/capture_service_recheck.gd는 실제 버튼을
눌러 보건·교육 탭과 병원·진료소·대형병원·화장터 창을 캡처하며 도시34개를 보존한다.
전시 화면도 새로 촬영했다. Xorg dummy/llvmpipe 사용; 그래픽 캡처와 headless를 구분한다.
기존 SERVICE_ASSETS 문서의 비활성 설명은 역사 기록으로 표시하고 최신 상태로 연결했다.
관련 검사·문서·실제 이미지를 같은 작업으로 Git main에 커밋·푸시한다.

## 최신 작업: 기존 차량 보존·원본 18종 및 교육/의료 회수 (2026-11-04 KST)

기존 오프라인 환경이 복구됐다. 전체 디렉터리/.git 백업+해시 확인과 stash 뒤 기존 체크아웃을
main e4a8c1d로 fast-forward했다. [실제 변경·재현·한계·검증](recovered-assets-validation/README_KO.md).
원본과 현재 등록본을 동일 카메라/조명/쌍별 축척으로 비교해 20쌍이 다른 모델임을 확인했다.
사용자 결정은 기존 23종 유지, 원본 버스·택시 제외, 나머지 원본 18종 추가이며 최종 사용자 요청으로 커밋·푸시한다.

기존 cities-do-vehicles/SKILL.md, vehicle/SKILL.md·rig-contract, cities-do-construction,
godot-gdscript 및 godot-gdscript-headless-testing 지침을 읽고 적용했다. 외부 원본 스킬은 수정하지 않았다.
vehicle 출처 https://github.com/duolahypercho/zstack, 고정 74f7786e9931b9ced858a0e2df880f23e4c2430e, MIT.
GDScript 두 스킬의 기존 고정 출처/Apache-2.0 NOTICE는 그대로다. 새 외부 스킬 설치는 없다.
이번에는 기존 제작된 18종을 회수·등록·방향 렌더링했으며 common.py 제작 파이프라인/실차IoU/
문개폐/충돌 게이트를 새로 실행한 것이 아니다. 교육·의료는 회수 .blend를 열어 GLB로 내보냈다.

새 경로 assets/original-vehicle-fleet, tools/{capture_original_vehicle_sprites.gd,
register_original_vehicle_sprites.py,export_recovered_services.py}, vehicles original-*와 services 7종.
메뉴/전시/traffic civilian 후보/검증기를 연결했다. 카탈로그41·Blender41·GLB41·PNG328 구조 검사,
기존 230파일 해시 보존, 11스크립트 통과(차량308/308·회수애셋38/38), 실제 교육·의료7종 화면 확인.
기존 23종 모델 재제작과 전체 upstream 게이트, 대량 성능/시설운영·도시 배치는 실행/구현하지 않았다.
등록이 가격 승인/새 과금이라는 뜻은 아니다. 기존 미승인 PRICE/CAPACITY 제안은 유지했다.
초기 검사/수정과 명령은 링크한 보고서와 로그를 확인한다. 최종 사용자 지시에 따라 관련 소스·스킬 인계장·검증을 함께 커밋·푸시한다.

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
