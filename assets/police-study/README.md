# 경찰시설 3종 — 사용자 검토용 시안

사용자 요청: 소방처럼 소형·일반·광역 3종, 파란색 계열 공통 스타일.

- small-police-station: 4×4 단층 파출소형, 평지붕과 넓은 민원실 창.
- police-station: 6×6 ㄱ자 청사, 2층 민원동과 3층 사무동.
- regional-police-station: 8×8 큰 4층 본관, 중앙 유리 아트리움과 큰 경찰 표식.

크기·층수는 시안 제안이다. 모두 도로변 육상 공공시설을 의도하며 승인 대기, 게임 미등록이다. 경찰 순찰·사건 대응·치안 범위 계산은 미구현이다.

각 폴더에 building.blend 원본(폰트 포함), building.png 정면, reverse-review.png 뒷면, metadata.json 규격을 저장했다. 차량은 정지 조형이다. 기존 로컬 Blender 모델링 헬퍼를 조정해 건물·표식·차량을 제작했고 외부 모델·텍스처는 사용하지 않았다.

Blender 4.3.2 CPU, 30도 정투영, 900×1100 투명 RGBA. 종류별 프레이밍이 달라 화면 크기가 실제 부지 비율은 아니다. 글꼴 조건은 FONT_LICENSE.txt 참조.

재생성: 저장소 루트에서 `blender --background --factory-startup --python-exit-code 1 --python assets/police-study/build_small-police-station.py` 등 실행.

## 광역 경찰서 옥상 착륙장

사용자 요청에 따라 H·원형 안전표시·경계선을 갖춘 옥상 헬기 착륙장과 계단실 출입구·연결 통로를 추가했다. 공조·통신설비는 가장자리로 재배치했다. 기존 소방본부 착륙장 모델링을 재사용하고 경찰 청사의 옥상 높이에 맞췄다. 4층 본관과 8×8 부지를 유지하며 실제 헬기 운항·인물 이동은 미구현이다.
