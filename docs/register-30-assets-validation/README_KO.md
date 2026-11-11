# 원본 30종 검사 전용 등록 검증

- 기록: 2026-11-11 KST, 체크아웃 `D:/project/simcity`.
- 시작점: `main` / `12dbc38b8163a773ee384736b0219e547d1b1f6c`.
- 작업 브랜치: `feature/register-30-assets`. **로컬 커밋까지만, main 병합·푸시 없음.**
- 이번 새 실행: import 성공, 전체 `tests/test_*.gd` **26/26**, 신규 등록 검사 **635/635**.
  정본은 `results.json`, `test_registered_30_assets.log`. 이전 단계 로그의 550/550 등은 중간 실행이다.
- 등록/GLB/spec/기존 PNG 복사/파생 썸네일: **30/30**, 누락 0.
- 원본 5개 study 디렉터리의 **209파일 SHA-256 불변**. `.blend`·metadata·제작 스크립트·제안 문서/CSV를 수정하지 않았다.

## 등록과 기존 UI 재사용

| 분류 | 수 | 등록/검사 경로 |
|---|---:|---|
| 상업 | 10 | 건물 카탈로그, 기존 전시 장면의 동일 그리드 |
| 공업 | 8 | 건물 카탈로그, 기존 전시 장면의 동일 그리드 |
| 발전 | 6 | 전력 탭의 C형 카드 → 실제 GLB 검사창 |
| 상하수도 | 4 | 수도 탭의 C형 카드 → 실제 GLB 검사창 |
| 쓰레기 | 2 | 환경 탭의 C형 카드 → 실제 GLB 검사창 |

- 공통 인덱스: `cities_do/assets/registered_30.json`.
- 기반시설 12종: 기존 `assets/services/catalog.json` + `services/specs/`/GLB/PNG.
- 상업·공업 18종: 기존 `assets/buildings/catalog.json` + `buildings/specs/`/`models/`/PNG.
  **`growth_enabled:false`, `simulation_enabled:false`**, 실제 자동 성장 대상에서 제외한다.
  원본 metadata 전체 값과 업종/소매 유형/층수/부지·앵커를 보존했다.
- 기존 발전시설/취수장/하수처리장 배치 도구 및 선·관 도구는 교체하지 않았다.
  새 카드의 연결은 `open_registered_asset()`뿐이며 배치 함수/가격/용량/운영을 호출하지 않는다.
- C형은 기존 `core/asset_thumbnail_button.gd` 그대로 사용: 최소 128×96, cover, 둥근 모서리,
  어두운 반투명 이름 띠, 흰 18px, 말줄임·전체 이름 툴팁. 새 메뉴나 HUD 레이아웃을 만들지 않았다.
- 기존 PNG와 바이트가 같은 복사본에서 256×192 썸네일 30개를 파생했다. 공통 manifest는 기존23+신규30=53개이고 기존23 레코드·그림은 그대로다.
- 상업·공업은 하단 구획 탭에 메뉴를 추가하지 않았다. 기존 `vehicle_showcase.tscn`에 데이터 그룹 옵션을 지정한다:

```bash
"C:/Users/wlgml/AppData/Local/hermes/profiles/cities-gpt/tools/godot/Godot_v4.6.3-stable_win64_console.exe" --path D:/project/simcity/cities_do --rendering-method gl_compatibility res://vehicle_showcase.tscn -- --asset-group=commercial_industrial
```

이는 기존 전시 화면의 제목/데이터/정보행과 카메라 맞춤을 재사용한다. 새 버튼·탭·전시 레이아웃은 없다.
긴 이름/ID/업종·치수는 동일 라벨에서 말줄임하고 툴팁으로 전체 값을 제공한다.
기존 '같은 축척 비교' 스위치로 18개 카메라의 m/화소 축척을 일치시킬 수 있다.
기본 개별 맞춤 캡처는 물리 축척 비교 이미지와 구분한다.

## 실측 / 정면 / 원본 예외

- 읽기 쉬운 30행 표: [MEASUREMENTS_KO.md](MEASUREMENTS_KO.md).
- 원시/파생 AABB·지면 기준·정면 근거: `measurements.json`, `source-audit.json`.
- 스프레드시트용: `measurements.csv`(UTF-8 BOM).
- GLB는 source의 실측 m 축척을 유지한다. Blender -Y → Godot +Z 변환만 하며 크기를 보정하지 않는다.
- 지면은 원본 Lot/PresentationBase/해안 LandSurface의 **기준판 하단**을 0으로 맞춘다.
  전체 메시 최저점으로 무조건 올리지 않아 석탄 지하부·취수/하수 해안 관의 원본 지하 형상을 보존한다.
  H는 전체 메시 AABB 높이이며 지하부가 있으면 지상 지붕 높이와 다르다. 원시/파생 min/max를 함께 기록했다.

### 축척·부지 예외: 임의 수정 없음

1. **풍력** `power-wind`: 지상 점유는 원본 2×2칸(8×8m), 로터 포함 전체 실측은 약
   **19.053×4.887×37.400m**. 원본 `rotor_overhang_allowed:true` 그대로다. 8m에 맞춰 축소하지 않았다.
2. **수력** `power-hydro`: 원본 `footprint_cells:null`인 드래그형이다. 원본 시연 프레임과 실제 메시가
   **60×32m**, 높이 약 **9.770m**다. 이를 고정 15×8칸 시설로 바꾸지 않았다.
   검사 카메라용 폭/깊이와 `fixed_footprint:false`/원본 null을 구분했다.
3. **석탄·취수장·하수장**: 원본의 지면 아래 형상을 삭제·축소하거나 부지를 공중에 띄우지 않았다.
   기준판 이동량과 음수 Y를 실측 JSON에 남겼다. 나머지 고정부지의 수평 크기는 원본 4m/칸과 일치한다.

### 출입구 검증 한계 7종

`power-coal`, `power-hydro`, `power-nuclear`, `power-oil`, `power-solar`, `power-wind`, `water-water-tower`는
원본에서 **명명된 사람 출입구 근거를 확인하지 못했다**. 수문의 기계 게이트를 사람 문으로 간주하지 않는다.
+Z는 검사 방향 규약만 기록했으며, 원본에 없는 문을 만들거나 출입구 검증 완료로 표시하지 않았다.
나머지 23종은 실제 원본 Door/문 분할 등 출입구 형상 노드의 GLB 존재와 변환 후 위치를 검사했다.
화분/로비 글자/간판을 출입문 근거로 선택하지 않는다. 모든 종의 접도·물리 통행·배치는 **미구현/범위 밖**이다.

## 실제 렌더 / 캡처

### Blender: 파생 GLB를 다시 불러 렌더, 원본 .blend를 재제작하지 않음

- [overview-30.png](overview-30.png): 30종 6열×5행 일람, 4800×3600.
- [scale-commercial.png](scale-commercial.png): 상업10 + 세단/트럭 각10, 3600×2600.
- [scale-industrial.png](scale-industrial.png): 공업8 + 세단/트럭 각8, 3600×2600.
- [scale-infrastructure.png](scale-infrastructure.png): 기반시설12 + 세단/트럭 각12, 3600×2600.

차량은 기존 `car-sedan-03.glb`, `truck-flatbed-02.glb`. 이미지마다 한 직교 카메라에서 건물과 차량의
원본 m 축척을 유지한다. 이미지별 자동 프레이밍으로 **분류 이미지 사이의 화소/m는 다를 수 있다**.
각 `.json`에 실제 차량 치수/인스턴스 scale=1/모델 수/카메라 폭/PNG 해시가 있다.
이미지를 사후 리사이즈하지 않았다. 각 메시/주석 AABB가 카메라 near/far와 화면 범위 안인지 렌더 전에 검사한다.

### Godot: 실제 framebuffer, 리사이즈 없음

- [power-1920.png](power-1920.png): 전력, 1920×1080.
- [water-1920.png](water-1920.png): 수도, 1920×1080.
- [environment-1920.png](environment-1920.png): 환경, 1920×1080.
- [power-1280.png](power-1280.png): 전력, 1280×820. 좁은 화면은 기존 가로 스크롤을 사용한다.
- 추가 기존 전시 확인: [commercial-industrial-top-1920.png](commercial-industrial-top-1920.png),
  [commercial-industrial-bottom-1920.png](commercial-industrial-bottom-1920.png). 세로 스크롤로 18종을 볼 수 있다.

기본 전시 캡처는 개별 모델 맞춤이며 같은 축척 모드는 위 신규 자동 검사에서도 별도로 검증했다.
필수 HUD 4장은 실제 자금 50,000 doth/인구 0을 유지한다. 새 가격·운영·행복도/수지 값을 만들지 않았다.

## 새 검사 / 전체 회귀

`test_registered_30_assets.gd` **635/635**:

- 30개 실제 spec/GLB/기존 PNG 복사/파생 썸네일, 분류10/8/6/4/2, 원본 부지/계측 m 치수.
- 실제 Godot MeshInstance3D AABB의 GLB 왕복 W/D/H와 기준판 정렬, 지하부/풍력/수력 예외 보존.
- +Z 마커 및 23개 실제 출입구 근거 노드 위치, 확인 못 한 7개는 명시적 비검증 상태.
- 30개 실제 검사창 열기, 12개 C카드 바인딩·신호와 실제 viewport 마우스 press/release, 가로 스크롤로 모든 카드 접근, 기존 도구 분리.
- 검사 전후 자금·건물·도로·구획·전력/수도 시설/선/관·수요·인구·시계·RNG·활성 도구 불변.
- 상업/공업 growth 제외, 업종/층수, 동일 전시 그리드18종, 같은 축척 카메라 및 전체 프러스텀 포함.

전체 **26/26**. `test_showcase`는 텍스처 캐시 수가 정확히10이라는 오래된 기대만 교정했다.
주거 10종은 여전히 같은 10종/배치이며 전체 확장 카탈로그 텍스처를 불러오는지 별도로 검사한다.
기존 원본 서비스/하단바/C형143검사/도시/성장/전력/수도/차량 회귀도 재실행했다.

## 재현 도구 / 실행파일

- Godot 4.6.3: `C:/Users/wlgml/AppData/Local/hermes/profiles/cities-gpt/tools/godot/Godot_v4.6.3-stable_win64_console.exe`.
- Blender 4.3.2: `C:/Users/wlgml/AppData/Local/hermes/profiles/cities-gpt/tools/blender/blender-4.3.2-windows-x64/blender.exe`.
- `tools/audit_remaining_asset_sources.py`: 원본 읽기 전용 실측/209파일 해시.
- `tools/export_remaining_assets.py`: 기존 emergency exporter의 bounds/dump를 재사용, 그룹별 export 가능.
  `--groups commercial industrial` / `--groups power water waste`로 나눠 실행했다.
- `tools/derive_asset_thumbnails.py`: 기존 규약에 신규18 건물 입력을 더해 총53 썸네일 파생.
- `tools/render_remaining_assets.py`: category별 별도 실행. 검증된 기본 백엔드는 **EEVEE Next**(`--eevee`).
- `tools/capture_registered_assets.py`, `tools/capture_registered_gallery.gd`: 기존 캡처/전시 재사용.
- `tools/audit_registered_delivery.py`: 30행 표/CSV·원본 해시·등록/메타데이터/PNG·이미지 해시/크기 검증.

```bash
python tools/validate_delivery.py --output docs/register-30-assets-validation --godot C:/Users/wlgml/AppData/Local/hermes/profiles/cities-gpt/tools/godot/Godot_v4.6.3-stable_win64_console.exe
python tools/audit_registered_delivery.py
python tools/capture_registered_assets.py --godot C:/Users/wlgml/AppData/Local/hermes/profiles/cities-gpt/tools/godot/Godot_v4.6.3-stable_win64_console.exe
# Blender 각 실행은 -b --factory-startup -t 6 --python-exit-code 1 -P tools/render_remaining_assets.py -- --category <overview|commercial|industrial|infrastructure> --eevee
```

## 실행 중 해결한 문제 / 남은 범위

- CUDA 장치 조회는 성공했지만 Cycles 렌더가 Sample1 이후 진행되지 않아 300초 타임아웃.
  `render-commercial-cuda-timeout.log`를 보존하고, EEVEE Next로 실제4장을 새로 렌더했다. 드라이버 원인은 단정하지 않는다.
- 큰 장면에서 카메라 거리가 기본 far=1000을 넘어 배경만 나온 중간 결과를 거부했다.
  `red-render-frustum.log`의 실제 실패(1607m>1000m)를 확인하고 clip_end=10000 + 전체 프러스텀 검사를 적용했다.
  최종4장은 실제 형상/비어 있지 않은 픽셀/해시/치수/시각 확인을 통과했다. 잘못된 중간 PNG는 최종 증거가 아니다.
- 원본 제작기 실행/재저장/재생성, archive 코드 덮어쓰기, 1B 도시 배치, 자동 성장 연결,
  가격·용량·발전량·처리량·수요·경제·사운드·main 변경/푸시는 하지 않았다.
- 등록/썸네일 누락과 실행 차단은 없다. **7종의 사람 출입구 확인 및 실제 도로/차량 통과 판정은 미완**이다.
- 자체 리뷰(`review_mode:self-review`)와 실제 테스트/이미지/원본 보존 검사다. 독립 리뷰 에이전트를 사용했다고 주장하지 않는다.
- 재임포트 .import churn/기존 미추적 .uid8개/병행 기획 문서·mistake 변경은 이번 커밋에서 제외한다.
