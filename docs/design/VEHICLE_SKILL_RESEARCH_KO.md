# 차량 제작 스킬 재설치 · 2026-11-01

원본: https://github.com/duolahypercho/zstack/tree/74f7786e9931b9ced858a0e2df880f23e4c2430e/skills/vehicle

해당 고정 커밋을 실제 체크아웃하여 `skills/vehicle/` 전체를
`.agents/skills/vehicle/`로 복사했다. 원본 루트 LICENSE는 MIT,
Copyright (c) 2026 duolahypercho다. 원본 SKILL.md·스크립트·템플릿·참고자료를
수정 없이 유지하며 `UPSTREAM.json`에 경로별 SHA-256을 기록했다.

원본은 실측 레퍼런스 기반 바디 케이지·패널·개폐 리그·충돌 변형·IoU 검증까지
다루는 스킬이다. Claude 로그인은 필요 없으며 Blender 헤드리스 실행이 가능하다.
실사 비교 단계는 별도 numpy/opencv/scipy와 레퍼런스 작업이 필요하다.
이번 게임용 제작에는 그 전체 의존성을 설치하거나 파이프라인을 실행하지 않았다.

`common.py`의 좌표계와 피벗·도형 헬퍼를 실제 호출해 게임용 파라미터 생성기를
작성했다. CITIES_DO용 적응 지침은 `.agents/skills/cities-do-vehicles/SKILL.md`에
새로 작성했다. 이전 환경의 적응 파일이나 생성기를 복구한 것은 아니다.

라이선스 사본과 출처 표기는 편집 원본·게임 애셋 양쪽 경로에 포함했다.
제작 결과·재현·검증 한계는 `assets/vehicle-fleet/README.md`에 기록한다.
