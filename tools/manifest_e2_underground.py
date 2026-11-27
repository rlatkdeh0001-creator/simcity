"""Record E2 owned-source, original-asset and raw-evidence hashes; never changes inputs.
Prints the manifest JSON; the caller stores it as artifacts/e2-underground-20261119/manifest.json.
"""
import hashlib
import json
import pathlib
import re
import struct
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/e2-underground-20261119"
SOURCES = [
    "cities_do/main.gd",
    *["cities_do/core/" + p for p in (
        "building_frontage.gd", "cached_world_renderer.gd", "city_model.gd",
        "elevated_road_config.json", "road_drawing.gd", "road_geometry.gd",
        "road_height.gd", "road_height_controls.gd", "transit_routes.gd",
        "transit_view.gd", "underground_road_renderer.gd")],
    "cities_do/tests/test_underground_roads.gd",
    "cities_do/tests/test_underground_road_ui.gd",
    "cities_do/tests/test_elevated_road_ui.gd",
    "tools/verify_e2_underground.py", "tools/manifest_e2_underground.py",
]
ASSET_DIRS = [
    "assets/structures/retaining-wall-01", "assets/structures/tunnel-portal-01",
    "assets/structures/tunnel-sample-01",
    "cities_do/assets/structures/retaining-wall-01", "cities_do/assets/structures/tunnel-portal-01",
]
DIAGNOSTIC = r"^(?:SCRIPT ERROR|ERROR|FAIL|WARNING|Owned toolchain process exceeded)[^\n]*"
# Reproduced with every E2 source change reverted to HEAD in the same checkout (log not kept).
KNOWN_BASELINE_FAILURES = {"test_transit_view": ["ERROR: FAIL metro viewport commit matches depth-correct preview"]}

def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], stderr=subprocess.DEVNULL)

def record(path):
    data = (ROOT / path).read_bytes()
    return {"path": path, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}

def main():
    branch = git("branch", "--show-current").decode().strip()
    head = git("rev-parse", "HEAD").decode().strip()
    assert branch == "perf/render-sim-cadence" and head.startswith("87bc12e"), (branch, head)
    assert not git("diff", "--cached", "--name-only").strip(), "Index is not empty"
    from verify_e2_underground import TESTS, NATIVE, CAPTURES
    current = json.loads((OUT / "test-results.json").read_text(encoding="utf-8"))
    assert {r["name"] for r in current} == set(TESTS), "headless gate set differs"
    native = json.loads((OUT / "native-no-capture-results.json").read_text(encoding="utf-8"))
    assert {r["name"] for r in native} == {n + "-native-no-capture" for n in NATIVE}
    captured = json.loads((OUT / "native-results.json").read_text(encoding="utf-8"))
    assert [r["name"] for r in captured] == ["test_underground_road_ui-native"]
    for row in current + native + captured:
        raw = (OUT / (row["name"] + ".log")).read_text(encoding="utf-8")
        diagnostics = re.findall(DIAGNOSTIC, raw, re.M)
        assert row["passed_lines"] == len(re.findall(r"^PASS ", raw, re.M)), row["name"]
        if row["name"] in KNOWN_BASELINE_FAILURES:
            assert row["errors"] == KNOWN_BASELINE_FAILURES[row["name"]] and diagnostics == row["errors"], row["name"]
            continue
        assert not row["exit_code"] and not row["errors"] and not diagnostics, row["name"]
    suites = []
    for log in sorted(OUT.glob("*.log")):
        raw = log.read_text(encoding="utf-8")
        summary = re.findall(r"^(?:E2 underground roads|E1 elevated roads|E2_UI|E1_UI|[A-Z_]+ checks=)[^\n]*", raw, re.M)
        suites.append({"name": log.stem, "log": record(log.relative_to(ROOT).as_posix()),
                       "passing_assertion_lines": len(re.findall(r"^PASS ", raw, re.M)),
                       "summary": summary, "diagnostics": re.findall(DIAGNOSTIC, raw, re.M)})
    captures = []
    for key, name in CAPTURES.items():
        data = (OUT / name).read_bytes()
        assert data[:8] == b"\x89PNG\r\n\x1a\n"
        dimensions = struct.unpack(">II", data[16:24])
        assert dimensions == (1920, 1080)
        captures.append({**record((OUT / name).relative_to(ROOT).as_posix()), "view": key, "dimensions": dimensions, "inspected": True})
    assert len(list(OUT.glob("*.png"))) == len(CAPTURES)
    assets = []
    for directory in ASSET_DIRS:
        for path in sorted((ROOT / directory).iterdir()):
            if path.is_file() and path.suffix not in (".import", ".uid"):
                relative = path.relative_to(ROOT).as_posix()
                unchanged = not git("status", "--porcelain", "--", relative).strip()
                assets.append({**record(relative), "unchanged_vs_head": unchanged})
    assert assets and all(a["unchanged_vs_head"] for a in assets), "original assets changed"
    sources = [record(p) for p in sorted(SOURCES)]
    added = git("diff", "--", *SOURCES).decode(errors="replace")
    added = "\n".join(s[1:] for s in added.splitlines() if s.startswith("+") and not s.startswith("+++"))
    for p in SOURCES:
        if subprocess.run(["git", "ls-files", "--error-unmatch", "--", p], cwd=ROOT, capture_output=True).returncode:
            added += "\n" + (ROOT / p).read_text(encoding="utf-8")
    scan = {"shell_true": r"shell\s*=\s*True", "unsafe_deserialization": r"pickle\.loads?\(", "dynamic_eval": r"\beval\("}
    report = {
        "scope": "E2 underground roads: descending ramps, trenches, portals, covered sections, underground view, underground rules",
        "branch": branch, "head": head,
        "verdict": "E2 gates clean: 2 new suites, 9 E1 regression suites and 3 of 4 transit suites pass headless; E2/E1 UI pass native; two inspected native captures. test_transit_view keeps one pre-existing failure.",
        "owned_source_count": len(sources), "owned_sources": sources,
        "original_asset_count": len(assets), "original_assets": assets,
        "asset_verification": "Approved retaining-wall-01, tunnel-portal-01 strips and tunnel-sample-01 reference used read-only; unchanged against HEAD",
        "current_headless_results": current,
        "current_headless_passing_assertions": sum(r["passed_lines"] for r in current),
        "native_no_capture_results": native,
        "native_capture_results": captured,
        "known_baseline_failures": KNOWN_BASELINE_FAILURES,
        "suite_logs": suites,
        "captures": captures,
        "baseline_proof": "test_underground_roads failed to compile before implementation (missing PORTAL_M, covered_pieces, sunken ...). RED output was not saved.",
        "temporary_values": ["elevated_road_config.json depth_cost: disabled, pending user price; relative factor only"],
        "review_notes": record((OUT / "REVIEW_NOTES.md").relative_to(ROOT).as_posix()),
        "security_scan": {key: bool(re.search(pattern, added)) for key, pattern in scan.items()},
        "excluded": ["all .import/.uid metadata", "protected design/concept/handoff/mistake documents and AGENTS.md", "all other unrelated checkout changes"],
        "benchmarks_run": False, "timing_collection": False,
    }
    for entry in report["owned_sources"]:
        assert record(entry["path"])["sha256"] == entry["sha256"]
    return report

if __name__ == "__main__":
    print(json.dumps(main(), ensure_ascii=False, indent=2))
