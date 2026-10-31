# CITIES_DO · 4층 공동주택 맨션 시안

동일한 4×4 부지와 카메라·조명 아래 두 외관을 비교하는 원본 제작 시안입니다.
`game-art`의 스타일·스케일 일관성 지침과 `blender-kiln`의 로컬 스크립팅·원본
보존·반대 시점 검수 원칙을 참고했습니다. 서로 다른 두 생성기로 만든 비교가
아니며, kiln 원본 툴킷·MCP·Studio를 설치해 그대로 실행한 결과도 아닙니다.
Blender 4.3.2에 맞춘 자체 스크립트를 사용합니다.

- A: 붉은 벽돌, 경사지붕, 석재 창틀, 작은 측면 발코니.
- B: 밝은 외벽, 평지붕, 우드 포인트, 넓은 전면 발코니, 열린 옥상 퍼골라.
- 공통: 4층, 층고 3.05m, 부지 16×16m (4m/cell), 투명 RGBA PNG, 고정 2:1 투영.

`comparison.html`을 브라우저에서 열어 비교하고, 각 폴더의 mansion.png,
reverse-review.png 및 편집 가능한 mansion.blend를 확인하세요.
metadata.json에는 피벗·부지 꼭짓점·층수·좌표·시점·제한사항이 들어 있습니다.

## 재생성

저장소 루트에서:

```sh
blender --background --factory-startup --python-exit-code 1 \
  --python assets/mansion-study/build_mansions.py -- --variant A --samples 64
blender --background --factory-startup --python-exit-code 1 \
  --python assets/mansion-study/build_mansions.py -- --variant B --samples 64
```

동일 출력 폴더를 갱신하므로 직접 수정한 .blend가 있으면 먼저 다른 이름으로 보관하세요.
프로젝트 생성 스크립트는 기본 장면을 빈 상태로 시작하며 다른 Blender 작업 파일은 열지 않습니다.
외부 모델·텍스처·폰트를 다운로드하지 않으며 Claude 로그인이나 생성 API 호출이 없습니다.
검토한 공개 스킬 원본과 라이선스는 ../../docs/asset-skills/sources.lock.json에 기록되어 있습니다.

## 현재 범위

시각 비교용 컨셉 애셋입니다. Godot에 자동 연결하지 않았으며 최종 게임용 피벗 변환,
작은 해상도 정리, 충돌·LOD·아틀라스·선택 영역의 게임 통합은 별도 작업입니다.
현대형의 청색 발코니 패널은 반투명 셰이더가 아닌 스타일화된 불투명 재질입니다.
실내·실제 세대 평면도·건축법 검토를 포함하지 않습니다.

## 게임 등록 상태

두 안은 사용자 승인으로 중형 주거 카테고리에 채택했습니다.
Godot 런타임 PNG와 피벗은 ../../cities_do/assets/buildings/catalog.json에 등록되어
4×4 주거 성장 시 표시됩니다. 위의 초기 시안 범위 설명과 별도로, 현재는 이
정적 이미지 연결과 알파 선택·격자 정렬 검증이 완료되어 있습니다. 원본 메타데이터와
생성 시점 로그는 보존했으며 최종 LOD·아틀라스·실내 등은 여전히 별도입니다.
