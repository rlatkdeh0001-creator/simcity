# 소방·경찰·교도소 원본 7종 · 게임 애셋 검사 등록

기준 main `21d36db`, 작업 브랜치 `feature/emergency-assets`, 현재 체크아웃 `D:/project/simcity`.
승인 범위는 **실제 GLB 애셋 검사창까지**이며 도시 건설/운영은 포함하지 않는다. 로컬 커밋만 한다.

## 원본 보존과 변환

`assets/{fire,police,prison}-study`의 51파일을 해시로 확인했다. .blend·metadata·빌드 스크립트는
수정하지 않았으며 원본 빌드 스크립트를 실행하지 않았다. 이전 `export_recovered_services.py`는
참고만 했다(그 스크립트는 metadata를 갱신하므로 이번 작업에는 실행하지 않았다).
새 `tools/export_emergency_services.py`가 .blend를 열어 메모리상 텍스트를 메시로 변환하고
메시/실제 재질만 GLB로 내보낸다. 원본 지면 하단 −0.12m를 파생 GLB에서만 +0.12m 이동해 0에 맞췄다.
XY 크기/전체 높이를 확대·축소하지 않았다. Blender −Y 정면은 GLB +Z로 변환되며
실제 원본 출입구/차고 메시의 +Z 위치와 정면 메타데이터를 검사했다.

[원본 SHA-256 보존](source-hashes.json) · [실측값/차고/실제 출입구](measurements.json) · [export 로그](export.log).
DejaVu 출처/라이선스는 기존 원본 `FONT_LICENSE.txt`에 그대로 있다. 새로운 외부 모델/텍스처는 없다.

## 등록과 실측 (미터)

아래는 **부지와 부속물을 포함한 전체 메시 AABB**의 폭×깊이×높이다. 건물 본관만의 치수가 아니다.

| 슬롯 | 게임 이름 | 실제 모델 ID | 셀 | 실측 W×D×H (m) |
|---|---|---|---|---|
| fire.small | 소형소방서 | small-fire-station | 4×4 | 16×16×5.985 |
| fire.standard | 소방서 | fire-station | 6×6 | 24×24×10.070 |
| fire.regional | 광역소방서 | regional-fire-station | 8×8 | 32×32×22.120 |
| police.small | 파출소 | small-police-station | 4×4 | 16×16×4.995 |
| police.standard | 경찰서 | police-station | 6×6 | 24×24×10.270 |
| police.headquarters | 경찰본부 | regional-police-station | 8×8 | 32×32×22.475 |
| police.prison | 교도소 | prison-8x8 | 8×8 | 32×32×10.425 |

사용자가 확정한 부지 그대로 1셀=4m다. 기존 소형 경찰서/광역 경찰서 원본 표기는 보존하고
게임 표시만 파출소/경찰본부로 매핑했다.

`cities_do/assets/services/<id>.glb`, 원본 PNG 복사본 `<id>.png`, `specs/<id>.json`과 카탈로그를 추가했다.
기존 8종 서비스 항목을 보존했다. `pending_slots.json`의 7개 경로/상태만 실제 spec/`ready`로 연결한다.
버튼은 실제 검사창을 열며 돈을 차감하거나 건물을 도시 상태에 추가하지 않는다.
검사창은 GLB를 사용하므로 이번에는 추가 8방향 스프라이트가 필요하지 않다. 원본 단방향 PNG 7장을 보존했고,
향후 별도 방향 PNG가 필요하면 비교 렌더 도구의 `--sprites` 옵션을 쓸 수 있으나 이번에는 실행하지 않았다.

## 실제 비교 렌더

- [7종 일람](emergency-overview.png)
- [7종 + 기존 소방차/경찰차/중형 세단 공통 축척](emergency-vehicle-scale.png)

둘 다 Blender 4.3.2/Cycles 실제 GLB 렌더, 2400×1500이다. 7개에 같은 정사영 카메라/조명,
모델 배율 1, 카메라 폭 210m·높이각 30도를 적용했다. 시설별로 따로 확대해 합성한 그림이 아니다.
차량은 기존 `fire-engine-01`, `police-car-01`, `car-sedan-03` GLB를 그대로 읽었다.
원본 건물 안에 이미 있는 차량과 이번 비교용 기존 차량은 서로 다른 모델이며 삭제·대체하지 않았다.

[차량·차고 실측](vehicle-clearance.json): 소방차는 미러/지붕 부속 포함 약 **2.557×7.685×3.530m**,
경찰차 **2.130×4.920×1.785m**, 세단 **2.130×4.920×1.480m**다.
소형/일반 소방서 차고 문 폭은 **3.450m**, 광역은 **4.650m**로 소방차 폭 대비 총 여유는
각각 약 **0.893m / 2.093m**다. 중앙 정렬 시의 정적 폭 여유이며 회전·출입 경로 검증이 아니다.

**확인된 원본 한계:** 소형소방서 차고 높이 **3.400m**가 기존 소방차의 부속 포함 **3.530m**보다 약 **0.130m 낮다**.
일반/광역 차고 높이 여유는 각각 약 +0.320m/+0.620m다. 원본 수정 금지 범위에 따라 고치거나
차량을 축소하지 않았다. `all_door_heights_fit:false`, `physical_drive_through_validated:false`를 명시했다.
검사창 등록 자체의 차단 사항은 아니지만 향후 실제 출동/출입 구현 전에 별도 결정이 필요하다.

## 실제 검사

[최종 전체 결과](results.json): **전체 23스크립트 통과 / 0실패**, 신규 emergency **79/79**.
7개 spec/모델·정확한 표시 이름·부지/높이/접지·실제 출입구 방향·ready 버튼·실제 검사창 메시·자금 불변을 검사했다.
초기 결과는 [results-initial.json](results-initial.json)에 별도 보존했다. 신규 headless fixture 창이 기본 64×64여서
검사창 중심 좌표가 음수였으며 1280×820 fixture를 명시한 뒤 최종 전체를 새로 실행했다. 오류 로그를 무시하지 않았다.

## 재현

```powershell
$blender='C:/Users/wlgml/AppData/Local/hermes/profiles/cities-gpt/tools/blender/blender-4.3.2-windows-x64/blender.exe'
$godot='C:/Users/wlgml/AppData/Local/hermes/profiles/cities-gpt/tools/godot/Godot_v4.6.3-stable_win64_console.exe'
& $blender -b --factory-startup -t 2 -P tools/export_emergency_services.py
& $blender -b --factory-startup -t 4 -P tools/render_emergency_comparison.py
python tools/validate_delivery.py --output docs/emergency-assets-validation --godot $godot
```

가격/용량은 기존 PRICE/CAPACITY/CSV의 미승인 제안을 유지한다.
건설비·유지비·용량 수치는 바꾸지 않았고 가격 표시/실제 과금/서비스 운영/도시 배치·접도·철거(1B)/사운드는 구현하지 않았다.
