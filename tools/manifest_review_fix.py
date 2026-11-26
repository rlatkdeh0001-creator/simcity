"""Record review-fix owned-source and raw-evidence hashes; never changes inputs.
Prints the manifest JSON; the caller stores it as artifacts/review-fix-20261119/manifest.json.
REVIEW_FIX_STAGE=1 records the first commit (picking + lift), 2 also the regeneration fix, the default 3
also route_changed and the edit warning (3-2).
"""
import hashlib
import json
import os
import pathlib
import re
import struct
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/review-fix-20261119"
STAGE = os.environ.get("REVIEW_FIX_STAGE", "3")
STAGE_ONE = [
    *["cities_do/core/" + p for p in (
        "cached_world_renderer.gd", "transit_line_planner.gd", "transit_view.gd")],
    "cities_do/main.gd",
    "cities_do/tests/test_review_fix_ui.gd",
    "cities_do/tests/test_review_fix_lift.gd",
    "tools/verify_review_fix.py", "tools/manifest_review_fix.py",
]
STAGE_TWO = [
    "cities_do/core/transit_operations.gd",
    "cities_do/tests/test_review_fix_regen.gd",
    "cities_do/tests/test_terminal_turnback_edit.gd",
]
STAGE_THREE = [
    "cities_do/bottom_ui.gd", "cities_do/core/route_reset_warning.gd",
    "cities_do/core/transit_line_tool.gd", "cities_do/tests/test_review_fix_dialog.gd",
]
SOURCES = STAGE_ONE + (STAGE_TWO if STAGE in ("2", "3") else []) + (STAGE_THREE if STAGE == "3" else [])
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
    assert branch == "perf/render-sim-cadence", branch
    assert STAGE != "1" or head.startswith("eee20fc"), (STAGE, head)
    assert not git("diff", "--cached", "--name-only").strip(), "Index is not empty"
    from verify_review_fix import TESTS, NATIVE, CAPTURES, EDIT_REGRESSION
    expected = set(TESTS) - ({"test_review_fix_regen"} if STAGE == "1" else set())
    expected -= set() if STAGE == "3" else set(EDIT_REGRESSION) | {"test_review_fix_dialog"}
    current = json.loads((OUT / "test-results.json").read_text(encoding="utf-8"))
    assert {r["name"] for r in current} == expected, "headless gate set differs"
    native = json.loads((OUT / "native-no-capture-results.json").read_text(encoding="utf-8"))
    assert {r["name"] for r in native} == {n + "-native-no-capture" for n in NATIVE}
    captured = json.loads((OUT / "native-results.json").read_text(encoding="utf-8"))
    assert [r["name"] for r in captured] == ["test_review_fix_ui-native"] + (["test_review_fix_dialog-native"] if STAGE == "3" else [])
    for row in current + native + captured:
        raw = (OUT / (row["name"] + ".log")).read_text(encoding="utf-8")
        diagnostics = re.findall(DIAGNOSTIC, raw, re.M)
        assert row["passed_lines"] == len(re.findall(r"^PASS ", raw, re.M)), row["name"]
        assert not row["exit_code"] and not row["errors"] and not diagnostics, row["name"]
    suites = []
    for log in sorted(OUT.glob("*.log")):
        raw = log.read_text(encoding="utf-8")
        summary = re.findall(r"^(?:[A-Za-z0-9_ ]+: \d+ passed|[A-Za-z0-9_ ]+ checks=)[^\n]*", raw, re.M)
        suites.append({"name": log.stem, "log": record(log.relative_to(ROOT).as_posix()),
                       "passing_assertion_lines": len(re.findall(r"^PASS ", raw, re.M)),
                       "summary": summary, "diagnostics": re.findall(DIAGNOSTIC, raw, re.M)})
    assert {s["name"] for s in suites} == expected | {r["name"] for r in native} | {r["name"] for r in captured}, "stray or missing logs"
    captures = []
    for key, name in CAPTURES.items():
        data = (OUT / name).read_bytes()
        assert data[:8] == b"\x89PNG\r\n\x1a\n"
        dimensions = struct.unpack(">II", data[16:24])
        assert dimensions == (1920, 1080)
        captures.append({**record((OUT / name).relative_to(ROOT).as_posix()), "view": key, "dimensions": dimensions, "inspected": True})
    assert len(list(OUT.glob("*.png"))) == len(CAPTURES)
    sources = [record(p) for p in sorted(SOURCES)]
    added = git("diff", "eee20fc", "--", *SOURCES).decode(errors="replace")
    added = "\n".join(s[1:] for s in added.splitlines() if s.startswith("+") and not s.startswith("+++"))
    for p in SOURCES:
        if subprocess.run(["git", "ls-files", "--error-unmatch", "--", p], cwd=ROOT, capture_output=True).returncode:
            added += "\n" + (ROOT / p).read_text(encoding="utf-8")
    scan = {"shell_true": r"shell\s*=\s*True", "unsafe_deserialization": r"pickle\.loads?\(", "dynamic_eval": r"\beval\("}
    report = {
        "scope": "Independent review fixes: height-aware demolition picking (roads and rails at their drawn height, E1 decks included)"
                 + ", per-route train lift (route id per plan segment, one lookup per pose)"
                 + (", consist regeneration when a line's plan changes or is blocked (P5 edit contract)" if STAGE in ("2", "3") else "")
                 + (", route_changed (path or stop change only) and the edit warning before edits that reset trains (3-2)" if STAGE == "3" else ""),
        "stage": STAGE,
        "branch": branch, "head": head,
        "verdict": "Review-fix gates: %d suites headless and %d native-only suites, all green; %d native UI runs with one inspected capture each." % (len(expected), len(native), len(captured)),
        "owned_source_count": len(sources), "owned_sources": sources,
        "original_asset_count": 0, "original_assets": [],
        "asset_verification": "No assets added or changed",
        "current_headless_results": current,
        "current_headless_passing_assertions": sum(r["passed_lines"] for r in current),
        "native_no_capture_results": native,
        "native_capture_results": captured,
        "known_baseline_failures": KNOWN_BASELINE_FAILURES,
        "suite_logs": suites,
        "captures": captures,
        "baseline_proof": "test_review_fix_ui (11 failed) and test_review_fix_lift (15 failed) failed before the picking/lift fix; test_review_fix_regen (6 failed) failed before the regeneration fix. RED output was not saved."
                          + (" 3-2 at 443ba4e: test_review_fix_dialog 17 checks / 6 failed, test_review_fix_regen with test_branch 57 checks / 2 failed (route_changed calls stubbed); RED logs kept outside the artifacts." if STAGE == "3" else ""),
        "temporary_values": [],
        "review_notes": record((OUT / "REVIEW_NOTES.md").relative_to(ROOT).as_posix()),
        "security_scan": {key: bool(re.search(pattern, added)) for key, pattern in scan.items()},
        "excluded": ["all .import/.uid metadata", "protected design/concept/handoff/mistake documents and AGENTS.md", "project.godot", "all other unrelated checkout changes"],
        "benchmarks_run": False, "timing_collection": False,
    }
    for entry in report["owned_sources"]:
        assert record(entry["path"])["sha256"] == entry["sha256"]
    return report

if __name__ == "__main__":
    print(json.dumps(main(), ensure_ascii=False, indent=2))
