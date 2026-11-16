# 아이v2 — 성인 축소 실루엣 수정

기준: 아이v1 `5687639` 원본/카탈로그/검증 보존, 성인 `d0416dd`/`495bd0a`/`3a48f25` 사용자 검수 통과 원본 보존. [승인 제작 요청](../../design/ASSET_REQUEST_CHILD_V2_KO.md).

## 실측과 형상

- 전체 키 **1.10000002m**, 두상 높이 **0.28000009m**, 약 **3.92857등신**. 두상 폭0.21316129m·깊이0.18967742m. 머리카락을 제외한 실제 두상 정점 범위이며 [측정값](proportions.json)을 보관한다.
- v1 두상0.2418m에 비해 가로/세로/깊이를 같은 비율로 확대했다. 새 본·위치 키 배율은 성인 대비0.56(v1은0.60), 어깨 중심 폭은0.2296m(v1은0.246m). 팔/다리는 해당 길이 배율에서 반경을1.12배, 손과 소매 끝도 접속을 유지하도록 조정했다. 상의 목 윗부분은 국소 조정해 긴 목처럼 보이지 않도록 했다.
- 새 `assets/citizens/full-set/child-v2/`에 피부/공유 뼈대 베이스1 + 머리6(남3/여3) + 상의4 + 하의/신발3. 선택 부위13개, 베이스는 별도다. 직접 작성한 지오메트리·회색4층·한 armature/14본만 사용하며 얼굴 세부·외부 모델/텍스처/생성 API 없음.
- 각 폴더는 `citizen.blend`, 실행 가능한 `build.py`, 부위 GLB, spec.json, 렌더 기록, PNG/깊이를 포함한다. 기본 상의·하의는 새 베이스와 같은 실제 형상을 공유하므로 그25+25장과 깊이를 재사용한다. PNG는 총425장, 실제 새 렌더375장+동일 기본 부위 재사용50장이다.

## 이번 실행 증거

- 원 rig29항목×14＝406, sprite10항목×14＝140, RGBA/깊이 미러210경우 모두 통과. 실제 GLTFDocument에서14GLB/14본/소스 경계 로드도 통과.
- 머리6×상의4×하의3 **72조합×25포즈**의 목/허리/손목 최소 alpha253. 실제 변형 바지 허리 정점과 공통 상의12각 단면 여유는 최소0.00489616m, 머리/상의 높이 여유0.02327996m. [검증](validation-results.json)·[전체 조합](combination-checks.json).
- 성인 원 검증기 파일은 수정하지 않았다. 임시 아이 검사 복사본의 키1.10m/실제 허리 겹침0.0392m/실제 관절 좌표만 매개변수화했다. alpha240·오차1e-5·14본·가중치/재질·접지/원점·4포즈·17=1 루프·카메라 기준은 그대로다.
- **[실제 Godot 비교 시트](adult-comparison.png)**: 무작위 아이12명+승인된 성인2명. 모든 native는40px/m·발(32,84), 확대 검수는 모두2배로 동일하다. 성인2명은 둘째 줄 오른쪽에서 아이들과 같은 기준선/축척으로 선다. 위쪽은 동일 game zoom1 배율0.1237436867이다. 1280×610 실제 GL framebuffer이며 이미지 합성/늘리기로 게임 화면을 가장한 것이 아니다. 비교 시각 검수상 머리 폭이 몸통 대비 커지고 다리/팔이 짧아졌으며,0.28m가 과도하다고 판단하지 않아0.26m 대안은 쓰지 않았다. 사용자 최종 승인과는 별개다.

## 재현과 등록

기존 Blender4.3.2/동봉 Python3.11·NumPy1.24.3, 승인된 `D:/tools/cities-asset-python311/site-packages`의 Pillow11.3.0만 사용한다. 새 설치·전역 PATH 변경 없음. `godot-windows-validation`의 실제 프레임/깊이/단위 검사와 자체 코드 검수를 적용했다. 같은 프로젝트 demo031ce4b5ba488c2ea5991fc69d8d712f1fd273d1 adapter/shader는 `tools/citizen_demo_reference/`에서 변경 없이 읽는다.

진입점 `tools/run_citizen_child_v2.py --phase all|finish|verify-existing --cache <agent-scratch> --blender <절대exe> --godot <절대exe>`를 해당 Python에서 `PYTHONPATH=D:/tools/cities-asset-python311/site-packages`로 실행한다. Blender가 PYTHONPATH를 무시하는 경우 검증기는 승인된 D: 경로만 해당 프로세스 sys.path에 추가한다. 생성기는 `tools/build_citizen_child_v2.py`, 검증 어댑터 `tools/verify_citizen_child_v2.py`, 실제 캡처 `tools/capture_citizen_child_v2.gd`다. 기존 원본은 거부하며 새버전 폴더만 만든다. 베이스의39항목 선행 검사 후 다른 부위를 확장했다. 임시 raw/EXR/검사 복사본은 제거한다.

통합 `assets/citizens/full-set/catalog.json`의 아이 참조만 v2로 전환하고 v1 카탈로그를 archive로 남긴다. 성인 선택 부위/원본·아이v1·기존 공통 코드/검증기·게임 코드/경제/인구는 변경하지 않았다. 게임 내 새 부위 선택 로더/UI·대규모 보행 시뮬레이션은 미적용/미검증이며, 바인드 GLB 로드는3D 애니메이션 게임 검증이 아니다. 경제상 독립 건설비/유지비/생산량/수용량은 외형 데이터의 적용 대상이 아니라는 기존 제안 유지. push/main 반영 없음.
