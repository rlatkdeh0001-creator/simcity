# 수도 시설 4종 — 사용자 검토용 시안

| 폴더 | 시설 | 부지 제안 | 사용자 확정 설치 조건 |
|---|---|---|---|
| intake | 취수장 | 4×4 | 물가의 육상 |
| water-tower | 급수탑 | 2×2 | 도로변 육상 |
| sewage-treatment | 하수처리장 | 8×8 | 도로변 육상 |
| sewage-outfall | 하수장(방류시설) | 4×4 | 물가의 육상 |

크기는 제안이고 설치 표면·도로변 조건은 사용자 지시다. 모두 승인 대기, 게임 미등록. 실제 수도망이나 설치 검증을 구현했다고 주장하지 않는다.

각 폴더의 building.blend는 편집 가능한 원본(간판용 글꼴 포함), building.png는 정면, reverse-review.png는 뒷면, metadata.json은 부지·배치 의도와 투영 정보다. Context_* 물 표면은 검토용 배경이므로 실제 게임에는 지도 수면을 사용한다.

Blender 4.3.2 CPU, 30도 정투영, 900×1100 투명 PNG. 시설별 카메라 배율이 달라 동일 화면상의 크기가 동일 부지 크기를 뜻하지 않는다. 외부 모델·텍스처 없이 제작했으며 DejaVu 글꼴 사용 조건은 FONT_LICENSE.txt 참조.

재생성: 저장소 루트에서 `blender --background --factory-startup --python-exit-code 1 --python assets/water-study/build_intake.py`처럼 각 build_*.py를 실행한다.

수도 탭 설계 및 구현할 설치 규칙: docs/design/WATER_TAB_KO.md.

## 사용자 정정 — 물가 육상 설치

취수장·하수장은 물 위 시설이 아니다. 본체와 기초를 땅에 설치하고 취수구·방류관만 수역으로 뻗는다. 수정 시안의 Context_ShoreLand/Context_LandSurface/Context_Water는 이 조건을 설명하는 지형이며 게임 적용 시 실제 지도 지형을 사용한다. 급수탑·하수처리장의 도로변 육상 조건은 유지한다.
