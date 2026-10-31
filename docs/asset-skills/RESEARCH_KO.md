# CITIES_DO 건물 애셋 스킬 조사·추적

확인일: 2026-10-31 (Asia/Seoul). 이번 작업은 **원본 스킬과 도구의 조사**다.
제3자 스킬을 새로 설치하거나 실행하지 않았고, 건물 이미지를 생성하지 않았다.

## 추천

CITIES_DO는 **파라미터로 건물 모델 생성 → 고정 시점 렌더 → 투명 PNG → Godot**
방식을 기본으로 삼는 것이 적합하다. 2×2·4×4·8×8의 부지와 광원·카메라를
고정할 수 있고, 같은 건물의 층수·색상·지붕을 바꿔 일관된 변형을 만들기 쉽다.
외부 이미지 생성 API 없이도 Blender Python으로 구현할 수 있다.
이는 설계 권고이며, 이번 조사에서 이 파이프라인을 실행 검증한 것은 아니다.

가장 가까운 공개 제작 스킬은 **blender-kiln**이다. 다만 원본의 Claude 플러그인
명령·MCP 도구·Studio 워커를 Codex에 그대로 설치하면 된다는 뜻은 아니다.
우리 에이전트가 지침을 읽고 Blender CLI 경로로 맞춰 쓰는 별도 연결이 필요하다.

## 원본 확인 결과

| 후보 | 분류 | 실제 파일·저장소 | CITIES_DO 적용 | 인증·환경·제약 |
|---|---|---|---|---|
| **game-art** | 실제 SKILL.md | [antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills/blob/6844ad2b0e3724caad0c50fa974fbaf475cf80a3/skills/game-development/game-art/SKILL.md) | 스타일, 팔레트, 스프라이트/아틀라스, 스케일과 파일명 기준 수립 | MIT 확인. 지침 스킬이며 건물 생성기는 없음. 자체 사용에 Claude 인증 불필요 |
| **kiln / blender-kiln** | 실제 SKILL.md 및 보조 스크립트 | [plugin/SKILL.md](https://github.com/elithril/blender-kiln/blob/4e8a1c942804f2a6b1a27ea16169b3ec30249a0a/plugin/SKILL.md) | 모델링·정리·재질·일괄 제작·GLB 등 내보내기. 건물 제작 기반으로 가장 가까움 | MIT 확인. 원본은 Blender 4.4+와 Claude/MCP 흐름을 전제. 기본 스크립트 모델링 자체에 생성 API가 필요하지 않음. Studio의 Claude 작업 기능은 별도 |
| **fal-gamedev** | 실제 SKILL.md | [skills/fal-gamedev/SKILL.md](https://github.com/fal-ai-community/skills/blob/9ca850412943251fc9a466c4c29fdaf7a303a3d8/skills/fal-gamedev/SKILL.md) | 픽셀 아트, 스프라이트, 배경 제거, 아이소메트릭 맵. 컨셉·보조 이미지 후보 | genmedia CLI와 fal API 키·서비스 비용 필요. 정밀한 부지/피벗을 보장하는 건물 전용 생성기는 아님. README는 MIT라 쓰지만 Git 트리에 루트/해당 스킬 LICENSE가 없으므로 복제·배포 조건 추가 확인 필요 |
| **Aseprite MCP** | MCP 도구, 스킬과 구분 | [diivi/aseprite-mcp](https://github.com/diivi/aseprite-mcp/tree/a89b205bed31930ee141edf319e78c71ef16bba6) | 팔레트·레이어·픽셀 보정·아틀라스 내보내기. 아이소메트릭 예시 포함 | MCP 코드 MIT 확인. Aseprite 프로그램 자체의 설치·라이선스는 별도. 현재 실행 파일 없음. MCP 서버 설정 필요, 특정 Claude 모델 전용 도구는 아님 |
| **Blender MCP** | MCP 도구, 스킬과 구분 | [ahujasid/blender-mcp](https://github.com/ahujasid/blender-mcp/tree/992233bb258975a05eec8b5691465c50c2831e34) | Blender 장면 생성·Python 실행·모델 검사 연결 | MIT 확인. 현재 문서의 패키지명은 mcp-for-blender. Blender 애드온/MCP 서버 필요. 외부 생성·마켓플레이스 기능은 각 서비스 조건이 따름. 이번에는 설치하지 않음 |
| **canvas-design** | 기존 설치 스킬 | [Anthropic 원본](https://github.com/anthropics/skills/blob/ca45fc496a3436251f191354091d557da31c15b5/skills/canvas-design/SKILL.md) | 아트 방향·레퍼런스 시트 등 보조 | Apache-2.0 확인. 포스터/정적 아트 중심이며 부지 규격·스프라이트 추출 기능 없음 |
| **algorithmic-art** | 기존 설치 스킬 | [Anthropic 원본](https://github.com/anthropics/skills/blob/ca45fc496a3436251f191354091d557da31c15b5/skills/algorithmic-art/SKILL.md) | 시드 기반 변형 제작 원리 참고 | Apache-2.0 확인. p5.js 생성 예술 중심이며 건물 전용 스킬은 아님 |

MIT 등은 해당 저장소 코드/스킬 라이선스 관찰이다. 가져오는 3D 모델·텍스처·폰트나
외부 생성 서비스의 산출물까지 동일 라이선스라고 간주하지 않는다.

## 이 환경의 준비 상태

- Blender: `blender --version` 결과 **4.3.2**. kiln 문서의 최소 4.4보다 낮음.
  원본 툴킷 전체를 준비 완료로 볼 수 없다.
- Aseprite·LibreSprite 실행 파일: PATH에서 발견되지 않음.
- Blender MCP / Aseprite MCP: 이번 조사에서 설치·연결·실행 검증하지 않음.
- Claude 로그인 없이 제작하려면: Codex가 Blender Python을 작성하고 로컬 Blender로
  실행하는 경로를 우선 검증. kiln을 쓰려면 버전 및 도구 연결을 맞추고 테스트 필요.
- fal/기타 외부 생성 API: 호출하거나 키를 요청하지 않음. 인증·과금 경로 미검증.

## CITIES_DO 전용 스킬에 필요한 추가 규약

일반 게임 아트 스킬만으로 아래 사항이 자동 충족되지는 않는다.

1. **크기와 발전을 분리**: R/C/I 업종 × 부지 2/4/8 × 레벨 × 변형 시드.
   게임에서는 레벨이 올라가도 작은 부지가 가능하므로 부지와 층수를 동일시하지 않는다.
2. **투영 일치**: 현재 Godot의 cell diamond는 28×14 픽셀(2:1).
   권장 소스가 64×32라면 2×2 바닥은 128×64, 4×4는 256×128, 8×8은 512×256.
   Godot 표시 배율 28/64를 메타데이터에 명시한다. 높이·그림자 여백은 별도로 추가한다.
   2:1 투영은 수학적 정등각과 다르므로 Blender 카메라를 눈대중으로 두지 않는다.
3. **피벗 명시**: 바닥 다이아몬드의 기준점과 이미지 내부 anchor_px를 기록한다.
   바닥 앞 꼭짓점을 피벗으로 쓰면 현재 모델의 screen(x+size, y+size)에 정렬한다.
   PNG 중앙을 부지 중심으로 간주하지 않는다.
4. **출력**: 편집 가능한 .blend와 생성 스크립트, 투명 RGBA PNG,
   asset_id/zone/footprint/level/seed/tile_px/anchor_px/source/license 메타데이터.
5. **고정 스타일**: 카메라·조명·팔레트·텍셀 밀도·그림자 방향 통일.
   우선 현재 게임의 고정 시점 1개부터 검증하고 회전 뷰는 후속 작업으로 둔다.
6. **품질 확인**: 바닥 규격, 잘린 지붕·그림자, 알파, 파일명 충돌, 시드 재현성,
   Godot 지도에서 도로·이웃 건물과의 정렬을 실제로 검사한다.

## 추적 방식

`sources.lock.json`에 **7개 후보/기존 스킬**, 저장소 6개, 원본 HEAD 커밋,
SKILL.md/README/LICENSE 등 **19개 파일 SHA-256**과 고정 링크를 기록했다.
원본 파일을 실행하지 않고 내용만 읽어 해시를 계산했다.

```sh
# 로컬 목록 조회: 네트워크 없음
python3 tools/track_asset_skills.py
# 현재 원격 HEAD가 바뀌었는지 확인: 변경본을 설치하거나 잠금을 바꾸지 않음
python3 tools/track_asset_skills.py --check-heads
# 검토했던 커밋의 19개 파일이 기록한 해시와 일치하는지 확인
python3 tools/track_asset_skills.py --verify-pins
```

도구는 읽기 전용이다. 자동 설치·자동 업데이트·정기 실행은 설정하지 않았다.
새 HEAD 발견은 수정 검토가 필요하다는 뜻이며 기능이 개선되었다는 판정이 아니다.

검색은 접근 가능한 GitHub 원본/공개 목록을 사용했다. skills.sh 및 GitHub REST
검색 API는 이 환경 네트워크 정책에서 403으로 차단되어 검색 범위에 포함하지 못했다.
확인되지 않은 검색 결과나 존재하지 않는 경로를 후보로 기록하지 않았다.
