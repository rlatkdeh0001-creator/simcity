# 파트 B — 14m 간격과 인접 횡단보도

- `feature/e4-one-way-roads`, C `2fb2074f643a1ccd6131c2773ecf014fdcf49bf4` 위 별도 B 변경. 승인된 14m 중심선 거리 규칙은 양방향·편도 공통: 실제 입력 13.99m 거절, 14.00m 허용, 양쪽 모두 원본 보존. 겹치는 맞은편 횡단보도만 실제 공유 도로 중점에 한 줄로 그린다. 원본 이음이 중간에 있어도 연결을 따라 검사하며, 정지선은 교차로 밖 유효 공간이 있을 때만 유지한다.
- 관련 헤드리스 **1,772/1,772** (10개), 실제 Godot GL 입력·도색·저장 **81/81**. 렌더 직전 실제 폴리곤의 횡단보도 중복은 14/15/16m 모두 **0쌍**. 14m·15m는 완전한 중점 횡단보도 각 1개, 횡단보도–정지선과 정지선–정지선 중복도 0쌍. 양쪽 T·삽입/포인트 순서·분할 이음·8/2차로 X는 별도 기하 테스트로 검사했다.
- 고정 main `84825b41ce92367817807e3d3b9ef4b2c836222f`의 scratch 복제에서 같은 네이티브 불투명 본체 검사 **22/22**. 양쪽 버전 모두 본체 정지선–중앙선/갓길선 겹침 0쌍; AA 가장자리 6쌍은 양쪽에서 동일. 기준 main의 14m·15m 상대 횡단보도 중복은 각각 9쌍. 16m는 횡단보도·정지선·중앙선·흰 선 폴리곤 해시 네 종류 모두 main과 일치(16m의 기존 횡단보도–정지선 교차 10쌍은 변경 범위 밖). main 비교에만 scratch import 후 철도 이미지 내보내기 관련 경고 3줄이 있으며 원문을 로그에 보존했다.
- 눈으로 확인한 실제 1920×1080 프레임버퍼: [14m](b-junction-14m-1920.png), [15m](b-junction-15m-1920.png). [최종 결과/경로/해시](final-results.json): 정확한 실행 명령, 소유 소스 9개의 SHA-256, 원본 최종 로그 12개의 SHA-256, PNG 해시·크기. 별도 성능 측정/전체 회귀는 하지 않았다. 이전 `artifacts/e4a-prep-20261127/` 결함 증거 및 C의 다른 작업은 그대로 두었다.

- 통합 검토에서 `test_one_way_ground_edits`의 옛 16m 기대값이 두 API에서만 실패(129/131)하는 것을 재현했다. 두 API 모두 13.99/14.00m 및 종전 15.99/16.00m를 확인하고 미리보기 불변성을 추가했다(135/135). 실제 입력·도색 스크립트의 별도 무캡처 헤드리스 79/79를 확인했다. [통합 결과](integration-results.json): 헤드리스 12개 1,986/1,986(기존과 다른 모드/묶음만 추가), 네이티브와 main 비교는 위와 같다.

**소스 경로:** `cities_do/core/{city_model,road_construction,road_junctions,road_junction_paint}.gd`, `cities_do/tests/{test_road_close_crosswalks,test_road_junction_spacing,test_road_junction_spacing_input,test_road_overlap_policy,test_one_way_roads,test_one_way_ground_edits}.gd`. **증거 경로:** 이 폴더의 결과 JSON이 원시 로그와 PNG를 가리킨다. 검토 방식: 구현자 자체 검토 및 상위 통합 검토.

## 확인 대기

- 16m 기존 도색은 승인대로 그대로 유지했다. 전체 프로젝트 단일 전수 확인, main 병합·push는 이 B 커밋에 포함되지 않는다.
