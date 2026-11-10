# 소형 상업건물 시안 01 — 동네 MART

사용자가 승인한 2×2칸(8×8m), 단층 상업건물입니다. 게임 카탈로그에 소형 상업건물로 등록했습니다.

- `small-2x2-mart-01/mart.png`: 정면 시안, 투명 RGBA 900×1100
- `small-2x2-mart-01/reverse-review.png`: 뒷면 검토 이미지
- `small-2x2-mart-01/mart.blend`: 편집 가능한 원본
- `build_mart.py`: Blender 4.3.2 재생성 스크립트

재생성: 저장소 루트에서 `blender --background --factory-startup --python-exit-code 1 --python assets/commercial-study/build_mart.py`

외부 모델과 텍스처 없이 직접 제작했습니다. 간판용 DejaVu 글꼴은 원본에 포함했으며 사용 조건은 `FONT_LICENSE.txt`에 있습니다. 기존 주거건물과 같은 정투영 방식으로 렌더링했습니다. 2×2 상업 신축에 사용하며, 큰 부지에는 늘려 쓰지 않습니다.

## 4×4 소형 상업 — 사용자 승인

- `small-4x4-market-03`: 단층 동네 슈퍼마켓 FRESH MART.
- `small-4x4-cafe-diner-04`: 2층 식당·카페 복합상가.
- 두 안 모두 16×16m 부지, 편집 가능한 Blender 원본과 정면·뒷면 투명 PNG 포함. 두 안 모두 게임 카탈로그에 등록했습니다.
- 보석·명품 매장은 향후 고밀도 상업건물에만 사용합니다.
- 각 `build_small-4x4-*.py`를 Blender에서 실행하면 재생성됩니다.

## 중형 상업 1번 — 승인 대기

`medium-4x4-office-retail-05`: 4×4·4층 업무·상가 복합빌딩. 약국·베이커리와 사무실. 게임 미등록.

## 중형 상업 2번 — 승인 대기

`medium-4x4-brick-services-06`: 4×4·4층 벽돌형 식당·서비스 상가. BISTRO·SALON, 세로 업종 안내판. 게임 미등록.

## 대형 상업 1번 — 승인 대기

`large-4x4-department-07`: 4×4·8층 AUREL 백화점, 고밀도 상업 디자인. 보석 모양 간판과 대형 쇼윈도. 게임 미등록.

## 대형 상업 2번 — 승인 대기

`large-4x4-office-nova-08`: 4×4·10층 NOVA 오피스 타워. 저층 CAFE·TECH, 별도 사무실 로비와 2단 후퇴 상층부. 게임 미등록.

## 8×8 대형 상업 2종 — 승인 대기

- `large-8x8-grand-department-09`: AUREL GRAND, 8층 대형 백화점.
- `large-8x8-twin-central-10`: NOVA CENTRAL, 최고 14층 트윈 복합타워.

두 안 모두 32×32m, 정면·뒷면 투명 PNG와 Blender 원본 포함. 게임 미등록.
