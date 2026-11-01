# CITIES_DO 스킬 인계장

최종 기록: 2026-11-01 KST. 사용자의 요청으로 이후 작업에서도 계속 갱신한다.
**새 담당자는 이 문서 → AGENTS.md → 관련 SKILL.md → 실제 코드와 검증 기록 순으로 확인한다.**
“배웠다”는 말은 모델에 영구 설치했다는 뜻이 아니다. Git에 보존한 지침·코드·출처와
검증 기록을 읽어 같은 작업을 이어갈 수 있다는 뜻이다. 자동 스킬 탐색 여부와
원본 파이프라인 전체 실행 여부도 구분한다.

## 현재 설치 목록: 로컬 19종

아래 경로는 모두 `.agents/skills/<이름>/SKILL.md`다.
설치만 한 스킬을 실제 제작에 적용했다고 간주하지 않는다.

| 이름 | 용도 | 실제 적용·검증 상태 |
|---|---|---|
| academy-guide | Claude 학습 자료 안내 | 설치 확인. 개별 작업 실행 검증 기록 없음 |
| algorithmic-art | p5.js 생성 예술 | 설치 확인. 작품 제작 실행 미검증 |
| brand-guidelines | 브랜드 스타일 지침 | 설치 확인. 개별 적용 품질 미검증 |
| canvas-design | 정적 시각 디자인 | 설치 확인. 개별 제작 실행 미검증 |
| discernment-nudge | 판단·검토 지침 | 설치 확인. 개별 적용 품질 미검증 |
| frontend-design | 웹 화면 설계 | 이전 작업에서 도시 공원 웹 예제 제작·모바일 확인 기록 |
| internal-comms | 내부 문서 작성 | 설치 확인. 개별 적용 품질 미검증 |
| mcp-builder | MCP 서버 제작 | 설치 확인. 실제 서버/API 실행 미검증 |
| skill-creator | 스킬 작성·검사·패키징 | 이전 작업에서 메타데이터 검사·패키징 성공. 자동 평가/개선은 Claude CLI 의존 |
| slack-gif-creator | GIF 생성·검사 | 이전 작업에서 공식 도우미로 12프레임 GIF 검사 성공. 이번 주행 GIF는 Godot 캡처/Pillow 경로 |
| theme-factory | 테마 적용 | 설치 확인. 개별 작업 실행 미검증 |
| web-artifacts-builder | 웹 초기화·빌드·단일 HTML | 이전 작업에서 Vite/TypeScript/Parcel 실행 기록. 최신 의존성 보정 필요 |
| webapp-testing | Playwright 웹 테스트 | 이전 작업에서 데스크톱/모바일 조작·번들 검사 성공 |
| cities-do-construction | 이 게임의 건설·성장·구획 | 로컬 프로젝트 지침. 기존 Godot 도시·UI·애셋·도로·구획·전시 검사에 적용 |
| vehicle | Blender 차량 모델링·리그 | 원본 재설치. common.py의 도형·피벗 헬퍼를 차량 20종 생성기에 실제 사용 |
| cities-do-vehicles | 차량 원본 스킬의 게임용 적응 | 이번 대화에서 새로 작성. 미터 단위·좌표계·우측통행·출력·출처·검증 규약 적용 |
| game-ai | 상태·경로·이동 분리, A* | 차선 그래프/교통 상태/렌더 어댑터 분리와 경로 재사용에 적용 |
| godot-gdscript | GDScript 구현 지침 | 교통 모듈·장면·버튼 구현에 적용. 원본 4.7 예시를 현재 4.6.3에서 검증 |
| godot-gdscript-headless-testing | 명시적 종료 코드·헤드리스 검사 | 주행 검사에서 실패 집계·비정상 종료·로그 확인·시간 제한을 적용 |

Anthropic 13종의 과거 실행 근거는 [validation/RESULTS.md](../validation/RESULTS.md)다.
새 환경에서 그 13종의 런타임을 전부 재실행한 결과가 아니다. 당시 `/workspace/skill-validation`
임시 출력이 현재도 존재한다고 가정하지 않는다. 메타데이터 검사를 작업 품질 검증으로 확대하지 않는다.

## 출처·라이선스와 실제로 익힌 내용

### Anthropic 공개 스킬 13종

위 표의 academy-guide부터 webapp-testing까지다.
출처: https://github.com/anthropics/skills

고정 SHA: `ca45fc496a3436251f191354091d557da31c15b5`, Apache-2.0.
각 폴더의 LICENSE.txt 등 제공된 출처 파일을 보존한다.
TypeScript 7의 baseUrl 제거, UI 라이브러리 API, pnpm 네이티브 빌드 승인,
Parcel 리소스 처리 등 보정 기록은 validation/RESULTS.md에 있다.
Claude 로그인 없는 문서 읽기·로컬 실행 경로와 Claude CLI 전용 자동 평가를 구분한다.
docx/pdf/pptx/xlsx 같은 별도 라이선스 스킬은 설치 목록에 없다.

### CITIES_DO 프로젝트 스킬 2종

- [cities-do-construction](../.agents/skills/cities-do-construction/SKILL.md): 기존 저장소의 자체 지침.
  건설/성장 로직과 렌더 분리, 회전 부지, 난수 분리, 기존 검사 보존을 다룬다.
  별도 LICENSE 파일은 없으며 외부 라이선스를 임의로 부여하지 않는다.
  오래된 기획·임시 수치보다 최신 사용자 합의와 실제 코드 상태를 우선한다.
- [cities-do-vehicles](../.agents/skills/cities-do-vehicles/SKILL.md): 2026-11-01 재작성본.
  이전 환경의 수정본을 회수한 것이 아니다. 새 스킬을 작성했다는 사실과 원본 재설치를 구분한다.

### vehicle: 로컬 Blender로 차량 20종

출처: https://github.com/duolahypercho/zstack/tree/74f7786e9931b9ced858a0e2df880f23e4c2430e/skills/vehicle

MIT, Copyright 2026 duolahypercho. 원본 SKILL.md·스크립트·템플릿·참고자료·LICENSE와
[UPSTREAM.json](../.agents/skills/vehicle/UPSTREAM.json)의 파일 해시를 보존한다.

실제 사용: common.py의 `empty`, `parent_keep`, `rounded_box`, `revolve`, `tube`, `tri_count`.
Blender -Y 전방/+X 왼쪽/+Z 위 → GLB +Z 전방/+X 왼쪽/+Y 위.
운전석은 +X, 버스 승객 문은 -X. 차체·바퀴 조향/회전·적재 장치 피벗을 분리했다.

구현: [생성기](../tools/build_vehicle_fleet.py), [제작 원본·재현](../assets/vehicle-fleet/README.md),
[제작 기록](../assets/vehicle-fleet/production_log.md), [결과 보고서](VEHICLE_FLEET_20_KO.md).
20개 .blend/GLB, spec, 160장 PNG와 catalog/render_manifest를 Git에 보존했다.
가상 로우폴리 설계이며 실사 레퍼런스 IoU·문 개폐·충돌 변형 전체 검증은 하지 않았다.
원본의 모든 기능을 배웠거나 통과했다고 주장하지 않는다.

### 게임 AI/GDScript/검사 스킬 3종

출처: https://github.com/gamedev-skills/awesome-gamedev-agent-skills/tree/19d93f97c9c1ea0f8b306e77aa81e0d3e352d3e9

Apache-2.0. 각 설치 폴더의 SKILL.md·하위 참고자료·LICENSE·NOTICE·UPSTREAM.json을 보존한다.
경로/의사결정/이동을 분리하고, AStar2D 차선 탐색과 30Hz 고정 시뮬레이션을 구현했다.
실제 구현·검증·제약은 [도로 주행 보고서](TRAFFIC_AI_KO.md)를 따른다.

## 스킬과 구분해야 할 도구·참고 코드

| 항목 | 설치·출처 | 실제 활용과 한계 |
|---|---|---|
| Godot Road Generator 0.9.5 | `cities_do/addons/road-generator/`, TheDuckCow/godot-road-generator, `7cbefde04e57a84499c5d8ba636c9cb4fd7d22c0`, MIT | 실제 RoadLane/RoadLaneAgent/RoadManager로 주행 위치 계산. 원본 코드 보존, Godot가 재생성한 21개 .import 변경은 UPSTREAM.json에 별도 기록. 스킬 자체가 아님 |
| city-traffic-sim | `third_party/city-traffic-sim/`, kristofsw/city-traffic-sim, `cd0e2b82f74851821d33d93e17b05b8d9754c84b`, MIT | 앞차 속도·차체 간격 기반 ACC 공식을 미터 단위로 적응. 전체 프로젝트 실행·통합으로 간주하지 않음 |
| Blender 4.3.2 / Godot 4.6.3 | 실행 도구 | 모델 생성/원본 열기와 게임 임포트/테스트/실제 OpenGL 캡처에 사용. 새 환경에서 설치·버전 재확인 |
| 건물 애셋 제작 | `assets/mansion-study/build_mansions.py`, `assets/residential-eight/build_residentials.py` | 로컬 Blender Python 경로가 확인됨. 외부 건물 전용 스킬을 도입했다고 지어내지 말 것. 후보 조사는 docs/asset-skills/RESEARCH_KO.md |

cloud-environment:cloud-environment-runtime과 cloud-environment-onboarding:setup은 플랫폼에서
제공되는 환경 스킬이다. Git의 로컬 19종에 포함하지 않는다. 이번 대화에서는 runtime의
네트워크·연결 진단 지침을 사용했다. setup의 과거 사용 기록이 있지만 이번에 환경 설정을
저장/게시한 것은 아니다. 새 채팅에서 제공 여부를 다시 확인하고 읽는다.

## 검증 상태와 다음 작업

2026-11-01의 실제 저장 결과: [8종 검사 모두 통과](traffic-validation/results.json),
[주행 43/43](traffic-validation/test_traffic.log), [차량 외형 156/156](traffic-validation/test_vehicles.log).
원본 .blend 열기·PNG 160장 검사와 실제 주행 GIF도 해당 제작/주행 보고서에 있다.
이 수치는 이후 수정본이나 새 환경을 자동으로 검증한 결과가 아니다.

새 세션에서는 리소스를 임포트하고 관련 검사를 다시 실행한다.

```sh
godot --headless --editor --import --path cities_do --quit
godot --headless --path cities_do --script tests/test_traffic.gd
godot --headless --path cities_do --script tests/test_vehicles.gd
```

사용자와 마지막으로 확인한 미완료 사항:

- 원형 시험장의 원 안쪽이 전부 아스팔트로 채워지는 표시 문제. **아직 수정하지 않았다.**
  최종 의도는 도로 띠만 아스팔트, 내부는 지형/건설 공간이다.
- 교차로 전체 제어·안전한 차선 변경·합류·통근/물류/버스 노선·대형 도시 성능은 미완료.
- 이전 환경의 후속 건물 애셋·도로 수정 어댑터는 미회수. 원본 Road Generator 재설치와
  이전 C2 어댑터 복구를 혼동하지 않는다. [최초 인계문](recovery/ORIGINAL_HANDOFF_KO.txt) 참고.

현재 결과는 [GitHub 자료 안내](GITHUB_DOWNLOADS_KO.md)에서 확인한다.
ZIP은 특정 커밋의 스냅샷이며 이후 인계장 변경이 자동 반영되지 않는다. 최신 내용은 Git main이다.
개인 토큰·인증 헤더는 기록하지 않는다. GitHub 인증 실패 시 완료/미전송 범위를 나눠 보고한다.

## 앞으로 갱신할 양식

스킬/도구를 새로 도입·사용·수정·검증할 때 같은 작업의 커밋에 아래 내용을 추가한다.

1. 날짜, 정확한 이름, 로컬 경로, 스킬/애드온/참고 코드 구분.
2. 원본 URL·고정 SHA·LICENSE/NOTICE, 재설치인지 자체 재작성인지.
3. 실제로 읽고 적용한 기능, 변경한 구현/애셋 파일과 재현 명령.
4. 실행한 검사와 결과 파일, 상속한 과거 기록과 새 실행 결과의 구분.
5. 실행하지 않은 기능·한계·다음 담당자가 이어갈 작업.
6. Git 커밋·푸시 상태. 최종 사용자 안내에는 GitHub 링크 사용.

원본 지침을 임의로 수정해 검증 범위를 넓혀 적지 않는다. 목록을 갱신하고도
스킬 파일·보조 스크립트·라이선스를 Git에서 누락하지 않도록 실제 파일을 대조한다.
