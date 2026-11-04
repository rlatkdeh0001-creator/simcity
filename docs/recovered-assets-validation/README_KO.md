# 복구된 교육·의료 및 차량 원본 등록 · 2026-11-04

## 사용자 결정과 결과

GitHub main e4a8c1d의 기존 차량 23종은 유지한다. 이 채팅의 원본 버스·택시는 제외하고
원본 시민차 10종·산업차 8종을 `original-<기존 ID>`로 추가했다. 총 41종이다.
기존 카탈로그 23개 항목과 방향 캘리브레이션 23개 항목은 값까지 그대로 유지했다.
기존 GLB 23·Blender 23·방향 PNG 184, 총 230개 파일의 SHA-256 일치를 검증했다.
신규 18개 GLB도 원본 버퍼를 그대로 복사했고 Blender 원본/spec과 새 등록 매핑을 분리했다.
기존 파일은 동일 ID로 덮어쓰지 않는다. 최종 사용자 요청으로 이 통합을 커밋하고 main에 푸시한다. 강제 푸시는 사용하지 않는다.

복구된 교육 4종(초·고 4×4, 전문대·대학 8×8), 의료 3종(진료소 4×4, 병원 6×6,
대형병원 8×8)을 원본 Blender에서 GLB로 내보내 services catalog와 실제 전시/검사 창에 연결했다.
보건 탭에 대형병원을 추가하고 학교·의료의 준비 중 버튼을 실제 애셋 열기로 연결했다.
현재 공공시설과 같은 애셋 통합 범위다. 도시 배치·진료/교육 운영·통학·서비스 출동·시설 요금은
아직 연결하지 않았다. 이전 시안 등록을 운영 시뮬레이션 완성으로 보고하지 않는다.

## 보존과 작업 기준

기존 작업은 `/workspace/simcity-recovered-before-integration-20261104.tar.gz`에 .git 포함 전체
백업하고 핵심 파일 8개의 원본/압축 내부 SHA-256을 확인했다. 별도로 Git stash
`Recovered cloud work before approved asset integration 2026-11-04`에도 보존했다.
그 뒤 기존 체크아웃을 최신 main으로 fast-forward했다. 예전의 미완성 코드를 최신 게임 위에
덮어쓰지 않았다. 이 작업에 포함하지 않은 과거 도로/건물 작업도 백업과 stash에 남아 있다.
새 worktree·원격 강제 갱신·삭제·초기화는 수행하지 않았다. 최종 사용자 요청으로 승인된 통합만 커밋·푸시한다.

## 적용과 재현

- 차량 원본: assets/original-vehicle-fleet, 별도 registration.json에서 현재 ID 매핑.
- 추가 모델/이미지: cities_do/assets/vehicles/original-*.glb, sprites/original-*.
- 원본 차량 144방향 프레임은 현재 규약(000=정면, +각도=차량 왼쪽 시점), 430×245 RGBA,
  30도 고도와 실제 ppm으로 Godot에서 새로 렌더했다. 예전 고정 카메라 프레임을 잘못 재사용하지 않았다.
- GLB의 바퀴 조향/회전과 트레일러·덤프·믹서 피벗을 그대로 유지. 회수본 피벗 이름 차이는
  explicit rig_schema로 검증한다. 시민차 주행 후보는 기존 고정 10칸 대신 전체 civilian 목록이다.
- tools/build_vehicle_fleet.py의 기존 전체 빌드도 별도 원본 등록을 보존하도록 했다.
  이번에 기존 23종 재제작은 실행하지 않았다.
- 교육·의료 원본: assets/{education,medical}-study. 원본 .blend를 재저장하지 않았다.
  tools/export_recovered_services.py가 GLB/PNG/카탈로그와 등록 상태를 재현한다.
- 차량 원본 촬영: `DISPLAY=:97 godot --path cities_do --audio-driver Dummy --rendering-method gl_compatibility --script tools/capture_original_vehicle_sprites.gd`.
  이어 `python tools/register_original_vehicle_sprites.py`. 기존 23개 ppm의 JSON 정밀도도 보존한다.
- 실제 전시: education_medical_showcase.tscn, 기존 vehicle_showcase.tscn에서 41종 스크롤.

## 이번 검증

Godot 4.6.3 재임포트 및 실제 GL Compatibility/Mesa 렌더링을 사용했다.
results.json의 11개 테스트 스크립트 모두 통과. 차량 308/308, 신규 회수 애셋 38/38,
교통 43/43, 보건/교육 UI를 포함한 하단 UI 36/36, 기존 서비스 9/9.
구조 감사: Blender41 / GLB41 / 8방향 PNG328. preserved-vehicles.json에 230개 보존 해시.
교육·의료 7종의 실제 화면은 education-medical-7.png. 종료 코드와 SCRIPT ERROR/ERROR/FAIL도 검사했다.

초기 신규 검사에서 타입 추론 실패와 headless 팝업의 화면 크기 문제가 있었다.
타입을 명시하고 테스트에 실제 current_scene/임베디드 창/화면 크기를 설정해 재검증했다.
초기 오류 기록은 test_recovered_assets-initial.log. 기존 테스트를 약하게 만들거나 오류를 무시하지 않았다.
초기 Godot manifest 직렬화에서 기존 float의 끝자리 정밀도가 바뀌는 것을 발견해 기존 항목을
원본에서 복구하고 새 캘리브레이션만 Python으로 병합하도록 수정했다. 보존 검사가 다시 통과했다.

실차 IoU·문 개폐·충돌 변형·수천 대 차량 성능·시설 서비스 운영·도시 배치는 이번 검증 대상이 아니다.

## 경제·출처

새 외형 등록은 비용/서비스 정원 승인이 아니다. 기존 PRICE_PROPOSALS_KO.md와
CAPACITY_PROPOSALS_KO.md의 교육·의료 7종 제안을 유지하며 실제 차감을 추가하지 않았다.
원본 민간/산업 차량의 소유·구매·유지비는 기존 동종 미정/제안 상태를 그대로 따른다.
원본 차량 기법은 zstack vehicle, 74f7786e9931b9ced858a0e2df880f23e4c2430e, MIT.
이번에는 원본 모델 회수/엔진 등록/방향 렌더링만 수행했고 전체 upstream 제작 게이트를 재실행하지 않았다.
Blender 교육/의료 직접 제작과 DejaVu 글꼴 출처는 원본 폴더 FONT_LICENSE/README를 보존했다.
