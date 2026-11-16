# 시민 전체 세트 — 원본/재현/검증 진입점

작업 브랜치 `assets/citizens-full-20261116`, worktree `D:/project/simcity-citizens`. 보호 기준 `957d806`의 시안, ① 머리10은 `d0416dd`로 1차 검수 통과. 최신 지시는 ②③④를 승인 대기 없이 연속 제작하고 마지막에 한 번 보고하는 것이다.

| 묶음 | 범위 | 이 기록 시점 |
|---|---|---|
|①|성인 머리10(남5·여5)|d0416dd, 검수 통과|
|②|성인 상의5+교복1|이 커밋, 생성/원검증/60조합/실제 GL 확인 완료|
|③|성인 하의/신발4|제작 진행, 별도 결과로 판정|
|④|아이1.10m 체형+머리6/상의4/하의3|후속 묶음, 아직 통과를 주장하지 않음|

각 묶음 폴더의 README_KO.md, validation-results.json, combination-checks.json, preview-samples.json 및 **combinations.png(실제 Godot GL)**가 해당 묶음의 증거다. ①은 adult-heads/godot-combinations.png. 시트에는 무작위12명 이상, native1배/확대 검수와 기존 게임 zoom1의 실제 배율을 구분한다. ①의 통과나②의 통과를 후속 부위 검사로 대신하지 않는다.

## 재현

- 원본: `assets/citizens/full-set/<batch>/<id>/citizen.blend`, 해당 부위GLB, `build.py`, spec.json, rendered25PNG+depthNPZ. 아이의 공용 피부/뼈대 베이스는4층100PNG이며13가지 선택 부위와 구분한다.
- 생성: `tools/build_citizen_remaining.py --batch adult-tops|adult-bottoms|child --cache <agent scratch>`. Blender CLI의 `--` 뒤에 인자를 둔다. 각 build.py는 고정 ID의 실제 생성기를 호출한다. 보호된 폴더는 거부한다. 재생성은 이 저장소 안의 새 `--output-root`에 하며, 입력 원본은 읽기 전용이다.
- 검증/시트 진입점: **Blender4.3.2 동봉 Python3.11**에서 `tools/run_citizen_remaining.py --batch <batch> --phase all|finish|verify-existing --cache <agent scratch> --blender <절대 경로> --godot <절대 경로>`. all은 새 원본/렌더부터, finish는 이미 생성한 raw를 최종화, verify-existing은 납품 PNG를 재렌더하지 않고 검사한다.
- Python 프로세스에만 `PYTHONPATH=D:/tools/cities-asset-python311/site-packages`를 적용한다. Blender 자체는 PYTHONPATH를 무시하므로 검증기가 승인된 해당 D: 경로만 sys.path에 추가한다. 추가 설치/시스템 PATH 변경은 없다. 기존 Pillow11.3.0(MIT-CMU), 동봉 NumPy1.24.3을 사용한다.
- 임시100장 해석 뷰를 만들고 원 rig29/sprite10 검사를 실행한다. 성인은 원 검증기 무수정. 아이는 물리적으로 다른 키1.10m/겹침.042m/관절 좌표만 임시 복사본에 넣는다. 나머지 alpha240/오차1e-5/14본/4걷기/0.8s/40pxm/64×96/발(32,84)은 동일하다. 원 검증기 파일 자체는 바꾸지 않는다.
- `tools/citizen_demo_reference/`의 동일 프로젝트 demo031ce4b5ba488c2ea5991fc69d8d712f1fd273d1 adapter/shader를 변경 없이 재사용한다. 실제 게임 코드는 건드리지 않는다. Source bindGLB는 실제 GLTFDocument 로드/14본/원본 높이 검사로 별도 확인하며3D 애니메이션 게임 검증은 아니다.

모든 새 형상은 직접 작성한 지오메트리이며 외부 모델·텍스처·생성 API·얼굴 세부 없음. 손·두상·목 피부는 분리된1층이다. 임시 raw EXR/고해상도 PNG/검증 복사본과 미승인 초안은 최종 검사 후 제거한다. 경제·인구·게임 부위 선택 UI·main/push 변경 없음. 외형 데이터에는 독립 건설비/유지비/생산량/수용량 적용 대상이 없다는 제안이며 경제 규칙으로 구현하지 않았다.
