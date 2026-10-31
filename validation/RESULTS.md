# 스킬 실행 검증 결과

검증일: 2026-10-31 (Asia/Seoul)
출처 스킬 커밋: ca45fc496a3436251f191354091d557da31c15b5

## 통과

- 13개 스킬 전체: 원본 quick_validate.py로 메타데이터 검사 13/13 통과.
- 모든 Python 소스 AST 파싱, 모든 shell 스크립트 bash -n 통과. 실행 검증과 구분함.
- skill-creator: 공식 package_skill.py로 frontend-design.skill 생성 성공.
- web-artifacts-builder: 공식 init-artifact.sh로 React 프로젝트 생성 성공.
- frontend-design: 지침을 읽고 색상·레이아웃을 정해 도시 공원 예제 제작. 색상은 배경 #e4edf3, 글자 #17354b, 지도 #cad8e2, 공원 #5b845b, 건물 #fdfefe. 좌측 설명과 우측 도시 지도를 배치하고 모바일에서 세로로 전환. 동일한 카드 나열 대신 도로 격자의 의미를 살림. 모바일 스크린샷 확인.
- 웹 프로젝트: 아래 호환 보정 후 TypeScript 검사와 Vite production build 통과.
- webapp-testing: 공식 with_server.py + Python Playwright + 시스템 Chromium 실행. 초기 상태, 공원 3개 추가, 지도 갱신, 초기화, 390px 모바일 가로 넘침 없음, 모바일 클릭, JS 오류 없음 확인.
- web-artifacts-builder: 아래 보정 후 공식 bundle-artifact.sh로 301,839바이트 단일 HTML 생성. Playwright set_content로 번들 내용을 로드하여 클릭 동작 확인. 네트워크 요청 0건, JS 오류 0건. file:// 탐색 자체는 브라우저 관리자 정책으로 차단되어 검증하지 못함.
- slack-gif-creator: imageio 설치 후 공식 GIFBuilder로 128×128, 12프레임 GIF 생성. Pillow로 12프레임 재확인, 공식 validate_gif(is_emoji=True) 통과.
- 위 실동작 검증에서 Claude CLI·로그인·Anthropic API를 사용하지 않음.

## 확인한 호환성 문제와 검증 프로젝트의 보정

원본 스킬 파일은 수정하지 않았다. 초기화 스크립트가 최신 의존성을 설치하므로 원본 그대로의 완전한 동작은 보장되지 않는다.

1. TypeScript 7이 baseUrl 옵션을 제거함. 생성 프로젝트의 tsconfig.json과 tsconfig.app.json에서 compilerOptions.baseUrl을 제거. 기존 상대 paths 매핑은 유지.
2. 기존 shadcn 컴포넌트와 최신 라이브러리 API 충돌. `pnpm add react-day-picker@9.11.1 react-resizable-panels@2.1.9`로 보정. 8.x 달력은 API가 맞지 않아 실패했고 9.11.1로 성공.
3. pnpm 11이 Parcel 네이티브 의존성 빌드를 보류함. 검증 프로젝트 pnpm-workspace.yaml의 allowBuilds에서 @parcel/watcher, @swc/core, lmdb, msgpackr-extract를 true로 설정 후 pnpm rebuild 실행. 검증·무결성 확인은 비활성화하지 않음.
4. 새 Vite 템플릿의 /favicon.svg를 Parcel이 해석하지 못함. 검증 프로젝트 index.html의 favicon link 제거 후 번들 성공.
5. 서버 도우미에서 pnpm dev가 준비 시간 내 열리지 않음. 서버 명령을 `node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4174 --strictPort`로 바꿔 성공.
6. GIF 실행 시 imageio가 없었음. 검증 전용 python-deps에 imageio 2.38.1, numpy 2.5.4, pillow 13.0.0 설치 후 실행 성공.

## 제한

- skill-creator의 run_eval.py, improve_description.py 및 이를 호출하는 자동 개선 흐름은 claude 명령에 의존한다. 이 부분은 Claude 로그인 없이 원본 그대로 사용할 수 없다. 작성 지침·정적 검사·패키징은 사용 가능.
- MCP 평가의 실제 모델/API 호출, 모든 shadcn 컴포넌트, 알고리즘 아트·캔버스 생성 등 나머지 스킬의 개별 작업은 실행 검증하지 않았다.
- 지침 기반 디자인·글쓰기 스킬에는 공통 자동 합격 기준이 없다. 메타데이터 검사를 해당 분야 결과 품질 검증으로 간주하지 않는다.
- Codex 클라이언트의 새 세션 자동 스킬 탐색은 검증하지 않았다. 이번에는 SKILL.md를 직접 읽고 적용했다.

## 증거와 재실행

현재 인스턴스의 /workspace/skill-validation/에 init.log, build.log, bundle.log, demo/bundle.html, desktop.png, mobile.png, test.gif, frontend-design.skill이 있다. 임시 인스턴스의 파일이므로 새 작업에서 보존된다고 가정하지 않는다.

browser_test.py는 해당 검증 프로젝트와 포트 4173을 가정한다. 실제 성공한 도우미 실행에서는 4174로 치환했다. 도우미는 시작한 테스트 서버를 종료했다.

```sh
cd /workspace/skill-validation/demo
python3 /workspace/simcity/.agents/skills/webapp-testing/scripts/with_server.py \
  --server 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4174 --strictPort' \
  --port 4174 -- python3 -c "exec(open('/workspace/simcity/validation/browser_test.py').read().replace(':4173', ':4174'))"
```
