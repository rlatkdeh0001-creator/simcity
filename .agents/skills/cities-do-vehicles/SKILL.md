---
name: cities-do-vehicles
description: Create and validate stylized CITIES_DO vehicle fleets using the pinned zstack vehicle helpers and local Blender, without Claude login.
---

# CITIES_DO 차량 제작

2026-11-01 재작성본이다. 이전 환경의 적응 스킬 파일을 회수한 것이 아니다.
원본 `../vehicle/SKILL.md`, `../vehicle/reference/rig-contract.md`와
`../vehicle/UPSTREAM.json`을 읽고 적용한다. 원본은 그대로 보존한다.

사용자 요청은 실사 차량 복제가 아닌 도시 게임용 로우폴리 20종이다.
원본의 실사 레퍼런스 생성·카메라 최적화·IoU·충돌 변형·문 개폐 전체 파이프라인을
완료했다고 주장하지 않는다. 대신 common.py의 empty, parent_keep, rounded_box,
revolve, tri_count를 실제 호출하고 아래 게임 규약으로 별도 제작한다.

- 미터 단위. Blender -Y 전방, +X 왼쪽, +Z 위; GLB +Z 전방, +X 왼쪽, +Y 위.
- 바퀴 접지는 0. 운전석/운전대 +X, 버스 승객 문 -X. 우측통행.
- 원본 사진/브랜드 로고를 복제하지 않는 가상 차량. 치수는 게임용 설계값으로 명시.
- 바퀴 조향/회전 피벗을 분리한다. 트레일러 연결·덤프 적재함·믹서 회전 피벗을 제공한다.
- 차종별 실루엣·유리·등화·산업 적재 장치를 구별한다. 기존 도시 색감과 부드러운 단색 재질을 쓴다.
- 생성기는 `tools/build_vehicle_fleet.py`, 원본/사양은 `assets/vehicle-fleet/<id>/`에 둔다.
- GLB/catalog/sprites는 `cities_do/assets/vehicles/`에 둔다. 원본 MIT 라이선스를 배포 경로에도 유지한다.
- Godot 전시는 실제 GLB를 사용한다. 도로 주행 AI와 대량 차량 성능은 별도 작업이다.
- Blender 빌드 결과와 GLB 재임포트, Godot 테스트, 투명 PNG 검사, 실제 캡처를 구분한다.
- 실패를 숨기거나 검증 임계치를 완화하지 않는다. 테스트 전후 결과와 남은 한계를 문서화한다.

재현 명령 및 모델별 사양은 `assets/vehicle-fleet/README.md`에 유지한다.

새 차량 애셋에도 doth 가격/유지비 제안과 근거를 함께 제시한다. 민간 소유인지 공공
구매인지 미정이면 그 전제를 먼저 명시하고 가격을 승인된 차감 규칙으로 취급하지 않는다.
`docs/PRICE_PROPOSALS_KO.md`와 AGENTS.md의 가격 제안 지침을 따른다.
