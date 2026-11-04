# 공공차량·화장터·보건/교육 탭 현재 상태 재확인

2026-11-04 KST. 사용자가 병원·진료소 업데이트 확인과 기존 작업의 중복 방지를 요청했다.
로컬은 `cdca2de`, 원격은 `4651283`이었다. 깨끗한 작업 트리에서 fetch 후 fast-forward하여
원격의 이미 완료된 애셋과 탭 개편을 보존했다. 이번에 이 모델들을 새로 만들었다고 주장하지 않는다.

## 확인 결과

| 요청 | 현재 실제 상태 |
| --- | --- |
| 소방차·경찰차·운구차 | 기존 .blend·GLB·사양과 8방향 PNG 각각 8장 있음. 카탈로그·공공차량 전시 연결 정상 |
| 화장터 | 4×4=16×16m 모델 존재. 보건 탭에서 실제 GLB 미리보기 열림 |
| 병원·진료소 업데이트 | 흰 벽·빨간 지붕의 회수 원본이 등록돼 있음. 각각 대응하는 실제 GLB 미리보기 열림 |
| 보건 탭 | 병원·진료소·대형병원·화장터, 네 버튼 모두 활성 |
| 교육 탭 | 초등학교·고등학교·전문대학·대학교, 네 버튼 모두 활성 |
| 기타 탭 | 삭제돼 있음. 삭제 전에는 빈 탭으로, 시설/교육 항목은 없었음. 설정 버튼도 빈 탭을 여는 기능뿐이었음 |
| 도시 보존 | 미리보기 열기·닫기 후 같은 도시와 34개 예시 건물 유지 |

**위 서비스 시설은 애셋 미리보기 단계다.** 도시 내 건설·진료·교육·화장 처리·긴급 출동
서비스가 완성된 것은 아니다. 카탈로그의 `asset_preview_only`, `simulation_enabled:false`도
그대로 유지했다. 현재 하단 UI 검토 장면과 메인 화면 전체 통합도 구분한다.

## 이번 실제 화면

- [보건 탭](health-tab.png) / [교육 탭](education-tab.png)
- [병원](hospital.png) / [진료소](clinic.png) / [대형병원](large_hospital.png) / [화장터](crematorium.png)
- [소방차·경찰차·운구차·화장터 전시](public-assets.png)

Godot 4.6.3 Compatibility / llvmpipe의 실제 화면이다. 병원·진료소 등은 실제 하단 버튼을
눌러 해당 창을 연 뒤 캡처했다. 이미지 합성·생성형 시안이 아니다.
탭/시설 창은 1280×820, 공공 애셋 전시는 1920×1080이다.

## 보강·검증

기존 회수 애셋 검사에는 버튼이 없으면 건너뛰는 경로가 있어 이를 보강했다.
이제 각 탭의 네 버튼과 정확한 창 제목·실제 메시를 명시적으로 검사한다.
화장터도 같은 메뉴 검사에 포함한다. 제품 코드·기존 애셋·경제 수치는 변경하지 않았다.

- [전체 검사 결과](results.json): **21개 스크립트 통과**, 종료 코드와 오류 로그 확인.
- [회수 애셋/메뉴](test_recovered_assets.log): **59/59**.
- [서비스 모델](test_service_assets.log): **9/9**.
- [차량](test_vehicles.log): **308/308**, 전체 등록 41종 유지.
- [하단 UI](test_bottom_ui.log): **36/36**.
- 공공차량 3종의 PNG 총 24장이 430×245이며 알파 영역이 비어 있지 않음을 추가 확인했다.
- [메뉴 실제 캡처 로그](capture.log), [전시 로그](gallery.log), [이미지 크기·해시](capture-manifest.json).

원본 Blender 재제작·실차 IoU·문 개폐·충돌 변형·출동 AI·시설 운영·대량 성능은 이번 검증이 아니다.
기존 가격/용량 제안을 중복 추가하거나 실제 과금으로 바꾸지 않았다.

## 재현

저장소 루트에서 writable XDG 경로를 설정하고 리소스를 임포트한 후 실행한다.

```sh
XDG_DATA_HOME=/tmp/cities-do-data XDG_CONFIG_HOME=/tmp/cities-do-config XDG_CACHE_HOME=/tmp/cities-do-cache godot --headless --editor --import --path cities_do --quit
XDG_DATA_HOME=/tmp/cities-do-data XDG_CONFIG_HOME=/tmp/cities-do-config XDG_CACHE_HOME=/tmp/cities-do-cache godot --headless --path cities_do --script tests/test_recovered_assets.gd
DISPLAY=:99 XDG_DATA_HOME=/tmp/cities-do-data XDG_CONFIG_HOME=/tmp/cities-do-config XDG_CACHE_HOME=/tmp/cities-do-cache godot --audio-driver Dummy --path cities_do --resolution 1280x820 --script ../tools/capture_service_recheck.gd -- "$PWD/docs/service-recheck-validation"
DISPLAY=:99 XDG_DATA_HOME=/tmp/cities-do-data XDG_CONFIG_HOME=/tmp/cities-do-config XDG_CACHE_HOME=/tmp/cities-do-cache godot --audio-driver Dummy --path cities_do --resolution 1920x1080 res://service_assets_showcase.tscn -- --capture-vehicles="$PWD/docs/service-recheck-validation/public-assets.png"
```

`DISPLAY`는 실제 그래픽 디스플레이에 맞춘다. 이번 환경은 Xorg dummy를 사용했다.
미리보기 확인 요청을 도시 서비스 전체 구현 요청으로 확대하지 않았다.
