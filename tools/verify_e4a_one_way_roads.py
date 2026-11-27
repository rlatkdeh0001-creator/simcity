"""E4a affected regression gate; never runs the full project suite or D27.

--baseline uses the pre-code regression inventory, --tests selects a subset,
--red runs future E4a assertions without saving logs, and native capture is
always explicit. Keep baseline and final evidence separately under --out.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

from run_full_regression_20261127 import assertions, entry_point, import_project_copy
from measure_e4_frames import BRANCH, START_HEAD, git, require_idle, sha

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "cities_do"
OWN = ("test_one_way_roads", "test_one_way_road_ui", "test_one_way_render",
       "test_one_way_buses", "test_one_way_frontage", "test_one_way_connector_containment",
       "test_one_way_ground_edits", "test_one_way_arrow_marks")
REGRESSION = tuple("test_" + name for name in """
road_width_grades road_lane_cards road_profile_connections road_seams road_transition_marks
road_overlap_policy road_continue road_junction_boxes road_junction_spacing junctions
road_approach_markings road_side_contacts traffic vehicles transit_traffic_regression
scheduled_buses bus_stop_host road_parcels roads_zoning building_frontage zoning_development
road_demolition_model demolition demolition_precedence elevated_roads underground_roads
main_bottom_ui road_mode_ui
""".split())
WORKER_PARITY = ("test_city_worker_parity", "test_native_worker_parity")
RELATED_FINAL = ("test_horizontal_card_strip", "test_play_tools", "test_road_toolbar_cleanup",
                 "test_road_draw_modes", "test_transport_hud_presentation", "test_transit_commuting_bus_replacement",
                 "test_elevated_roads_fifo", "test_transit_operations_fifo", *WORKER_PARITY)
TESTS = OWN + REGRESSION + RELATED_FINAL
NATIVE_ONLY = ()  # Existing suites proven to require the real rendering device.
NATIVE = (OWN[1], *NATIVE_ONLY)
CAPTURES = {"kinds": "e4a-one-way-kinds-1920.png", "draw": "e4a-one-way-draw-1920.png"}
THUMBNAILS = tuple(f"cities_do/assets/ui/roads/one-way-{n}.png" for n in range(1, 5))
FEATURE_INPUTS = ("cities_do/main.gd", "cities_do/bottom_ui.gd", *THUMBNAILS,
                  *(f"cities_do/core/{name}.gd" for name in """
                  building_frontage cached_world_renderer city_model city_simulation_worker public_facilities road_construction
                  road_drawing road_geometry road_height road_height_controls road_junctions road_length_units
                  road_profile road_transitions scheduled_bus_network traffic_controller traffic_network transit_operations
                  """.split()))
DIAGNOSTIC = re.compile(r"^\s*(?:SCRIPT ERROR\b|ERROR\b|FAIL\b|FATAL\b|Fatal error\.|0xC0000005\b|WARNING\b|Owned toolchain process exceeded)")
PASS = re.compile(r"^PASS ", re.M)
ZONING = "test_roads_zoning"
ZONING_TIMING = (
    "\tvar started := Time.get_ticks_msec()\n",
    '\tprint("1024-map short-stroke zoning update ms: ",Time.get_ticks_msec()-started)\n',
)


def write_json(path, value):
    pending = path.with_suffix(".tmp")
    pending.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    pending.replace(path)


def source_for(name):
    return PROJECT / "tests" / (name + ".gd")


def zoning_redirect(directory):
    source = source_for(ZONING)
    text = source.read_text(encoding="utf-8")
    for line in ZONING_TIMING:
        if text.count(line) != 1:
            raise RuntimeError("Zoning fixture timing lines changed; review the untimed redirect")
        text = text.replace(line, "", 1)
    if "get_ticks_" in text or "BENCHMARK" in text:
        raise RuntimeError("Zoning fixture has unreviewed timing code")
    redirected = directory / source.name
    with redirected.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(text)
    return redirected


def diagnostics(text):
    return [line for line in text.splitlines() if DIAGNOSTIC.match(line)]


def run(name, mode, directory, imported, user_args, red):
    native = mode != "headless"
    if native:
        require_idle()
    source = source_for(name)
    source_hash = sha(source)
    project = imported if name == "test_vehicles" else PROJECT
    script = source
    if name == ZONING:
        script = zoning_redirect(directory)
    elif project != PROJECT:
        script = project / "tests" / source.name
        if sha(script) != source_hash:
            raise RuntimeError(f"{name}: imported test differs from working source")
    # These two supplemental 5,400-tick suites use the long bound of the
    # established full runner. All E4a gates retain their 240-second bound.
    timeout = "900" if name in WORKER_PARITY else "240"
    command = [sys.executable, "tools/run_dotnet.py", "--timeout", timeout, "godot"]
    if native:
        command += ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3",
                    "--resolution", "1920x1080", "--fullscreen", "--quit-after", "5500"]
    else:
        command.append("--headless")
    command += ["--audio-driver", "Dummy"]
    # Match the existing full runner: throttle native input, not headless
    # 5,400-tick parity loops that await the worker at process-frame boundaries.
    if native:
        command += ["--max-fps", "30"]
    command += ["--path", str(project), "--script", script.as_posix()]
    if user_args:
        command += ["--", *user_args]
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    text = result.stdout.decode("utf-8", errors="replace")
    if sha(source) != source_hash:
        raise RuntimeError(f"{name}: source changed during the run")
    counts = assertions(text)
    row = dict(name=name, mode=mode, exit_code=result.returncode, passed_lines=len(PASS.findall(text)),
               assertions=list(counts) if counts else None, errors=diagnostics(text),
               source_sha256=source_hash, script_sha256=sha(script), command=command)
    if red:
        print(text, end="", flush=True)
    else:
        log = directory / (name + ".log")
        with log.open("xb") as stream:
            stream.write(result.stdout)
        row.update(log=log.name, log_sha256=sha(log))
    print(json.dumps(row, ensure_ascii=True), flush=True)
    return row


def clean(row):
    counts = row["assertions"]
    completed = row["passed_lines"] > 0 if counts is None else 0 < counts[0] == counts[1]
    return row["exit_code"] == 0 and not row["errors"] and completed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, help="evidence parent; the phase/mode directory must not exist")
    parser.add_argument("--tests", nargs="*", choices=TESTS, help="optional affected subset")
    phase = parser.add_mutually_exclusive_group()
    phase.add_argument("--baseline", action="store_true", help="run pre-code regression cases only")
    phase.add_argument("--red", action="store_true", help="target new tests; stdout only, nothing saved")
    native = parser.add_mutually_exclusive_group()
    native.add_argument("--native-no-capture", action="store_true")
    native.add_argument("--native-once", action="store_true", help="native E4a UI run, two captures, no overwrite")
    args = parser.parse_args()
    native_mode = args.native_no_capture or args.native_once
    if args.native_once and (args.tests is not None or args.baseline or args.red):
        parser.error("--native-once is the final E4a UI run only")
    if args.red and (not args.tests or not set(args.tests) <= set(OWN) or args.out is not None):
        parser.error("--red requires explicit new --tests and does not take --out")
    if not args.red and args.out is None:
        parser.error("--out is required outside RED")

    inventory = REGRESSION if args.baseline else TESTS
    if args.native_once:
        inventory = (OWN[1],)
    elif args.native_no_capture:
        inventory = tuple(n for n in NATIVE if n in inventory)
    else:
        inventory = tuple(n for n in inventory if n not in NATIVE_ONLY)
    names = tuple(args.tests or inventory)
    if not names or len(set(names)) != len(names) or not set(names) <= set(inventory):
        parser.error("No suites, duplicated suites, or suites outside the selected phase/mode")
    for name in names:
        if not entry_point(source_for(name)):
            parser.error(f"{name} does not resolve to a SceneTree/MainLoop entry point")

    head, branch = git("rev-parse", "HEAD"), git("branch", "--show-current")
    if branch != BRANCH or (args.baseline and head != START_HEAD):
        parser.error(f"unexpected checkout: {branch} {head}")
    # Refuse a pre-code run against live gameplay/test edits, but don't touch shared
    # generated metadata or the pre-existing editor reserialization of project.godot.
    if args.baseline and git("diff", "--name-only", "HEAD", "--", "cities_do", ":!*.import", ":!*.uid", ":!cities_do/project.godot"):
        parser.error("tracked project content differs from the pre-code HEAD")
    if native_mode:
        require_idle()
    mode = "native-capture" if args.native_once else "native-no-capture" if args.native_no_capture else "headless"
    evidence = args.out.resolve() / ("baseline" if args.baseline else "final") if args.out else None
    directory = evidence / mode if evidence else None
    if directory:
        directory.mkdir(parents=True, exist_ok=False)
    inputs = {path: sha(ROOT / path) for path in (
        "cities_do/project.godot", "cities_do/.godot/mono/temp/bin/Debug/CitiesDo.dll")}
    feature = {path: sha(ROOT / path) for path in FEATURE_INPUTS} if not args.baseline else {}
    imported = PROJECT
    import_record = None
    if "test_vehicles" in names:
        if evidence is None:
            parser.error("test_vehicles requires an isolated import evidence directory")
        # The committed importer copies the project + prepared DLL, runs a real
        # engine import outside the checkout, and produces a hashed import log.
        import_evidence = evidence / "vehicle-import"
        thumbnail_inputs = () if args.baseline else THUMBNAILS
        imported = import_project_copy(import_evidence, extra_project_paths=thumbnail_inputs)
        if any(sha(imported.parent / path) != sha(ROOT / path) for path in thumbnail_inputs):
            raise RuntimeError("The isolated project did not import the current E4a thumbnails")
        metadata = import_evidence / "normal-import.json"
        import_record = json.loads(metadata.read_bytes())
        if (import_record["exit_code"] or import_record["errors"] or not import_record["resources"]
                or sha(import_evidence / import_record["log"]) != import_record["log_sha256"]
                or sha(imported / ".godot/mono/temp/bin/Debug/CitiesDo.dll") != inputs["cities_do/.godot/mono/temp/bin/Debug/CitiesDo.dll"]):
            raise RuntimeError("Invalid copied Godot import evidence")
    user_args = []
    if args.native_once and directory is not None:
        user_args = [f"--e4a-{key}-capture={(directory / filename).as_posix()}" for key, filename in CAPTURES.items()]
    rows = []
    report = dict(branch=branch, head=head, mode=mode, baseline=args.baseline, inputs_sha256=inputs,
                  feature_sha256=feature, expected=list(names), normal_import=import_record, results=rows)
    def verify_checkout():
        if git("rev-parse", "HEAD") != head or any(sha(ROOT / p) != h for p, h in (inputs | feature).items()):
            raise RuntimeError("Checkout, runtime or E4a inputs changed during the run")
    for name in names:
        verify_checkout()
        rows.append(run(name, mode, directory, imported, user_args, args.red))
        verify_checkout()
        if directory:
            write_json(directory / "results.json", report)
    if not args.red:
        from manifest_e4a_one_way_roads import accepted
        return int(not all(accepted(row) for row in rows))
    return int(not all(clean(row) for row in rows))


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        raise SystemExit(str(error)) from error
