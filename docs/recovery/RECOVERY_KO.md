# CITIES_DO 복구 조사 · 2026-11-01 KST

이 문서는 차량 재제작 전 최초 조사 기록이다. 이후 스킬 재설치와 새 차량 20종 제작을
진행했다. 최신 상태는 [차량 제작 결과](../VEHICLE_FLEET_20_KO.md)를 확인한다.
아래 누락 수량과 검사 결과는 조사 당시 상태로 보존한다.

## 확인된 저장 범위

조사 시작 시 로컬 HEAD와 GitHub `main`은 모두
`620ae3735bb6cf520589f7358f1731bf7b9c9607`이었다. 로컬 브랜치는 `work`였고
미커밋 변경은 없었다. 같은 커밋에서 `main` 브랜치를 만들어 작업을 이어갔다.
원격에서 확인된 브랜치는 main 하나다. 저장소 초기화나 파일 덮어쓰기는 하지 않았다.
`git fsck --full --no-reflogs`에서 복구 가능한 후속 커밋은 발견되지 않았다.

현재 확보된 게임은 주거 10종 전시와 도로 직각 구획까지다. 인계문에 기록된
상업·공업·공공시설 전체, 개선된 나들목, Road Generator, 차량 20종은 이 체크아웃에
없다. 접근 가능한 `/workspace`, `/tmp` 검색에서도 차량 생성기·전시 코드를 찾지 못했다.
이전 환경의 파일을 현재 환경 ID로 조회할 수 있는 도구는 제공되지 않았다.
이전 환경이 삭제됐거나 파일이 영구 소실됐다고 판정한 것은 아니다.

## 보존

- `/workspace/recovery-backups/simcity-before-recovery.tar.gz`: 변경 전 파일 백업. .git과 .godot 제외, 로컬 제작 원본 포함.
- `/workspace/recovery-backups/simcity-history.bundle`: 기존 모든 Git 참조와 이력.
- `/workspace/cities-do-recovered-checkout.zip`: 현재 확보한 게임·애셋·제작 소스·스킬·조사 결과. 차량 완성 배포본이 아니다.

백업은 이 실행 환경의 파일이다. 별도 다운로드 없이 장기 보존을 보장하지 않는다.

## 실제 검증

Godot 4.6.3, Blender 4.3.2가 설치돼 있다. Godot 리소스 임포트 후 아래 6종을
새로 실행했고 모두 종료 코드 0, 오류/실패 로그 없이 통과했다.

- test_building_assets.gd: 25/25
- test_city.gd: 24/24
- test_road_parcels.gd: 18/18
- test_roads_zoning.gd: 18/18
- test_showcase.gd: 26/26
- test_ui.gd: 출력된 검사 모두 PASS

원본 로그와 기계 판독 결과는 이 폴더의 `test_*.log`, `tests.json`에 있다.
새 그래픽 캡처·차량 외관 검수·차량 버튼 회귀 검사는 수행하지 못했다.
기존 UI 테스트 통과를 차량 UI 통과로 간주하지 않는다.

`python3 tools/verify_vehicle_fleet.py --output docs/recovery/vehicles.json`은
종료 코드 1로 누락을 보고한다. Blender 0/20, GLB 0/20, PNG 0/160.
검증기는 파일 헤더·GLB JSON/메시 존재·PNG 규격/알파를 검사한다.
이는 피벗, 실측 스케일, 차체 모양, GLB 전체 무결성, Godot 임포트 검증을 대체하지 않는다.
압축된 .blend는 별도 Blender 검사 대상으로 보고한다.

## 스킬·출처

설치된 로컬 스킬은 README의 Anthropic 공개 스킬 13개와
`cities-do-construction` 1개다. SKILL.md 및 라이선스 파일 해시는
`skills-inventory.json`에 기록했다. Anthropic 스킬에는 Apache-2.0 LICENSE.txt가
있으며 출처 고정 SHA는 README에 있다. construction에는 별도 라이선스 파일이 없다.
기존 파일은 그대로 보존했다. 이전 실행 결과는 `validation/RESULTS.md`이며
이번 환경에서 전체 스킬 런타임을 재실행한 것은 아니다.

건물 제작 경로는 `assets/mansion-study/build_mansions.py`,
`assets/residential-eight/build_residentials.py`의 로컬 Blender Python이다.
외부 스킬 후보와 고정 출처는 `docs/asset-skills/RESEARCH_KO.md`에 있다.
후보가 설치됐다고 간주하지 않는다. vehicle 스킬과 MIT 원문이 없으므로
인계문의 출처를 실제 설치·라이선스 검증 완료로 표시하지 않았다.

## 회수와 재제작 구분

우선 회수할 대상은 이전 환경의 전체 작업 디렉터리 또는 백업 아카이브다.
특히 승인된 애셋의 .blend/PNG/GLB, 생성기, catalog, 도로 어댑터,
차량 스킬 원본·UPSTREAM.json·라이선스·미커밋 문서가 필요하다.
구체적인 예상 경로는 `missing-paths.json`, 차량 개별 파일은 `vehicles.json`에 있다.

회수가 불가능하면 차량 스킬은 인계문의 고정 SHA에서 출처와 MIT 원문을 다시
검증해 설치할 수 있다. 차량 생성기·20종 모델·피벗·전시·160장 캡처는 재제작해야 한다.
이 작업은 이전 모델의 복구와 다르며 과거 90/90 결과도 재사용할 수 없다.
승인된 건물 외형과 도로 수정의 정확한 구현은 인계문만으로 복원할 수 없다.
재제작 시 기존 팔레트·규약을 적용하고 요청된 시안 승인 절차를 지켜야 한다.

이번 변경은 복구 조사·검증 도구·증거 문서다. 누락된 차량을 생성하거나 게임에
적용한 작업, 차량 라이선스 배포 정리, 환경 설정 저장·게시를 완료했다는 뜻이 아니다.
