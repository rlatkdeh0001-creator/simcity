# 실행·수정 레시피

## 실행

`python <skill>/scripts/assetkit.py list`가 정확한 전체 ID 목록이다.
`run --workspace <empty-dir> --profile NAME [--only ID]`로 실행한다.
`service-vehicles`, `traffic-signals`, `citizen`은 고정 검증기가 두 모델/100장을 함께 읽어서
`--only`를 받지 않는다. `road-study`는 `--lanes 2|4`를 사용한다.
각 독립 시험은 별도 디렉토리를 쓰면 좋다. Blender CPU 렌더여서 수 분 걸릴 수 있다.

| Profile | 중심 생성기 | 수정할 지점/검사 |
|---|---|---|
| building-growth | `tools/build_growth_14.py` | FLEET + style별 shape 함수. FLOOR=3.05m. 간판 오클루전 수정본 |
| vehicle-fleet | `tools/build_vehicle_fleet.py` | FLEET + build_* 함수. `--render`, 단일 ID 지원 |
| service-vehicles | `tools/build_service_vehicles_2.py` | garbage/ambulance 형상. `verify_service_vehicles_2.py` 미러 연결·높이·축 검사 |
| primary-grain | `tools/build_primary_industry.py` | 곡물 메인/매끈한 golden ridge 타일 |
| primary-main | `tools/build_primary_main.py` | ROWS + 업종별 shape 함수, growth/work helpers 의존 |
| primary-tiles | `tools/build_primary_work_tiles.py` | ROWS + 타일 종류/변형. 엣지 높이/4m 주기 확인 |
| traffic-signals | `tools/build_traffic_signals.py` | 동일 head/독립 lamp mesh. 단독 등 render/재질 정의 정리→검증→review 순서 |
| citizen | `tools/build_citizen_adult_pilot.py` | 부위/본/weight/Walk, 아래 전체 파이프라인 유지 |
| parking-parks | `tools/build_facilities.py` | `facility_layout.py` SPECS. 주차된 차량은 없음. 환경 ID 필터 |
| road-study | `assets/road-tile-study/build_roads.py` | 2/4차선 직선 아트 시안. 길이32m, 옛 도로폭8/16m |

vehicle-fleet의 GLB/8방향 PNG와 parking-parks의 GLB/catalog는 **출력 작업 공간의**
`cities_do/assets/`에만 생긴다. 검토 전 프로젝트에 그 디렉토리를 통째로 복사하면 안 된다.
도로 시안은 현재 게임의 차선별 폭·곡선·교차로·램프 생성기가 아니다.
전력·교육·의료·소방/경찰 건물의 모든 과거 생성기/시안도 이 묶음에 있는 것은 아니다.

## 신규 ID를 직접 실행할 때

`prepare` 후 `<work>/tools`에 있는 생성기를 수정한다. 원본 스킬 kit을 직접 고치지 않는다.
`run --only`는 묶음의 원래 ID를 검증하므로, 새 ID는 아래 템플릿으로 실행한다.
셸 별 줄 연결 문법이 달라 한 줄로 적었다. 경로를 실제 값으로 바꾼다.

```sh
blender -b --factory-startup -t 2 --python-exit-code 1 --python-expr "import sys; sys.path.insert(0, r'<work>/tools')" -P "<work>/tools/build_growth_14.py" -- --only NEW-ID
python "<skill>/scripts/assetkit.py" check --workspace "<work>"
```

직접 실행도 해당 스크립트의 flags를 따른다. `--` 뒤가 Blender가 아닌 스크립트 인수다.
새 ID의 수치 검증기를 함께 갱신한다. signals/service/citizen의 고정 batch 검증기는
새 ID를 자동 검증하지 않는다. runner의 `list`도 신규 ID를 표시하려면 배포 kit을 갱신해야 한다.
주차시설 직접 실행은 `CITIES_DO_ONLY` 환경변수를 ID로 설정한다. 알려지지 않은 ID라면
생성이 없으므로 결과 파일 존재도 확인한다. runner는 모르는 ID를 거부한다.

## 시민 순서

1. Blender `build_citizen_adult_pilot.py`: 원본/뼈대/메타데이터.
2. Blender `render_citizen_adult_pilot.py`: 100개 고해상도 RGBA와 EXR 깊이 중간 파일.
3. 시스템 Python `compose_citizen_pilot.py`: PNG 100장, 깊이 NPZ, 시트/GIF.
4. Blender `audit_citizen_projection.py`: 25개 pose/방향 투영 접점 기록.
5. Blender `verify_citizen_adult_pilot.py`: 본/층/키/weight/loop/source 보존 검사.
6. 시스템 Python `verify_citizen_sprites.py`: 파일명/캔버스/그레이/alpha/깊이/가림/접점.

runner는 이 순서를 처리하고 workspace의 `.render-cache/`에 임시 파일을 격리한다.
최종 PNG/NPZ/원본/스크립트/검사 결과를 보관한 후 캐시는 삭제 가능하다.
100 PNG는 부위별 원본이므로 캐릭터 전체 실루엣의 확인은 depth 합성 시트/GIF도 함께 한다.

## 폰트/환경

모델 간판은 `assetkit_support.py`가 CITIES_DO_FONT → DejaVu Sans Bold → Liberation Sans
→ Noto Sans → macOS DejaVu → Blender Bfont 순으로 찾는다. 리뷰 레이블은 지정 폰트 → Noto Sans CJK(설치된 Linux 경로) → 같은 로컬 폰트
또는 Pillow 기본 폰트를 쓴다. 한글 리뷰 문구가 □로 보이면 한글 지원 오픈 폰트 경로를
CITIES_DO_FONT로 지정한다. 기본 영어 간판/모델 지오메트리와 별도 문제다.
렌더 구도와 폰트 shape는 설치된 폰트/Blender 버전에 따라 픽셀 단위로 달라질 수 있다.
정확한 기존 간판 모양을 재현하려면 DejaVu Sans Bold를 사용한다. 파일 저장 전에 폰트
pack을 실행하는 recipe는 packed font도 포함한다. 재배포할 폰트의 라이선스를 함께 확인한다.

시스템 Python: Pillow/NumPy. Blender: 자체 bpy/mathutils/NumPy.
권장 Blender4.3.2; 5.x는 API 차이로 실패할 수 있다. Linux에서 시험했고 Windows/macOS는
경로 예시만 제공한다. doctor가 성공해도 실제 생성/렌더/check까지 실행해야 한다.
오류는 `<work>/logs/`를 읽는다. 버전/폰트/renderer 문제를 치수·규격을 바꿔 숨기지 않는다.

## 출처와 범위

고정 source revision과 원본/묶음 SHA-256은 `source-manifest.json`에 있다.
묶음 복사본에만 폰트 fallback, citizen cache 격리, 주차장 ID 필터를 적용했다.
지오메트리를 새 스타일로 리디자인하지 않았다. zstack common helper와 LICENSE는 보존했다.
이 문서/runner/검증기/font helper는 이번 인계를 위해 새로 작성했다. 원본 프로젝트 전체를
MIT로 재허가하는 문서가 아니다. upstream MIT는 해당 helper에만 적용된다.
