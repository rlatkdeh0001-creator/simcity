# Godot 렌더러 비교 — 2026-11-26

게임 코드 기준 `74930af` (`perf/render-sim-cadence`), Windows / Godot 4.6.3 .NET / GeForce RTX 2070 SUPER. `project.godot`는 작업 전후 동일했고 런타임에서 `--rendering-method`만 달리했다. 로그에서 각 렌더러가 실제로 활성화됐고 다른 렌더러로 대체되지 않았음을 확인했다.

| 렌더러 | 실제 그래픽 드라이버·API (로그) | 평균 프레임 ms | p95 ms | 프레임 수 | 오류 / 경고 | 1920×1080 원본 |
|---|---|---:|---:|---:|---:|---|
| `gl_compatibility` | `opengl3` / OpenGL 3.3.0 NVIDIA 596.36 | 4.121 | 4.908 | 971 | 0 / 0 | [도시](gl_compatibility/city.png) · [건물](gl_compatibility/building.png) |
| `forward_plus` | `vulkan` / Vulkan 1.4.329 | 2.263 | 2.865 | 1,768 | 0 / 0 | [도시](forward_plus/city.png) · [건물](forward_plus/building.png) |
| `mobile` | `vulkan` / Vulkan 1.4.329 | 2.240 | 2.762 | 1,786 | 0 / 0 | [도시](mobile/city.png) · [건물](mobile/building.png) |

## 같은 장면인지 확인
- 이전 `tools/capture_perf_cadence.gd`의 `fixture()`를 재사용했다. 시드 `20261114`, 도로 6개·건물 24채·정지 차량 24대. 세 실행의 배치·표준 카메라 SHA-256은 `15cc0ec9a47c7d9af2e559adf9f0950f8d5d23a59dcead092e733fd63eb1d14c`로 같다.
- 계측 및 도시 캡처는 기본 보기 0.9배, 세계 좌표 (48, 48)을 화면 (960, 410)에 배치했다. 확대는 계측 후 별도로 4.5배, 건물 #24 `small-2x2-a` (37, 50.5)를 같은 위치에 놓았다. 이 건물은 미리 구운 방향별 이미지가 아닌 실제 3D 모델을 `SubViewport`로 찍어 그린 경우다. 여섯 장을 직접 확인했으며 도시·건물 구도가 같고, 확대 화면에서 눈에 띄는 모델 누락이나 조명 이상은 없었다. 픽셀 단위 동일성을 뜻하지는 않는다.
- 다른 Godot 프로세스가 없을 때 순차 실행했다. 전체 화면, VSync 끔, FPS 제한 없음. 건물 이미지 준비 완료 후 1초 준비·최소 4초 샘플을 렌더러별 1회 수집했다. `frame_post_draw` 간 벽시계 시간의 산술평균과 nearest-rank p95이며 GPU 단독 시간이나 초기 건물 생성 비용은 아니다. 캡처는 계측 구간 밖에서 촬영했다.
- 이 정지 도시와 GPU에서는 두 Vulkan 모드의 프레임이 Compatibility보다 짧았다. 1회 표본이므로 Forward+와 Mobile의 작은 차이, 큰 도시 성능, 운영 중 시뮬레이션 또는 다른 GPU에 일반화하지 않는다. 게임 렌더러 설정은 바꾸지 않았다.

## 재현 및 증거
- 프로젝트 루트에서 `python tools/compare_renderers_20261126.py`. 내부 실행은 모두 `tools/run_dotnet.py`를 사용한다. 이미 캡처한 폴더는 덮어쓰지 않고 확인한다.
- 새로 재현하려면 다른 Godot 창이 없는 상태에서 렌더러별로 같은 명령을 아래처럼 순차 실행하고 새 출력 경로를 쓴다.

```text
python tools/run_dotnet.py --timeout 95 godot --path cities_do --rendering-method <method> --resolution 1920x1080 --fullscreen --audio-driver Dummy --quit-after 40000 --script D:/project/simcity/tools/compare_renderers_20261126.gd -- --evidence-dir=<new-absolute-dir>
```

각 폴더의 `godot.log`에 실제 장치·드라이버와 진단, `frames.json`에 µs 단위 원시 프레임 간격과 카메라/배치 지문, `process.json`에 종료 코드가 있다. 규칙 변경 결과와 확인 대기는 [2차 검토 노트](../second-fix-20261126/REVIEW_NOTES.md)에 기록했다.

## 기존 최대 실화면 도시 — 2026-11-27

게임 코드 `4cda9db`, Windows / Godot 4.6.3 .NET / RTX 2070 SUPER. `PERFORMANCE_NOTES_KO.md`의 240명 실화면 측정에 해당하는 `727a9e1`의 장면 레시피를 재현했다. 시드 `20261114`, **도로 6개·건물 61채·120가구·240명·지정 32칸·차량 0대**. 30만 인구 시험은 렌더링 없는 별도 부하이므로 이 표에 섞지 않았다.

| 렌더러 | 실제 드라이버·API | 정지 평균 / p95 ms | 1× 평균 / p95 ms | 표본 수 (정지 / 1×) | 1× 발행 틱 |
|---|---|---:|---:|---:|---:|
| `gl_compatibility` | `opengl3` / OpenGL 3.3.0 NVIDIA 596.36 | 4.164 / 4.742 | 4.213 / 4.949 | 1,922 / 1,899 | 3 |
| `forward_plus` | `vulkan` / Vulkan 1.4.329 | 2.532 / 3.089 | 3.097 / 3.945 | 3,160 / 2,583 | 2 |
| `mobile` | `vulkan` / Vulkan 1.4.329 | 2.931 / 4.409 | 3.035 / 4.846 | 2,730 / 2,637 | 2 |

- 실행 6건 모두 정상 종료, 오류·경고·렌더러 대체 0. 각 실행 직전 다른 Godot 프로세스가 없음을 확인했다. 1920×1080 전체 화면, VSync·FPS 제한 해제, 건물 이미지 준비 후 1초 예열과 8초 표본. 카메라 0.9×, 세계 `(57, 47.5)`→화면 `(960, 410)`으로 고정했다. 옛 카메라 이동 입력은 재생하지 않았다.
- 여섯 실행의 초기 상태/카메라 지문이 같았다(`8687ed0370bd7ab2d8671be72db2a4f91cc82aa5113d434ce0785184373acd85`). 정지는 상태가 바뀌지 않았고, 1×에서는 실제 운영 worker가 각각 144/96/96 게임 초를 발행했다. 동일한 벽시계 구간의 프레임 결과이지, 동일 틱 수나 GPU 단독 비용 비교가 아니다.
- 이 장면에서 가장 낮은 p95는 정지·1× 모두 Forward+였다. 렌더러별 1회, 차량 없는 장면이므로 운영 대도시·교통 부하·다른 GPU까지 일반화하지 않는다. `project.godot` 기존 작업 사본의 해시는 그대로이며 설정은 바꾸지 않았다. 추가 캡처는 하지 않았다.
- [실행 요약 및 원시 자료](large-20261127/summary.json). `python tools/compare_renderers_large_20261127.py --plan`은 명령 확인만, `--measure`는 승인된 조용한 실행 창에서 새 출력 폴더가 비어 있을 때만 사용한다. 이미 존재하는 증거 폴더에는 덮어쓰지 않는다.
