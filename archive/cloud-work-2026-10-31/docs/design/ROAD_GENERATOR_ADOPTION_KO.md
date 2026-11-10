# Godot Road Generator 도입 및 전후 비교

## 실제 설치

- 원본: https://github.com/TheDuckCow/godot-road-generator
- 버전: 0.9.5
- 고정 커밋: `7cbefde04e57a84499c5d8ba636c9cb4fd7d22c0`
- 경로: `cities_do/addons/road-generator`
- 라이선스: MIT, 원문 LICENSE와 UPSTREAM.json 포함.
- `project.godot`의 editor_plugins에서 활성화. 별도 Claude 로그인·API 키 없음.
- Godot 4.6.3에서 실제 편집기 가져오기·종료와 런타임 메시 생성을 확인함.

## 비교 방법

메인 화면 → **도로 플러그인 · 도입 전후 비교**.
왼쪽은 현재 게임의 기존 평면 도로 렌더러, 오른쪽은 설치한 플러그인의
RoadManager/RoadContainer/RoadPoint로 만든 실제 3D 도로다.
양쪽은 같은 4차로 나들목 모델과 평면 축척(18px/칸)을 사용한다.
오른쪽 평면/입체 전환 버튼으로 교량과 경사를 확인한다.

- 평면 캡처: `docs/screenshots/road-generator-before-after.png`
- 입체 캡처: `docs/screenshots/road-generator-isometric.png`
- 장면: `cities_do/road_generator_comparison.tscn`
- 어댑터: `cities_do/core/road_generator_adapter.gd`

## 이번 적용

원본 게임 단위 1칸=4m를 플러그인의 미터 단위로 변환한다.
일반도로 높이는 0m, 고속도로는 8m, 램프는 둘 사이 높이를 보간한다.
기존 도로망의 side attachment를 읽어 램프 시작과 끝에 약 20m 연결 구간을 추가한다.
램프는 해당 방향의 가장 바깥 차로 중심으로 이어지고, 접선은 본선과 나란하다.
플러그인이 점 사이 곡선·가변 단면·표면·아랫면·차로 경로를 생성한다.
중앙분리대와 예시 교각은 CITIES_DO 어댑터가 추가한 요소다.
기본 on/off-ramp 프리팹도 설치되어 있으나 이번 나들목은 런타임 생성 API로 만들었다.

4차로 예시의 실제 결과: RoadContainer 6개, RoadSegment/메시 26개,
차로 경로 32개, 기본 생성 정점 14,710개, 측면 연결 구간 8개.
중복 면 절단 후 재삼각화한 최종 시각 메시의 정점은 15,962개다.

현재 적용 범위는 **게임 내 비교 장면**이다. 일반 건설 화면의 기본 2D 렌더러를
전면 교체한 것은 아니다. 원본 CityModel과 제한속도(일반 80·고속 160km/h)는
변경하지 않는다. 렌더 어댑터의 차로 경로가 기존 교통 시뮬레이션과 통합되었다고
주장하지 않는다. 차량 합류·교차로 신호·정체 시뮬레이션은 후속 작업이다.

## 로컬 패치

플러그인을 활성화한 편집기 종료 시 고아 임시 MeshInstance3D와 Object가 남는 문제를
확인했다. `plugin.gd::_exit_tree`에서 `lane_divider`와 `connection_tool`을 해제하도록
최소 수정했다. 이후 실제 편집기 가져오기·종료 로그에 오류·누수 경고가 없음을 확인했다.
차로 생성 알고리즘은 수정하지 않았다.
재현 패치: `tools/patches/road-generator-0.9.5-cleanup.patch`.

## 검증

기존 9개 테스트와 `tests/test_road_generator.gd`를 실행한다.
신규 검사는 실제 상류 메시 생성, 외측 차로 연결 위치, 원본 모델 불변,
정점 유효성, 비교 장면 실행, 평면/입체 전환을 확인한다.
화면은 Xorg/OpenGL llvmpipe에서 실제 Godot로 캡처했다.


## 색감·합류부·중복 면 보정

- `core/road_surface_finisher.gd`가 실제 생성된 메시를 후처리한다.
- `shaders/road_palette.gdshader`로 기존 아스팔트 #4c5659, 흰 차선 #e8e7dc,
  노란 중앙선 #e4bd5f, 일반 보도 #c8cbc3, 고속도로 길어깨 #a8b4b6을 사용한다.
- 합류 입구마다 바깥 가장자리의 흰 실선과 길어깨 색을 끊는다.
  합류부 밖의 점선과 중앙선은 보존한다. 미세 차선은 축소 화면에서도 남도록 부드럽게 혼합한다.
- 같은 높이(차이 0.6m 이내)에서 부모 도로와 포개지는 램프 삼각형을
  부모 도로 경계로 잘라낸다. 클리핑 후 정점 높이와 UV를 보간하고 원래 면 방향을 유지한다.
- 높이가 다른 고속도로/일반도로의 입체교차는 이 규칙으로 잘라내지 않는다.
- 메시 후처리는 시각 표면을 대상으로 하며 차량 합류·교통 경로 정의는 기존 후속 범위다.
- 신규 검사는 램프-부모 도로의 같은 높이 표면에 양의 넓이의 중복이 남지 않는지,
  8개 합류부가 열리고 중앙선은 보존되는지를 검사한다.
- 최종 평면 캡처: `docs/screenshots/road-generator-clean-joins.png`
- 최종 입체 캡처: `docs/screenshots/road-generator-clean-joins-isometric.png`


## 후속: 유선형 연결을 실제 게임 규칙으로 통합

현재 새 램프는 `core/ramp_geometry.gd`의 공통 C2 경로·가변 폭·높이를 사용한다.
위에 설명한 어댑터 전용 20m 접합 경로는 새 램프에서 제거했고 모델의 공간 검사에 통합했다.
실제 게임의 2D 렌더러와 건설 미리보기도 새 규칙을 사용한다.
자세한 현재 규칙과 검증은 SMOOTH_RAMP_JOINS_KO.md 참조.
4차로 예시의 현재 플러그인 결과는 메시 66개·차로 경로 72개이며 이전 수치는 초기 도입 당시 값이다.


## 사용자 확정 통행 규칙

현재는 우측통행이며 램프 전체 길이에 흰 실선이 없다.
이전 이미지의 차로 방향과 램프 가장자리 선은 변경되었다. 현재 규칙은 TRAFFIC_RULES_KO.md 참조.
