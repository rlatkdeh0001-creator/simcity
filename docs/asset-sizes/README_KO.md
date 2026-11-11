# 건물·시설 크기표

1칸=4m. **2×2=8×8m, 4×4=16×16m, 8×8=32×32m**다. 크기는 건물 본체가 아닌 건물이 차지하는 부지 기준이다.

원본 규격은 각 폴더의 `metadata.json` → `footprint_cells`, 공원·주차·화장터는 `spec.json` → `width`/`depth`에 있다.
게임 등록 크기는 `cities_do/assets/buildings/catalog.json`의 `footprint`, services/facilities 카탈로그의 `width`/`depth`에도 있다.
[CSV 내려받기/Excel용](sizes.csv) · [JSON](sizes.json)

6×6 및 2×4·4×8도 원본에 있는 값을 그대로 표시한다. 시안 규격을 정식 건설 규칙으로 새로 승인한 것은 아니다.
수력발전댐은 사용자가 길이를 정하므로 고정 칸 수가 없다. 시안의 48m 댐 길이나 배경판 60×32m를 고정 필지로 쓰지 않는다.
이 표는 규격 조회용이며 런타임 로더가 아니다. 크기를 수정할 때 원본·실제 모델·게임 카탈로그를 함께 맞춰야 한다.

총 63종. 과거 archive와 차량은 중복 집계하지 않았다.

## 주거

| 이름 | 부지(칸) | 부지(m) | 규격 상태 | ID / 원본 규격 |
|---|---|---|---|---|
| 벽돌형 맨션 | 4×4 | 16×16 | 원본 규격 | [mansion-a-4x4-4f](../../assets/mansion-study/a-brick/metadata.json) |
| 모던형 맨션 | 4×4 | 16×16 | 원본 규격 | [mansion-b-4x4-4f](../../assets/mansion-study/b-modern/metadata.json) |
| 발코니 아파트 | 4×4 | 16×16 | 원본 규격 | [large-4x4-a](../../assets/residential-eight/large-4x4-a/metadata.json) |
| 코너 주거타워 | 4×4 | 16×16 | 원본 규격 | [large-4x4-b](../../assets/residential-eight/large-4x4-b/metadata.json) |
| L자형 주거 아파트 | 8×8 | 32×32 | 원본 규격 | [large-8x8-a](../../assets/residential-eight/large-8x8-a/metadata.json) |
| 계단형 주거타워 | 8×8 | 32×32 | 원본 규격 | [large-8x8-b](../../assets/residential-eight/large-8x8-b/metadata.json) |
| 단층 전원주택 | 2×2 | 8×8 | 원본 규격 | [small-2x2-a](../../assets/residential-eight/small-2x2-a/metadata.json) |
| 2층 타운하우스 | 2×2 | 8×8 | 원본 규격 | [small-2x2-b](../../assets/residential-eight/small-2x2-b/metadata.json) |
| 정원형 단독주택 | 4×4 | 16×16 | 원본 규격 | [small-4x4-a](../../assets/residential-eight/small-4x4-a/metadata.json) |
| 안뜰형 연립주택 | 4×4 | 16×16 | 원본 규격 | [small-4x4-b](../../assets/residential-eight/small-4x4-b/metadata.json) |

## 상업

| 이름 | 부지(칸) | 부지(m) | 규격 상태 | ID / 원본 규격 |
|---|---|---|---|---|
| AUREL 백화점 | 4×4 | 16×16 | 원본 규격 | [large-4x4-department-07](../../assets/commercial-study/large-4x4-department-07/metadata.json) |
| NOVA 오피스 타워 | 4×4 | 16×16 | 원본 규격 | [large-4x4-office-nova-08](../../assets/commercial-study/large-4x4-office-nova-08/metadata.json) |
| AUREL GRAND 대형 백화점 | 8×8 | 32×32 | 원본 규격 | [large-8x8-grand-department-09](../../assets/commercial-study/large-8x8-grand-department-09/metadata.json) |
| NOVA CENTRAL 트윈 복합타워 | 8×8 | 32×32 | 원본 규격 | [large-8x8-twin-central-10](../../assets/commercial-study/large-8x8-twin-central-10/metadata.json) |
| 벽돌형 식당·서비스 상가 | 4×4 | 16×16 | 원본 규격 | [medium-4x4-brick-services-06](../../assets/commercial-study/medium-4x4-brick-services-06/metadata.json) |
| 업무·상가 복합빌딩 | 4×4 | 16×16 | 원본 규격 | [medium-4x4-office-retail-05](../../assets/commercial-study/medium-4x4-office-retail-05/metadata.json) |
| 자동차 전시장 AUTO | 2×2 | 8×8 | 원본 규격 | [small-2x2-auto-02](../../assets/commercial-study/small-2x2-auto-02/metadata.json) |
| 동네 MART | 2×2 | 8×8 | 원본 규격 | [small-2x2-mart-01](../../assets/commercial-study/small-2x2-mart-01/metadata.json) |
| 식당·카페 복합상가 | 4×4 | 16×16 | 원본 규격 | [small-4x4-cafe-diner-04](../../assets/commercial-study/small-4x4-cafe-diner-04/metadata.json) |
| 동네 슈퍼마켓 | 4×4 | 16×16 | 원본 규격 | [small-4x4-market-03](../../assets/commercial-study/small-4x4-market-03/metadata.json) |

## 공업

| 이름 | 부지(칸) | 부지(m) | 규격 상태 | ID / 원본 규격 |
|---|---|---|---|---|
| 화학 생산시설 | 4×4 | 16×16 | 원본 규격 | [large-4x4-chemical-06](../../assets/industrial-study/large-4x4-chemical-06/metadata.json) |
| 제약 생산시설 | 4×4 | 16×16 | 원본 규격 | [large-4x4-pharma-05](../../assets/industrial-study/large-4x4-pharma-05/metadata.json) |
| 자동차 조립공장 | 8×8 | 32×32 | 원본 규격 | [large-8x8-auto-assembly-07](../../assets/industrial-study/large-8x8-auto-assembly-07/metadata.json) |
| 대규모 화학 플랜트 | 8×8 | 32×32 | 원본 규격 | [large-8x8-chemical-complex-08](../../assets/industrial-study/large-8x8-chemical-complex-08/metadata.json) |
| 전자부품 공장 | 4×4 | 16×16 | 원본 규격 | [medium-4x4-circuitworks-04](../../assets/industrial-study/medium-4x4-circuitworks-04/metadata.json) |
| 정밀기계 공장 | 4×4 | 16×16 | 원본 규격 | [medium-4x4-precision-03](../../assets/industrial-study/medium-4x4-precision-03/metadata.json) |
| 식품가공 작업장 | 2×2 | 8×8 | 원본 규격 | [small-2x2-foodworks-02](../../assets/industrial-study/small-2x2-foodworks-02/metadata.json) |
| 금속가공 작업장 | 2×2 | 8×8 | 원본 규격 | [small-2x2-metalworks-01](../../assets/industrial-study/small-2x2-metalworks-01/metadata.json) |

## 발전

| 이름 | 부지(칸) | 부지(m) | 규격 상태 | ID / 원본 규격 |
|---|---|---|---|---|
| 석탄발전소 | 8×8 | 32×32 | 원본 규격 | [power-coal](../../assets/power-study/coal/metadata.json) |
| 수력발전댐 | 가변 | 가변 | 가변 길이 · 고정 필지 없음 | [power-hydro](../../assets/power-study/hydro/metadata.json) |
| 원자력발전소 | 8×8 | 32×32 | 원본 규격 | [power-nuclear](../../assets/power-study/nuclear/metadata.json) |
| 석유발전소 | 8×8 | 32×32 | 원본 규격 | [power-oil](../../assets/power-study/oil/metadata.json) |
| 태양광발전소 | 4×4 | 16×16 | 원본 규격 | [power-solar](../../assets/power-study/solar/metadata.json) |
| 풍력발전소 | 2×2 | 8×8 | 원본 규격 | [power-wind](../../assets/power-study/wind/metadata.json) |

## 상하수도

| 이름 | 부지(칸) | 부지(m) | 규격 상태 | ID / 원본 규격 |
|---|---|---|---|---|
| 취수장 | 4×4 | 16×16 | 시안 규격 | [water-intake](../../assets/water-study/intake/metadata.json) |
| 하수장 | 4×4 | 16×16 | 시안 규격 | [water-sewage-outfall](../../assets/water-study/sewage-outfall/metadata.json) |
| 하수처리장 | 8×8 | 32×32 | 시안 규격 | [water-sewage-treatment](../../assets/water-study/sewage-treatment/metadata.json) |
| 급수탑 | 2×2 | 8×8 | 시안 규격 | [water-water-tower](../../assets/water-study/water-tower/metadata.json) |

## 쓰레기

| 이름 | 부지(칸) | 부지(m) | 규격 상태 | ID / 원본 규격 |
|---|---|---|---|---|
| 쓰레기 소각장 | 8×8 | 32×32 | 시안 규격 | [waste-incinerator](../../assets/waste-study/incinerator/metadata.json) |
| 재활용센터 | 8×8 | 32×32 | 시안 규격 | [waste-recycling-center](../../assets/waste-study/recycling-center/metadata.json) |

## 소방

| 이름 | 부지(칸) | 부지(m) | 규격 상태 | ID / 원본 규격 |
|---|---|---|---|---|
| 소방서 | 6×6 | 24×24 | 시안 규격 | [fire-station](../../assets/fire-study/fire-station/metadata.json) |
| 광역 소방서 | 8×8 | 32×32 | 시안 규격 | [regional-fire-station](../../assets/fire-study/regional-fire-station/metadata.json) |
| 소형 소방서 | 4×4 | 16×16 | 시안 규격 | [small-fire-station](../../assets/fire-study/small-fire-station/metadata.json) |

## 경찰

| 이름 | 부지(칸) | 부지(m) | 규격 상태 | ID / 원본 규격 |
|---|---|---|---|---|
| 경찰서 | 6×6 | 24×24 | 시안 규격 | [police-station](../../assets/police-study/police-station/metadata.json) |
| 광역 경찰서 | 8×8 | 32×32 | 시안 규격 | [regional-police-station](../../assets/police-study/regional-police-station/metadata.json) |
| 소형 경찰서 | 4×4 | 16×16 | 시안 규격 | [small-police-station](../../assets/police-study/small-police-station/metadata.json) |

## 교정

| 이름 | 부지(칸) | 부지(m) | 규격 상태 | ID / 원본 규격 |
|---|---|---|---|---|
| 교도소 | 8×8 | 32×32 | 사용자 지정 | [prison-8x8](../../assets/prison-study/prison/metadata.json) |

## 의료

| 이름 | 부지(칸) | 부지(m) | 규격 상태 | ID / 원본 규격 |
|---|---|---|---|---|
| 진료소 | 4×4 | 16×16 | 시안 규격 | [medical-clinic](../../assets/medical-study/clinic/metadata.json) |
| 병원 | 6×6 | 24×24 | 시안 규격 | [medical-hospital](../../assets/medical-study/hospital/metadata.json) |
| 대형병원 | 8×8 | 32×32 | 시안 규격 | [medical-large-hospital](../../assets/medical-study/large-hospital/metadata.json) |

## 교육

| 이름 | 부지(칸) | 부지(m) | 규격 상태 | ID / 원본 규격 |
|---|---|---|---|---|
| 초등학교 | 4×4 | 16×16 | 사용자 지정 | [elementary-school](../../assets/education-study/elementary-school/metadata.json) |
| 고등학교 | 4×4 | 16×16 | 사용자 지정 | [high-school](../../assets/education-study/high-school/metadata.json) |
| 전문대 | 8×8 | 32×32 | 사용자 지정 | [technical-college](../../assets/education-study/technical-college/metadata.json) |
| 대학교 | 8×8 | 32×32 | 사용자 지정 | [university](../../assets/education-study/university/metadata.json) |

## 공원·주차

| 이름 | 부지(칸) | 부지(m) | 규격 상태 | ID / 원본 규격 |
|---|---|---|---|---|
| 꽃정원 공원 | 2×2 | 8×8 | 원본 규격 | [park-garden-2x2](../../assets/facilities/park-garden-2x2/spec.json) |
| 놀이터 공원 | 4×4 | 16×16 | 원본 규격 | [park-play-4x4](../../assets/facilities/park-play-4x4/spec.json) |
| 분수 광장 공원 | 4×4 | 16×16 | 원본 규격 | [park-plaza-4x4](../../assets/facilities/park-plaza-4x4/spec.json) |
| 쉼터 공원 | 2×2 | 8×8 | 원본 규격 | [park-pocket-2x2](../../assets/facilities/park-pocket-2x2/spec.json) |
| 대형 주차장 | 4×8 | 16×32 | 원본 규격 | [parking-large-4x8](../../assets/facilities/parking-large-4x8/spec.json) |
| 중형 주차장 | 4×4 | 16×16 | 원본 규격 | [parking-medium-4x4](../../assets/facilities/parking-medium-4x4/spec.json) |
| 소형 주차장 | 2×4 | 8×16 | 원본 규격 | [parking-small-2x4](../../assets/facilities/parking-small-2x4/spec.json) |
| 4층 주차타워 | 4×4 | 16×16 | 원본 규격 | [parking-tower-4x4-4f](../../assets/facilities/parking-tower-4x4-4f/spec.json) |

## 기타 공공시설

| 이름 | 부지(칸) | 부지(m) | 규격 상태 | ID / 원본 규격 |
|---|---|---|---|---|
| 화장터 | 4×4 | 16×16 | 원본 규격 | [crematorium-4x4](../../assets/service-facilities/crematorium-4x4/spec.json) |

재생성: 저장소 루트에서 `python tools/build_asset_size_index.py`. 원본·카탈로그 값이 다르면 생성이 중단된다.
