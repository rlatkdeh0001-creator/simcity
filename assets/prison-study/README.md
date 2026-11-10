# 교도소 8×8 — 외관 검토용

사용자가 지정한 8×8칸(32×32m). 회색 ㄷ자 수용동, 높은 담장, 모서리 감시탑 4개, 출입 통제동과 내부 운동장을 표현했다. 실제 보안 설계가 아닌 축약된 도시 게임용 시안이다.

도로변 육상 공공시설을 의도한다. 승인 대기, 게임 미등록이며 수용·교정·치안 시뮬레이션은 구현하지 않았다.

prison/building.blend: 편집 원본, building.png: 정면, reverse-review.png: 뒷면, metadata.json: 규격·승인 상태. 기존 로컬 Blender 헬퍼를 활용해 직접 제작했으며 외부 모델·텍스처는 사용하지 않았다. 글꼴 조건은 FONT_LICENSE.txt 참조.

재생성: 저장소 루트에서 `blender --background --factory-startup --python-exit-code 1 --python assets/prison-study/build_prison.py`. Blender 4.3.2 CPU, 30도 정투영, 900×1100 투명 RGBA.
