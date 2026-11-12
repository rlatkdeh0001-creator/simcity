# 작업지10종 · 매끈한 곡물 스타일 기준

**현재 최종 작업:** [메인8종 완성·연결형 광산 바닥·목초지3변형](../completion/README_KO.md). 전체 메인9+작업지12=21종. 아래는 이전 단계 기록이다.

브랜치 assets/primary-industry-20261112. 사용자 최신 지시: 곡물밭을6afefd8로 되돌리고 같은 단순한 스타일로 나머지 작업지만 제작.
곡물 원본/metadata/단일 PNG/3×3 PNG/README의5개 파일은 지정 커밋과 바이트 단위로 일치한다.
곡물 생성기와 검사기도 해당 버전으로 복원했다. 이후 물결/톱니/밝기 변경은 현재 버전에서 제외했다.
이전 수정 이력은 Git ae3a3f0와 인계장에 보존된다.

## 새 작업지9종

![작업지9종](overview.png)
위 이미지는 실제 Blender 렌더9장을 배치·축소한 검토표다. 원본 PNG를 수정하거나 생성형 이미지로 만든 것이 아니다.

| 이름 | id | 실측 W×D×H(m) | 삼각형 |
|---|---|---|---:|
| 곡물 밭 | primary-tile-grain-01 | 4.000×4.000×0.860 | 140 |
| 채소·과수 밭 | primary-tile-vegetable-01 | 4.000×4.000×2.080 | 200 |
| 목초지 | primary-tile-pasture-01 | 4.000×4.000×1.410 | 216 |
| 벌목지 | primary-tile-forestry-01 | 4.000×4.000×2.505 | 212 |
| 철 채굴지 | primary-tile-mine-iron-01 | 4.000×4.000×0.535 | 74 |
| 석탄 채굴지 | primary-tile-mine-coal-01 | 4.000×4.000×0.535 | 74 |
| 시추지·펌프잭 | primary-tile-oil-01 | 4.000×4.000×1.800 | 152 |
| 시추지·빈 작업면 | primary-tile-oil-02 | 4.000×4.000×0.370 | 76 |
| 우라늄 채굴지 | primary-tile-mine-uranium-01 | 4.000×4.000×1.190 | 92 |
| 어장 | primary-tile-fishing-01 | 4.000×4.000×0.805 | 162 |

H는 바닥/매설 부분을 포함한 전체 경계다. 채굴지의 외곽 지표는z=0, 내부 채굴면−0.15/−0.30m, 매설 바닥−0.40m다.
어장은 물 표면 없이 그물·부표·표식만 포함한다. 어장의4×4m 실측 경계는 그물 끝이며 투명한 물판으로 채우지 않았다.
원래 곡물은 작물 최고점0.70~0.74m, 바닥 포함 높이0.86m와140삼각형을 그대로 유지한다.

## 3×3 동일 타일 연결

![작업지3×3 검토](overview-3x3.png)
각 원본을4m 간격으로9개 복제해 실제 Blender 장면에서 렌더했다. 이미지 이어붙이기가 아니다.
같은 종류의 X/Y 반대 경계의 좌표·높이·재질색이 일치하고 바닥 테두리/울타리를 넣지 않았다.
자원별 흙 색과 식생의 차이는 의도한 구분이다. 다른 종류 사이의 모든 지형/색 전환을 자동 블렌딩한 것은 아니다.
시추지 두 변형은 같은 바닥 높이·색·경계로 자유롭게 섞을 수 있다.

## 개별 원본과 PNG

### 곡물 밭

[원본·metadata](../../../assets/primary-industry/primary-tile-grain-01/)

![단일](../../../assets/primary-industry/primary-tile-grain-01/tile.png)
![3×3 연결](../../../assets/primary-industry/primary-tile-grain-01/tile-3x3.png)

### 채소·과수 밭

[원본·metadata](../../../assets/primary-industry/primary-tile-vegetable-01/)

![단일](../../../assets/primary-industry/primary-tile-vegetable-01/tile.png)
![3×3 연결](../../../assets/primary-industry/primary-tile-vegetable-01/tile-3x3.png)

### 목초지

[원본·metadata](../../../assets/primary-industry/primary-tile-pasture-01/)

![단일](../../../assets/primary-industry/primary-tile-pasture-01/tile.png)
![3×3 연결](../../../assets/primary-industry/primary-tile-pasture-01/tile-3x3.png)

### 벌목지

[원본·metadata](../../../assets/primary-industry/primary-tile-forestry-01/)

![단일](../../../assets/primary-industry/primary-tile-forestry-01/tile.png)
![3×3 연결](../../../assets/primary-industry/primary-tile-forestry-01/tile-3x3.png)

### 철 채굴지

[원본·metadata](../../../assets/primary-industry/primary-tile-mine-iron-01/)

![단일](../../../assets/primary-industry/primary-tile-mine-iron-01/tile.png)
![3×3 연결](../../../assets/primary-industry/primary-tile-mine-iron-01/tile-3x3.png)

### 석탄 채굴지

[원본·metadata](../../../assets/primary-industry/primary-tile-mine-coal-01/)

![단일](../../../assets/primary-industry/primary-tile-mine-coal-01/tile.png)
![3×3 연결](../../../assets/primary-industry/primary-tile-mine-coal-01/tile-3x3.png)

### 시추지·펌프잭

[원본·metadata](../../../assets/primary-industry/primary-tile-oil-01/)

![단일](../../../assets/primary-industry/primary-tile-oil-01/tile.png)
![3×3 연결](../../../assets/primary-industry/primary-tile-oil-01/tile-3x3.png)

### 시추지·빈 작업면

[원본·metadata](../../../assets/primary-industry/primary-tile-oil-02/)

![단일](../../../assets/primary-industry/primary-tile-oil-02/tile.png)
![3×3 연결](../../../assets/primary-industry/primary-tile-oil-02/tile-3x3.png)

### 우라늄 채굴지

[원본·metadata](../../../assets/primary-industry/primary-tile-mine-uranium-01/)

![단일](../../../assets/primary-industry/primary-tile-mine-uranium-01/tile.png)
![3×3 연결](../../../assets/primary-industry/primary-tile-mine-uranium-01/tile-3x3.png)

### 어장

[원본·metadata](../../../assets/primary-industry/primary-tile-fishing-01/)

![단일](../../../assets/primary-industry/primary-tile-fishing-01/tile.png)
![3×3 연결](../../../assets/primary-industry/primary-tile-fishing-01/tile-3x3.png)

## 범위와 검증

- 외부 모델/텍스처/생성형 이미지/API 없음. 모든 형상은 스크립트 기하와 단색 재질이다.
- 승인된 곡물의 둥근 매스/작은 팔레트/낮은 삼각형 수를 기준으로 채소4이랑+작은 과수, 소1마리, 나무/그루터기,
  광물별 얕은 단차, 펌프잭/빈 작업면, 경고 표식, 어장 소품을 구분했다. 과수는 침엽수 대신 둥근 수관이다.
- 모든 타일4×4m, 300삼각형 이하. Blender 미터/-Y 정면/+Z 위, Godot +Z 정면 규약 유지.
- [기하/복원179검사](geometry-validation.json): 열 원본을 재개방해 실측/경계색/카메라/투명/타일 유형/업종 구성,
  곡물5개 파일의 정확한 복원 및 시추지 두 변형의 공통 경계를 검사했다.
- [PNG20장 검사](image-validation.json): 지정900×900/RGBA/투명/잘림 없음/해시. 보고서 검토표는 별도 레이아웃이다.
- [곡물·농장 기존48검사](../geometry-validation.json)도 이번에 다시 실행했다. 농장 원본은 변경하지 않았다.
- 채소의 과수는 둥근 수관으로 최종 수정했으며200삼각형을 유지한다. 어장의 그물 교차 높이도 분리했고 최종 로그를 보존했다.
- 단일 source blend에는 각 타일1개만 저장했다. 소품은 타일 내부에 있고 부지 기하를 넘어가지 않는다.
- 게임 등록/자동 확장/도로 덮기 삭제/자원 수확/GLB 변환/애니메이션/성능 검증/main 병합은 하지 않았다.
- 나머지 메인 건물8종은 이번 요청의 작업지 범위에 포함하지 않았다. 생성/가격·수치 적용은 없다.

재현:
```sh
blender -b --factory-startup -t 4 -P tools/build_primary_work_tiles.py
blender -b --factory-startup -t 2 -P tools/verify_primary_work_tiles.py
blender -b --factory-startup -t 2 -P tools/verify_primary_industry.py
python tools/build_primary_work_tile_review.py
```
새 생성기는 기존 build_primary_industry.py의 studio/bounds/mesh와 build_growth_14.py의 재질/단위 helper를 import한다.
기존 cities-do-construction의4m 부지/방향 규약을 유지한다. 새 외부 스킬/패키지/상류/에이전트 없음.
기존 helper 파일은 수정하지 않았고 곡물 생성기/검사기만 사용자가 지정한 버전으로 복원했다.
Blender4.3.2 CPU Cycles48샘플 실제 렌더. 새 타일은 폰트를 쓰지 않는다.
Pillow/Noto CJK는 보고서 배치에만 쓰며 기존 시스템 도구다. 새 애셋의 외부 소재로 쓰지 않았다.

## 비용·용량 초안 · 미승인/미적용

작업지는 거점 주변 자동 확장용이므로9종 모두 시정부 건설비0doth/칸, 별도 유지비0doth/(칸·게임월)을 제안한다.
기존 곡물 작업지의0/0 제안과 같은 기준이다. 50,000doth 시작 자금에 추가 작업지 요금은0이며,
거점의 미정 운영비/연료/인건비를 타일별로 이중 부과하지 않는다. 민간 건물 자동 신축에 공사비를 임의로 만들지 않는다.
메인 건물의 소유/건설비는 별도 결정 사항이며 이번에 새 수치를 만들거나 기존 경제 CSV를 변경하지 않았다.

| 타일 | 정격 / 평균 수확 환산(칸·게임일당) | 자체 수요 제안 | 잔재 제안 |
|---|---|---|---|
| 채소 | .006 / .004톤 | 관개.03m³, 추가 전력0kW | 작물 잔재.001톤 |
| 목초지 | 원유 환산.005 / .003톤 | 물.05m³, 사료.008톤, 전력0kW | 분뇨.003톤 |
| 벌목지 | 원목.008 / .004톤 | 물.004m³, 전력0kW | 수피/가지.001톤 |
| 철 채굴지 | 원광.006 / .004톤 | 물.01m³, 평균 전력1.5kW | 선별 잔재.003톤 |
| 석탄 채굴지 | 원탄.007 / .005톤 | 물.01m³, 평균 전력1.5kW | 선별 잔재.002톤 |
| 시추지01/02 공통 | 원유.008 / .005m³ | 물.006m³, 평균 전력2kW | 오염수.002m³ |
| 우라늄 채굴지 | 원광.001 / .0006톤 | 물.02m³, 평균 전력2kW | 관리 대상 잔재.0004톤 |
| 어장 | 수산물.005 / .003톤 | 현장 전력/용수0, 선박 연료 환산.006L | 어획 잔재.0005톤 |

위 게임일당 수치는 계절/성장/회전을 평균한 추상 게임 초안으로 현실 연간 생산량이나 구현값이 아니다.
시추지02는 시각 변형이므로 논리 수확·수요는01과 같고 한 칸에 두 변형을 중복 합산하지 않는다.
실제 처리량은 자원/작업지 수확 합계와 거점 반입/출하 상한 중 작은 값이다. 거점 용량을 타일 생산에 더하지 않는다.
저장은 생산이 아니며 만재·차량/도로 접근·인력·관개·허용 수역/수질·매장량이 병목이다.
분뇨·폐석·오염수·관리 대상 잔재는 각각 처리 경로가 필요하며 일반 쓰레기로 임의 소멸/대체하지 않는다.
추가 종사자는 거점 고용과 함께 설계하고 칸 수만큼 중복 생성하지 않는다. 현재 애셋만으로 이 규칙이 작동하지 않는다.
