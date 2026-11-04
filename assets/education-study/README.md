# 교육시설 4종 — 배치·비율 수정 시안

사용자 지정 부지: 초등학교·고등학교 4×4, 전문대·대학교 8×8. 1칸=4m 기준 16×16m 및 32×32m. 사용자 수정 요청에 따라 빈 포장 면적을 줄이고 학교와 캠퍼스의 배치를 다시 설계했다.

- elementary-school: 부지 가장자리의 2층 교실동 2개와 단층 활동동. 내부 작은 순환 트랙, 정문·지붕 벤치.
- high-school: 3층 후면 교실동과 2층 양쪽 교사동. 내부 순환 트랙과 정문.
- technical-college: 서로 떨어진 4개 동. 3층 강의동, 2층 연구동, 단층 기계실습동, 2층 디자인동. 십자 보행축과 공학 프로젝트 전시물.
- university: 서로 떨어진 5개 동. 3층 본관, 2층 인문동, 3층 과학동, 2층 도서관, 단층 학생회관. 보행로·분수·녹지.

각 원본은 건물 규모를 축소한 게임용 조형이다. 특히 16×16m 부지의 트랙은 실제 육상 경기장 규격이 아닌 축약 순환 트랙이다. 실제 학교·캠퍼스 크기를 재현했다고 주장하지 않는다.

각 폴더: building.blend 원본(폰트 포함), building.png 정면, reverse-review.png 뒷면, metadata.json 규격과 승인 상태. 부지는 사용자 지정이며 층수·배치·색상은 수정 시안이다. 모두 승인 대기, 게임 미등록. 교육·학생·통학 시뮬레이션은 미구현이다.

Blender 4.3.2 CPU, 30도 정투영, 900×1100 투명 RGBA. 카메라 배율은 시설별로 달라 이미지 크기가 실물 비율을 뜻하지 않는다. 외부 모델·텍스처 없이 직접 제작. 글꼴 조건은 FONT_LICENSE.txt 참조.

재생성: 저장소 루트에서 `blender --background --factory-startup --python-exit-code 1 --python assets/education-study/build_elementary-school.py` 등 각 build_*.py를 실행한다.

## 2026-11-04 등록 상태

사용자 요청으로 원본을 회수하여 services 카탈로그·실제 GLB 전시·보건/교육 애셋 검사 창에 등록했다. 위의 승인 대기/게임 미등록 설명은 과거 시안 단계 기록이다. 도시 배치·서비스 운영은 별도 미구현이다. 재내보내기는 tools/export_recovered_services.py를 사용한다. [통합 및 검증](../../docs/recovered-assets-validation/README_KO.md).
