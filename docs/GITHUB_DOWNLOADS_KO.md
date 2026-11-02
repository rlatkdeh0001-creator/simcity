# GitHub에서 보기·다운로드

[실제 게임 배경의 하단 UI](concepts/bottom-ui/actual-game-power.png) · [수도 탭](concepts/bottom-ui/actual-game-water.png) · [동작/실행법](concepts/bottom-ui/ACTUAL_GAME_KO.md). 생성형 그림이 아닌 실제 Godot 캡처.

[하단 통합 UI 시안](concepts/bottom-ui/concept.png) · [배치/스킬 조사 기록](concepts/bottom-ui/DESIGN_KO.md) — 게임 미적용.

**[수도 거래요금 적용·단가 수정 방법](WATER_TARIFFS_KO.md)** — 상수 수입·수출/하수 위탁의 m³ 요금과 소수 doth 정산.

**[상하수도망 실제 도입·조작·가격/용량 제안](WATER_SEWAGE_KO.md)** · [게임 GIF](screenshots/water-game-running.gif) · [꿀렁이는 흐름 확대](screenshots/water-flow-closeup.gif)

**최신 전력 업데이트:** [실제 건설·동시 공급·자동 수출입·거래단가·실행 안내](UNDERGROUND_POWER_KO.md). 계약한도 미적용. 최신 코드는 main 기준이며 기존 ZIP은 이전 스냅샷입니다.

이 저장소의 게임 소스, 건물·차량 애셋, Blender 제작 원본, 생성기, 설치한 스킬,
라이선스, 조사 보고서, 테스트 로그와 화면 자료는 모두 Git에 저장돼 있다.
클라우드 작업 공간을 열지 않아도 아래 링크로 볼 수 있다.

## 공원·주차 시설 추가

[8종 제작·결합 보고서](PARKS_PARKING_KO.md) · [8종 화면](screenshots/facilities-8.png) · [결합 화면](screenshots/parking-merged.png)

[새 시설 제작 묶음](../downloads/cities-do-parks-parking-8.zip)은 원본·애셋·결합 코드·전용 스킬을 담습니다. 게임 실행은 저장소 최신 main을 사용하세요. 아래 전체 프로젝트 ZIP은 주행 AI 완료 시점의 스냅샷이며 새 공원·주차 시설은 포함하지 않습니다.

## 최신 작업

- [실제 지중 전력 도입 보고서](UNDERGROUND_POWER_KO.md) · [게임 실행 GIF](screenshots/power-game-running.gif) · [실제 수출 화면](screenshots/power-game-export.png) · [검사 결과](power-validation/results.json)

아래 전력 시안 링크는 도입 전 기록이다. 현재는 위 실제 구현을 기준으로 확인한다.

- [64m 반경·32m 간격·하얀 원 흐름 GIF](concepts/underground-power-v2/flow-demo.gif) · [시안 설명](concepts/underground-power-v2/DESIGN_KO.md) — 게임 미적용

- [지중 전력망 시안과 kWh 단가 제안](ELECTRICITY_TARIFF_PROPOSAL_KO.md) — 생성형 예시, 게임 미적용

- [새 규칙: 네 이웃 마을과 외부 교류](REGIONAL_EXCHANGE_RULES_KO.md)

- [도로 주행 AI 도입·테스트 결과](TRAFFIC_AI_KO.md)
- [주행 GIF](screenshots/traffic-ai-running.gif)
- [주행 시험장 화면](screenshots/traffic-ai-demo.png)
- [건설 화면에서 주행](screenshots/traffic-main-ui.png)
- [차량 20종 제작 결과](VEHICLE_FLEET_20_KO.md)
- [차량 20종 전시 화면](screenshots/vehicle-fleet-20.png)
- [전체 테스트 결과](traffic-validation/results.json)
- [게임 실행 방법](../cities_do/README.md)
- [차량 제작 원본·재현 방법](../assets/vehicle-fleet/README.md)
- [설치된 스킬](../.agents/skills/)
- [최초 복구 조사](recovery/RECOVERY_KO.md)
- [이전 채팅에서 받은 인계문 원문](recovery/ORIGINAL_HANDOFF_KO.txt)

## 전체 파일과 백업

[GitHub 다운로드 폴더](https://github.com/rlatkdeh0001-creator/simcity/tree/main/downloads)

| 파일 | 내용 |
|---|---|
| [cities-do-traffic-ai.zip](https://raw.githubusercontent.com/rlatkdeh0001-creator/simcity/main/downloads/cities-do-traffic-ai.zip) | **최신 권장 다운로드**. 게임·주행 AI·차량·Blender 원본·스킬·라이선스·참고 소스·검증 기록 |
| [cities-do-vehicles-20.zip](../downloads/cities-do-vehicles-20.zip) | 도로 주행 AI 연결 전 차량 20종 제작 완료 시점의 프로젝트 |
| [cities-do-recovered-checkout.zip](../downloads/cities-do-recovered-checkout.zip) | 차량 재제작 전 최초 확보한 체크아웃과 복구 조사 |
| [simcity-before-recovery.tar.gz](../downloads/simcity-before-recovery.tar.gz) | 복구 작업을 시작하기 전의 파일 백업. .git과 .godot 제외 |
| [simcity-history.bundle](../downloads/simcity-history.bundle) | 최초 복구 조사 시점의 Git 참조·이력 백업 |
| [SHA256SUMS.txt](../downloads/SHA256SUMS.txt) | 모든 아카이브의 SHA-256 |
| [ARCHIVES.json](../downloads/ARCHIVES.json) | 파일 크기·해시와 최신 패키지의 소스 커밋 |

나머지 첨부 파일도 downloads 폴더에서 받을 수 있다.
ZIP은 Godot 프로젝트 원본이며 운영체제별 독립 실행 바이너리는 아니다.
Git 이력이 필요한 경우 저장소를 clone한다. 과거 최초 백업의 Git 이력은 bundle에도 있다.
이전 환경에서 미커밋됐고 현재 회수하지 못한 파일은 백업에 포함됐다고 간주하지 않는다.

## 재현·확인

```sh
git clone https://github.com/rlatkdeh0001-creator/simcity.git
cd simcity
godot --headless --editor --import --path cities_do --quit
godot --headless --path cities_do --script tests/test_traffic.gd
godot --path cities_do traffic_demo.tscn
```

문서 속 `/workspace`와 `/tmp`는 제작 당시 실행 환경의 경로다.
완료된 결과물을 받는 데 해당 경로에 접근할 필요는 없다. 위 GitHub 파일과 다운로드 폴더를 사용한다.
