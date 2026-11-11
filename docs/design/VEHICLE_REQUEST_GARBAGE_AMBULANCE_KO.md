# CITIES_DO 서비스 차량 2종 제작 요청 — 쓰레기차 · 구급차

도시 시뮬레이션 게임 CITIES_DO에 쓸 서비스 차량 **2종**을 Blender 스크립트로 만들어 주세요.
기존 차량 시리즈(`assets/vehicle-fleet/`: 소방차 fire-engine-01, 경찰차 police-car-01, 운구차 hearse-01 등)와 같은 방식·톤이어야 합니다.

## 1. 제작 목록

| id | 이름 | category / style | 크기 제안 (길이×폭×높이 m) | 내용 |
|---|---|---|---|---|
| garbage-truck-01 | 쓰레기차 | service / waste | 8.0 × 2.45 × 3.2 | 운전석 + 압축식 적재함(후면 투입구·리프트 암), 녹색 계열 + 흰 줄, 측면 재활용 표식 |
| ambulance-01 | 구급차 | service / medical | 5.9 × 2.1 × 2.6 | 승합형 차체 + 박스형 후부, 흰색 + 빨강/주황 반사띠, 지붕 경광등, 측면·후면 별 모양 의료 표식 |

- 구급차 높이는 **3.4m 이하 필수**(소형 소방서·병원 차고 문 높이 기준). 쓰레기차는 3.3m 이하 권장.
- 실제 차량을 그대로 베끼지 말고 게임용 가상 디자인으로.

## 2. 공통 규격 (기존 차량과 동일)

- **좌표계:** Blender에서 전방 **-Y**, 왼쪽 **+X**, 위 **+Z** (glTF/Godot으로 내보내면 전방 +Z, 위 +Y).
- 운전석은 **왼쪽**(driver_side: left). 바퀴 바닥면이 z=0.
- 1m = 1 Blender 단위, 실측 축척. 승용차(세단 약 4.6m)·소방차(7.6m) 옆에 세웠을 때 자연스러운 크기.
- 단순한 매스와 또렷한 실루엣, 기존 시리즈와 같은 저채도 팔레트(서비스 표식 색만 선명하게).
- 삼각형 수 **약 2,000~5,000** (소방차 4,336 참고). 미러·램프 같은 작은 부품은 단순하게.
- **외부 모델·외부 텍스처·생성형 이미지 금지.** 스크립트 지오메트리와 시스템 폰트만.

## 3. 산출물 (차량마다)

폴더 `assets/vehicle-fleet/{id}/`
- `vehicle.blend` — 원본
- `spec.json`:
```json
{
  "id": "{id}", "name": "{한글 이름}", "category": "service", "style": "waste|medical",
  "length_m": 0.0, "width_m": 0.0, "height_m": 0.0,
  "dimensions_source": "fictional game design; nominal body envelope excludes mirrors, lamps and roof accessories",
  "frame_blender": {"forward": "-Y", "left": "+X", "up": "+Z"},
  "frame_gltf": {"forward": "+Z", "left": "+X", "up": "+Y"},
  "triangles": 0, "driver_side": "left",
  "reconstruction": "new service asset",
  "not_validated": ["door opening", "traffic AI", "large-fleet performance"]
}
```
- 확인용 미리보기 PNG 1장(앞·옆이 보이는 3/4 각도, 투명 배경).

GLB 변환과 8방향 스프라이트(000~315)는 게임 쪽에서 기존 파이프라인으로 만듭니다.

## 4. 진행 방식

- 쓰레기차 → 구급차 순으로, 각 차량 완료 시 미리보기 PNG와 실측(길이×폭×높이, 삼각형 수)을 보고해 주세요.
- 높이가 기준을 넘으면 제출 전에 직접 조정해 주세요.
