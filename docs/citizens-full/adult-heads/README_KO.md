# 성인 머리10 — 시민 전체 세트 묶음①

- 브랜치 `assets/citizens-full-20261116`, 기준 `957d806` / adult-pilot-01. 이 묶음은 남5·여5 hair층만 새로 만들고 시안의 피부/두상·상의·하의/신발·14본·Idle/Walk를 그대로 재사용한다.
- [부위 카탈로그](../../../assets/citizens/full-set/adult-heads/catalog.json), [제작 요청 기록](../../design/ASSET_REQUEST_CITIZENS_FULL_KO.md).
- 각 부위: `citizen.blend`(공용4층 조합 원본), `hair.glb`(회색 hair1층+공유 뼈대, bind geometry), `build.py`, `spec.json`, `render-manifest.json`, 새 PNG25장, `layer-depths.npz`25깊이. GLB는 정지 부위 지오메트리이며, Idle/Walk 원본은 .blend에 있다. 기존 게임 원본/코드는 바꾸지 않았고 런타임 부위 선택 등록도 하지 않았다.
- 머리108~348삼각형, 시안 옷을 포함한 원본696~936삼각형. 성인 키1.75m, 뼈대/본 이름/가중치 계약 동일. 새 형상은 직접 작성한 저폴리 cap/fringe/ellipsoid 지오메트리로만 구성한다. 외부 모델·텍스처·생성 그림·얼굴 세부 없음.

## 스프라이트와 조합 계약

시안과 동일한 CPU Cycles24샘플·4배 렌더 → premultiplied RGBA LANCZOS 축소·64×96·40px/m·발(32,84), 회색 한 재질이다. S/SE/E/NE/N×idle/걷기4를 저장하고, SW/W/NW는 각각 SE/E/NE의 RGBA와 uint16 깊이를 함께 반전한다. 따라서 실제 PNG는 부위당25장, 논리방향은8개다. 16비트 mm 깊이/65535 투명값·줄별 이미지 이름 매칭·깊이 정렬 후 틴트/알파 합성은 시안과 같다.

`shared_layer_reference`의 body/top/bottom과 깊이는 보호된 `assets/citizens/adult-pilot-01`을 읽어 사용한다. 조합된100장짜리 스프라이트를 부위마다 중복 납품하거나 공용75장을 다시 렌더하지 않는다. 머리 최저 원본 Z는1.44m 이상이며, 향후 상의 목 주변 최대 Z≤1.40m 인터페이스를 사용한다. 이 수치는 형상 추가 시 지킬 접속 규칙이지, 아직 제작하지 않은 모든 옷의 조합 검사를 끝냈다는 뜻이 아니다.

## 이번에 실제 실행한 검증

1. Blender4.3.2에서 새 머리10종 생성, 실제 PNG/Z pass250개 렌더 및 최종화.
2. 공용75PNG/깊이+신규25PNG/깊이를 **임시 해석 뷰**로 합친 뒤, 시안의 `audit_citizen_projection.py`, `verify_citizen_adult_pilot.py`, `verify_citizen_sprites.py`를 파일 내용 변경 없이 실행했다. 새 .blend를 열어 실제 접속점25위상을 투영했으며, 검증 중 원본을 저장하지 않는다.
3. 10/10종 통과: rig29항목씩 총290, sprite10항목씩 총100, RGBA/깊이 동시 반전과 합성의 교환성150경우 통과. 목/허리/손목 샘플 최소 alpha251. [실행 결과 집계](validation-results.json).
4. 실제 Godot4.6.3/OpenGL3에서 **기존 demo adapter/shader 그대로** 새10종·12조합·8논리방향을 로드해 캡처했다. 참조 코드는 `demo/citizens-100`의 `031ce4b5ba488c2ea5991fc69d8d712f1fd273d1`; 라이브 게임 파일은 수정하지 않고 agent scratch 프로젝트에서 실행했다. [실제 Godot 시트](godot-combinations.png), [CPU 참조 시트](adult-heads-combinations.png), [고정 seed의12조합](preview-samples.json). 별도 headless GLTFDocument smoke도 GLB10개 로드·각14본·Y 최고점1.75m 확인 후 exit0이었다. 이는 bind 원본 형식 검사이며3D 애니메이션 플레이 검증은 아니다.
5. 시트 위쪽은 기존 게임 공식 `14/4*sqrt(2)*map_zoom/40`, map_zoom=1.0 배율0.1237436867을 적용한다. 아래는 원본1배·머리3배 확대이므로 구분해서 본다. 이는 실제 도시 시뮬레이션 실행/100명 운행 검사나 신규 부위 선택 UI 통합 결과가 아니다.

검수: `review_mode: self-review`. 추가 검수 에이전트 호출 없이 실제 생성/검증/GL캡처·정적 보안 검사와 변경 경로 검토를 한다. 기본 Python의 NumPy 미설치/Pyright missing-import는 별도 Blender Python 런타임과 구분한다. 이번 지정 런타임에서 전 단계 exit0이며, ruff/mypy는 설치되어 있지 않아 설치·실행하지 않았다.

## 다시 실행

Blender4.3.2의 동봉 Python3.11/NumPy1.24.3을 사용한다. 사용자 승인으로 Pillow11.3.0 공식 cp311 win_amd64 wheel만 `D:/tools/cities-asset-python311/site-packages`에 설치했다. 패키지 METADATA의 라이선스는 **MIT-CMU**이며 설치 폴더의 원래 LICENSE들을 보존한다. C: 신규 설치·시스템 PATH·전역 설정 변경은 없다. `PYTHONPATH`는 아래 명령의 프로세스에만 적용한다.

```bash
PYTHONPATH=D:/tools/cities-asset-python311/site-packages \
'C:/Users/wlgml/AppData/Local/hermes/profiles/cities-gpt/tools/blender/blender-4.3.2-windows-x64/4.3/python/bin/python.exe' \
D:/project/simcity-citizens/tools/run_citizen_adult_heads.py \
  --phase verify-existing \
  --blender 'C:/Users/wlgml/AppData/Local/hermes/profiles/cities-gpt/tools/blender/blender-4.3.2-windows-x64/blender.exe' \
  --godot 'C:/Users/wlgml/AppData/Local/hermes/profiles/cities-gpt/tools/godot/Godot_v4.6.3-stable_win64_console.exe' \
  --cache 'C:/Users/wlgml/AppData/Local/hermes/profiles/cities-asset/cache/scratch/citizens-full-adult-heads'
```

`verify-existing`는 납품된25장/깊이를 읽어 해석 뷰와 검증·시트를 만들며, 보호 원본/납품 부위는 덮어쓰지 않는다. 전체 재생성은 `--phase all --output-root <새 출력 루트>`를 사용한다. 입력 시안/공통 코드/검증기는 현재 저장소에서 읽는다. 테스트용 기존 demo adapter/shader는 `tools/citizen_demo_reference/`에 출처 커밋과 함께 그대로 보관하며, 실제 검수에 사용한 복사본과 byte 동일성을 확인했다. 따라서 형제 demo 브랜치나 Git 이력을 별도로 읽을 필요가 없다. 라이브 게임 소스를 대체하거나 수정하는 파일이 아니다. 기존 부위 폴더는 거부한다. 중단 복구의 `--resume`은 이미 생성한 새 원본을 다시 저장하지 않고 누락된 raw 렌더만 처리한다. `--cache`는 명시적 agent scratch 경로를 지정한다; 이 환경의 TMPDIR 실제값이 시스템 Temp였으므로 암묵값에 의존하지 않는다. 임시 EXR/고해상도 PNG/검사 복사본은 검수 후 제거한다.

원본 생성기: `tools/build_citizen_adult_heads.py`. 최종화/해석 뷰: `tools/finalize_citizen_adult_heads.py`. 원 검증기 호출: `tools/verify_citizen_adult_head_rigs.py`. 실제 GL 캡처: `tools/capture_citizen_adult_heads.gd`. GLB 형식 smoke: `tools/verify_citizen_hair_glb.gd`. 실행 진입점: `tools/run_citizen_adult_heads.py`. 각 폴더의 build.py는 저장소 내 생성기를 호출하며 새 출력 루트와 명시적 cache 인자를 받는다.

## 범위와 다음 묶음

이번 목/허리 접속 검사는 **시안 옷과 새 머리** 조합 기준이다. 신규 성인 상의5+교복1, 하의/신발4, 아이 체형+머리6/상의4/하의3은 아직 만들지 않았다. 후속 묶음에서 모든 부위 조합의 접속을 추가 확인한다. push/main 반영 없음.

경제/용량 제안: 외형 부위는 건설시설·생산기·수용시설이 아니므로 독립 건설비·유지비·생산량·수용량 적용 대상이 아니다(외형 데이터로만 취급하는 제안). 인구 수·소비·경제 설정/과금은 변경하지 않았다.
