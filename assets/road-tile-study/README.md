# CITIES_DO · 타일·도로 시안

기존 맨션과 같은 1칸=4m, 카메라 고도 30도의 2:1 투영으로 제작한 원본 Blender 시안.
`game-art`의 축척/팔레트 지침과 `blender-kiln`의 로컬 제작·원본 보존 원칙을 참고했다.
외부 모델·텍스처·이미지 생성 API를 사용하지 않았으며 원본 kiln 툴킷 실행 결과는 아니다.

| 구분 | 전체 폭 | 차도 | 양쪽 보도 | 예시 길이 |
|---|---|---|---|---|
| 왕복 2차로 (1+1) | 2칸 / 8m | 6m | 각 1m | 8칸 / 32m |
| 왕복 4차로 (2+2) | 4칸 / 16m | 13m | 각 1.5m | 8칸 / 32m |
| 잔디 타일 | 1×1칸 | 4m×4m | 해당 없음 | 해당 없음 |

폭에는 보도를 포함한다. 최종 도로 설계/밸런스가 아닌 비교용 제안이다.
4차로는 편도 4차로가 아니며 방향별 두 차로다. 중앙 황색선은 진행 방향을 구분하고
흰 점선은 같은 진행 방향의 차로를 구분한다.

- comparison.png / comparison.html: 같은 축척의 비교판
- road-2/road.png, road-4/road.png: 1000×760 RGBA 개별 시안
- road-2/road.blend, road-4/road.blend: 편집 가능한 원본
- grass-tile.png / grass-tile.blend: 512×512 RGBA 기본 타일 원본
- metadata.json: 폭·길이·방향별 차로 수·시점·제작 출처

## 재생성

저장소 루트에서 다음 명령을 각각 실행한다. 기존 생성 파일을 갱신하므로
직접 수정한 Blender 파일은 먼저 별도 보관한다.

```sh
blender --background --factory-startup --python-exit-code 1 \
  --python assets/road-tile-study/build_roads.py -- --lanes 2
blender --background --factory-startup --python-exit-code 1 \
  --python assets/road-tile-study/build_roads.py -- --lanes 4
python3 assets/road-tile-study/capture_comparison.py
```

Blender 4.3.2 CPU Cycles 48 samples로 렌더했다. 비교판 캡처에는 Python Playwright와
시스템 Chromium을 썼다. 제한된 환경에서는 쓰기 가능한 XDG 경로가 필요할 수 있다.

## 게임과의 관계

이 PNG는 직선 애셋의 스타일 비교용이다. 자유 도로를 직선 PNG로 붙이는 방식이
아니라, 게임은 연속 좌표 경로에서 폭을 가진 벡터 면을 생성한다. 차도·보도·중앙선·
4차로 점선을 같은 규격으로 표시한다. 지형도 100만 개의 PNG 타일을 깔지 않고
단색 지형 면과 주변 건설 구획으로 표시한다.

현재 맵: cities_do/maps/example_100.json에서 크기·시드를 지정한다.
100×100=400m×400m. 향후 1024×1024=4.096km×4.096km.
격자는 처음 숨기고 일반도로 주변 8칸 깊이 범위에서만 드러낸다. 현재 구획은
도로별 방향을 따라 반듯한 블록으로 회전한다. 곡선 안쪽 틈은 비워 두며 칸을 변형하지
않는다. 이 폴더의 직선 도로 시안은 그대로 보존했다. 상세 규칙은 cities_do/README.md 참고.
1024 빈 지도와 짧은 도로의 국소 구획만 검증했으며 대규모 도시 전체 성능은 미검증이다.
