# CITIES_DO 발전시설 6종 — 규격 수정 시안

사용자 확정: 석탄·석유·원자력 8×8, 태양광 4×4, 풍력 2×2, 수력은 길이를 사용자가 정하는 가변 댐.

| 폴더 | 부지 | 수정 내용 |
|---|---|---|
| coal | 8×8 (32×32m) | 야적장 확대, 굴뚝 높이 19→29m·반경 0.8→1.25m, 본관 축소 |
| oil | 8×8 (32×32m) | 탱크 반경 3.3→5m·원통 높이 5→8.3m, 굴뚝 높이 15→25m·반경 0.65→1.15m |
| nuclear | 8×8 (32×32m) | 돔 반경 5→6.6m, 냉각탑 높이 20m·밑반경 6.8m·최소 허리 반경 5.2m로 재조정, 터빈동 축소 |
| solar | 4×4 (16×16m) | 승인된 패널 배치 유지, 전체 규격을 절반으로 축소 |
| wind | 2×2 지상 점유 (8×8m) | 전시 바닥판·포장·접근로 제거, 작은 원형 기초와 변압기 유지 |
| hydro | 고정 부지 없음 | 기본 48m 예시, 길이에 따라 수문 반복 생성. 도로처럼 물길을 막는 설치 방식 |

태양광 디자인은 승인됐으며 나머지 수정안은 사용자 검토 대기다. 모두 게임에는 미등록이다. 발전 시뮬레이션·전력 탭 UI·수력의 드래그 설치와 침수 계산은 미구현이다. 수력 원본은 가변 길이를 지원하는 Blender 시각 프로토타입이다.

풍력의 날개 반경은 11m로 지상 부지를 벗어날 수 있다. 2×2는 날개의 회전 반경을 뜻하지 않으며 런타임에서 별도 간격·공간 검사가 필요하다. 풍력 원본에는 Lot/Ground/AccessTrack이 없고 물리적 원형 기초만 남겼다.

각 폴더: building.blend 편집 원본, building.png 정면, reverse-review.png 뒷면, metadata.json 규격, production_log.md. Blender 4.3.2 CPU 48 samples, 30도 정투영, 900×1100 투명 RGBA. 카메라 프레이밍이 다르므로 화면상의 크기로 부지·높이를 비교하지 않는다.

재생성: 저장소 루트에서 `blender --background --factory-startup --python-exit-code 1 --python assets/power-study/build_coal.py` 등 실행. 외부 모델·텍스처 없이 직접 제작했으며 글꼴 조건은 FONT_LICENSE.txt 참조.

가변 댐 예시: `blender --background --factory-startup --python-exit-code 1 --python assets/power-study/build_hydro.py -- --span-m 80 --out /tmp/dam-80`. `--model-only`를 추가하면 렌더 없이 모델·규격만 검증한다. 기본 예시 길이는 48m이고 고정된 게임 크기나 상한이 아니다.

설계: docs/design/POWER_TAB_KO.md.
