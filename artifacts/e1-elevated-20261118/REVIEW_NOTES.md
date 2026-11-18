# E1 six independent-review blockers — repaired, parent re-review pending

## Current six-blocker repair

HEAD remains `8ad4117f17a9cfa92b3783fbf26d3b5de4db2348` on `perf/render-sim-cadence`; all changes remain unstaged. Fresh related acceptance is **543 headless assertions across nine deduplicated suites**, plus **38 native no-capture assertions**. All exited zero with no error/warning diagnostics. The prior four fixture-cleanup files are preserved unchanged.

1. **Actual ramp/deck cars:** retained renderer calls `elevated.lift_vehicle` using real lane/source road, interpolated height and full body footprint; culling uses lifted bounds. Ground catenary synchronization previously reset the sort anchor after lifting; raised cars are now excluded from that ground-only reset. Real production traffic sedan at ramp and flat-deck positions passes physical artwork lift and furthest-overlapping-piece rear/car/front ordering in headless and native GL.
2. **Support boundaries:** support admission now checks first/last eligible deck boundary to first/last support, not only internal support gaps. The reported `(10,40)→(50,40)` ground overlap beneath `(10,40)→(90,40)` at +10m and its mirrored last-boundary case reject atomically. Actual demolition of a legacy-obstructed road also rejects unsupported survivors without changing road records or ID watermark.
3. **Height-layer drawing:** snap, tangent, grid context, angle assistance and overlay fitting use the selected layer before authoritative commit, preserving inherited grid lattices. Native mouse construction verifies a feasible 8-lane +10m deck stacked over a 2-lane ground road with grid off/on; a same-profile resolver check independently proves it no longer incorrectly returns already-road before height/support admission. This does not waive support rejection for an entirely obstructed same-width stack.
4. **Park/deck order:** actual footprint intersections place parks before every overlapping deck piece, including when the deck is added after the retained park. Road edits invalidate the dependency. Cached bounds remain unchanged; native sprite offsets compensate the changed anchor.
5. **Final junction geometry:** authoritative admission checks actual resulting T/cross patches as well as the stroke. Patch-only private overlap returns exact confirmation IDs; wrong approval/public overlap rejects before mutation. T and cross fixtures prove their lot misses the proposed ribbon but intersects the final patch, followed by exact confirmed demolition.
6. **Solid ramps:** both public park placement and road-over-park admission share the usable-under-deck test. Earth-filled sections below +5m reject parks in both placement orders; equivalent +10m decks remain permitted.

RED production-path failures were observed before fixes; no RED logs were saved. Final raw logs replace superseded suite runs and are hashed in `manifest.json`. `test_elevated_roads` is 74/74, headless UI 37/37, native UI 38/38 (extra native sprite compensation assertion), FIFO 12/12; the other six related suites remain 50/46/30/23/67/204. No benchmark, timing collection, import, build, install, new capture, user-game closure, asset/protected-document edit, staging, commit, push, main or E2/E3 work occurred. Original capture remains **pre-fix historical evidence only**, not visual proof of these corrections. Parent independent re-review remains outstanding.

## Historical acceptance before this repair (superseded counts/source claims)


Repository remains `perf/render-sim-cadence` at `8ad4117f17a9cfa92b3783fbf26d3b5de4db2348`. Nothing was staged, committed, pushed, merged, or switched. Review mode: implementer self-review; independent parent review is still required.

## Implemented

- Per-point metre heights, 5m flat layers, 8% local / 5% highway limits and upward 8m ramp-length rounding; full-width clearance checks against roads and 10m rail structures.
- Height-aware topology, continuation/render chains, road fragments and traffic sprite lift. Raised pavement is excluded from the ground road/zoning layers and ground building frontage.
- Native C height controls (underground disabled), +/-5m and PgUp/PgDn; elevated preview, ground projections and support preview. B cursor-side private-building warning, count and confirmation/cancel. Confirmation stores exact demolition IDs, rechecks before commit, and passes them through deferred FIFO replay.
- Original retaining-wall/side textures and assembled original pier parts in production WorldActors; retaining sections below +5m, piers at/above +5m, two supports for W >= 14m, layered deck/vehicle draw ordering and raised junction surfaces.
- Public-facility blocking, private-building yellow confirmation, parks beneath decks, support collision avoidance. Fragment support geometry is rebuilt before demolition mutation.
- Actual production worker gate/FIFO, journal ingestion, road-ID watermark and checkpoint restoration tests.

## Evidence and limits

Raw logs are direct stdout/stderr captures from `tools/verify_e1_elevated.py`, which only invokes Godot through `tools/run_dotnet.py`. No benchmark or timing collector is invoked. `manifest.json` contains deduplicated suite results, current source hashes and exact original asset hashes.

All nine related headless gates are now clean: **480/480 assertions**, zero error/warning diagnostics. Fresh repairs: profile 50/50, side-contact 46/46, junction boxes 67/67, frontage 204/204. Unchanged model 33/33, UI 15/15, FIFO 12/12, seams 30/30 and demolition 23/23 reuse their matching original source/log evidence; they are not represented as fresh reruns.

Root causes were reproduced before correction, without saving new RED logs. The profile fixture reproduced its unfinished-thread/resource errors despite 50 passing assertions. Both actual-main fixtures now call the prior model's real `simulation.shutdown()` before replacement; the existing mailbox shutdown calls `JoinNative()`. No diagnostics were suppressed, and the runner now rejects warnings as well as errors.

The junction fixture reproduced six failures: it still expected 1.25 cells for the old two-cell local-road width. Approved width grades (`docs/design/ROAD_DRAWING_KO.md`, 2026-11-13) require three cells for two lanes including shoulders. The oracle is now 1.75 = 3/2 + .22 + .03, with five extra assertions pinning three/eight-cell widths; all existing geometry assertions remain. Frontage's formerly unchecked dictionary access was replaced by explicit success assertions, reproducing `도로와 충돌합니다` instead of a timeout. The original lot y=15..19 overlapped a road centered at 20 by .5 cells. Supporting roads now sit at 20.5/13.5, retaining the original lot, all orientation/rebinding/highway/model assertions, and production collision/access guards. Production E1 source was not changed. No pinned baseline replay was run or claimed; these are diagnosed fixture repairs, not waived baseline failures.

### Exactly one native capture

`e1-native-1920.png` is the sole native capture. Its raw log records Windows / NVIDIA RTX 2070 SUPER / OpenGL 3.3 / gl_compatibility / 1920x1080 / max_fps 30. No timing measurements were collected.

The inherited visual inspection shows retaining ramp, raised roadway surfaces, assembled piers, a +20m crossing above the +10m road, adjacent original buildings and C controls. **That original image lacks B's warning and its run remains 16/17**, not a pass. The endpoint-under-drawer fixture correction is now exercised in actual Windows OpenGL native UI: **15/15 clean**, including final B+C composition, through `python tools/verify_e1_elevated.py --native-no-capture`. This omits only the two image size/save assertions, takes no framebuffer and saves no image. The existing capture and historical failed native log remain unchanged. The old image cannot prove the corrected B appearance; no fresh visual approval is claimed.

## Configuration pending

`cities_do/core/elevated_road_config.json` records construction/upkeep formulas as null and height charging disabled pending approval. This does not designate zero as an approved price. The existing road charging behaviour remains unchanged. The support search resolution is explicitly a reversible implementation default.

## Asset provenance and exclusions

Only original files under `assets/structures/`, `cities_do/assets/structures/`, and the approved facility catalog were copied from `517bd05`; the two-pier v2 spec is from `39ae3b9`. Catalog's exact delta adds the two inspection-only structure samples; those entries are excluded from map-tool buttons. Existing catalog bytes were verified against HEAD after Git CRLF normalization before copying the exact approved blob. Originals were not generated or edited.

Protected design/concept/mistake documents were read only. Shared checkout contains many unrelated modified `.import` and other files; these are excluded, not restored or staged. No `.uid` or `.import` file belongs to the handoff. E2/E3/E4 and interchanges were not implemented. Do not stage broad directories or all checkout changes.

## Parent review focus

- The four regression failures and corrected actual native UI acceptance are closed. Parent independent E1 review remains pending; old-capture visual limitation remains explicitly recorded, not an unrun native interaction gate.
- Review the height-aware geometry/contact rules, support spacing including end cantilevers and demolition-fragment behaviour, exact confirmed-ID replay, and deck/building/vehicle depth ordering on neighboring cases.
- Road height costs remain pending; no approved financial formula was invented.
- Preserve the original `manifest.json` 22-source/40-asset lists. Four necessary regression-fixture changes are separately enumerated under `acceptance_repair_sources`; do not silently expand or replace the original list. The two owned evidence tools add no-capture execution, strict diagnostics, deduplicated results and read-only manifest calculation. E2/E3 must wait for E1 review/acceptance.
