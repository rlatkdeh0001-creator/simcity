"""Record E1 owned-source, original-asset and raw-evidence hashes; never changes inputs."""
import hashlib
import json
import pathlib
import re
import struct
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/e1-elevated-20261118"
SOURCES = [
    "cities_do/bottom_ui.gd",
    *["cities_do/core/" + p for p in (
        "building_frontage.gd", "cached_world_renderer.gd", "city_model.gd",
        "city_simulation.gd", "city_simulation_worker.gd", "public_facilities.gd",
        "road_demolition.gd", "road_drawing.gd", "road_geometry.gd",
        "road_junctions.gd", "road_length_units.gd", "road_height.gd",
        "road_height_controls.gd", "road_demolition_warning.gd",
        "elevated_road_renderer.gd", "elevated_road_config.json")],
    "cities_do/tests/test_elevated_roads.gd",
    "cities_do/tests/test_elevated_road_ui.gd",
    "cities_do/tests/test_elevated_roads_fifo.gd",
    "tools/verify_e1_elevated.py", "tools/manifest_e1_elevated.py",
]
REPAIR_SOURCES = [
    "cities_do/tests/test_road_profile_connections.gd",
    "cities_do/tests/test_road_side_contacts.gd",
    "cities_do/tests/test_road_junction_boxes.gd",
    "cities_do/tests/test_building_frontage.gd",
]

def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], stderr=subprocess.PIPE)

def record(path):
    data = (ROOT / path).read_bytes()
    return {"path": path, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}

def main():
    branch = git("branch", "--show-current").decode().strip()
    head = git("rev-parse", "HEAD").decode().strip()
    assert branch == "perf/render-sim-cadence" and head.startswith("8ad4117")
    assert not git("diff", "--cached", "--name-only").strip(), "Index is not empty"
    # The six-blocker repair does not change assets. Preserve approved provenance;
    # a repeated whole-asset audit belongs to integration, not this correction.
    assets = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))["original_assets"]
    assert len(assets) == 40
    current = json.loads((OUT / "test-results.json").read_text(encoding="utf-8"))
    from verify_e1_elevated import TESTS
    assert len(current) == len(TESTS) and {r["name"] for r in current} == set(TESTS)
    native = json.loads((OUT / "native-no-capture-results.json").read_text(encoding="utf-8"))
    assert len(native) == 1 and native[0]["name"] == "test_elevated_road_ui-native-no-capture"
    for row in current + native:
        raw = (OUT / (row["name"] + ".log")).read_text(encoding="utf-8")
        diagnostics = re.findall(r"^(?:SCRIPT ERROR|ERROR|FAIL|WARNING|Owned toolchain process exceeded)[^\n]*", raw, re.M)
        assert row["passed_lines"] == len(re.findall(r"^PASS ", raw, re.M)), row["name"]
        assert not row["exit_code"] and not row["errors"] and not diagnostics, row["name"]
    suites = []
    for log in sorted(OUT.glob("*.log")):
        raw = log.read_text(encoding="utf-8")
        suites.append({"name": log.stem, "log": record(log.relative_to(ROOT).as_posix()), "passing_assertion_lines": len(re.findall(r"^PASS ", raw, re.M)), "diagnostics": re.findall(r"^(?:SCRIPT ERROR|ERROR|FAIL|WARNING|Owned toolchain process exceeded)[^\n]*", raw, re.M), "current_headless_gate": log.stem in {r["name"] for r in current}})
    capture = OUT / "e1-native-1920.png"
    assert len(list(OUT.glob("*.png"))) == 1
    data = capture.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    dimensions = struct.unpack(">II", data[16:24])
    assert dimensions == (1920, 1080)
    sources = [record(p) for p in sorted(SOURCES)]
    added = git("diff", "--", *SOURCES, *REPAIR_SOURCES).decode(errors="replace")
    added = "\n".join(s[1:] for s in added.splitlines() if s.startswith("+") and not s.startswith("+++"))
    for p in SOURCES:
        result = subprocess.run(["git", "ls-files", "--error-unmatch", "--", p], cwd=ROOT, capture_output=True)
        if result.returncode:
            added += "\n" + (ROOT / p).read_text(encoding="utf-8")
    scan = {"shell_true": r"shell\s*=\s*True", "unsafe_deserialization": r"pickle\.loads?\(", "dynamic_eval": r"\beval\("}
    findings = {key: bool(re.search(pattern, added)) for key, pattern in scan.items()}
    report = {
        "scope": "E1 elevated roads only", "branch": branch, "head": head,
        "verdict": "SIX_REVIEW_BLOCKERS_REPAIRED: nine fresh headless gates and actual native no-capture render/input gate clean; parent review pending",
        "review_mode": "repair self-review; parent independent E1 review pending",
        "owned_source_count": len(sources), "owned_sources": sources,
        "acceptance_repair_source_count": len(REPAIR_SOURCES),
        "acceptance_repair_sources": [record(p) for p in REPAIR_SOURCES],
        "original_asset_count": len(assets), "original_assets": assets,
        "asset_verification": "Inherited approved 40-asset provenance preserved; no assets edited or full asset audit repeated in this repair",
        "current_headless_results": current,
        "current_headless_passing_assertions": sum(r["passed_lines"] for r in current),
        "current_clean_passing_assertions": sum(r["passed_lines"] for r in current if not r["errors"] and not r["exit_code"]),
        "suite_logs": suites,
        "native_results": native,
        "historical_capture_results": json.loads((OUT / "native-results.json").read_text(encoding="utf-8")),
        "capture": {**record(capture.relative_to(ROOT).as_posix()), "dimensions": dimensions, "count": 1, "inspected": True, "limitation": "Unchanged historical pre-fix capture lacks B warning and is not evidence of these six corrections. Fresh native render/input assertions pass without framebuffer access or any new capture."},
        "evidence_reuse": {"unchanged_passing_suites": [], "fresh_headless_suites": list(TESTS), "production_source_changed_by_repair": True},
        "baseline_proof": "Production-path failures were observed before fixes for car lift/sort, boundary supports, layer snap/tangent, park/deck sort, final junction collisions and solid-ramp park placement. RED output was not saved. No pinned baseline replay claimed.",
        "blocker_proofs": [
            {"id": 1, "production": "cached_world_renderer._process -> elevated.lift_vehicle; raised bounds; ground catenary no longer resets raised car anchors", "test": "test_elevated_road_ui.test_production_ramp_car", "native": True},
            {"id": 2, "production": "road_height.supports checks both boundary spans before admission and demolition-fragment mutation", "test": "test_elevated_roads.test_support_boundaries and actual demolish_road_selection rejection"},
            {"id": 3, "production": "road_drawing layer-filtered snap/tangent/grid/overlay before height-aware commit", "test": "test_elevated_road_ui.test_stacked_flow; real mouse grid off/on", "native": True},
            {"id": 4, "production": "cached_world_renderer footprint-overlapping park/deck dependency invalidated by road edits; compensated sprite offset", "test": "test_elevated_road_ui.test_park_depth", "native": True},
            {"id": 5, "production": "city_model.add_elevated_road final T/cross patches included in public rejection and exact private confirmation IDs before mutation", "test": "test_elevated_roads.test_junction_obstacles false/true; patch-only overlap and atomic rejection"},
            {"id": 6, "production": "city_model placement and road admission share usable_under_deck height threshold; solid retaining ramp is not park space", "test": "test_elevated_roads.test_solid_ramp_parks; both placement orders with usable-deck controls"},
        ],
        "review_notes": record((OUT / "REVIEW_NOTES.md").relative_to(ROOT).as_posix()),
        "security_scan": findings,
        "excluded": ["all .import/.uid metadata", "protected design/concept/mistake documents", "all other unrelated checkout changes"],
        "no_stage_commit_push_branch_switch": True, "benchmarks_run": False, "timing_collection": False,
    }
    # Calculation only: caller applies the returned report through the file tool.
    for entry in report["owned_sources"] + report["acceptance_repair_sources"]:
        assert record(entry["path"])["sha256"] == entry["sha256"]
    return report

if __name__ == "__main__":
    print(json.dumps(main(), ensure_ascii=False, indent=2))
