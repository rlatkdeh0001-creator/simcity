# Anthropic 공개 스킬 · Codex 작업 공간

## 2026-11-01 복구 조사

[현재 확보된 파일·누락 범위·새 검증 결과](docs/recovery/RECOVERY_KO.md)를 확인하세요.
현재 저장 범위에는 인계문에 기록된 차량 20종과 Road Generator가 없습니다.
`python3 tools/verify_vehicle_fleet.py`로 예상 차량 파일의 누락·구조를 검사할 수 있습니다.

Claude 자체 대신, 공식 Anthropic 스킬 중 Apache-2.0 라이선스가 확인된 스킬을 Codex 프로젝트 경로 `.agents/skills/`에 설치했습니다. Claude 로그인이나 Claude Code가 필요하지 않습니다.

출처: https://github.com/anthropics/skills
고정 출처 커밋: `ca45fc496a3436251f191354091d557da31c15b5`
각 폴더의 LICENSE.txt 및 THIRD_PARTY_NOTICES.md를 유지했습니다. 원본 스킬은 수정하지 않았습니다.

## 설치한 스킬

- `academy-guide`
- `algorithmic-art`
- `brand-guidelines`
- `canvas-design`
- `discernment-nudge`
- `frontend-design`
- `internal-comms`
- `mcp-builder`
- `skill-creator`
- `slack-gif-creator`
- `theme-factory`
- `web-artifacts-builder`
- `webapp-testing`

## 사용

이 저장소에서 “frontend-design 스킬로 페이지를 만들어 줘”, “web-artifacts-builder 스킬로 앱을 만들어 줘”, “webapp-testing 스킬로 확인해 줘”처럼 요청하세요. 에이전트가 해당 SKILL.md를 읽고 적용합니다. 현재 대화에서도 파일을 직접 읽어 사용할 수 있습니다. 새 세션의 자동 목록 표시는 클라이언트의 프로젝트 스킬 탐색 지원에 따라 달라집니다. AGENTS.md에도 적용 절차를 기록했습니다.

스킬 파일과 참조 자료의 존재를 검증했습니다. 각 스킬의 모든 보조 스크립트 실행이나 런타임 의존성 설치까지 완료한 것은 아닙니다. 실제 작업 시 필요한 도구만 준비합니다. 외부 서비스나 API를 사용하는 개별 작업에는 별도 인증이 필요할 수 있습니다. Claude 전용 도구 지침은 사용 가능한 도구로 적용합니다.

## 제외 항목

- docx, pdf, pptx, xlsx: 별도 라이선스의 복제·배포 제한
- doc-coauthoring: 폴더 내 라이선스 파일 없음
- claude-api: Claude API 개발 전용으로 현재 요청 범위에서 제외

이 저장소는 Claude 내부의 비공개 스킬 전체를 복제한 것이 아닙니다. 잘못 설치했던 Claude Code 의존성과 미완성 미리보기 앱은 제거했습니다.

## 실제 실행 검증

[검증 결과와 호환성 보정](validation/RESULTS.md)을 확인하세요. 웹 제작·빌드·번들·브라우저 상호작용, GIF 생성, 스킬 패키징을 실행 검증했습니다. 원본 웹 제작 스크립트는 최신 의존성과의 호환 보정이 필요했고, skill-creator의 일부 자동 평가 기능은 Claude CLI에 의존합니다.

## CITIES_DO 건설 스킬

`cities-do-construction` 스킬과 Godot MVP를 추가했습니다. [실행·조작·검증](cities_do/README.md)을 참고하세요.

## 건물 애셋 제작 스킬 조사

[CITIES_DO 건물 애셋 후보와 출처 추적](docs/asset-skills/RESEARCH_KO.md)에 Blender·픽셀 아트 제작 스킬, 라이선스·환경 조건과 원본 커밋을 정리했습니다. `python3 tools/track_asset_skills.py --check-heads`로 원본 변경을 확인할 수 있습니다. 새 후보를 설치하거나 정기 모니터링을 설정한 것은 아닙니다.

## 4층 맨션 시안

[벽돌형 / 모던형 비교 이미지](assets/mansion-study/comparison.png)와 [Blender 원본·재생성 방법](assets/mansion-study/README.md)을 추가했습니다. 두 시안 모두 4×4 부지의 4층 공동주택이며 외부 생성 API 없이 로컬 제작했습니다.

## 타일·도로 시안과 100×100 예시 맵

[왕복 2차로·4차로·잔디 타일 비교](assets/road-tile-study/comparison.png)를 제작했습니다. 1칸=4m, 2차로=2칸, 4차로=4칸(보도 포함) 제안입니다. 게임은 빈 100×100 맵에서 시작해 도로 주변 구획만 표시합니다. [범위와 재생성 방법](assets/road-tile-study/README.md)을 확인하세요.

## 소형·대형 주거 8종 시안

[8개 건물 비교](assets/residential-eight/comparison.png): 소형 2×2/4×4 각각 2개, 대형 4×4/8×8 각각 2개입니다. [개별 PNG·Blender 원본·재생성 방법](assets/residential-eight/README.md)을 제공합니다. 현재는 게임 등록 전 외관 시안입니다.

## 실제 게임에서 주거 10종 보기

[Godot 실제 게임 화면](docs/screenshots/residential-showcase.png)에서 소형 4종·중형 맨션 2종·대형 4종을 같은 축척으로 나란히 볼 수 있습니다. 건설 화면의 **주거 건물 10종 전시** 버튼 또는 `godot --path cities_do residential_showcase.tscn`으로 실행합니다. [소형·중형 확대](docs/screenshots/residential-showcase-small-medium.png) / [대형 확대](docs/screenshots/residential-showcase-large.png)도 제공합니다.

## 도로 직각 구획

[실제 게임의 직선·사선·꺾임·곡선 구획](docs/screenshots/road-perpendicular-parcels.png)을 추가했습니다. 도로별 직각 좌표계에서 건설·성장을 처리하고, 곡선은 짧은 반듯한 블록으로 나눕니다. **도로 직각 구획 예시** 버튼 또는 `godot --path cities_do road_parcel_demo.tscn`으로 확인할 수 있습니다. 회전 부지는 현재 임시 입체 건물로 표시합니다.
