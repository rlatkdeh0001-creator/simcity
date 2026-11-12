# 1차 산업 마무리 · 연결형 광산/목초지3변형/메인8종

**최신 광산 수정:** [철=붉은 크러셔 / 석탄=대형 검은 야적+컨베이어](../mine-silhouettes/README_KO.md). 나머지19애셋은 보존했다.

브랜치 assets/primary-industry-20261112. 현재 전체는 **메인9종 + 작업지12종 = 21종**이다.
사용자 최신 요청에 따라 철/석탄 구덩이 반복을 없애고, 소 없는 목초지와 서로 다른 위치/방향의 소 타일을 추가했으며,
원래 요청서의 남은 메인 건물8종을 모두 제작했다. 게임/메뉴/자원·생산/카탈로그 적용과 main 병합은 하지 않았다.

## 메인 건물8종

![신규 메인8종](mains-overview.png)
각 미리보기는 실제 Blender 원본 렌더다. 검토표만 기존 Pillow/Noto로 배치/축소했다.
모두 4×4칸=16×16m이며 Blender -Y 정면/+Z 위, Godot +Z 정면을 유지한다.
층수는 점유 건물 기준이며 권양탑/사일로/크레인/지붕을 별도 점유층으로 세지 않는다.

| 시설 | 실측 W×D×H(m) | 점유층 | 삼각형 |
|---|---|---|---:|
| 채소·과수 농장 | 16.000×16.000×7.440 | 2 | 3,980 |
| 축산 농장 | 16.000×16.000×6.640 | 1 | 4,318 |
| 벌목장 | 16.000×16.000×5.439 | 1 | 2,068 |
| 철광산 | 16.000×16.000×9.400 | 1 | 6,850 |
| 석탄 광산 | 16.000×16.000×9.400 | 1 | 2,448 |
| 유정 본부 | 16.000×16.000×7.440 | 2 | 2,708 |
| 우라늄 광산 | 16.000×16.000×4.390 | 1 | 6,118 |
| 어항 | 16.000×16.000×4.390 | 1 | 3,912 |

전체 H는 바닥판을 포함한다. 층고3.05m, 지면 바닥판−0.12~+0.12m, 모든 건물·마당·장비는 부지 안이다.
채소 농장은 농가/선별장/비닐하우스2동, 축산은 긴 우사/사일로/울타리 마당, 벌목장은 제재소/통나무/크레인,
광산은 갱구/권양탑/업종별 광석(석탄에는 컨베이어), 유정은 사무동/탱크2기/펌프잭,
우라늄은 갱구/밀폐 저장고/방사능 표식/철망, 어항은 처리장/부두/어선2척으로 구성했다.

## 채굴지 · 한 깊이의 넓은 바닥

![철 채굴지3×3](../../../assets/primary-industry/primary-tile-mine-iron-01/tile-3x3.png)
![석탄 채굴지3×3](../../../assets/primary-industry/primary-tile-mine-coal-01/tile-3x3.png)
- 전체4×4m 바닥은z=−0.30m로 동일하며, 매설 바닥은−0.42m다. 개별 타일을 둘러싸는 구덩이/닫힌 테두리를 제거했다.
- 낮은 계단 띠와 광석/흙 둔덕은Y방향 경계까지 연장했다. 인접 타일에서 같은 단면/높이/재질로 이어진다.
- X방향은 같은 평탄 바닥으로 연결된다. 3×3 전체가 열린 평행 작업면으로 보이고 타일마다 분리된 구덩이가 되지 않는다.
- 자원 영역 바깥의 도로/일반 지형0m와의 외곽 전환은 후속 배치 시스템 범위다. 이번 타일에는 영역 외곽 테두리/진입 램프를 고정하지 않는다.

## 목초지3변형

![수정 타일](tiles-overview.png)
![25칸 혼합 목초지](pasture-mixed-5x5.png)
01은 소 없는 풀밭,02는 소를 좌측에 두고28도 회전,03은 우측의 소를−66도 회전했다.
바닥 높이/색/4×4m 경계는 세 변형 모두 동일하다. 소의 실제 중심과 방향이 다른 것도 원본 기하로 검사했다.
위25칸 시안은 고정 시드1212/빈 타일50%·소 변형 각25% 가중치로 뽑고90도 회전을 섞었다.
이는 실제 Blender 비교 장면의 배치 레시피이며 게임의 랜덤 선택 로직을 구현했다는 뜻이 아니다.
시각 변형만으로 논리적인 작업지 생산 수치를 자동으로 바꾸지 않는다.

| 수정/추가 타일 | 실측 W×D×H(m) | 삼각형 |
|---|---|---:|
| 철 채굴지 (primary-tile-mine-iron-01) | 4.000×4.000×0.250 | 52 |
| 석탄 채굴지 (primary-tile-mine-coal-01) | 4.000×4.000×0.250 | 52 |
| 목초지·빈 풀밭 (primary-tile-pasture-01) | 4.000×4.000×0.120 | 12 |
| 목초지·소 좌측 (primary-tile-pasture-02) | 4.000×4.000×1.410 | 216 |
| 목초지·소 우측 (primary-tile-pasture-03) | 4.000×4.000×1.410 | 216 |

## 어항 후면 검수

![어항 후면](../../../assets/primary-industry/primary-fishing-01/rear-review.png)
정면 도로는−Y, 물은 뒤쪽+Y다. 육지판은Y=+2m에서 끝나며 부두와 두 어선은+2~+8m 안에 있다.
물판을 모델에 넣지 않았고 부두가 부지를 넘어가지 않는다. 파도/수위/접안·출항 AI는 구현하지 않았다.

## 개별 메인 원본/PNG

### 채소·과수 농장

[원본·metadata](../../../assets/primary-industry/primary-farm-vegetable-01/)

![채소·과수 농장](../../../assets/primary-industry/primary-farm-vegetable-01/building.png)

### 축산 농장

[원본·metadata](../../../assets/primary-industry/primary-farm-livestock-01/)

![축산 농장](../../../assets/primary-industry/primary-farm-livestock-01/building.png)

### 벌목장

[원본·metadata](../../../assets/primary-industry/primary-forestry-01/)

![벌목장](../../../assets/primary-industry/primary-forestry-01/building.png)

### 철광산

[원본·metadata](../../../assets/primary-industry/primary-mine-iron-01/)

![철광산](../../../assets/primary-industry/primary-mine-iron-01/building.png)

### 석탄 광산

[원본·metadata](../../../assets/primary-industry/primary-mine-coal-01/)

![석탄 광산](../../../assets/primary-industry/primary-mine-coal-01/building.png)

### 유정 본부

[원본·metadata](../../../assets/primary-industry/primary-oil-01/)

![유정 본부](../../../assets/primary-industry/primary-oil-01/building.png)

### 우라늄 광산

[원본·metadata](../../../assets/primary-industry/primary-mine-uranium-01/)

![우라늄 광산](../../../assets/primary-industry/primary-mine-uranium-01/building.png)

### 어항

[원본·metadata](../../../assets/primary-industry/primary-fishing-01/)

![어항](../../../assets/primary-industry/primary-fishing-01/building.png)

## 이번 실행한 검증과 출처

- [메인156검사](main-geometry-validation.json): 원본8개 재개방, 정확한16m 부지/실측/삼각형/정면 접근점/30도 정투영/투명,
  요청한 업종별 구성 개수와 어항의+Y 물가/부지 내 부두·배를 검사했다.
- [작업지227검사](../work-tiles/geometry-validation.json): 12타일, 네 변 형상/재질 연결, 단일 광산 바닥/단차 연속,
  소 없는01/02·03의4다리·접지·실제 서로 다른 위치/방향·세 변형 경계 호환, 곡물 원본 정확 복원 등을 통과했다.
- [PNG34장](image-validation.json): 현재21종의 단일/3×3/어항 후면을 디코딩해 크기/RGBA/투명/프레임/해시를 확인했다.
- [기존31파일 보존](preserved-assets.json): 승인된 매끈한 곡물과 다른6작업지의 원본/PNG/metadata 및 곡물 농장 원본은473d6e0과 바이트 동일이다.
- 기존 곡물/농장48검사도 재실행했다. 실제 렌더는 Blender4.3.2 CPU Cycles48샘플이며 외부 모델/텍스처/생성형 이미지/API 없음.
- 최초 로그에는 후속 확인 전의 이동/회전 시안이 포함돼 있다. 최종 pasture-final-build.log와 main-final-build.log, 현재 metadata/검증이 제출 버전이다.
- 원래 내부 cities-do-construction의4m/부지/정면 규약과 primary/growth/작업지 helper를 재사용했다. 새 외부 upstream/패키지/에이전트 없음.
- 이동된 묶음의 월드 행렬을 읽기 전 view_layer.update로 변환을 확정한다. 소의 접지/높이와 소품의 부지 경계 검사로 배치를 확인했다.
- GLB 변환/게임 등록/자동 작업지 확장·삭제/고저차 전환/실제 생산/차량·선박·기계 애니메이션/교통/성능 검증/main 병합은 별도다.

재현:
```sh
blender -b --factory-startup -t 4 -P tools/build_primary_main.py
# 바뀐 타일만: 아래 생성기에 -- --only ID
blender -b --factory-startup -t 4 -P tools/build_primary_work_tiles.py -- --only primary-tile-mine-iron-01
blender -b --factory-startup -t 2 -P tools/verify_primary_main.py
blender -b --factory-startup -t 2 -P tools/verify_primary_work_tiles.py
blender -b --factory-startup -t 4 -P tools/render_primary_completion_review.py
python tools/build_primary_completion_sheet.py
```

[비용·용량·자체 수요 제안 · 전부 미승인/미적용](PROPOSALS_KO.md).
