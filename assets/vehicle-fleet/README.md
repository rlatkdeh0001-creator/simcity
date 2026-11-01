# CITIES_DO 차량 20종 · 재제작 원본

2026-11-01에 새로 제작한 가상 로우폴리 차량이다. 이전 환경의 모델을 회수한 것이 아니다.
버스 1, 택시 1, 시민차 10, 산업차 8을 포함한다. 각 폴더의 `vehicle.blend`는
미터 단위 편집 원본이고 `spec.json`은 치수·분류·삼각형 수·제작 범위를 기록한다.
치수는 가상 차량 설계값이며 실차 제조사 제원 검증을 주장하지 않는다.
사이드미러·등화·루프 부속은 명목 차체 치수보다 조금 돌출될 수 있다.

## 재현

저장소 루트에서 Blender 4.3.2로 실행했다. 원본 vehicle 스킬은 Blender 4.2+를
요구한다. Claude CLI, Blender MCP, 외부 생성 API는 필요 없다.

```sh
blender -b --factory-startup -t 2 -P tools/build_vehicle_fleet.py -- --render
blender -b --factory-startup -t 2 -P tools/verify_vehicle_sources.py
python3 tools/verify_vehicle_fleet.py --output docs/recovery/vehicles-rebuilt.json
godot --headless --editor --path cities_do --import --quit
godot --headless --path cities_do --script tests/test_vehicles.gd
```

`--render`를 생략하면 모델만 만든다. `--only car-hatch-01 --render`로 한 차종만
다시 만들 수도 있지만, 단일 제작은 전체 catalog/render_manifest를 갱신하지 않는다.
최종 배포 전 전체 명령으로 다시 생성한다. PNG는 Cycles CPU 24샘플이며 이 환경의
Blender에는 OpenImageDenoise가 없어 디노이즈를 사용하지 않는다.

## 출력과 규약

- `cities_do/assets/vehicles/<id>.glb`: 게임 모델과 바퀴 피벗 계층.
- `cities_do/assets/vehicles/catalog.json`: 20종 카탈로그.
- `cities_do/assets/vehicles/sprites/<id>/000.png` ~ `315.png`: 45도 간격 8장.
- `render_manifest.json`: 430×245 RGBA, 카메라 고도 30도, 차종별 pixels_per_metre.
- 000도는 정면이며 카메라가 차량 왼쪽으로 이동하면서 각도가 증가한다.
- Blender -Y 전방/+X 왼쪽/+Z 위 → GLB +Z 전방/+X 왼쪽/+Y 위.
- `Wheel_FL` 등의 조향 피벗 아래 `Wheel_FL_Spin` 회전 피벗. Godot 회전 축은 Y/X.
- `Seat_FL`은 +X. 버스 앞·중간 승객 문은 -X.
- 트레일러 `TrailerHitch`, 덤프 `DumpBedPivot`, 믹서 `MixerSpin` 피벗 포함.

## 출처와 범위

원본 zstack vehicle 스킬의 `common.py`에서 empty, parent_keep, rounded_box,
revolve, tube, tri_count 등을 실제로 사용한다. 고정 SHA와 파일 해시는
`.agents/skills/vehicle/UPSTREAM.json`에 있다. MIT 원문은 이 폴더와 게임 배포
폴더에 복사했다. `THIRD_PARTY_NOTICES.md`도 함께 유지한다.

이는 원본의 실사 차량 전체 파이프라인 통과 결과가 아니다.
실사 레퍼런스 IoU, 문 개폐, 충돌 변형, 도로 주행 AI, LOD, 대량 차량 성능은 미검증이다.
이전 환경의 90/90 검사는 이번 결과에 적용하지 않는다.
