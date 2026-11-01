# CITIES_DO 차량 20종 · 2026-11-01 재제작

고정 커밋의 vehicle 스킬을 재설치하고 차량 20종을 새로 제작했다.
이전 환경의 차량·생성기·게임용 스킬을 회수한 결과가 아니다.

[실제 Godot 전시 화면](screenshots/vehicle-fleet-20.png) ·
[Blender 렌더 비교](screenshots/vehicle-fleet-blender-review.png) ·
[원본과 재현 명령](../assets/vehicle-fleet/README.md) ·
[스킬 출처 조사](design/VEHICLE_SKILL_RESEARCH_KO.md)

## 생성·적용

- 버스 1종, 택시 1종, 시민 차량 10종, 산업 차량 8종.
- Blender 20개, spec.json 20개, GLB 20개, 8방향 투명 PNG 160개.
- 모델당 1,724~7,144 삼각형. 실측 단위는 미터이며 치수 자체는 가상 설계값이다.
- 운전석은 왼쪽, 버스 승객 문은 오른쪽. 조향·바퀴 회전·트레일러·덤프·믹서 피벗 포함.
- 게임의 **차량 20종 전시** 버튼 또는 `godot --path cities_do vehicle_showcase.tscn`으로 실행.
- 실제 GLB별 3D 뷰포트, 5열×4행(넓은 화면), 자동 확대/같은 축척 비교,
  차체 회전·바퀴 회전, 건설 화면 복귀를 제공한다. 좁은 화면에서는 열 수를 줄인다.
- 전시를 나갔다 돌아와도 기존 도시와 카메라를 보존한다.

## 검증

Blender 4.3.2, Godot 4.6.3에서 실행했다.

- `verify_vehicle_fleet.py`: Blender/GLB/PNG 기대 수량·구조 검사 통과.
- 160개 PNG 전부 430×245 RGBA, 투명 배경/가시 픽셀 존재, 가장자리 잘림 없음.
- `verify_vehicle_sources.py`: 20개 .blend 실제 열기, 유한 좌표, 삼각형 수,
  바퀴 계층, 왼쪽 운전석, 외부 이미지 의존성 없음 통과.
- Godot `test_vehicles.gd`: **156/156** 통과. GLB 실제 임포트, 축·접지·미터 단위,
  피벗, 차종별 수량, 버스 오른쪽 문, 버튼 진입·복귀와 상태 보존을 검사했다.
- 기존 도시·건물·구획·도로·주거 전시·UI 테스트 6종을 다시 실행했다.
  로그와 결과는 `docs/vehicle-validation/`에 보존한다.
- 실제 OpenGL 렌더러로 2400×1800 Godot 화면을 캡처하고 20개 모델을 시각 확인했다.
  Blender 합성판과 Godot 직접 캡처는 파일을 구분했다.
- 원본 스킬 파일·라이선스는 UPSTREAM.json의 해시와 일치함을 확인했다.

초기 차량 테스트 1건은 버스 문의 변환 원점으로 좌우를 판단해 실패했다.
생성 메시에는 위치가 정점 좌표로 들어가므로 실제 메시 경계 중심을 검사하도록
수정했다. 문의 실제 위치나 좌우 판정 조건은 바꾸지 않았다.
시각 검수에서 버스 앞면의 겹치는 색 띠를 발견해 표면 간격을 수정하고 다시 생성했다.

## 한계

도로 주행 AI, 차선 그래프, 교통 시뮬레이션은 연결하지 않았다.
실사 레퍼런스 IoU, 개폐 가능한 승객 문, 충돌 변형, LOD, 대량 차량 프레임 성능은
검증하지 않았다. 피벗 제공이 모든 동작·충돌 검사 완료를 뜻하지 않는다.
기존 Road Generator와 미회수 후속 건물 애셋의 복구는 별도 미완료다.

## 라이선스·배포

zstack/vehicle 고정 커밋 `74f7786e9931b9ced858a0e2df880f23e4c2430e`, MIT,
Copyright 2026 duolahypercho. 원본·하위 코드·참고자료·템플릿·라이선스를 보존했다.
MIT 사본과 THIRD_PARTY_NOTICES.md는 편집 원본과 게임 배포 폴더 양쪽에 포함했다.

`/workspace/cities-do-vehicles-20.zip`은 게임·애셋·제작 소스·스킬·검증 기록을 담는다.
`.git`, `.godot`, node_modules, Python 캐시, Blender 자동 백업은 제외한다.
이 ZIP은 Godot 프로젝트 원본이며 운영체제별 독립 실행 바이너리는 아니다.
환경 설정을 변경하거나 환경을 게시한 작업은 아니다.
