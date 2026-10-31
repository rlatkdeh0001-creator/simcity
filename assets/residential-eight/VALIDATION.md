# 8종 시안 검증

- 요청한 분류 정확히 일치: 소형 2×2 두 채, 소형 4×4 두 채, 대형 4×4 두 채, 대형 8×8 두 채. 총 8개의 별도 애셋.
- 각 모델 생성 시 실제 월드 좌표 메시 경계가 지정된 부지 안에 있는지 검사.
- validate_blends.py가 저장된 .blend 8개를 다시 열어 실제 층수 마커 1/2/2/3/8/10/14/18개, 연속 층 인덱스, 메시 경계, 정사영 카메라·30도 고도·배율·900×1100 설정을 재확인. 결과 source-validation.json.
- validate_images.py로 앞/반대 PNG 총 16개의 RGBA 모드·900×1100 크기·투명 경계 여백·잘림 없음 및 분류를 확인. asset-manifest.json에 해시 기록.
- 최종 정면·반대편 비교판을 직접 검수. 전면 창문, 현관 지붕/기둥, 지붕 접합부 겹침, 코너 유리의 중복 창틀, 타워 상부 난간 위치를 보완 후 재렌더.
- 브라우저 비교판: 8개 카드와 8개 렌더 이미지 정상 로드, 정면·반대편 캡처 완료.
- 게임 카탈로그·성장 로직 연결, 실제 게임 화면 표시, 충돌·LOD·실내·건축 구조는 이번 검증에 포함하지 않음.
- 전체 비교판은 각 열의 두 건물끼리 같은 배율이며 열 사이 배율은 다름. 원본 단위는 모두 1칸=4m.
- Blender 4.3.2 CPU Cycles 32 samples. 외부 생성 API·유료 모델·다운로드한 텍스처 없음.

재검증: 저장소 루트에서 `python3 assets/residential-eight/validate_images.py`,
`blender --background --factory-startup --python-exit-code 1 --python assets/residential-eight/validate_blends.py`.
클라우드에서는 쓰기 가능한 XDG_CONFIG_HOME/XDG_CACHE_HOME 지정이 필요할 수 있음.
