# CITIES_DO 실제 게임 화면

- residential-showcase.png: 10종 전체, 같은 축척.
- residential-showcase-small-medium.png: 동일 지도에서 소형·중형 구간 확대.
- residential-showcase-large.png: 동일 지도에서 대형 구간 확대.

각 2560×1100 PNG는 실제 Godot 4.6.3 GL Compatibility 뷰포트를 직접 저장했습니다.
Blender 렌더 이미지를 HTML로 나열한 비교판이나 이미지 합성이 아닙니다.
Godot가 프로젝트의 PNG 텍스처를 필지 크기·바닥 피벗에 맞춰 그리며 실제 도로·
희소 구획·UI·선택 강조를 함께 렌더합니다. 각 사진 옆 json은 캡처 시점의 건물 목록,
맵 확대율에 따른 셀 폭, 렌더러와 화면 크기를 기록합니다.

작은 건물과 큰 타워의 화면 높이 차이는 공통 지도 축척에서의 실제 애셋 높이 차이입니다.
확대 화면은 카메라가 이동한 것으로 다른 건물이 화면 밖이나 일부 잘려 보일 수 있습니다.
전시 장면은 cities_do/residential_showcase.tscn이며 실행/조작은 cities_do/README.md 참고.

## 도로에서 직각으로 나오는 구획

road-perpendicular-parcels.png는 2000×1250 실제 Godot 뷰포트입니다. 직선·사선·
꺾임·곡선에서 로컬 정사각형 블록이 생성되는 모습을 보여 줍니다. 우측 아래는
같은 월드 좌표의 평면도이며, 화면상 투영 각도와 지도상 직각을 구분하기 위한
참고입니다. 회전된 부지는 임시 입체 건물로 표시합니다.
