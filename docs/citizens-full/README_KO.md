# 시민 전체 세트 — 원본/재현/검증 진입점

작업 브랜치 `assets/citizens-full-20261116`, worktree `D:/project/simcity-citizens`. 보호 기준 `957d806`의 시안, ① 머리10은 `d0416dd`로 1차 검수 통과. 최신 지시는 ②③④를 승인 대기 없이 연속 제작하고 마지막에 한 번 보고하는 것이다.

**현재 아이 참조는v2**: 사용자에게 성인 d0416dd/495bd0a/3a48f25는 통과했고, 아이5687639는 성인 축소 실루엣으로 반려되어 보존 후 새 버전을 만들었다. [v2 원본/실측/검증](child-v2/README_KO.md)·[아이12+성인2 같은 축척 실제 비교](child-v2/adult-comparison.png). 키1.10m·두상0.28m/3.93등신,72조합 최소 alpha253. 통합 카탈로그는 새 아이13부위를 가리키며 v1은 archive로 남는다. 아래 표와v1 설명은 과거 실행 기록이다.

| 묶음 | 범위 | 이 기록 시점 |
|---|---|---|
|①|성인 머리10(남5·여5)|d0416dd, 검수 통과|
|②|성인 상의5+교복1|495bd0a, 원검증234/미러90/60조합/실제 GL 확인|
|③|성인 하의/신발4|3a48f25, 원검증156/미러60/240조합/실제 GL 확인|
|④|아이1.10m 체형+머리6/상의4/하의3|이 커밋, 베이스 포함 원검증546/미러210/72조합/실제 GL 확인|

**선택 부위33종 완성**: 성인10/6/4, 아이6/4/3. 아이 공용 피부 베이스1종은 선택 부위 수와 별도다. [원본 보존형 통합 애셋 카탈로그](../../assets/citizens/full-set/catalog.json)는 부위 경로·성별·나이·몸 참조·8방향/깊이 계약을 제공한다. 게임 등록 상태는 false이며 런타임 로더/시뮬레이션은 수정하지 않았다. 전체 조합의 최대 삼각형 수는 성인1108/아이1064로1500 이하다.

④는 몸통/팔다리 본·위치 키를0.60배, 머리를0.78배로 별도 배치해 키1.10m와 큰 머리 비율을 맞췄다. 목/손/소매 끝은 native 해상도 접속을 위해 국소적으로 넓혔으며 alpha 기준을 낮추지 않았다. 모든72조합 최소 alpha248, 허리 최소 여유5.246mm, 머리/상의 높이 여유20mm. 공용 베이스100장과 신규275장을 실제 렌더했고, 베이스와 동일한 형상/면을 확인한 기본 상의·하의50장은 해당 PNG/깊이를 그대로 재사용해 총425장을 납품한다.

각 묶음 폴더의 README_KO.md, validation-results.json, combination-checks.json, preview-samples.json 및 **combinations.png(실제 Godot GL)**가 해당 묶음의 증거다. ①은 adult-heads/godot-combinations.png. 시트에는 무작위12명 이상, native1배/확대 검수와 기존 게임 zoom1의 실제 배율을 구분한다. ①의 통과나②의 통과를 후속 부위 검사로 대신하지 않는다.

## 재현

- 원본: `assets/citizens/full-set/<batch>/<id>/citizen.blend`, 해당 부위GLB, `build.py`, spec.json, rendered25PNG+depthNPZ. 아이의 공용 피부/뼈대 베이스는4층100PNG이며13가지 선택 부위와 구분한다.
- 생성: `tools/build_citizen_remaining.py --batch adult-tops|adult-bottoms|child --cache <agent scratch>`. Blender CLI의 `--` 뒤에 인자를 둔다. 각 build.py는 고정 ID의 실제 생성기를 호출한다. 보호된 폴더는 거부한다. 재생성은 이 저장소 안의 새 `--output-root`에 하며, 입력 원본은 읽기 전용이다.
- 검증/시트 진입점: **Blender4.3.2 동봉 Python3.11**에서 `tools/run_citizen_remaining.py --batch <batch> --phase all|finish|verify-existing --cache <agent scratch> --blender <절대 경로> --godot <절대 경로>`. all은 새 원본/렌더부터, finish는 이미 생성한 raw를 최종화, verify-existing은 납품 PNG를 재렌더하지 않고 검사한다.
- Python 프로세스에만 `PYTHONPATH=D:/tools/cities-asset-python311/site-packages`를 적용한다. Blender 자체는 PYTHONPATH를 무시하므로 검증기가 승인된 해당 D: 경로만 sys.path에 추가한다. 추가 설치/시스템 PATH 변경은 없다. 기존 Pillow11.3.0(MIT-CMU), 동봉 NumPy1.24.3을 사용한다.
- 임시100장 해석 뷰를 만들고 원 rig29/sprite10 검사를 실행한다. 성인은 원 검증기 무수정. 아이는 물리적으로 다른 키1.10m/겹침.042m/관절 좌표만 임시 복사본에 넣는다. 나머지 alpha240/오차1e-5/14본/4걷기/0.8s/40pxm/64×96/발(32,84)은 동일하다. 원 검증기 파일 자체는 바꾸지 않는다.
- `tools/citizen_demo_reference/`의 동일 프로젝트 demo031ce4b5ba488c2ea5991fc69d8d712f1fd273d1 adapter/shader를 변경 없이 재사용한다. 실제 게임 코드는 건드리지 않는다. Source bindGLB는 실제 GLTFDocument 로드/14본/원본 높이 검사로 별도 확인하며3D 애니메이션 게임 검증은 아니다.

모든 새 형상은 직접 작성한 지오메트리이며 외부 모델·텍스처·생성 API·얼굴 세부 없음. 손·두상·목 피부는 분리된1층이다. 임시 raw EXR/고해상도 PNG/검증 복사본과 미승인 초안은 최종 검사 후 제거한다. 경제·인구·게임 부위 선택 UI·main/push 변경 없음. 외형 데이터에는 독립 건설비/유지비/생산량/수용량 적용 대상이 없다는 제안이며 경제 규칙으로 구현하지 않았다.
