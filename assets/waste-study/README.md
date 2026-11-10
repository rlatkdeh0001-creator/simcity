# 쓰레기 소각장 — 사용자 검토용 시안

매립지 없이 소각장만 제작. 8×8칸(32×32m)은 시안용 부지 제안이며 도로변 육상 설치를 의도한다. 흰색 패널의 네모난 소각로동, 밀폐 반입동과 하역구 2개, 외부 집진·배기가스 정화설비, 단일 사각 배기탑·제어실·계근대로 다시 구성했다. 사용자 요청에 따라 곡면 지붕과 녹색·주황색 주요 외벽을 제거한 세 번째 시안이다.

`incinerator/building.blend`: 편집 원본, `building.png`: 정면, `reverse-review.png`: 뒷면, `metadata.json`: 규격과 승인 상태. 사용자 승인 대기, 게임 미등록. 폐기물 수거·소각 시뮬레이션과 배치 UI는 미구현이다.

재생성: 저장소 루트에서 `blender --background --factory-startup --python-exit-code 1 --python assets/waste-study/build_incinerator.py`. Blender 4.3.2 CPU 48 samples, 30도 정투영, 900×1100 투명 RGBA. 외부 모델·텍스처 없이 직접 제작. 글꼴 조건은 FONT_LICENSE.txt 참조.

동작 설계: docs/design/WASTE_TAB_KO.md.

## 재활용센터 추가

사용자 요청에 따라 `recycling-center/` 시안을 추가했다. 녹색 저층 선별동, 4종 분류함, 압축품 출하장. 8×8은 부지 제안이며 승인 대기·게임 미등록이다. 흰색 사각 소각장은 디자인 승인 완료, 게임 등록 대기다.
