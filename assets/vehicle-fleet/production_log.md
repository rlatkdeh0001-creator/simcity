# 차량 제작 기록

2026-11-01 KST. 이전 환경의 원본은 미회수 상태이므로 새로 제작했다.

1. zstack 고정 커밋에서 vehicle 스킬 전체와 MIT 라이선스를 가져오고 경로별 해시 기록.
2. SKILL.md, rig-contract.md, common.py를 읽고 CITIES_DO 적응 지침을 재작성.
3. common.py 도형·피벗 헬퍼를 실제 사용하는 파라미터 생성기 작성.
4. 해치백 시험 렌더. 환경 Blender에 디노이즈 기능이 없어 Cycles CPU 24샘플로 수정.
5. 창틀이 유리 표면의 경사에 맞게 이어지도록 튜브 끝점 수정. 운전대 위치를 실내로 이동.
6. 20종 .blend/spec/GLB 및 160장 투명 PNG 생성. 카탈로그·렌더 메타데이터 기록.
7. 전체 비교판 시각 검수. 실제 GLB 20개를 표시하는 Godot 전시 화면 구현.
8. 파일·알파·잘림 검사, Blender 원본 열기 검사 통과. Godot 메시 위치를 기반으로
   버스 문 좌우 검사 수정 후 차량 검사 156/156 통과.
9. Godot 직접 캡처에서 버스 앞면 색 띠의 공면 겹침을 수정하고 버스 재생성.
10. 최종 임포트·검사·캡처·기존 회귀 검증·배포 아카이브 검증 결과는
    docs/vehicle-validation/와 docs/VEHICLE_FLEET_20_KO.md에 기록.

마지막 전체 빌드의 스펙 요약은 last-build.json, 부분 재생성은 last-build-<id>.json.
모델별 현재 spec.json과 실제 .blend/GLB가 최종 파일이다.
