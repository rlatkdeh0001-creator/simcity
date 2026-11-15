# 검증 범위

구체적인 이번 실행 결과는 이 묶음의 [smoke-results.json](smoke-results.json)과
저장소 `docs/asset-production-skill/`에 기록한다.
아카이브는 스킬/생성 코드/계약을 담고, 전체 생성된 대용량 모델은 중복 포함하지 않는다.

- doctor: Blender가 실제 실행되는지, Blender NumPy/시스템 Python Pillow/NumPy 존재 확인.
- list: bpy를 import하지 않고 AST에서 원래 ID 테이블을 읽음.
- run: 별도 workspace에서 생성→렌더→해당 특화 검사→generic check. 성공시 run JSON 생성.
- generic blend 검사: 평가된 geometry, 유한 좌표, tri 양수, scale_length=1, 전체 bounding box.
- generic PNG 검사: 디코드 성공, RGBA, nonempty alpha, 캔버스 가장자리에서 잘리지 않음.
- 서비스차량: 전체 높이/땅/축/tri/재질 및 구급차 미러 마운트 연결 등의 원래 assertion.
- 신호등: 공유 head, 4개 lamp 이름/재질, 16개 독립 상태×2종, 모든 등 off 원본 보존,
  가로대 방향/clearance, 단독 점등 실제 렌더 리뷰. 모든 등을 켠 그림은 색상 시험용.
- 시민: source rig/skin/loop, 실제100PNG, 깊이 sidecar, 합성 가림/접점 등 원래 assertion.

범용 검사는 부지 제한/정면/층수/삼각형 예산/타일 이음매/간판 가림을 모두 증명하지 않는다.
새로운 디자인은 요청의 수치/시각 검사를 추가해야 한다. seam은 edge 좌표와 반복 배치를,
mirror는 실제 교차/접촉을, 간판은 시점별 가독성을 확인해야 한다.
게임 엔진 통합, 신호 주기, traffic AI, 대규모 성능, 미제작 의복 조합은 이번 검사 밖이다.

`references/eval-prompts.json`(저장소의 `evals/evals.json`과 같은 내용)은 다른 AI에 맡길 때 쓸 **향후 평가 입력**이다. 이번에는 AI 모델 간
성능 비교나 Claude/Codex 별 실행 평가를 하지 않았다. 스크립트 standalone 실행 시험과
혼동하지 않는다. 다른 AI가 이 스킬을 읽을 수 있으면 실행 명령과 계약을 따라 작업할 수
있지만 해당 AI의 도구/Blender 실행 권한은 사용하는 환경이 제공해야 한다.

재현 가능한 smoke 시험: `python <skill>/scripts/test_portability.py` 후
`python <skill>/scripts/smoke_recipes.py --output <new-empty-test-folder> --jobs 3`.
후자는 10개 유형에서 대표 모델(일부 고정 batch는 전체)을 실제 렌더하며
전체 catalog의 모든 모델을 재시험하는 것은 아니다.
