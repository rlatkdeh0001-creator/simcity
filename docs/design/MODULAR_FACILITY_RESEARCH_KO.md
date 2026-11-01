# 모듈 결합 스킬 조사 · 2026-11-01

GitHub 저장소 검색: `modular building SKILL.md`, `modular environment agent skills`, `godot modular building gridmap`. 전용 주차장 결합 제작 스킬은 이번 검색 범위에서 확인하지 못했다. 모든 공개 스킬이 없다는 판정은 아니다.

고정 출처에서 procedural-gen과 godot-tilemap의 실제 SKILL.md를 읽었다. 전자는 데이터 생성/결정성/연결성 검증, 후자는 TileMapLayer 지형 연결 지침이다. 주차장 GLB/내부 경계석 제거/공유 통로 모델을 제공하지 않아 원본을 설치하지 않고 참고 자료로만 기록했다.

전용 cities-do-modular-facilities를 자체 작성했다. 기존 skill-creator의 작성 원칙을 참고했으며 Claude CLI 자동 평가·트리거 최적화와 에이전트 비교 실험은 실행하지 않았다. 실제 기하/연결성 검사는 Python 기준 결과와 Godot 런타임을 대조한다.

출처·고정 SHA·문서 해시는 MODULAR_FACILITY_SOURCES.json에 보존한다.
