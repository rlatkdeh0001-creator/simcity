# UI 스킬 검색·도입 기록

2026-11-02 KST. 사용자 요청은 건설 시뮬레이션의 UI 배치를 그리는 스킬을 찾아
적합한 것이 있으면 도입하고, 기존 아이콘을 전부 하단으로 옮긴 시안을 만드는 것이다.

이미 설치된 frontend-design/canvas-design의 범위와 이전에 사용한 공개 게임 개발
스킬 모음의 고정 커밋 전체 파일 목록을 확인했다.
검색 경로: GitHub API의 gamedev-skills/awesome-gamedev-agent-skills 재귀 트리,
커밋 `19d93f97c9c1ea0f8b306e77aa81e0d3e352d3e9`.
UI/UX/HUD/interface/simulation/tycoon 관련 SKILL.md 경로를 찾았다.

후보:

- `skills/disciplines/game-ui-ux/`: 엔진 공통 HUD·메뉴·오버레이 배치,
  anchor/container, 화면 배율·안전 영역·포커스·상태별 메뉴 흐름. 이번 요청에 적합해 도입.
- `skills/godot/godot-ui-control/`: Godot Control/Theme/Container의 실제 구현 지침.
  이번은 그림 검토 단계이므로 추가 설치/적용하지 않았다.
- `skills/other-engines/roblox-ui/`: 엔진이 맞지 않아 선택하지 않았다.

이 조사 범위에서 '도시 건설 전용 UI 그림 생성 스킬'은 확인하지 못했다.
도입한 game-ui-ux는 범용 게임 UI 설계 지침이며, 그림을 생성하는 도구/애셋 묶음이 아니다.
시안 그림은 image_gen으로 제작했다. frontend-design의 기존 색/타이포/정보 위계 원칙도 참고했다.

원본: https://github.com/gamedev-skills/awesome-gamedev-agent-skills/tree/19d93f97c9c1ea0f8b306e77aa81e0d3e352d3e9/skills/disciplines/game-ui-ux

로컬: `.agents/skills/game-ui-ux/`. SKILL.md, references/layout-and-flow.md,
Apache-2.0 LICENSE와 NOTICE를 원본 그대로 보존했다. UPSTREAM.json에 파일별 SHA-256을 기록했다.
원본 Godot 4.7/Unity 예제는 현재 Godot 4.6.3에 실행/통합하지 않았다.

검증: 설치 파일 4개의 SHA-256 일치와 필수 파일 존재를 검사했다.
시안 PNG 1672×941을 열어 하단 8개 메뉴, 하단 상태·설정·시간 아이콘,
상단/좌우 상시 패널 제거 및 선택 도구의 하단 연결 배치를 육안으로 확인했다.
반응형/키보드/게임패드/화면 안전 영역 동작은 정적 그림만으로 검증할 수 없으므로
후속 구현 항목이다. 게임 코드 변경이 없어 회귀 검사는 재실행하지 않았다.
