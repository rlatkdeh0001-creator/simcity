# 소방·경찰·교도소 원본 7종 회수

2026-11-10 KST. 사용자 요청으로 이전 클라우드 작업의 편집 원본·승인 시안·규격·제작 코드를 GitHub에 보존한다.
최신 main e8fff35를 먼저 가져왔으며 현재 게임 코드·보건/교육/차량·공공시설 배치 상태는 바꾸지 않는다.
이번 커밋은 원본 업로드이며 게임 등록·설치·소방/치안 운영·요금 적용을 새로 구현했다는 뜻이 아니다.

| 이름 | 원본 ID | 부지 | 최대 층수 | 원본 폴더 |
|---|---|---|---|---|
| 소방서 | `fire-station` | 6×6 | 3 | [원본·이미지](../../assets/fire-study/fire-station) |
| 광역소방서 | `regional-fire-station` | 8×8 | 4 | [원본·이미지](../../assets/fire-study/regional-fire-station) |
| 소형소방서 | `small-fire-station` | 4×4 | 1 | [원본·이미지](../../assets/fire-study/small-fire-station) |
| 경찰서 | `police-station` | 6×6 | 3 | [원본·이미지](../../assets/police-study/police-station) |
| 경찰본부 | `regional-police-station` | 8×8 | 4 | [원본·이미지](../../assets/police-study/regional-police-station) |
| 파출소 | `small-police-station` | 4×4 | 1 | [원본·이미지](../../assets/police-study/small-police-station) |
| 교도소 | `prison-8x8` | 8×8 | 미지정 | [원본·이미지](../../assets/prison-study/prison) |

소방서·경찰서의 6×6 등은 원본 시안의 부지 값이다. footprint_status가 draft인 값을 새로 확정한 규칙으로 간주하지 않는다.
원본 metadata의 ‘소형 경찰서’는 사용자용 이름 ‘파출소’, ‘광역 경찰서’는 ‘경찰본부’에 대응한다. 원본 내용은 바꾸지 않았다.
광역소방서는 4층·옥상 헬리패드·계단 출입구·보행 연결, 경찰본부는 옥상 H 패드와 출입구가 기록된 수정본이다.

## 보존·검증

이전 전체 백업과 함께 남긴 Git stash의 untracked tree에서 51파일을 회수했다. 기존 파일과 다르면 중단하며 덮어쓰지 않았다.
51파일 전체가 보존 원본과 바이트 단위 일치한다. file-validation.json에 SHA-256과 원본 트리를 기록했다.
14장 앞·뒷면 PNG를 디코딩해 규격/투명 배경/내용을 확인하고 Blender 원본 7개를 열어 메시·유한 좌표·metadata 경계를 검사한다.
source-validation.json 및 source-check.log가 이번 실행 결과다. 새 렌더링·전체 게임 테스트는 실행하지 않는다.

## 제작·출처

새 모델이나 외부 스킬을 도입하지 않고 이전 직접 제작한 원본을 보존했다. 각 폴더에 build_*.py·제작 기록·README·DejaVu FONT_LICENSE.txt가 있다.
제작 스크립트 재실행은 시안과 metadata를 덮어쓰므로 검증에는 사용하지 않았다. 이번 Blender 검사는 읽기 전용이다.
원본 metadata의 과거 승인/등록 상태는 역사 자료로 보존하며 이 인덱스로 현재 업로드 범위를 구분한다.
외형 업로드는 가격·용량·운영비 승인이 아니다. 기존 PRICE_PROPOSALS_KO.md/CAPACITY_PROPOSALS_KO.md의 제안은 변경하지 않았다.
