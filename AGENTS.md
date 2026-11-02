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
when removing explanatory text. Current layout review is bottom_ui_preview.tscn.

Road intersections: read `docs/ROAD_JUNCTIONS_KO.md`. Same-level centreline
crossings form actual junctions with derived lane sections/turn connectors.
Keep original road/parcel IDs and demolition semantics. Reserve junctions before
entry, keep reservations through rear clearance, and do not enter blocked exits.
Junction pavement must be excluded from building/utility/parcel footprints.
Keep corners square at right-angle crossings: use the union of road-width strips,
not a flared convex hull that cuts into adjacent zoning. Keep turn paths on pavement.
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
