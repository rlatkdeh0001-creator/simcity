"""Verify E4a evidence without editing the checkout; emit the manifest on stdout.

Use --out <regression root> --perf-start <D27 root> for the pre-code manifest.
For the later final gate add --final --review-notes <file>; its two named
captures must have been inspected and described in those notes.
"""
import argparse
from hashlib import sha256
import json
from pathlib import Path
import statistics
import struct
import subprocess
from typing import Any

from measure_e4_frames import BRANCH, START_HEAD, DIAGNOSTIC as PERF_DIAGNOSTIC, git, sha, verify_sample
from verify_e4a_one_way_roads import (
    ROOT, CAPTURES, FEATURE_INPUTS, NATIVE_ONLY, OWN, PASS, REGRESSION, TESTS, THUMBNAILS,
    assertions, clean, diagnostics, source_for,
)

SOURCES = (
    "tools/verify_e4a_one_way_roads.py", "tools/manifest_e4a_one_way_roads.py",
    "tools/measure_e4_frames.py", "tools/measure_e4_frames.gd",
    "tools/run_full_regression_20261127.py", "tools/render_road_lane_thumbnails.gd",
)
ASSET_DIRS = ("assets/structures/retaining-wall-01", "cities_do/assets/structures/retaining-wall-01")
# Frozen before the feature is implemented. Match exit status and each exact
# diagnostic in order, not a substring or blanket warning suppression.
RAIL_EXPORT_WARNINGS = tuple(
    "WARNING: Loaded resource as image file, this will not work on export: "
    f"'res://assets/rail/rail-track-01/{name}'. Instead, import the image file as an Image resource and load it normally as a resource."
    for name in ("strip.png", "strip_end.png", "strip_rails.png")
)
KNOWN_BASELINE_FAILURES = {
    # test_vehicles passed 328/328 after normal import. Main scene entry and
    # return from the standalone vehicle showcase each log this exact triplet.
    ("headless", "test_vehicles"): (0, RAIL_EXPORT_WARNINGS * 2),
}
KNOWN_IMPORT_DIAGNOSTICS = ()


def require(ok, message):
    if not ok:
        raise ValueError(message)


def record(path):
    return {"path": str(path), "sha256": sha(path), "bytes": path.stat().st_size}


def accepted(row):
    known = KNOWN_BASELINE_FAILURES.get((row["mode"], row["name"]))
    if known is None:
        return clean(row)
    return ((row["exit_code"], tuple(row["errors"])) == known
            and (row["exit_code"] != 0 or clean({**row, "errors": []})))


def verify_suite(root, phase, mode, names, head):
    directory = root / phase / mode
    report = directory / "results.json"
    data = json.loads(report.read_bytes())
    require((data["branch"], data["head"], data["baseline"], data["mode"]) ==
            (BRANCH, head, phase == "baseline", mode), f"{report}: wrong checkout/phase/mode")
    if phase == "final":
        require(data.get("feature_sha256") == {path: sha(ROOT / path) for path in FEATURE_INPUTS},
                f"{report}: E4a source or asset fingerprint differs")
    rows = data["results"]
    recorded = [row["name"] for row in rows]
    require(len(recorded) == len(set(recorded)) and set(recorded) == set(names)
            and recorded == data["expected"], f"{report}: incomplete, duplicate or unexpected suites")
    imports = []
    if "test_vehicles" in names:
        imported = data["normal_import"]
        log = root / phase / "vehicle-import" / "normal-import.log"
        require(imported["log"] == log.name and imported["log_sha256"] == sha(log)
                and imported["exit_code"] == 0 and not imported["errors"] and imported["resources"] > 0,
                "invalid normal-import evidence for test_vehicles")
        import_diagnostics = diagnostics(log.read_text(encoding="utf-8", errors="replace"))
        require(tuple(import_diagnostics) == KNOWN_IMPORT_DIAGNOSTICS, "normal-import diagnostics changed")
        imports.append({**record(log), "resources": imported["resources"], "diagnostics": import_diagnostics})
    results = []
    for row in rows:
        name = row["name"]
        log = directory / (name + ".log")
        text = log.read_text(encoding="utf-8", errors="replace")
        counts = assertions(text)
        require(row["mode"] == mode and row["log"] == log.name and row["log_sha256"] == sha(log)
                and row["passed_lines"] == len(PASS.findall(text)) and row["errors"] == diagnostics(text)
                and row["assertions"] == (list(counts) if counts else None), f"{log}: evidence mismatch")
        if phase == "final":
            require(row["source_sha256"] == sha(source_for(name)), f"{name}: stale final result")
        require(accepted(row), f"{log}: new/changed diagnostic, nonzero exit or incomplete assertions")
        results.append({**row, "log": record(log), "clean": clean(row)})
    counted = [row["assertions"] for row in results if row["assertions"] is not None]
    return {"results_json": record(report), "inputs_sha256": data["inputs_sha256"], "suites": results,
            "feature_sha256": data.get("feature_sha256", {}),
            "suite_count": len(results), "clean_suite_count": sum(row["clean"] for row in results),
            "passing_assertions": sum(count[0] for count in counted),
            "total_assertions": sum(count[1] for count in counted),
            "uncounted_suites": [row["name"] for row in results if row["assertions"] is None],
            "normal_import": imports}


def verify_perf(root, phase="start", scene="A"):
    summary = root / "summary.json"
    data = json.loads(summary.read_bytes())
    require((data["branch"], data["head"], data["phase"], data["scene"], data["captures"]) ==
            (BRANCH, START_HEAD, phase, scene, 0), f"not the E4a D27 scene {scene} {phase} run")
    if phase == "end":
        require(data.get("feature_sha256") == {path: sha(ROOT / path) for path in FEATURE_INPUTS},
                f"{summary}: D27 did not sample the current E4a checkout")
    rows = data["runs"]
    require([row["run"] for row in rows] == [1, 2, 3], "D27 needs three serial runs")
    samples = []
    for row in rows:
        number = row["run"]
        case = f"{scene.lower()}-{number}"
        raw, log = root / f"{case}-frames.json", root / f"{case}-godot.log"
        require((raw.name, sha(raw), log.name, sha(log)) ==
                (row["frames_json"], row["frames_sha256"], row["log"], row["log_sha256"]), "D27 file hash mismatch")
        frames = json.loads(raw.read_bytes())
        text = log.read_text(encoding="utf-8", errors="replace").splitlines()
        require(row["exit_code"] == 0 and row["diagnostics"] == []
                and not any(PERF_DIAGNOSTIC.match(line) for line in text)
                and "D27_PASS method=gl_compatibility driver=opengl3" in text
                and row["device"] in text, "D27 process or renderer evidence is not clean")
        require(all(frames[k] == row[k] for k in ("layout_sha256", "frames", "elapsed_usec")), "D27 row mismatch")
        sample = verify_sample(frames, scene)
        require(sample == (row["average_ms"], row["p95_ms"]), "D27 metrics did not match their row")
        samples.append(sample)
    medians = [statistics.median(metric) for metric in zip(*samples)]
    require(medians == [data["median_average_ms"], data["median_p95_ms"]]
            and len({(row["layout_sha256"], row["device"]) for row in rows}) == 1, "D27 median or fixture mismatch")
    return {"summary": record(summary), "median_average_ms": medians[0], "median_p95_ms": medians[1],
            "layout_sha256": rows[0]["layout_sha256"], "device": rows[0]["device"],
            "inputs_sha256": data["inputs_sha256"], "feature_sha256": data.get("feature_sha256", {}), "runs": rows}


def compare_scene_a(before, after):
    for key in ("layout_sha256", "device"):
        require(before[key] == after[key], f"D27 scene A changed {key}")
    for path in ("cities_do/project.godot", "cities_do/.godot/mono/temp/bin/Debug/CitiesDo.dll",
                 "tools/capture_perf_cadence.gd"):
        require(before["inputs_sha256"][path] == after["inputs_sha256"][path], f"D27 changed {path}")
    average = after["median_average_ms"] / before["median_average_ms"]
    p95 = after["median_p95_ms"] / before["median_p95_ms"]
    return dict(average_ratio=average, p95_ratio=p95, passed=average <= 1.10 and p95 <= 1.15)


def verify_paired(root, original) -> dict[str, Any]:
    """Recompute the approved paired result from pinned inputs and raw frames."""
    pinned_path, summary_path = root / "pair-inputs.json", root / "paired/summary.json"
    pinned, summary = (json.loads(p.read_bytes()) for p in (pinned_path, summary_path))
    require((pinned["head"], pinned["branch"]) == (START_HEAD, BRANCH), "incorrect paired baseline")
    paths = {p.removeprefix("cities_do/") for p in FEATURE_INPUTS}
    settings = {"project.godot", ".godot/mono/temp/bin/Debug/CitiesDo.dll"}
    require(pinned["candidate"].keys() == pinned["baseline"].keys() == paths | settings,
            "incomplete paired input fingerprint")
    require(pinned["script"] == sha(ROOT / "tools/measure_e4_frames.gd"), "paired fixture script changed")
    overlays = set(pinned["pinned_baseline_files"])
    tracked = set(git("-c", "core.safecrlf=false", "diff", "--name-only", START_HEAD, "--",
                      "cities_do/core", "cities_do/main.gd", "cities_do/bottom_ui.gd").splitlines())
    require(overlays == tracked and overlays <= {f"cities_do/{p}" for p in paths}, "incorrect baseline overlays")
    for name, digest in pinned["candidate"].items():
        rel = f"cities_do/{name}"
        require(sha(ROOT / rel) == sha(root / "candidate" / rel) == digest, f"stale paired candidate: {rel}")
        base_digest = digest
        if rel in overlays:
            blob = subprocess.check_output(["git", "show", f"{START_HEAD}:{rel}"], cwd=ROOT)
            base_digest = sha256(blob).hexdigest()
        require(sha(root / "baseline" / rel) == pinned["baseline"][name] == base_digest,
                f"stale paired baseline: {rel}")
        if name in settings:
            require(digest == original["inputs_sha256"][rel], f"paired runtime changed: {rel}")
    require(all(summary[k] == original[k] for k in ("device", "layout_sha256")), "paired device or scene differs")
    rows = summary["runs"]
    variants = ("baseline", "candidate")
    count = len(rows) // 2
    require(count >= 3 and len(rows) == 2 * count and
            [(row["pair"], row["variant"]) for row in rows] ==
            [(i, v) for i in range(1, count + 1) for v in (variants if i % 2 else variants[::-1])],
            "paired D27 needs at least three alternating pairs")
    samples = {v: [] for v in variants}
    evidence = [record(pinned_path), record(summary_path)]
    for row in rows:
        variant = row["variant"]
        prefix = f"{row['pair']}-{variant}"
        raw, log = (root / "paired" / f"{prefix}{suffix}" for suffix in ("-frames.json", "-godot.log"))
        require((raw.name, sha(raw), log.name, sha(log)) ==
                (row["frames_json"], row["frames_sha256"], row["log"], row["log_sha256"]), "paired file hash mismatch")
        command = row["command"]
        require(command[1:5] == ["tools/run_dotnet.py", "--timeout", "95", "godot"] and
                Path(command[command.index("--path") + 1]).resolve() == root / variant / "cities_do" and
                Path(command[command.index("--script") + 1]).resolve() == ROOT / "tools/measure_e4_frames.gd" and
                command[-2:] == [f"--frames-json={raw.as_posix()}", "--scene=A"], "unexpected paired command")
        lines = log.read_text(encoding="utf-8", errors="replace").splitlines()
        require(original["device"] in lines and "D27_PASS method=gl_compatibility driver=opengl3" in lines and
                not any(PERF_DIAGNOSTIC.match(line) for line in lines), "unclean paired log")
        data = json.loads(raw.read_bytes())
        sample = verify_sample(data)
        require(data["layout_sha256"] == original["layout_sha256"] and data["frames"] == row["frames"] and
                sample == (row["average_ms"], row["p95_ms"]), "paired raw scene or metrics differ")
        samples[variant].append(sample)
        evidence += [record(raw), record(log)]
    medians = {v: dict(zip(("average_ms", "p95_ms"), map(statistics.median, zip(*samples[v])))) for v in variants}
    require(medians == summary["medians"], "paired median differs")
    average, p95 = (medians["candidate"][metric] / medians["baseline"][metric] for metric in ("average_ms", "p95_ms"))
    require(dict(average_ms=average, p95_ms=p95) == summary["candidate_over_current_baseline"], "paired ratios differ")
    return dict(method="paired", approval="cities-claude 2026-11-27", pairs=count, medians=medians,
                comparison=dict(average_ratio=average, p95_ratio=p95, passed=average <= 1.10 and p95 <= 1.15),
                evidence=evidence)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--perf-start", required=True, type=Path)
    perf_end = parser.add_mutually_exclusive_group()
    perf_end.add_argument("--perf-end", type=Path, help="final D27 Scene A evidence")
    perf_end.add_argument("--perf-paired", type=Path, help="approved D27 paired Scene A evidence")
    perf_end.add_argument("--perf-deferred", help="reason Scene A could not run with exclusive Godot access")
    parser.add_argument("--perf-historical-a", nargs=2, type=Path, help="original, separately timed A and its authorized repeat")
    parser.add_argument("--perf-scene-b", type=Path, help="final D27 Scene B evidence, recorded without a threshold")
    parser.add_argument("--final", action="store_true")
    parser.add_argument("--review-notes", type=Path)
    args = parser.parse_args()
    require(git("branch", "--show-current") == BRANCH and git("rev-parse", "HEAD") == START_HEAD,
            "unexpected branch or E4a starting HEAD")
    require(not git("diff", "--cached", "--name-only"), "index is not empty")
    out = args.out.resolve()
    baseline = {"headless": verify_suite(out, "baseline", "headless",
                                        [name for name in REGRESSION if name not in NATIVE_ONLY], START_HEAD)}
    if NATIVE_ONLY:
        baseline["native-no-capture"] = verify_suite(out, "baseline", "native-no-capture", NATIVE_ONLY, START_HEAD)
    perf = verify_perf(args.perf_start.resolve())
    original_assets = []
    for directory in ASSET_DIRS:
        paths = [p for p in git("ls-tree", "-r", "--name-only", START_HEAD, "--", directory).splitlines()
                 if Path(p).suffix not in (".uid", ".import")]
        require(paths and not git("diff", "--name-only", START_HEAD, "--", *paths), f"original assets changed: {directory}")
        original_assets.extend(record(ROOT / p) for p in paths)
    captures = []
    report: dict[str, object] = dict(branch=BRANCH, head=START_HEAD, phase="baseline", scope="E4a pre-code regression and D27 scene A start",
                  baseline=baseline, d27_start=perf, captures=captures, original_assets=original_assets,
                  owned_sources=[record(ROOT / p) for p in SOURCES], benchmarks_run=True, timing_collection=True,
                  known_baseline_failures=[dict(mode=mode, name=name, exit_code=expected[0], diagnostics=expected[1])
                                           for (mode, name), expected in KNOWN_BASELINE_FAILURES.items()])
    if args.final:
        require(args.review_notes is not None, "final gate needs notes with both capture inspections")
        notes = args.review_notes.resolve()
        final = {"headless": verify_suite(out, "final", "headless",
                                          [name for name in TESTS if name not in NATIVE_ONLY], START_HEAD),
                 "native-capture": verify_suite(out, "final", "native-capture", [OWN[1]], START_HEAD)}
        thumb_records = []
        for thumbnail in THUMBNAILS:
            path = ROOT / thumbnail
            header = path.read_bytes()[:24]
            require(header.startswith(b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR")
                    and struct.unpack(">II", header[16:24]) == (256, 224), f"invalid thumbnail: {thumbnail}")
            thumb_records.append({**record(path), "dimensions": [256, 224]})
        optional_native = out / "final" / "native-no-capture" / "results.json"
        if NATIVE_ONLY or optional_native.exists():
            require(optional_native.exists(), "missing native-only regression results")
            expected = json.loads(optional_native.read_bytes())["expected"]
            require(set(NATIVE_ONLY) <= set(expected) <= {OWN[1], *NATIVE_ONLY}, "unexpected native-no-capture suites")
            final["native-no-capture"] = verify_suite(out, "final", "native-no-capture", expected, START_HEAD)
        directory = out / "final" / "native-capture"
        require({p.name for p in directory.glob("*.png")} == set(CAPTURES.values()), "native capture set differs")
        review = notes.read_text(encoding="utf-8")
        for view, name in CAPTURES.items():
            path = directory / name
            with path.open("rb") as stream:
                header = stream.read(24)
            require(header.startswith(b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR")
                    and struct.unpack(">II", header[16:24]) == (1920, 1080) and name in review,
                    f"invalid or unreviewed capture: {path}")
            captures.append({**record(path), "view": view, "dimensions": [1920, 1080]})
        require(args.perf_end or args.perf_paired or args.perf_deferred, "final gate needs D27 end evidence or a documented deferral")
        if args.perf_paired:
            require(args.perf_historical_a and args.perf_scene_b and
                    "측정 방식 변경(cities-claude 2026-11-27)으로 통과" in review, "paired approval or history missing")
            d27 = verify_paired(args.perf_paired.resolve(), perf)
            require(d27["comparison"]["passed"], f"paired D27 threshold not met: {d27['comparison']}")
            historical = [verify_perf(path.resolve(), "end") for path in args.perf_historical_a]
            prior = [compare_scene_a(perf, row) for row in historical]
            require(not any(row["passed"] for row in prior), "unexpected historical D27 result")
            scene_b = verify_perf(args.perf_scene_b.resolve(), "end", "B")
            require(all(row["device"] == scene_b["device"] and row["inputs_sha256"] == scene_b["inputs_sha256"]
                        for row in historical), "historical D27 and Scene B device or sources differ")
            d27.update(historical=[dict(scene_a=row, comparison=result) for row, result in zip(historical, prior)],
                       scene_b=scene_b)
        elif args.perf_end is not None:
            end = verify_perf(args.perf_end.resolve(), "end")
            comparison = compare_scene_a(perf, end)
            require(comparison["passed"], f"D27 scene A threshold not met: {comparison}")
            if args.perf_scene_b is None:
                raise ValueError("D27 end requires Scene B evidence too")
            scene_b = verify_perf(args.perf_scene_b.resolve(), "end", "B")
            require(scene_b["device"] == end["device"] and scene_b["inputs_sha256"] == end["inputs_sha256"],
                    "D27 end A and B must use the same device and sources")
            d27 = dict(scene_a=end, comparison=comparison, scene_b=scene_b)
        else:
            require(args.perf_deferred in review, "D27 deferral reason not found in the review notes")
            d27 = dict(deferred=True, reason=args.perf_deferred)
        report.update(phase="final", scope="E4a one-way road regressions and native UI captures",
                      final=final, review_notes=record(notes), d27_end=d27, thumbnails=thumb_records)
    print(json.dumps(report, ensure_ascii=True, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        raise SystemExit(str(error)) from error
