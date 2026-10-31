# Anthropic 공개 스킬 · Codex 작업 공간

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
