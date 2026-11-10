# CITIES_DO 100×100 전체 건물 전시 도시

지금까지 만든 최신 건물 시안 54종을 모두 최소 한 개씩 배치했다. 중복 주거·MART 5동을 추가해 총 59동이다. 1칸=4m, 지도 100×100칸이다.

주거 10, 상업 10, 공업 8, 전력 6, 수도 4, 쓰레기 2, 소방 3, 경찰 3, 교도소 1, 의료 3, 교육 4종. 이전 수정안은 중복 포함하지 않고 각 원본 폴더의 최신 렌더를 사용한다. 승인 대기 시안도 사용자의 전체 전시 요청에 따라 표시한다.

## 실행

Godot 4.6에서 cities_do/project.godot을 열고 실행한 뒤 “전체 54종 · 100×100 도시” 버튼을 누른다. 또는 저장소 루트에서 `godot --path cities_do res://all_buildings_showcase.tscn` 실행.

휠 확대, 가운데 버튼 드래그, 건물 클릭으로 이름과 부지 확인. 상단 종류 버튼은 해당 자산들의 화면 범위를 맞춰 확대한다. “건설 화면으로”는 기존 건설 도시와 카메라를 복원한다.

## 배치·검증

- 54종 누락 없음, 59개 부지 모두 지도 안에 위치, 건물 부지끼리 겹치지 않음.
- 일반 시설과 물가 시설은 도로에 접하면서 도로 면을 침범하지 않음.
- 취수장·하수장은 남측 육상 물가, 취수·방류 부분은 인접 물 쪽으로 배치.
- 댐은 동측 하천을 가로막는 시각 전시물이며 수계·침수 계산이나 드래그 설치 기능이 아니다.
- 고층 건물은 뒤쪽, 작은 건물은 앞쪽에 두고 높이순으로 배치했다. 모든 54종의 불투명 부분이 전경에서 보이고 선택 가능함을 검사했다.
- 모든 PNG는 기존 투영과 부지 기준점으로 동일한 지도 축척에 맞췄다. 풍력 날개는 지상 점유 부지를 벗어날 수 있다.

전시 전용 맵/뷰어로 일반 건설·성장 RNG·시설 운영 규칙과 분리했다. 전력·수도·쓰레기·치안·진료·교육 기능이 이 화면에서 계산된다는 뜻은 아니다. 모든 시설을 이번에 일반 성장 후보로 등록하지 않았다.

정의: cities_do/maps/all_buildings_100.json. 복사한 런타임 PNG: cities_do/assets/all_buildings/. 원본 출처는 각 entry.source에 기록했다. 재생성: `python tools/build_all_buildings_city.py`. 원본 Blender 파일은 기존 assets/ 하위에 보존했다.

## 실제 게임 화면

- docs/screenshots/all-buildings-city-100.png: Godot OpenGL 전경 3600×2400.
- docs/screenshots/all-buildings-education.png: 같은 도시 확대 화면 2400×1600.

Blender 합성이나 이미지 생성 결과가 아니라 Godot 뷰포트에서 저장했다. 캡처 예: `godot --path cities_do --rendering-method gl_compatibility --resolution 3600x2400 res://all_buildings_showcase.tscn -- --capture=/absolute/path/city.png`.

## 검사

기존 6종 Godot 검사와 새 tests/test_all_buildings.gd 모두 통과. 새 검사는 100×100 규격, 54개 정의·59개 배치, 전 종류 포함, 부지 경계, 부지 충돌, 도로 접면, 54종 전경 선택 가능성을 확인한다. 실제 그래픽 캡처도 별도로 확인했다.
