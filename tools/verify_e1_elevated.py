"""E1-only untimed acceptance runner. No benchmarks, editor/import or build commands.
Run from the repository root. Native mode is explicit and cannot overwrite its capture.
"""
import argparse
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts" / "e1-elevated-20261118"
TESTS = (
    "test_elevated_roads", "test_elevated_road_ui", "test_elevated_roads_fifo",
    "test_road_profile_connections", "test_road_side_contacts", "test_road_seams",
    "test_road_demolition_model", "test_road_junction_boxes", "test_building_frontage",
)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tests", nargs="+", choices=TESTS, default=list(TESTS))
    native = parser.add_mutually_exclusive_group()
    native.add_argument("--native-once", action="store_true")
    native.add_argument("--native-no-capture", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    capture = OUT / "e1-native-1920.png"
    if args.native_once and capture.exists():
        raise SystemExit("The one allowed native capture already exists; refusing another capture.")
    native_mode = args.native_once or args.native_no_capture
    names = ["test_elevated_road_ui"] if native_mode else args.tests
    results = []
    for name in names:
        cmd = [sys.executable, "tools/run_dotnet.py", "--timeout", "120", "godot"]
        if native_mode:
            cmd += ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--resolution", "1920x1080"]
        else:
            cmd += ["--headless"]
        cmd += ["--max-fps", "30", "--path", "cities_do", "--script", "tests/" + name + ".gd"]
        if args.native_once:
            cmd += ["--", "--e1-capture=" + capture.as_posix()]
        result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
        raw = "COMMAND " + json.dumps(cmd) + "\nSTDOUT\n" + result.stdout + "\nSTDERR\n" + result.stderr
        label = name + ("-native-no-capture" if args.native_no_capture else "-native" if args.native_once else "")
        (OUT / (label + ".log")).write_text(raw, encoding="utf-8")
        errors = re.findall(r"^(?:SCRIPT ERROR|ERROR|FAIL|WARNING|Owned toolchain process exceeded)[^\n]*", result.stdout + result.stderr, re.M)
        results.append({"name": label, "exit_code": result.returncode, "passed_lines": len(re.findall(r"^PASS ", raw, re.M)), "errors": errors})
        print(json.dumps(results[-1], ensure_ascii=False), flush=True)
    report = "native-no-capture-results.json" if args.native_no_capture else "native-results.json" if args.native_once else "test-results.json"
    prior = json.loads((OUT / report).read_text(encoding="utf-8")) if (OUT / report).exists() else []
    latest = {row["name"]: row for row in prior + results}
    (OUT / report).write_text(json.dumps(list(latest.values()), indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return int(any(r["exit_code"] or r["errors"] for r in results))

if __name__ == "__main__":
    raise SystemExit(main())
