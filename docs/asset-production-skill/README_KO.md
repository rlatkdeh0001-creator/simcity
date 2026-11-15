# 다른 AI에게 넘길 CITIES_DO 애셋 제작 스킬

우리가 사용한 **Blender 스크립트 지오메트리 → 정사영 투명 PNG → 실측/검증** 과정을
대화 기록과 Git 이력이 없어도 실행할 수 있게 묶었다. Claude 로그인이나 생성 API는 필요 없다.

- [AI가 먼저 읽을 SKILL.md](../../.agents/skills/cities-do-asset-production/SKILL.md)
- [전체 묶음 다운로드](../../downloads/cities-do-asset-production.skill) (`.skill`은 ZIP 형식)
- [규격/표현/좌표계](../../.agents/skills/cities-do-asset-production/references/CONTRACTS_KO.md)
- [실행 명령과 신규 애셋 수정법](../../.agents/skills/cities-do-asset-production/references/RECIPES_KO.md)
- [고정 원본 커밋/파일 해시/변경 내역](../../.agents/skills/cities-do-asset-production/references/source-manifest.json)
- [실제 시험 결과](smoke-results.json), [작업 공간 보호 검사](portability.json), [재생성 시안](preview-samples.png)

## 다른 AI에게 그대로 전달할 문구

> 이 저장소의 `.agents/skills/cities-do-asset-production/SKILL.md`를 먼저 읽고,
> 연결된 규격과 레시피까지 확인해 주세요. 대화 기록에 의존하지 말고 포함된 생성기와
> 검증기를 사용하세요. 먼저 doctor로 환경을 확인하고, 새 출력 폴더에서 물류창고 예제
> (`building-growth`, `small-4x4-logistics-01`)를 생성·렌더·검증해 주세요.
> PNG와 실측/삼각형 수를 보여주고, 그 방식을 기준으로 제가 요청하는 새 애셋을 만드세요.
> 게임에 바로 적용하지 말고 원본/생성기/메타데이터/검사 결과를 애셋 브랜치에 보관하세요.

AI에 파일만 첨부할 때는 `.skill`을 내려받아 전달한다. 압축을 자동으로 읽지 못하는
환경이면 확장자를 `.zip`으로 바꿔 풀고 **전체 폴더**를 전달한다. SKILL.md 한 장만
첨부하면 생성 코드/의존 파일/검증기가 없어 standalone 재현이 불가능하다.
AI가 Blender 명령을 실행할 수 있는 환경이어야 한다. AI 서비스의 스킬 자동 설치 여부와
이 문서를 읽고 지침에 따라 실행할 수 있는지는 별개다.

## 터미널에서 실행

Python3.10+와 Blender4.3.2를 준비한다. 시스템 Python에 `requirements.txt`를 설치한다.
Blender의 `bpy`를 시스템 Python에 따로 설치하지 않는다.

```sh
python .agents/skills/cities-do-asset-production/scripts/assetkit.py doctor
python .agents/skills/cities-do-asset-production/scripts/assetkit.py list
python .agents/skills/cities-do-asset-production/scripts/assetkit.py run --workspace /tmp/new-asset-review --profile building-growth --only small-4x4-logistics-01
```

Blender가 PATH에 없으면 `--blender "실행파일 전체경로"`를 덧붙인다.
`--workspace`는 새 빈 폴더를 사용한다. 기존 프로젝트 폴더는 거부하며, 다시 prepare해도
수정한 staged 생성기를 덮어쓰지 않는다. 같은 ID를 run하면 해당 생성 산출물은 다시 쓴다.
Windows/macOS 경로 예시는 스킬에 있으나 이번 실행 검증은 Linux에서만 했다.

## 들어 있는 것과 범위

성장 건물14종, 기존 차량 fleet23종, 쓰레기차/한국형 구급차, 산업 메인/확장 타일,
신호등2종, 시민 시험형, 빈 주차장/공원, 옛 2·4차선 도로 시안의 생성기가 들어 있다.
정확한 ID는 list로 확인한다. 기존 승인 형상을 재생성하는 코드와 새 디자인을 추가할
수정 지점을 함께 제공한다. 모든 과거 건물 시안이나 현재 도로 시스템 전체를 담은 것은 아니다.
기존 공개 스킬 조사/출처는 [애셋 스킬 연구 기록](../asset-skills/RESEARCH_KO.md),
전체 프로젝트 스킬 인계는 [인계장](../SKILL_HANDOFF_KO.md)을 참고한다.

vehicle/parking 레시피가 내보내는 GLB/catalog도 출력 작업 공간 안에만 생성한다.
이번 커밋은 스킬/재현 도구/검증 기록만 추가하며 게임 애셋/시뮬레이션/main을 변경하지 않는다.
`.skill`에는 대용량 완성 모델을 중복 넣지 않고 생성 코드와 의존성을 포함했다.

## 검증을 다시 하는 명령

압축을 푼 스킬 경로에서 다음을 실행한다. 첫 명령은 가벼운 보호/구문/해시 시험,
둘째는 10개 유형의 대표 애셋을 실제로 생성/렌더한다.

```sh
python <skill>/scripts/test_portability.py
python <skill>/scripts/smoke_recipes.py --output <new-empty-test-folder> --jobs 3
```

시험의 전체 범위/한계는
[검증 계약](../../.agents/skills/cities-do-asset-production/references/VERIFICATION_KO.md)을 따른다.
전체 catalog 모델을 전부 재렌더한 시험이나 다른 AI 모델의 수행 능력 비교는 아니다.
게임 통합/교통 AI/신호 주기/대규모 성능도 검증하지 않았다.

신호등 standalone 첫 시험에서 재질 정의 정리 전에 검증해 실패했다. 기존
`render_signal_states.py`가 spec의 재질 정의도 정규화하므로, 그 단계 뒤에 검증을 배치했다.
최종 패키지에서 해당 순서로 재시험하며, 원본 모델 지오메트리는 바꾸지 않았다.

## 이번 실행 결과

최종 코드가 포함된 .skill을 Git 정보가 없는 새 디렉토리에 풀어 실행했다.
10/10 profile, Blender 원본14개, PNG127개 generic 검사 통과. 시민 PNG100장은
이 합계에 포함된다. 기존 폴더 보호/수정 보존/잘못된 ID 거부/소스 해시 등 9개 보호 검사도
통과했다. [개별 원본의 평가된 실측/삼각형](asset-measurements.json)과
[유형별 상세 보고서](reports/)를 함께 보관했다.

신호등 독립16상태×2, 서비스차량 미러 접촉/높이, 시민 rig/100 PNG/깊이 합성 검사가
각 profile에서 통과했다. `preview-samples.png`는 이번 재생성 PNG를 배열한 확인용 시트다.
이미 승인된 baseline을 재생성한 것이며 이번에 새 게임용 디자인을 추가한 것은 아니다.
검증 당시 Linux, Blender4.3.2, 시스템 Python3.12.14/Pillow12.3.0/NumPy2.3.5를 사용했다.
아카이브는 코드 검증 후 문서/증빙을 추가해 재포장했고, 실제 시험한 Python 코드와
최종 아카이브의 Python 코드가 모두 동일한지도 확인했다.
