# 소방·경찰·교정 애셋 인수 슬롯 (업로드 대기)

상태: **원본 업로드 완료(origin/main a4913a2, 2026-11-10) — 게임 등록·배치는 아직.**
원본 위치와 검증은 `docs/recovered-emergency-assets/README_KO.md`. 슬롯 ↔ 원본 ID 매핑:
fire.small=small-fire-station(4×4), fire.standard=fire-station(6×6), fire.regional=regional-fire-station(8×8),
police.small=small-police-station(4×4), police.standard=police-station(6×6), police.headquarters=regional-police-station(8×8),
police.prison=prison-8x8(8×8). **부지 크기는 원본 값 그대로 사용자 확정(2026-11-10).**

(이하 업로드 전 작성 내용)
7개 건물은 이미 사용자가 제작해 보유하고 있다. 새로 만들거나 비슷하게 재제작하지 않는다
(AGENTS.md: 완성된 모델 보존, 부재 판단은 원격과 인계장 확인 후). 임시 모델·가짜 PNG를 넣지 않는다.

## 확정 슬롯 (사용자 지정, 2026-11-10)

| 분류(하단 UI 카테고리) | 이름 | 슬롯 ID (경제 CSV ID와 동일) | 건설비 / 월 유지비 (제안·미승인) |
|---|---|---|---|
| 소방 | 소형소방서 | fire.small | 8,000 / 120 |
| 소방 | 소방서 | fire.standard | 20,000 / 300 |
| 소방 | 광역소방서 | fire.regional | 50,000 / 700 |
| 경찰 | 파출소 | police.small | 6,000 / 100 |
| 경찰 | 경찰서 | police.standard | 18,000 / 250 |
| 경찰 | 경찰본부 | police.headquarters | 45,000 / 600 |
| 교정 | 교도소 | police.prison | 45,000 / 500 |

- 가격/유지비/용량은 PRICE_PROPOSALS_KO.md, CAPACITY_PROPOSALS_KO.md, ECONOMY_BALANCE.csv에 이미 제안으로 있으며 승인 전 미적용이다.
- 교정은 별도 하단 카테고리다. 슬롯 ID는 기존 CSV를 유지하므로 교도소만 `police.prison`이지만 카테고리는 교정이다.
- 부지 크기와 모델 구성은 **파일 도착 후** 확정한다. 지금 임의로 정하지 않는다.

## 빈 슬롯의 동작 (파일 도착 전)

- 하단 UI에 소방/경찰/교정 카테고리와 7개 이름 칸을 만든다.
- 보건·교육 탭의 "애셋 준비 중·비활성" 방식과 동일: 이름만 표시, 건설 불가, 가짜 가격/미리보기 없음.
- 데이터는 카탈로그 항목의 상태값(예: pending_asset)과 빈 파일 경로로 두어, 파일 도착 시 경로만 채우고 상태를 바꾸면 활성화되게 한다.

## 인수 절차 (파일 도착 후)

1. 파일 형식 확인(.blend / GLB / PNG 8방향 / spec). 원본 보존, 해시 기록.
2. 기존 services 규약(cities_do/assets/services/catalog.json, GLB+PNG, 미터 축척, +Z 정면)에 맞는지 검사.
   다르면 어댑터/변환으로 맞추되 원본은 수정하지 않는다.
3. 차량(소방차·경찰차)과 같은 축척 비교 화면 촬영 → 사용자 승인.
4. 승인 후 해당 슬롯에 경로 연결·활성화.
5. 가격·용량은 승인 전 미적용 유지.
