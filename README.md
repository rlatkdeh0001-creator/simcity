# simcity

공식 Anthropic Claude Code CLI를 사용하는 개발 작업 공간입니다.
Claude 모델이나 Claude Code 내부 소스를 복제한 프로젝트는 아닙니다.

## 시작

Node.js 22 이상이 필요합니다.

```sh
cd /workspace/simcity
npm ci
npm run check:claude
npm run claude
```

Claude Code 화면에서 지원되는 Anthropic 계정으로 로그인한 뒤 작업을 요청하세요.
계정의 사용 권한과 과금 조건이 적용됩니다. 인증 정보는 Git에 커밋하지 마세요.
이 클라우드 환경에서는 Claude 서비스 접근을 위한 네트워크 설정이 추가로 필요할 수 있습니다.

공식 README는 npm 설치를 deprecated로 안내하고 있습니다. 이 작업 공간은
npm 레지스트리를 통한 재현 가능한 버전 고정 설치를 사용합니다.

- 공식 저장소: https://github.com/anthropics/claude-code
- 공식 문서: https://code.claude.com/docs/en/overview
- 권장 네이티브 설치: https://code.claude.com/docs/en/setup

현재 게임 애플리케이션이나 애플리케이션 테스트는 포함되어 있지 않습니다.
