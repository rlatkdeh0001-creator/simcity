# 미업로드 원본 30종과 과거 작업 보존

2026-11-11 KST. 사용자가 누락 목록 보고 후 실제 업로드가 빠졌음을 지적해, 미업로드 원본과 과거 버전을 함께 보존한다.
현재 게임 소스·카탈로그·운영·가격을 변경하지 않는다. 원본/역사 자료 업로드와 게임 통합은 별개다.

| 분류 | 이름 | 원본 |
|---|---|---|
| 상업 | AUREL 백화점 | [모델·시안·규격](../../assets/commercial-study/large-4x4-department-07) |
| 상업 | NOVA 오피스 타워 | [모델·시안·규격](../../assets/commercial-study/large-4x4-office-nova-08) |
| 상업 | AUREL GRAND 대형 백화점 | [모델·시안·규격](../../assets/commercial-study/large-8x8-grand-department-09) |
| 상업 | NOVA CENTRAL 트윈 복합타워 | [모델·시안·규격](../../assets/commercial-study/large-8x8-twin-central-10) |
| 상업 | 벽돌형 식당·서비스 상가 | [모델·시안·규격](../../assets/commercial-study/medium-4x4-brick-services-06) |
| 상업 | 업무·상가 복합빌딩 | [모델·시안·규격](../../assets/commercial-study/medium-4x4-office-retail-05) |
| 상업 | 자동차 전시장 AUTO | [모델·시안·규격](../../assets/commercial-study/small-2x2-auto-02) |
| 상업 | 동네 MART | [모델·시안·규격](../../assets/commercial-study/small-2x2-mart-01) |
| 상업 | 식당·카페 복합상가 | [모델·시안·규격](../../assets/commercial-study/small-4x4-cafe-diner-04) |
| 상업 | 동네 슈퍼마켓 | [모델·시안·규격](../../assets/commercial-study/small-4x4-market-03) |
| 공업 | 화학 생산시설 | [모델·시안·규격](../../assets/industrial-study/large-4x4-chemical-06) |
| 공업 | 제약 생산시설 | [모델·시안·규격](../../assets/industrial-study/large-4x4-pharma-05) |
| 공업 | 자동차 조립공장 | [모델·시안·규격](../../assets/industrial-study/large-8x8-auto-assembly-07) |
| 공업 | 대규모 화학 플랜트 | [모델·시안·규격](../../assets/industrial-study/large-8x8-chemical-complex-08) |
| 공업 | 전자부품 공장 | [모델·시안·규격](../../assets/industrial-study/medium-4x4-circuitworks-04) |
| 공업 | 정밀기계 공장 | [모델·시안·규격](../../assets/industrial-study/medium-4x4-precision-03) |
| 공업 | 식품가공 작업장 | [모델·시안·규격](../../assets/industrial-study/small-2x2-foodworks-02) |
| 공업 | 금속가공 작업장 | [모델·시안·규격](../../assets/industrial-study/small-2x2-metalworks-01) |
| 발전 | 석탄발전소 | [모델·시안·규격](../../assets/power-study/coal) |
| 발전 | 수력발전댐 | [모델·시안·규격](../../assets/power-study/hydro) |
| 발전 | 원자력발전소 | [모델·시안·규격](../../assets/power-study/nuclear) |
| 발전 | 석유발전소 | [모델·시안·규격](../../assets/power-study/oil) |
| 발전 | 태양광발전소 | [모델·시안·규격](../../assets/power-study/solar) |
| 발전 | 풍력발전소 | [모델·시안·규격](../../assets/power-study/wind) |
| 상하수도 | 취수장 | [모델·시안·규격](../../assets/water-study/intake) |
| 상하수도 | 하수장 | [모델·시안·규격](../../assets/water-study/sewage-outfall) |
| 상하수도 | 하수처리장 | [모델·시안·규격](../../assets/water-study/sewage-treatment) |
| 상하수도 | 급수탑 | [모델·시안·규격](../../assets/water-study/water-tower) |
| 쓰레기 | 쓰레기 소각장 | [모델·시안·규격](../../assets/waste-study/incinerator) |
| 쓰레기 | 재활용센터 | [모델·시안·규격](../../assets/waste-study/recycling-center) |

## 보존 범위

- assets/*-study: 상업10·공업8·발전6·상하수도4·쓰레기2, 편집 가능한 Blender 원본과 PNG60장, metadata·제작 스크립트·원래 라이선스.
- [과거 작업 보존](../../archive/cloud-work-2026-10-31): 최신 main에 동일한 바이트가 없는 이전 코드·시안·문서·화면. 도로/나들목/54종 도시 전시와 당시 카탈로그/규칙 변경본 포함.
- 기존 파일은 덮어쓰지 않았고 원본 바이트/SHA-256을 확인했다. 실제 파일별 경로·원본 Git blob·해시는 preserved-files.json.
- 최신 코드로 바뀐 이전 버전을 현행 게임에 덮어쓰지 않는다. archive는 일부 옛 버전의 참고 자료이며 독립 실행/최신 코드 호환을 보장하지 않는다.
- 원본 버스·택시 모델/개별 프리뷰는 기존 제외 결정을 유지했다. 전체 백업과 stash는 삭제하지 않았다.

## 이번 검증

- Blender에서 원본30개를 읽기 전용으로 열어 메시 존재/유한 좌표를 확인: source-validation.json, source-check.log.
- Pillow로 시안60장 디코딩/알파/비어 있지 않은 내용을 확인: image-validation.json.
- 새 모델 생성/새 렌더/게임 코드 변경/운영·가격 적용은 하지 않았다. 게임 전체 회귀를 재실행한 결과로 주장하지 않는다.
- 원본 metadata의 과거 pending-user-review 값은 그대로 보존했다. 업로드는 새 승인/성능 검증을 뜻하지 않는다.
