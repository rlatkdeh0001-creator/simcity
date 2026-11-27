"""E3b-only untimed acceptance runner (rail trenches/tunnels). No benchmarks, editor/import or build commands.
Run from the repository root. Native capture mode is explicit and cannot overwrite its captures.
"""
import argparse
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts" / "e3b-underground-rail-20261119"
OWN = ("test_underground_rail", "test_underground_rail_ui")
E3A = ("test_elevated_rail", "test_elevated_rail_ui", "test_underground_road_ui")
RAIL_REGRESSION = (
    "test_rail_catenary", "test_rail_catenary_render", "test_terminal_turnback",
    "test_terminal_turnback_edit", "test_terminal_turnback_catenary",
)
TRANSIT_REGRESSION = (
    "test_transit_view", "test_transit_routes", "test_transit_geometry", "test_transit_render",
    "test_transit_operations", "test_transit_operation_safety",
)
ROAD_REGRESSION = ("test_elevated_roads", "test_underground_roads")
TESTS = OWN + E3A + RAIL_REGRESSION + TRANSIT_REGRESSION + ROAD_REGRESSION
NATIVE = ("test_underground_rail_ui",)
CAPTURES = {"trench": "e3b-trench-portal-1920.png", "underground": "e3b-underground-view-1920.png"}
DIAGNOSTIC = r"^(?:SCRIPT ERROR|ERROR|FAIL|WARNING|Owned toolchain process exceeded)[^\n]*"

def run(name, native, user_args, label):
    cmd = [sys.executable, "tools/run_dotnet.py", "--timeout", "240", "godot"]
    if native:
        cmd += ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--resolution", "1920x1080"]
    else:
        cmd += ["--headless"]
    cmd += ["--max-fps", "30", "--path", "cities_do", "--script", "tests/" + name + ".gd"]
    if user_args:
        cmd += ["--", *user_args]
    result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    raw = "COMMAND " + json.dumps(cmd) + "\nSTDOUT\n" + result.stdout + "\nSTDERR\n" + result.stderr
    (OUT / (label + ".log")).write_text(raw, encoding="utf-8")
    errors = re.findall(DIAGNOSTIC, result.stdout + result.stderr, re.M)
    row = {"name": label, "exit_code": result.returncode, "passed_lines": len(re.findall(r"^PASS ", raw, re.M)), "errors": errors}
    print(json.dumps(row, ensure_ascii=False), flush=True)
    return row

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tests", nargs="+", choices=TESTS, default=list(TESTS))
    native = parser.add_mutually_exclusive_group()
    native.add_argument("--native-once", action="store_true", help="native E3b UI run that saves the two captures once")
    native.add_argument("--native-no-capture", action="store_true", help="native E3b UI run without framebuffer capture")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    results = []
    if args.native_once:
        paths = {key: OUT / name for key, name in CAPTURES.items()}
        if any(path.exists() for path in paths.values()):
            raise SystemExit("The allowed native captures already exist; refusing another capture.")
        user_args = ["--e3b-capture=" + paths["trench"].as_posix(), "--e3b-underground-capture=" + paths["underground"].as_posix()]
        results.append(run("test_underground_rail_ui", True, user_args, "test_underground_rail_ui-native"))
        report = "native-results.json"
    elif args.native_no_capture:
        for name in NATIVE:
            results.append(run(name, True, [], name + "-native-no-capture"))
        report = "native-no-capture-results.json"
    else:
        for name in args.tests:
            results.append(run(name, False, [], name))
        report = "test-results.json"
    prior = json.loads((OUT / report).read_text(encoding="utf-8")) if (OUT / report).exists() else []
    latest = {row["name"]: row for row in prior + results}
    (OUT / report).write_text(json.dumps(list(latest.values()), indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return int(any(r["exit_code"] or r["errors"] for r in results))

if __name__ == "__main__":
    raise SystemExit(main())
