# CITIES_DO · 건설·성장 MVP

Godot 4.6 / GDScript. Claude 로그인과 외부 패키지가 필요하지 않습니다.

```sh
godot --path cities_do
```

Godot 편집기에서 이 폴더의 project.godot을 가져와 F6/F5로 실행할 수도 있습니다.
기본 화면 크기는 1280×820입니다.

## 조작

- 2×2 건설: 일반도로 옆 빈 셀을 클릭. 초록 미리보기는 가능, 빨강은 불가.
- 자유 도로: 지도에서 마우스 왼쪽 버튼을 누른 채 드래그 후 놓기.
  좌표는 격자에 스냅하지 않습니다. 충돌·경계 오류가 있으면 확정하지 않습니다.
- 건물 선택: 건물의 지붕 또는 부지를 클릭.
- 수치 +100 / 업그레이드: 선택한 건물 성장. 옆 건물이 확률적으로 함께 성장.
- 도시 초기화: 전체 지우기. 도로부터 다시 그릴 수 있습니다.

시작 시 일반도로와 건물 3개가 있습니다. 첫 주거 건물 수치는 120,
이웃은 10·5이므로 연쇄 성장에 의한 조건 면제를 시험할 수 있습니다.
건설 비용·경제·자동 시간 성장·저장/불러오기는 이 MVP 범위에 없습니다.

## 구조

- core/city_model.gd: 정수 부지, 연속 좌표 도로, 폭을 고려한 충돌, 가중 성장, 연쇄.
- core/growth_config.gd: 크기 확률·기준 수치·연쇄 확률·최대 개수·도로 접근 거리.
- main.gd: 아이소메트릭 투영, 건설 미리보기, 자유 드래그, 선택과 성장 UI.
- ../.agents/skills/cities-do-construction: 재사용 개발 스킬 및 기획 참고 자료.

## 검증

```sh
godot --headless --path cities_do --script tests/test_city.gd
godot --headless --path cities_do --script tests/test_ui.gd
```

클라우드에서 사용자 데이터 폴더 권한이 없으면 다음 환경 변수를 명령 앞에 붙입니다.
`XDG_DATA_HOME=/tmp/cities-do-data XDG_CONFIG_HOME=/tmp/cities-do-config XDG_CACHE_HOME=/tmp/cities-do-cache`

로직 테스트는 공간·확률·연쇄 및 100회 성장 불변성을 검증합니다.
UI 테스트는 실제 장면을 띄워 입력 이벤트·버튼 신호·데이터 반영을 headless로 확인합니다.
그래픽 화면의 실제 시각 검수와 마우스 장치를 통한 수동 플레이 검증은 별개입니다.

성장 크기 45/30/25%, 연쇄 55% 등은 임시 밸런스입니다. 상세 규칙은
스킬의 references/RULES_KO.md를 확인하세요. 원본 첨부 기획의 교통·경제 전체를
구현한 프로젝트는 아닙니다.
