# CITIES_DO · 주거 건물 8종 시안

| 번호 | 분류 | 부지 | 시안 | 지상 층수 |
|---|---|---|---|---|
| 01 | 소형 주거 | 2×2 | 단층 전원주택 | 1 |
| 02 | 소형 주거 | 2×2 | 2층 타운하우스 | 2 |
| 03 | 소형 주거 | 4×4 | 정원형 단독주택 | 2 |
| 04 | 소형 주거 | 4×4 | 안뜰형 연립주택 | 3 |
| 05 | 대형 주거 | 4×4 | 발코니 아파트 | 8 |
| 06 | 대형 주거 | 4×4 | 코너 주거타워 | 10 |
| 07 | 대형 주거 | 8×8 | L자형 주거 아파트 | 14 |
| 08 | 대형 주거 | 8×8 | 계단형 주거타워 | 18 |

1칸=4m. 따라서 부지는 각각 8×8m / 16×16m / 32×32m입니다.
층수는 비교용 디자인 선택이며 부지 크기와 건물 분류는 독립 메타데이터입니다.
기존 중형 맨션은 변경하지 않았고, 이 8종은 아직 게임 카탈로그에 자동 등록하지 않았습니다.

## 제작·출력

`game-art`의 스타일·스케일 일관성과 `blender-kiln`의 로컬 제작·원본 보존·
반대 시점 검수 원칙을 참고한 자체 Blender Python 제작입니다. 원본 kiln 툴킷이나
Claude를 실행하지 않았고 외부 생성 API·유료 애셋·다운로드한 텍스처를 쓰지 않았습니다.

- comparison.png / comparison.html: 8종 비교
- 각 asset ID 폴더: building.png, reverse-review.png, building.blend, metadata.json
- 각 PNG: 900×1100 RGBA, 투명 배경
- 카메라: 고도 30도, 2:1 투영. 조명 방향·색상·세계 단위 동일.
- 분류/부지별 **같은 쌍 안에서는 같은 카메라 배율**. 행/열 사이에는 작은 건물과
  타워를 보기 쉽게 확대율을 달리했으므로 전체 비교판의 화면 크기가 실제 크기는 아닙니다.
- roof terrace, attic roof, mechanical housing는 occupied floors에 포함하지 않습니다.

## 재생성

저장소 루트에서 예를 들어:

```sh
blender --background --factory-startup --python-exit-code 1 \
  --python assets/residential-eight/build_residentials.py -- --id small-2x2-a
```

다른 ID: small-2x2-b, small-4x4-a, small-4x4-b, large-4x4-a,
large-4x4-b, large-8x8-a, large-8x8-b. 한 명령은 한 건물만 생성합니다.
기존 생성 파일을 갱신하므로 직접 수정한 원본은 먼저 별도 이름으로 보관하세요.
제한된 클라우드에서는 쓰기 가능한 XDG_CONFIG_HOME / XDG_CACHE_HOME을 지정합니다.

Blender 4.3.2 CPU Cycles를 사용합니다. 비교판 캡처는 Playwright/Chromium입니다.
실내 평면, 구조·소방 검토, 충돌 메시, LOD, 최종 저해상도 픽셀 정리, Godot 통합은
포함하지 않는 외관 시안입니다. 유리 재질은 게임 가독성을 위한 불투명 스타일입니다.

## 이후 게임 전시 연결

이 8종은 현재 Godot의 `residential_showcase.tscn` 전시 장면에서 기존 맨션 2종과
함께 볼 수 있습니다. 실제 런타임 카탈로그와 PNG 사본을 연결했으며 자동 성장에
등장시키는 밸런스는 아직 적용하지 않았습니다(`growth_enabled: false`). 이 폴더의
생성 시점 메타데이터/manifest 상태는 제작 이력으로 보존했습니다.
