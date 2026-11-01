# 공원 4종·주차 시설 4종과 평면 주차장 결합

2026-11-01 KST. 기존 도시 팔레트를 사용한 자체 Blender 제작이다.

[8종 실제 Godot 화면](screenshots/facilities-8.png) · [결합된 주차장](screenshots/parking-merged.png) ·
[Blender 비교판](screenshots/facilities-blender-review.png) · [스킬 조사](design/MODULAR_FACILITY_RESEARCH_KO.md)

| ID | 시설 | 칸 | 실제 부지 | 주차면/층 |
|---|---|---|---|---|
| park-pocket-2x2 | 나무·벤치 쉼터 공원 | 2×2 | 8×8m | - |
| park-garden-2x2 | 꽃밭·퍼걸러 정원 | 2×2 | 8×8m | - |
| park-plaza-4x4 | 분수 광장 공원 | 4×4 | 16×16m | - |
| park-play-4x4 | 놀이기구·그네 공원 | 4×4 | 16×16m | - |
| parking-small-2x4 | 소형 평면 주차장 | 2×4 | 8×16m | 4면 |
| parking-medium-4x4 | 중형 평면 주차장 | 4×4 | 16×16m | 8면 |
| parking-large-4x8 | 대형 평면 주차장 | 4×8 | 16×32m | 16면 |
| parking-tower-4x4-4f | 4층 주차타워 | 4×4 | 16×16m | 4개 주차층·16면 |

주차면 수는 연결 통로를 넉넉히 둔 이번 모델의 설계값이다. 타워 지붕은 별도 주차층으로
세지 않는다. 외형 램프·기둥·층 슬래브·계단실·P 표식을 만들었으나 실제 차량의 램프
주행/회전 반경/시설 법규를 검증한 기능은 아니다.

## 실행과 공유 방식

건설 화면의 **공원·주차 시설 전시** 또는 아래 명령으로 실제 모델을 볼 수 있다.

```sh
godot --path cities_do facilities_showcase.tscn
```

**주차장 합치기**에서 소형·중형·대형의 L자 연결 예시와 독립 타워가 나온다.
**연결부 철거 / 복원**으로 분리/재결합을 시험한다. 추가 버튼으로 같은 격자에
새 평면 주차장을 붙일 수 있다. 원래 도시와 카메라는 돌아왔을 때 복원한다.

평면 주차장만 2칸 단위 격자에 배치한다. 양의 길이를 가진 변을 공유하면 한 단지로 묶고,
모서리 접촉만으로는 묶지 않는다. 내부 경계석을 제거하고 같은 규격의 3m 통로와
2.5×5m 주차면을 이어 총 수용량을 공유한다. 겹침·경계 이탈·잘못된 크기는 거부한다.
구멍이 있는 단지는 구멍을 아스팔트로 메우지 않고 내부 외곽선을 유지한다.
철거 후 연결 요소를 다시 계산하므로 연결부 제거 시 단지가 분리될 수 있다.

각 연결 단지는 **한 MeshInstance3D의 한 ArrayMesh**로 재생성된다. 원래 부지 ID는
보존하므로 개별 철거가 가능하다. 세 재질 표면(아스팔트/경계석/표시선)은 남아 있어
한 메시라는 사실이 한 GPU draw call이나 영구적인 단일 건물 ID를 뜻하지는 않는다.
공원·주차타워는 결합 대상이 아니다.

## 제작 원본·규약

- `assets/facilities/<id>/facility.blend`, `preview.png`, `spec.json`: 편집 원본·투명 이미지·사양.
- `cities_do/assets/facilities/`: GLB·PNG·카탈로그·Python 기준 결합 레시피.
- `tools/facility_layout.py`: 렌더링과 독립적인 결정적 모듈 레이아웃.
- `tools/build_facilities.py`: Blender 생성/원본 저장/단일 메시 GLB/이미지 출력.
- `cities_do/core/modular_parking.gd`: 배치·결합·철거·결합 메시 생성.
- `.agents/skills/cities-do-modular-facilities/SKILL.md`: 이번에 작성한 재사용 지침.

공개 procedural-gen/godot-tilemap 지침을 읽었으나 주차장 통합 모델을 제공하는
전용 스킬은 검색 범위에서 확인하지 못했다. 원본을 설치했다고 주장하지 않고,
전용 지침을 자체 작성했다. 기존 skill-creator는 작성 원칙만 참고했으며
Claude CLI 자동 평가/에이전트 비교/트리거 최적화는 실행하지 않았다.

실제 도형 제작은 기존 zstack vehicle common 헬퍼를 재사용했다. MIT 원문과 출처를
편집 원본·게임 애셋 폴더에 모두 포함했다. 새 모델은 다운로드한 애셋이나 외부 생성
API 없이 제작했다. 고정 출처와 검색 한계는 조사 문서에 기록했다.

## 검증과 현재 적용 범위

Blender 4.3.2, Godot 4.6.3. 시설 검사 **69/69**, 기존 검사와 합쳐 **9종**을 실행했다.
현재 결과 파일은 `docs/facilities-validation/`에 있다. Blender 실제 원본 열기·유한 좌표·
수평 바닥 축·타워의 정확히 4개 주차층은 `assets/facilities/source-validation.json`에 있다.
투명 PNG 8장과 가장자리 잘림도 검사했다. 실제 Godot 화면을 별도 캡처·시각 검수했다.

초기 시각 검사에서 Blender와 Godot의 높이/깊이 축 변환 및 파트 회전 피벗 문제를
발견해 생성기를 수정하고 다시 생성했다. 두 언어의 경계 레시피 비교는 JSON 숫자를
정수로 정규화해 좌표·방향을 비교한다. 레이아웃과 메시 레시피는 직사각형·L자·구멍
형상에서 Python 기준 결과와 일치한다.

이번 적용은 **원본 애셋·런타임 결합 로직·전시/결합 실험실**이다. 일반 도시 건설
도구에 공원/직사각형 시설 배치, 도로 접면·입출구 권한, 주차 수요·요금·교통 AI를
연결한 것은 아니다. 내부 통로 기하가 이어져도 실제 자동차 주차 경로 검증을
대체하지 않는다. 2칸 격자·직각 회전 부지만 지원하고 임의 각도나 서로 다른 고도는
미지원이다. 주차장 추가 시 단지 메시를 다시 만들며 거대한 단지 성능은 미검증이다.

## 재현

```sh
blender -b --factory-startup -t 2 -P tools/build_facilities.py
blender -b --factory-startup -t 2 -P tools/verify_facility_sources.py
godot --headless --editor --import --path cities_do --quit
godot --headless --path cities_do --script tests/test_facilities.gd
# 실제 그래픽 디스플레이 필요
godot --path cities_do --resolution 2000x1100 facilities_showcase.tscn -- \
  --capture-facilities=/absolute/path/facilities.png
# 결합 모드 캡처에는 --facilities-merged 추가
```

최신 파일은 Git main에 보존한다. 기존 전체 ZIP은 이전 작업의 스냅샷이므로 새 시설이
포함됐다고 간주하지 않는다. 이번 제작 묶음은 downloads/cities-do-parks-parking-8.zip에서
제공하며, 게임 실행은 저장소 전체를 사용한다.
