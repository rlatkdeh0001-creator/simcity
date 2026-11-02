# 공공차량 3종·화장터와 보건·교육 탭

2026-11-03 KST. 시작 체크아웃 `/workspace/simcity`, 로컬 `work`, 깨끗한 작업 트리.
`git fetch origin main`으로 원격이 `cdca2de1b1504648837853a00555d67f5524f781`과 같음을 확인했다.
이 문서는 이번 코드·애셋 작업이며 소방·치안·보건 시뮬레이션 완료 보고서가 아니다.

## 실제 조사 결과와 탭

기존 `bottom_ui_preview.gd`의 ‘기타’에는 **선택 항목이 하나도 없었다**.
`NAMES`와 톱니 아이콘만 있고 `select_category`에 other 분기가 없었다.
설정 버튼은 빈 기타 탭을 열었으며 실제 설정 기능은 없었다. 빈 탭과 그 버튼을 제거했다.
옮겨야 할 나머지 항목도 없으며 기존 항목을 삭제한 것이 아니다.
병원·진료소·학교는 PRICE/CAPACITY 제안 문서에만 있었고 카탈로그·모델·서비스 엔진은 없었다.

- 보건: 병원·진료소·화장터. 앞의 두 항목은 비활성, 툴팁 ‘준비 중’.
- 교육: 기존 제안서의 초등학교·고등학교·전문대학·대학교. 애셋 부재로 비활성.
- 화장터: 메뉴에서 실제 GLB 검사 창을 연다. 닫아도 도시·카메라를 보존한다.
- 9개 분류의 키보드 순환과 작은 화면 가로 스크롤을 유지하고 맨 오른쪽 불도저를 보존했다.
- 보건·교육에서는 배치 격자와 전력/수도 오버레이가 꺼진다.

이 변경은 **하단 UI 검토 장면**에 적용했다. 메인 플레이 화면 전체 통합, 화장터의 도시 내
배치·접도·방향 선택·공급 소비 등록·철거는 이번에 구현하지 않았다.
향후 배치에는 기존 공통 1.5m 접도 판정과 실제 GLB 방향 렌더러를 사용해야 한다.
비활성 병원/학교를 가짜 작동 시설로 등록하거나 주거 건물을 대신 표시하지 않았다.

## 제작물

| ID | 이름 | 명목 길이×폭×높이(m) / 부지 | 구별 요소 |
|---|---|---|---|
| fire-engine-01 | 소방차 | 7.60×2.35×2.95 | 장비 셔터·사다리·호스 릴·경광등 |
| police-car-01 | 경찰차 | 4.85×1.87×1.48 | 청색 띠·가상 방패·적청 경광등 |
| hearse-01 | 운구차 | 5.50×1.95×1.85 | 긴 후방 수납실·커튼·은색 장식 |
| crematorium-4x4 | 화장터 | 16×16m=4×4칸, 부속 포함 높이 7.215m | 정문·추모 벤치·차폐 연도·후면 작업 출입구 |

기존 20종에는 중복 차종이 없었다. 기존 승용·산업차의 기초 형상/바퀴/운전석 제작 함수를
재사용하고 위 서비스별 형상을 추가했다. 미터 단위, Blender -Y 정면/+X 운전석/+Z 위,
GLB +Z 정면/+X 운전석/+Y 위와 바퀴 접지 0을 유지한다. 차량 명목 높이에는 경광등·사다리·
미러가 포함되지 않으며 게임용 가상 설계다. 브랜드·실차 복제는 아니다.
기존 20종 파일을 재제작하지 않았다. 신규 .blend/GLB/차량 24장 PNG/화장터 PNG/spec을 저장했다.
차량 카탈로그는 23종이며 일반 교통 데모의 기존 20종 배차는 바꾸지 않았다.
화장터는 주거 성장 카탈로그와 분리된 `assets/services/catalog.json`에 둔다.

## doth·용량 제안 — 전부 미승인·런타임 미적용

공공 구매 차량을 가정했다. 게임월=30게임일도 제안 전제다. 월 유지비에는 인력·정기 정비·
통상 연료비를 포함하는 안으로, 연료량 표를 별도 요금에 연결해 이중 과금하지 않는다.
소방서·경찰서의 기존 제안에 차량 구매비가 포함되는지는 미정이다. 아래 금액을 그대로
합산 청구하지 말고 차량 포함/별도 정책을 먼저 정한다.

| 애셋 | 구매/건설(doth) | 유지(doth/게임월) | 정격·평균·동시 용량 | 자체 소비·배출 제안 |
|---|---:|---:|---|---|
| 소방차 | 3,200 | 45 | 승무원 4명, 화재당 2대이므로 1대는 독립 진압 불가; 계획 평균 0.5건/게임일/대 | 운행일 연료 12L/게임일; 시설 전기·수도는 별도 |
| 경찰차 | 1,200 | 20 | 승무원 2명, 동시 1건, 계획 평균 4건/게임일 | 운행일 연료 6L/게임일 |
| 운구차 | 1,800 | 25 | 동시 1구, 정격 6구/게임일, 평균 3구/게임일 | 운행일 연료 8L/게임일 |
| 화장터 | 12,000 | 180 | 대기 20구(저장), 정격 12구/게임일, 평균 6구/게임일; 차고 2대(차량 별도) | 정격 전기 35kW·상수 3m³/게임일·하수 2.4m³/게임일·열연료 600kWh-열/게임일; 유골 36kg/게임일 |

차량 처리량은 경로·이동시간·현장 체류·근무 인원에 의해 낮아진다. 사건/운구 횟수는
도로 속도나 모델 길이에서 자동으로 계산한 값이 아닌 초기 밸런스 가정이다.
화장터는 2로×6구/게임일의 정격을 가정하고 평균 50% 이용률을 별도 제시했다.
운구차 2대×평균 3구/일=6구/일이라 평균 유입이 병목이다. 대기 20구는 생산량이 아니다.
열연료 종류·배출가스 성분/허용치·필터 잔재량은 미정이고 CSV에 임의의 0을 넣지 않았다.
유골은 3kg/구×정격 12구/일의 별도 수거물 가정이며 일반 쓰레기와 동일시하지 않는다.

소방차는 기존 소형소방서 8,000보다 낮되 장비 때문에 경찰차보다 비싸게 잡았다.
경찰차는 일반 순찰 승용차, 운구차는 특장 수납 차량의 차이를 반영했다.
화장터는 진료소 6,000·병원 25,000 사이의 설비 투자로 제안한다.
시작 50,000 doth에서 차량은 각각 6.4%/2.4%/3.6%, 화장터는 24%다.
네 종류 각 1개는 18,200 doth(잔액 31,800), 유지 270/게임월이다.
실용 운구 예시 화장터+운구차 2대는 15,600(잔액 34,400), 유지 230/게임월이다.
수요·세금·인력 엔진이 없어 지속 가능성은 검증하지 않았다.
[경제 CSV](economy-balance/ECONOMY_BALANCE.csv)에 같은 값/단위/미적용 상태를 등록했다.

## 출처·재현

`.agents/skills/cities-do-vehicles`, `vehicle/reference/rig-contract.md`, construction,
godot-gdscript, godot-gdscript-headless-testing, modular-facilities의 애셋 보존 규약을 읽었다.
원본 vehicle: https://github.com/duolahypercho/zstack ,
`74f7786e9931b9ced858a0e2df880f23e4c2430e`, MIT.
원본 SKILL.md/UPSTREAM.json/LICENSE는 수정하지 않았다. 기존 배포 라이선스도 유지한다.
실제 common.py의 empty/parent_keep/rounded_box/revolve/tri_count 및 scene 도구를 재사용했다.
원본의 이미지 참조·cage/IoU·문 개폐·충돌 변형 전체 파이프라인은 실행하지 않았다.

```sh
blender -b --factory-startup -t 2 -P tools/build_vehicle_fleet.py -- --only fire-engine-01 --render
blender -b --factory-startup -t 2 -P tools/build_vehicle_fleet.py -- --only police-car-01 --render
blender -b --factory-startup -t 2 -P tools/build_vehicle_fleet.py -- --only hearse-01 --render
blender -b --factory-startup -t 2 -P tools/build_service_facility.py
blender -b --factory-startup -t 2 -P tools/verify_vehicle_sources.py
python3 tools/verify_vehicle_fleet.py --output docs/service-assets-validation/vehicle-files.json
```

차량 생성은 위처럼 **순차 실행**한다. --only는 선택 ID만 catalog/render_manifest에 병합하므로
동시에 실행하면 파일 갱신이 충돌할 수 있다. 전체 23종 재제작 명령과 구분한다.
Godot 명령에는 다음 환경 변수를 사용했다.

```sh
export XDG_DATA_HOME=/tmp/cities-do-data
export XDG_CONFIG_HOME=/tmp/cities-do-config
export XDG_CACHE_HOME=/tmp/cities-do-cache
godot --headless --editor --import --path cities_do --quit
python3 tools/validate_service_assets.py
godot --path cities_do service_assets_showcase.tscn -- --capture-vehicles=/absolute/path/service-assets.png
godot --path cities_do bottom_ui_preview.tscn -- --bottom-tab=health --capture-bottom-ui=/absolute/path/health-tab.png
```

[이번 실행 로그·실제 화면](service-assets-validation/)과 results.json을 확인한다.
실제 화면은 Godot GL Compatibility 렌더러이며 Blender 투명 PNG 및 headless 검사와 구분한다.
신규 환경에서 X 서버가 없어 Debian trixie xvfb/libxfont2/xserver-common 패키지를 `/tmp`에
압축 해제해 Xvfb :99를 실행했다. 시스템 설정/저장소 런타임 의존성은 바꾸지 않았다.
캡처 때 `DISPLAY=:99`와 위 XDG 경로를 사용했다. GPU·모바일·대규모 성능은 미검증이다.

## 이번 환경 최종 검증

전체 18개 스크립트 통과. 하단 UI 36/36, 차량 177/177, 신규 서비스 9/9,
도로 간격 49/49, 건물 정면 138/138이다. Blender 원본 23개와 GLB/PNG 23/184 구조 검사도 통과했다.
처음에는 하단 UI 34/36(좁은 화면 높이·창 식별), 신규 서비스 7/8(GLB 원점을 출입구
위치로 오해한 검사) 실패가 있었다. 높이/창 식별을 고치고 실제 메시 경계를 측정하도록
검사를 수정했다. 임계치를 완화하지 않았다. 초기 로그를 보존하고 해당 검사·영향받은
차량/UI를 선택 재실행했으며 results.json은 그 합본이다.
첫 캡처의 ALSA 장치 오류도 초기 로그에 보존하고 Dummy 음성 드라이버로 재캡처했다.
최종 로그의 SCRIPT ERROR/ERROR 유무를 확인했다. VSync 미지원과 기존 외부 Road Generator의
텍스처 UID 경고는 별개로 남아 있다. 원본 vehicle UPSTREAM의 파일 해시도 전부 일치했다.

- [네 애셋 실제 Godot 화면](service-assets-validation/service-assets.png)
- [보건 탭](service-assets-validation/health-tab.png)
- [교육 탭](service-assets-validation/education-tab.png)
- [검사 결과](service-assets-validation/results.json)
