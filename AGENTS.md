# User feedback and recurring mistakes

Read `mistake.md` at the start of every task, alongside this file and the handoff.
Before implementing or creating assets, apply its relevant prevention rules. When the
user identifies an unsatisfactory result, update mistake.md in the same work with the
actual feedback, verified cause (or unknown), prevention, validation and status/evidence.
Do not invent complaints or classify every new requirement as a mistake. Preserve
resolved entries and distinguish inherited evidence from checks run now. Current user
instructions take precedence. Do not add approval gates merely because of this log.

# Project skills

Power rule: read `docs/ELECTRICITY_RULES_KO.md` before implementing electricity.
Connected eligible consumers receive power simultaneously when supply suffices.
White traveling circles are display-only: their arrival, disappearance, speed,
count or visibility must never gate supply or change power/trade billing.

Water/sewage rule: read `docs/WATER_SEWAGE_KO.md`. Install/remove both pipes
atomically. Blue supply flows source-to-consumer; brown sewage flows consumer-to-sink.
Fluid circles, wobble, visibility and visual pause never affect actual services
or metering. Use m³/game day for rates and m³ for volume; do not reuse electric tariffs.
Water trade tariffs were delegated and applied: read `docs/WATER_TARIFFS_KO.md`.
Edit `cities_do/core/water_tariffs.json`; include both utilities' fractional balances
in the available funds calculation. Construction/upkeep proposals remain separate.

UI rule (user, 2026-11-02): reference Cities: Skylines' compact bottom categories,
asset chooser above and status/time row below. Keep our own icons and game art.
Do not put supply-radius/node-spacing explanations, development notes or tutorials
in player-facing HUDs. Keep those in docs. Tool labels, meaningful live values and
short action/error feedback remain appropriate. Do not change simulation rules
when removing explanatory text. Main now uses the shared bottom_ui.gd HUD;
bottom_ui_preview.tscn is an authored review fixture, not the playable city's initial state.
UI mockups first (user, 2026-11-10; mistake.md M-008): before implementing any UI/HUD/menu
layout change, show about 3 mockup options and implement only the one the user approves.

Road intersections: read `docs/ROAD_JUNCTIONS_KO.md`. Same-level centreline
crossings form actual junctions with derived lane sections/turn connectors.
Keep original road/parcel IDs and demolition semantics. Reserve junctions before
entry, keep reservations through rear clearance, and do not enter blocked exits.
Junction pavement must be excluded from building/utility/parcel footprints.
Keep corners square at right-angle crossings: use the union of road-width strips,
not a flared convex hull that cuts into adjacent zoning. Keep turn paths on pavement.
Place crosswalks per approach using the intersecting road edge/width; never use
the shared maximum junction control radius to space all crosswalks equally.
No explanatory mechanics text in player HUDs; keep limits in docs.

Placement-grid rule (user, 2026-11-02): hide roadside placement tiles by default.
Show them only for the zoning (구획, previously 건설) or road tab, never in
bulldozer/utility/other views. Hide rendering, not the underlying parcel data.
Use one rightmost bulldozer for visible buildings/roads/utilities; no duplicate
per-utility demolition buttons. Keep surviving road parcel IDs stable on deletion.
Read `docs/concepts/bottom-ui/DEMOLITION_ZONING_KO.md` for current scope.

Economic values register: `docs/economy-balance/ECONOMY_BALANCE.csv` is the single
editable overview requested by the user. Keep it in sync when changing economic
values. Preserve units, approval/application status and source locations. It is
currently a management sheet, not a runtime loader; synchronize live code/JSON
when applying approved edits. Blank undecided values are not zero.

## Road-adjacent lots (user rule, 2026-11-02)

Read `docs/BUILDING_ROAD_ADJACENCY_KO.md`. Place building lots in the road-adjacent
row. Maximum road-to-lot-front gap is 1.5 metres = 0.375 city cells, measured from
the sidewalk-inclusive road edge. The previous 10m proximity allowance is obsolete.
Use the shared frontage candidate validation for placement, growth and direction;
a nearby corner alone is insufficient. Keep internal yards and physical scale.
Do not force deep clicks onto occupied front lots or move existing buildings en masse.

## Building frontage (user rule, 2026-11-02)

A building's main entrance/front must face its accessible local road, not a fixed
screen compass direction. Read `docs/BUILDING_FRONTAGE_KO.md`. Store the frontage
road's stable ID and world front direction. Apply the same direction to placement,
growth, rendering and picking; preserve square lots and physical scale. At corners,
keep a valid existing frontage. Rebind when it disappears; highways do not provide
frontage. Use original-direction sprites only when they match; use real rotated
3D/directional assets for other views, never warp a fixed-camera image. Future
assets and eventual save-game serialization must honor this rule too.

## Shared asset scale

Keep 1 city cell = 4 metres. Vehicle and building rendering must share a physical
metre scale; normalize by camera calibration/lot width, not PNG canvas dimensions.
Before changing global scale, read `docs/ASSET_SCALE_REVIEW_KO.md`. The current
2x2 houses have small measured bodies; do not infer a renderer error
from their size alone. Compare doors, floor height and vehicle clearance as well.

## Asset pricing proposals (user requirement, 2026-11-02)

For every newly created asset, propose a construction price and recurring upkeep
in doth, with units, rationale, comparable assets and effect on the 50,000 doth
normal starting budget. Record proposals in `docs/PRICE_PROPOSALS_KO.md` (or a
linked asset proposal). Mark them proposed until the user approves; do not turn
a proposal into live charges without approval. Residential/commercial/industrial
zoning and automatic building construction have no municipal construction fee.
The confirmed design is drag-painted zones with automatic development; distinguish
this rule from the current click-placement/manual-growth prototype.
Also propose capacity/production/throughput, explicit time units, rated versus
average output, own resource demand, bottlenecks and residual outputs; consult
`docs/CAPACITY_PROPOSALS_KO.md`. Storage is not production. Do not count serial
network segment capacities additively or treat all proposed balance values as approved.

## Persistent skill handoff (user requirement)

At the start of every resumed/new session, read `docs/SKILL_HANDOFF_KO.md` and
check the actual checkout, Git status, and referenced evidence before continuing.
This register records installed skills, applied techniques, validation and limits;
it is not permanent model memory. Read the relevant SKILL.md before applying it.

Whenever introducing, adapting, applying, updating or validating a skill/tool,
update `docs/SKILL_HANDOFF_KO.md` in the same work: exact name/path, upstream URL
and pinned commit, license/NOTICE, actual use and affected files, commands/results,
unverified capabilities and next steps. Distinguish inherited evidence from tests
run in the current session. Preserve upstream files; record adaptations separately.
Do not invent missing skill names or call an addon a skill. Keep credentials out.
Commit and push the register with the related work within the user's authorized
scope. Report a failed push explicitly. Give this user GitHub links, not workspace
download links. Existing ZIPs are snapshots; current Git files are authoritative.

Use the existing /workspace/simcity checkout. Do not create a worktree unless requested.

Official Anthropic skills are installed in `.agents/skills/`. When a user names a skill or a task clearly matches one, read that skill's `SKILL.md` before applying it. Read linked resources only as needed. Resolve relative paths against the skill directory. Mention the selected skill briefly to the user. Follow user and platform instructions over skill instructions.

The skill catalog is in README.md. These are instructions for this agent, not a Claude CLI integration. Claude login is not required. Do not automatically run bundled scripts, install every skill dependency, enable external services, or spawn agents merely because files are present. Install only task-required dependencies and validate their operations. Some skill references mention Claude-specific tools; use available equivalent tools and explain unsupported capabilities.

Do not claim proprietary document skills are installed or that every skill runtime has been tested.

## Drag zoning and automatic construction (user, 2026-11-03)

Read `docs/ZONING_DEVELOPMENT_KO.md`. Zoning is a drag designation tool, not immediate
click construction. Use city.paint_zones and zone_designations keyed by stable road-local
parcel IDs. Develop only uniformly zoned 2x2 lots via the shared frontage/collision path.
Repainting/erasing preserves existing buildings and their uses; the common bulldozer is
separate. Prune only removed parcels after road changes. Keep zoning free and new private
construction free. The original ungated development was superseded by population demand;
read POPULATION_TIME_KO.md for the current clock and prototype household model. Pause/speed affect it, tab visibility does not. Keep original
2x2 display-only asset flags; procedural fallback is intentional until models are enabled.

## Population, jobs and clock (user, 2026-11-03)

Read docs/POPULATION_TIME_KO.md. At 1x one real hour is one game day; twelve game
days are one year. 05:00-09:00 commuting is ten real minutes; routes remain future.
Use city.clock and convert real delta by Clock.SCALE only at utility API boundaries.
Advance society on fixed ticks. Start with residential demand only; actual immigrants
then create commercial/industrial demand. Five job education bands accept absolute
education difference <=1, same-stage priority, working age independent of education.
Local births start at stage zero and need recorded education, not inherited degrees.
Keep population_config.json prototype values synchronized with the economy CSV.
Do not present school completion API as school operation or employment as commuting.

## New environment freshness check

Before reporting a requested feature or asset as absent, compare the local commit
with origin/main (fetch when available) and read the latest handoff. A stale checkout
is not evidence that work is missing. Preserve completed models and distinguish
asset registration/inspection from city placement and operational simulation.

## 작업 원칙 (전역 지침 요약, 사용자 승인 2026-11-13)

- 권위 순서: 사용자 현재 지시 > 확정 기획 문서 > 저장소 규칙 > 실제 코드·실행 > 테스트·fixture. 하위가 상위를 바꾸지 않는다.
- 에이전트 제안·추정은 사용자가 승인하기 전까지 임시다.
- 낡은 기대값으로 새 규칙을 막는 테스트는 TEST DRIFT — 규칙을 되돌리지 말고 테스트를 고친다.
- 완료 = 실제 게임 화면에서 의도한 조작 흐름으로 동작이 확인됨. 테스트·대체 경로만 통과했으면 완료라 하지 않는다.
- 필요한 범위를 빠짐없이, 그 이상은 하지 않는다. 관계없는 발견은 따로 보고한다.
- 이미 승인된 작업은 다시 묻지 않는다. 막힌 부분만 멈추고 나머지는 진행한다.
- 실제로 한 일과 증거만 보고한다. 확인 못 한 것은 그대로 말한다.
- 결론부터, 결론에 영향 없는 단서·뻔한 예외는 쓰지 않는다.

## 검수 수준 (사용량 절약, 사용자 승인 2026-11-13)

- 작업 브랜치 검증은 "제대로 작동하는지"만 본다: 바뀐 기능의 관련 테스트 + 요청한 캡처만.
- 애셋 등록·교체: 게임에서 로드되고 크기·정면이 맞는지 1회 확인 + 캡처 1장. 원본 해시 전수 대조·삼각형/재질 상세 감사·이미지 검증 JSON은 하지 않는다.
- 전체 회귀 테스트·원본 보호 파일 대조는 main 병합 직전 1회만.
- 보고는 5줄 이내: 브랜치·SHA·통과 수·캡처 경로·막힌 점. README·검증 폴더 긴 문서는 main 병합 때만.
- 같은 테스트를 이유 없이 반복 실행하지 않는다. 다시 돌리는 건 코드가 바뀌었거나 실패했을 때만.
- RED 로그·중간 결과 파일은 남기지 않는다(최종 결과만).
