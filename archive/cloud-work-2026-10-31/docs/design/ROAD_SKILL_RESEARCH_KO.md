# 도로 연결 스킬·플러그인 조사 (2026-10-31)

공개 GitHub 검색 결과와 각 저장소의 실제 README·SKILL.md·라이선스를 읽어 비교했다.
확인한 검색어: godot road generator, godot skills, city-builder skills,
city-building skill, road network SKILL.md. 전체 공개 스킬을 빠짐없이 검색했다는 의미는 아니다.

| 후보 | 종류 | 우리 게임 적용성 |
|---|---|---|
| [Godot Road Generator](https://github.com/TheDuckCow/godot-road-generator) | Godot 3D 플러그인, MIT | 가장 적합한 도로 연결 구현 참고. Godot 4.4+ 대상, GDScript. 곡선·차로별 단면·길어깨·교차로·진출입 램프 프리팹·런타임 생성 지원 |
| [CCBK 도로·레이어·연결 스킬](https://github.com/Schossi/CCBKSkills/blob/main/classic-city-builder-kit-roads-layers-connections/SKILL.md) | 실제 AI SKILL.md, MIT 저장소 | Unity 6 및 Classic City Builder Kit 의존. 격자 타일 도로·수도·전력 연결 중심. Godot 자유 곡선 도로에 바로 적용 불가 |
| [Godot Simulation 스킬](https://github.com/thedivergentai/Game-Dev-Agentic-Skills/blob/main/skills/godot-genre-simulation/SKILL.md) | 실제 AI SKILL.md | 도시 경영·시간 틱·경제·NPC 관리 참고. 도로 곡면·측면 합류 전용 구현 없음. 저장소 기준 Godot 4.7+이므로 현재 4.6.3과 버전 차이 있음 |
| [Cities: Skylines 1 Agent Skill](https://github.com/Sunwood-ai-labs/cities-skylines1-agent-skill) | Codex 스킬+게임 모드, MIT | 기존 CS1 게임을 API로 조작하는 용도. 자체 Godot 게임의 도로 엔진으로 사용 불가 |

## 추천

현재 문제에는 Godot Road Generator의 단면·가장자리 곡선 구조가 가장 유용하다.
README는 고속도로 on/off-ramp 프리팹과 런타임 기능을 명시한다.
`nodes/road_point.gd`의 방향별 차로·좌우 길어깨 속성과
`nodes/road_segment.gd`의 방향별 폭·edge curve 오프셋 계산을 확인했다.

이 후보는 AI 지시문 스킬과 구별되는 실제 엔진 플러그인이다.
현재 게임은 Node2D 기반이므로 그대로 설치한다고 기존 도로가 교체되지는 않는다.
초기 조사는 코드와 문서 확인 단계였다. 이후 사용자 요청으로 0.9.5를 설치하고
실제 비교 장면에 연결했다. 현재 적용·검증 범위는 ROAD_GENERATOR_ADOPTION_KO.md 참조.
README에서 절차적 교차로의 RoadLane/edge curve 지원은 예정으로 표시되어 있으므로
교차로 내부의 완성된 차량 연결까지 지원한다고 단정하지 않는다.

## 현재 프로젝트에 반영한 측면 연결

외부 코드를 복사하지 않고 기존 `cities-do-construction` 구현을 수정했다.
램프 끝은 차도 외측에 두고, 그래프에는 대응하는 방향의 논리 연결을 별도로 기록한다.
본선 중앙분리대·중앙선은 유지하고 램프가 붙는 쪽의 방호벽만 국소적으로 연다.
차량의 차로별 합류 시뮬레이션은 여전히 후속이다.
