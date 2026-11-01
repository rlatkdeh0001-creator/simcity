# 도로 주행 AI 도입·검증 · 2026-11-01

[실제 게임 화면](screenshots/traffic-ai-demo.png) ·
[주행·정지·재출발 GIF](screenshots/traffic-ai-running.gif) ·
[건설 화면에서 주행](screenshots/traffic-main-ui.png) ·
[후보 조사와 고정 출처](design/TRAFFIC_AI_RESEARCH_KO.md)

## 적용된 기능

건설 화면의 **도로 주행 시작** 버튼을 누르면 현재 그린 도로에서 시민 차량이 움직인다.
**주행 AI 시험장**은 4차로 순환 도로와 2차로 종점 도로에 차량 26대를 배치한다.
차체 외형은 앞서 만든 20종의 8방향 PNG이며, 시뮬레이션 좌표는 미터 단위다.
기존 도로 팔레트·건설·구획·성장 규칙을 바꾸지 않았다.

- 2·4차로 우측통행 경로, 곡선/폐회로 추종, 같은 방향의 도로 끝점 연결.
- AStar2D 차선 그래프 경로 탐색. 곡선의 길이를 비용으로 쓰고 휴리스틱은 0이다.
- 앞차의 길이를 반영한 간격 유지, 가속·감속, 정지·재출발.
- 제어 정지선(시험장의 빨강/초록 점), 종점 정지, 일시정지.
- 30Hz 고정 시뮬레이션으로 화면 프레임 변화와 이동 상태를 분리.
- 건설 화면에 돌아오면 기존 도시·카메라를 복원한다.
- 도로를 추가하거나 도시를 초기화하면 기존 차량 주행을 종료한다. 다시 시작하면 새 도로망으로 재생성한다.

시험장의 정지선은 12초마다 정지/통과를 바꾸며 수동 전환도 가능하다.
이는 독립적인 정지선 시험이며 교차로 전체 신호 체계가 아니다.
일반 도로/고속도로 상한은 각각 80/160km/h로 변환했다. 차량의 희망 속도는
그보다 낮을 수 있으며 현재 값은 교통 프로토타입 튜닝이다.

## 실제 도입한 외부 코드와 스킬

- **Road Generator 0.9.5**, 고정 SHA `7cbefde04e57a84499c5d8ba636c9cb4fd7d22c0`, MIT.
  `cities_do/addons/road-generator/`에 전체 애드온을 보존했다.
  런타임 어댑터가 실제 원본 `RoadLane`, `RoadLaneAgent`, `RoadManager`를 생성하고
  `move_along_lane()`으로 이동 위치를 계산한다. 원본 코드를 복제해 이름만 바꾼 구현이 아니다.
  2D 도시에서 만든 차선을 3D 경로로 전달하며 시각 도로는 기존 렌더러를 쓴다.
  에디터 플러그인 UI는 활성화하지 않아도 런타임 노드를 사용할 수 있다.
  원본 소스 코드는 그대로다. Godot 4.6.3이 재생성한 21개 `.import` 설정은
  UPSTREAM.json의 `local_changes`에 원본/현재 해시와 함께 구분했다.
- **game-ai**, **godot-gdscript**, **godot-gdscript-headless-testing**:
  고정 SHA `19d93f97c9c1ea0f8b306e77aa81e0d3e352d3e9`, Apache-2.0.
  SKILL.md·하위 참고자료·라이선스·NOTICE·출처를 `.agents/skills/`에 보존했다.
  판단/경로/이동 분리, 경로 재사용, 명시적 실패 종료와 로그 검사를 적용했다.
  원본 예시는 4.7 기준이지만 이번 코드는 현재 Godot 4.6.3에서 검증했다.
- **city-traffic-sim**, 고정 SHA `cd0e2b82f74851821d33d93e17b05b8d9754c84b`, MIT.
  `safe_speed = lead_speed + (gap-min_gap)/time_gap` 방식의 ACC를 미터 단위로
  적응했다. 원본 프로젝트 전체를 실행하거나 가져온 것은 아니다.
  참고한 소스·README·라이선스는 `third_party/city-traffic-sim/`에 보존했다.
  게임 배포 안에도 라이선스와 `THIRD_PARTY_NOTICES.md`를 포함했다.

주요 자체 파일은 `core/traffic_network.gd`, `traffic_simulation.gd`,
`road_generator_traffic.gd`, `traffic_controller.gd`, `traffic_demo.gd`다.
첫 두 파일은 장면/렌더링과 독립적으로 검사할 수 있다.

## 검증 결과

Godot 4.6.3에서 테스트 **8종 모두 통과**했다. 로그와 종료 코드는
`docs/traffic-validation/`에 보존했다. 차량 외형 검사는 기존 156/156도 통과했다.
새 주행 검사는 **43/43**이다.

- 미터 변환·우측 차선 오프셋·반대 방향 분리·2/4차로·속도 상한.
- 도로가 반대 순서로 입력돼도 같은 방향 끝점 연결, 경로 단절/역주행 경로 거부.
- 앞차 추종·보호 간격·정지선 앞 정지·통과 전환 후 재출발·종점 정지.
- 순환 경계의 차량 생성 간격 및 추종 간격, 3분간 곡선 경로 이탈 없음.
- 30/60fps 입력에서 같은 고정 시간 상태, 일시정지와 긴 프레임 처리.
- 실제 원본 RoadLaneAgent 위치와 시뮬레이션 위치의 일치, 폐회로와 다음 도로 전환.
- 100대·300틱 검사에서 간격/유한 좌표 유지. 이 환경에서 **약 1.21ms/틱**.
  이는 순수 교통 로직의 제한된 장면 측정이며, 3D 어댑터·렌더링·1024 맵 성능 결과가 아니다.
- 건설 화면에서 주행 시작·외형 방향·시험장 진입·버튼·복귀 상태 보존.
- 실제 OpenGL 렌더러 캡처와 24초 주행 기록(49프레임, GIF 960×600).
  프레임 간 도로 영역 변화와 GIF 재디코딩을 확인하고 정지/통과 화면을 시각 검수했다.

기존 UI 검사가 첫 자식 노드를 통해 UI에 접근하고 있어 교통 노드를 먼저 추가하면
실패했다. 기존 UI 계층을 보존하도록 교통 노드 추가 순서를 수정한 후 전체 검사를
다시 실행했다. 검사 조건을 없애서 통과시킨 것이 아니다.

## 현재 한계

교차로 회전·우선권·신호 단계·교착 방지와 안전한 차선 변경/합류는 아직 없다.
따라서 교차·분기·겹치는 도로는 주행 시작을 거부한다. 모든 도로 교차점을 자동으로
연결했다고 주장하지 않는다. 가까운 평행 도로와 급곡선의 차량 차체 전체 충돌 검사는
별도 보강이 필요하다. 현재 간격 보장은 같은 진행 경로의 종방향 차체 길이를 기준으로 한다.

노선 버스·택시 호출·통근/물류 수요, 트레일러 꺾임/바퀴 애니메이션, 도로 편집 후
개별 차량 경로 유지, 혼잡도 기반 재탐색, 보행자·주차·대규모 성능은 후속 작업이다.
8방향 외형은 방향을 양자화하므로 연속적인 3D 차체 회전과 다르다.
차량 표시의 건물과의 정밀한 깊이 정렬도 보강 대상이다.

## 실행·재현

```sh
godot --headless --editor --import --path cities_do --quit
godot --headless --path cities_do --script tests/test_traffic.gd
godot --path cities_do traffic_demo.tscn
# 실제 그래픽 디스플레이에서 캡처
godot --path cities_do --resolution 2000x1200 traffic_demo.tscn -- \
  --capture-traffic=/absolute/path/traffic.png
# 24초 동안 0.5초 간격의 실제 화면 저장
godot --path cities_do --resolution 1600x1000 traffic_demo.tscn -- \
  --record-traffic=/absolute/path/frames
python3 tools/package_vehicle_fleet.py --output /workspace/cities-do-traffic-ai.zip
```

ZIP에는 게임·차량·제작 소스·스킬·라이선스·참고 소스·검증 기록이 포함된다.
환경 설정 저장/환경 게시와 Git 커밋/푸시는 별개이며 환경 설정은 변경하지 않았다.
