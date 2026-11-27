"""D27 scene A or B (three serial native runs, no captures). Use a fresh --out."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import statistics
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
START_HEAD = "00c7f5ef41e5adfb1ea093b67f54ef000c57cc1e"
BRANCH = "feature/e4-one-way-roads"
DIAGNOSTIC = re.compile(r"^\s*(?:SCRIPT ERROR\b|ERROR\b|FAIL\b|FATAL\b|Fatal error\.|0xC0000005\b|WARNING\b|Owned toolchain process exceeded)")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require_idle():
    rows = subprocess.check_output(["tasklist.exe", "/FO", "CSV", "/NH"], cwd=ROOT)
    processes = [(row[0], row[1]) for row in csv.reader(rows.decode("ascii", "replace").splitlines())
                 if len(row) >= 2 and "godot" in row[0].casefold() and row[0].lower().endswith(".exe")]
    if processes:
        raise RuntimeError(f"Measurement deferred: other Godot process(es): {processes}")


def verify_sample(data, scene="A"):
    if scene not in ("A", "B"):
        raise ValueError(f"Unknown D27 scene: {scene}")
    expected = dict(scene=scene, method="gl_compatibility", driver="opengl3", width=1920,
                    height=1080, fullscreen=True, vsync=False, max_fps=0, paused=True,
                    seed=20261114, roads=6, buildings=24, vehicles=24, warmup_usec=1_000_000,
                    zoom=.9, camera_world_cell=[48, 48], camera_screen_point=[960, 410])
    if scene == "B":
        expected.update(roads=10, vehicles=34, moving_vehicles=10)
    for key, value in expected.items():
        if data[key] != value:
            raise ValueError(f"Unexpected {key}: {data[key]!r} (expected {value!r})")
    if not re.fullmatch(r"[0-9a-f]{64}", data["layout_sha256"]):
        raise ValueError("Invalid fixture fingerprint")
    frames = data["frame_usec"]
    if len(frames) != data["frames"] or any(type(t) is not int or t <= 0 for t in frames):
        raise ValueError("Invalid raw frame intervals")
    elapsed = sum(frames)
    if elapsed != data["elapsed_usec"] or elapsed < 4_000_000:
        raise ValueError("Incomplete sample")
    average = elapsed / len(frames) / 1000
    p95 = sorted(frames)[(95 * len(frames) + 99) // 100 - 1] / 1000
    if abs(average - data["average_ms"]) >= 1e-6 or p95 != data["p95_ms"]:
        raise ValueError("Reported metrics differ from raw frame intervals")
    return average, p95


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT).decode().strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="fresh output folder (prefer scratch)")
    parser.add_argument("--phase", choices=("start", "end"), default="start")
    parser.add_argument("--scene", choices=("A", "B"), default="A", help="B is only measured at the end")
    args = parser.parse_args()
    if args.phase == "start" and args.scene != "A":
        parser.error("The starting baseline must be scene A")
    out = args.out.resolve()
    head, branch = git("rev-parse", "HEAD"), git("branch", "--show-current")
    if branch != BRANCH or (args.phase == "start" and head != START_HEAD):
        parser.error(f"unexpected checkout: {branch} {head}")
    require_idle()
    paths = ("cities_do/project.godot", "cities_do/.godot/mono/temp/bin/Debug/CitiesDo.dll",
             "tools/capture_perf_cadence.gd", "tools/measure_e4_frames.gd", "tools/measure_e4_frames.py")
    inputs = {p: sha(ROOT / p) for p in paths}
    feature = {}
    if args.phase == "end":
        from verify_e4a_one_way_roads import FEATURE_INPUTS
        feature = {path: sha(ROOT / path) for path in FEATURE_INPUTS}
    out.mkdir(parents=True, exist_ok=False)
    rows = []
    for number in range(1, 4):
        require_idle()
        case = f"{args.scene.lower()}-{number}"
        frames = out / f"{case}-frames.json"
        log = out / f"{case}-godot.log"
        command = [sys.executable, "tools/run_dotnet.py", "--timeout", "95", "godot", "--path", "cities_do",
                   "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3",
                   "--resolution", "1920x1080", "--fullscreen", "--audio-driver", "Dummy",
                   "--script", str(ROOT / "tools/measure_e4_frames.gd"), "--",
                   f"--frames-json={frames.as_posix()}", f"--scene={args.scene}"]
        with log.open("xb") as stream:
            code = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT).returncode
        text = log.read_text(encoding="utf-8", errors="replace")
        errors = [line for line in text.splitlines() if DIAGNOSTIC.match(line)]
        if code or errors or "D27_PASS method=gl_compatibility driver=opengl3" not in text:
            raise RuntimeError(f"Scene {args.scene} run {number}: exit={code}, diagnostics={errors}; see {log}")
        data = json.loads(frames.read_bytes())
        average, p95 = verify_sample(data, args.scene)
        rows.append(dict(run=number, command=command, exit_code=code, diagnostics=errors,
                         frames_json=frames.name, frames_sha256=sha(frames), log=log.name, log_sha256=sha(log),
                         layout_sha256=data["layout_sha256"], frames=data["frames"], elapsed_usec=data["elapsed_usec"],
                         average_ms=average, p95_ms=p95,
                         device=next((line for line in text.splitlines() if "OpenGL API" in line), "")))
        print(f"Scene {args.scene} #{number}: avg={average:.6f} ms p95={p95:.3f} ms n={data['frames']}", flush=True)
    require_idle()
    if len({(r["layout_sha256"], r["device"]) for r in rows}) != 1:
        raise RuntimeError(f"Scene {args.scene} layout or device differed between runs")
    if git("rev-parse", "HEAD") != head or any(sha(ROOT / p) != digest for p, digest in (inputs | feature).items()):
        raise RuntimeError("Measurement inputs changed during sampling")
    summary = dict(branch=branch, head=head, phase=args.phase, scene=args.scene, inputs_sha256=inputs, runs=rows,
                   feature_sha256=feature,
                   median_average_ms=statistics.median(r["average_ms"] for r in rows),
                   median_p95_ms=statistics.median(r["p95_ms"] for r in rows),
                   limits_for_end={"average_ratio": 1.10, "p95_ratio": 1.15}, captures=0)
    with (out / "summary.json").open("x", encoding="utf-8") as stream:
        stream.write(json.dumps(summary, indent=2) + "\n")
    print(f"Scene {args.scene} {args.phase}: median avg={summary['median_average_ms']:.6f} ms, "
          f"median p95={summary['median_p95_ms']:.3f} ms; {out / 'summary.json'}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        raise SystemExit(str(error)) from error
