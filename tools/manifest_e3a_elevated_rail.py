"""Record E3a owned-source, original-asset and raw-evidence hashes; never changes inputs.
Prints the manifest JSON; the caller stores it as artifacts/e3a-elevated-rail-20261119/manifest.json.
"""
import hashlib
import json
import pathlib
import re
import struct
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/e3a-elevated-rail-20261119"
SOURCES = [
    "cities_do/bottom_ui.gd",
    *["cities_do/core/" + p for p in (
        "cached_world_renderer.gd", "city_model.gd", "elevated_road_config.json",
        "elevated_road_renderer.gd", "rail_catenary.gd", "road_height.gd", "road_height_controls.gd",
        "terminal_crossover.gd", "transit_line_planner.gd", "transit_routes.gd", "transit_view.gd")],
    "cities_do/tests/test_elevated_rail.gd",
    "cities_do/tests/test_elevated_rail_ui.gd",
    "tools/verify_e3a_elevated_rail.py", "tools/manifest_e3a_elevated_rail.py",
]
ASSET_DIRS = [
    "assets/structures/viaduct-pier-01", "assets/structures/viaduct-side-01", "assets/structures/retaining-wall-01",
    "cities_do/assets/structures/viaduct-pier-01", "cities_do/assets/structures/viaduct-side-01",
    "cities_do/assets/structures/retaining-wall-01",
]
VERDICT = "E3a gates: 2 new suites and 13 regression suites headless; native UI run with one inspected capture."
DIAGNOSTIC = r"^(?:SCRIPT ERROR|ERROR|FAIL|WARNING|Owned toolchain process exceeded)[^\n]*"
KNOWN_BASELINE_FAILURES = {}

def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], stderr=subprocess.DEVNULL)

def record(path):
    data = (ROOT / path).read_bytes()
    return {"path": path, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}

def main():
    branch = git("branch", "--show-current").decode().strip()
    head = git("rev-parse", "HEAD").decode().strip()
    assert branch == "perf/render-sim-cadence" and head.startswith("960e9c2"), (branch, head)
    assert not git("diff", "--cached", "--name-only").strip(), "Index is not empty"
    from verify_e3a_elevated_rail import TESTS, NATIVE, CAPTURES
    current = json.loads((OUT / "test-results.json").read_text(encoding="utf-8"))
    assert {r["name"] for r in current} == set(TESTS), "headless gate set differs"
    # E3a: the single native capture run carries every UI check; a no-capture rerun is optional.
    optional = OUT / "native-no-capture-results.json"
    native = json.loads(optional.read_text(encoding="utf-8")) if optional.exists() else []
    assert {r["name"] for r in native} <= {n + "-native-no-capture" for n in NATIVE}
    captured = json.loads((OUT / "native-results.json").read_text(encoding="utf-8"))
    assert [r["name"] for r in captured] == ["test_elevated_rail_ui-native"]
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
        summary = re.findall(r"^(?:[A-Za-z0-9_ ]+: \d+ passed|[A-Za-z0-9_ ]+ checks=)[^\n]*", raw, re.M)
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
        "scope": "E3a elevated rail: per-point rail heights, 3.5% ramps, concrete viaducts, deck track/catenary/trains, under-viaduct rules, rail height UI",
        "branch": branch, "head": head,
        "verdict": VERDICT,
        "owned_source_count": len(sources), "owned_sources": sources,
        "original_asset_count": len(assets), "original_assets": assets,
        "asset_verification": "Approved viaduct-pier-01, viaduct-side-01 and retaining-wall-01 originals used read-only; unchanged against HEAD",
        "current_headless_results": current,
        "current_headless_passing_assertions": sum(r["passed_lines"] for r in current),
        "native_no_capture_results": native,
        "native_capture_results": captured,
        "known_baseline_failures": KNOWN_BASELINE_FAILURES,
        "suite_logs": suites,
        "captures": captures,
        "baseline_proof": "test_elevated_rail failed before implementation (rail heights, ramps, viaduct rules absent). RED output was not saved.",
        "temporary_values": ["elevated_road_config.json rail_height_cost: disabled, pending user price; relative factor only"],
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
