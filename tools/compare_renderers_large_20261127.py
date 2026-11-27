"""P11 serial native comparison. --plan is read-only; --measure launches Godot."""
import argparse
import csv
import hashlib
import json
import re
import statistics
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'cities_do' / 'project.godot'
SCRIPT = Path(__file__).with_suffix('.gd')
OUT = ROOT / 'artifacts' / 'renderer-compare-20261126' / 'large-20261127'
METHODS = {'gl_compatibility': 'opengl3', 'forward_plus': 'vulkan', 'mobile': 'vulkan'}
WORKLOADS = ('paused', 'live_1x')
TIMEOUT = 95  # existing wrapper; hard outer guard also covers wrapper startup/cleanup
OUTER_TIMEOUT = 105
RSS_LIMIT = 6 * 1024**3
WARM_US = 1_000_000
SAMPLE_US = 8_000_000
FIXTURE_COMMIT = '727a9e1ebe38faa01d0ac500028349c854a9e70d'
FIXTURE_SOURCES = ('tools/validate_population_live.gd', 'tools/validate_csharp_population_live.gd')
DIAGNOSTIC = re.compile(r'^\s*(?:SCRIPT ERROR:|ERROR:|FATAL:|FAIL\b|WARNING:)', re.M)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, timeout=10)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def command(method, workload):
    directory = OUT / method / workload
    argv = [sys.executable, 'tools/run_dotnet.py', '--timeout', str(TIMEOUT), 'godot',
            '--path', 'cities_do', '--rendering-method', method, '--rendering-driver', METHODS[method],
            '--resolution', '1920x1080', '--fullscreen', '--audio-driver', 'Dummy',
            '--script', SCRIPT.as_posix(), '--', '--p11-measure', method, workload,
            (directory / 'frames.json').as_posix()]
    return directory, argv


def provenance():
    paths = git('-c', 'core.safecrlf=false', 'diff', '--name-only', '-z', 'HEAD', '--',
                'cities_do', ':(exclude,glob)**/*.import', ':(exclude,glob)**/*.uid',
                ':(exclude)cities_do/tests').decode('utf-8').split('\0')
    dirty_runtime = {path: sha((ROOT / path).read_bytes()) if (ROOT / path).is_file() else None
                     for path in paths if path}
    return {'fixture_commit': FIXTURE_COMMIT,
            'fixture_git_blob_sha256': {p: sha(git('show', f'{FIXTURE_COMMIT}:{p}')) for p in FIXTURE_SOURCES},
            'tested_head': git('rev-parse', 'HEAD').decode().strip(),
            'tracked_runtime_changes_sha256': dirty_runtime,
            'project_sha256': sha(PROJECT.read_bytes()),
            'harness_sha256': {p.name: sha(p.read_bytes()) for p in (Path(__file__), SCRIPT)},
            'wall_limit_s': TIMEOUT, 'process_guard_s': OUTER_TIMEOUT, 'rss_tree_limit_bytes': RSS_LIMIT}


def write_json(path, data):
    with path.open('x', encoding='utf-8') as file:
        json.dump(data, file, indent=2)
        file.write('\n')


def gate():
    listing = subprocess.check_output(['tasklist.exe', '/FO', 'CSV', '/NH'], cwd=ROOT, timeout=10)
    rows = [row for row in csv.reader(listing.decode('utf-8', 'replace').splitlines())
            if len(row) >= 2 and row[1].isdigit()]
    require(rows, 'process gate could not read tasklist')
    godots = [f'{row[0]} (PID {row[1]})' for row in rows if 'godot' in row[0].casefold()]
    require(not godots, 'Measurement deferred: other Godot process: ' + ', '.join(godots))


def run_owned(argv, log, psutil):
    process = subprocess.Popen(argv, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    deadline = time.monotonic() + OUTER_TIMEOUT
    stopped = None
    try:
        while process.poll() is None:
            if time.monotonic() >= deadline:
                stopped = 'owned process tree reached wall-time limit'
                break
            try:
                owner = psutil.Process(process.pid)
                tree = [owner, *owner.children(recursive=True)]
            except psutil.NoSuchProcess:
                continue
            rss = 0
            for child in tree:
                try:
                    rss += child.memory_info().rss
                except psutil.NoSuchProcess:
                    pass
            if rss > RSS_LIMIT:
                stopped = 'owned process tree exceeded 6 GiB RSS'
                break
            time.sleep(0.25)
    finally:
        if process.poll() is None:
            # Only the wrapper we launched and its descendants; never kill by image name.
            subprocess.run(['taskkill.exe', '/PID', str(process.pid), '/T', '/F'],
                           check=False, capture_output=True, timeout=10)
        process.wait(timeout=10)
    return process.returncode, stopped


def verify(directory, method, workload):
    data = json.loads((directory / 'frames.json').read_text(encoding='utf-8'))
    text = (directory / 'godot.log').read_text(encoding='utf-8', errors='replace')
    require(not DIAGNOSTIC.search(text), f'{directory}: engine or harness diagnostic')
    require(f'P11_ACTIVE method={method} driver={METHODS[method]} workload={workload}' in text and
            'P11_PASS' in text.splitlines(), f'{directory}: missing active backend or success marker')
    device = next((line for line in text.splitlines() if 'Using Device' in line), '')
    require(device and ('OpenGL' if method == 'gl_compatibility' else 'Vulkan') in device,
            f'{directory}: missing or mismatched graphics API/device in log')
    require((data['method'], data['driver'], data['workload']) == (method, METHODS[method], workload),
            f'{directory}: backend or workload mismatch')
    require((data['seed'], data['population_seed'], data['map_cells'], data['roads'], data['homes'],
             data['commercial'], data['zoned_cells'], data['vehicles']) ==
            (20261114, 20261114 ^ 0x71294, [100, 100], 6, 60, 1, 32, 0),
            f'{directory}: unexpected fixture counts or RNG seeds')
    require((data['width'], data['height'], data['fullscreen'], data['vsync'], data['max_fps'],
             data['zoom'], data['camera_anchor'], data['simulation_speed'], data['warmup_usec'],
             data['target_sample_usec']) == (1920, 1080, True, False, 0, 0.9, [960, 410], 1, WARM_US, SAMPLE_US),
            f'{directory}: unexpected display, camera or sampling configuration')
    first, last = data['initial'], data['final']
    require((first['population'], first['households'], first['buildings'], first['published_tick'],
             first['clock_seconds']) == (240, 120, 61, 0, 0), f'{directory}: initial city mismatch')
    require(first == last if workload == 'paused' else
            last['published_tick'] > 0 and last['clock_seconds'] > 0,
            f'{directory}: wrong simulation advancement')
    for key in ('recipe_sha256', 'initial_sha256'):
        require(re.fullmatch(r'[0-9a-f]{64}', data[key]), f'{directory}: invalid {key}')
    frames = data['frame_usec']
    require(0 < len(frames) <= 100_000 and len(frames) == data['frames'] and
            all(isinstance(value, int) and value > 0 for value in frames) and
            sum(frames) == data['elapsed_usec'] >= SAMPLE_US, f'{directory}: invalid raw frame samples')
    rank = (95 * len(frames) + 99) // 100
    require(abs(statistics.mean(frames) / 1000 - data['average_ms']) < 1e-6 and
            abs(sorted(frames)[rank - 1] / 1000 - data['p95_ms']) < 1e-9, f'{directory}: invalid mean or p95')
    keys = ('method', 'driver', 'workload', 'recipe_sha256', 'initial_sha256', 'camera_cell', 'camera_origin',
            'workplace_id', 'workplace_asset', 'initial', 'final', 'frames', 'elapsed_usec', 'average_ms', 'p95_ms')
    return {**{key: data[key] for key in keys}, 'graphics_device_log': device,
            'evidence': directory.relative_to(ROOT).as_posix()}


def measure(cases, source):
    import psutil  # Installed locally; no installation or engine call on the plan path.

    require(not OUT.exists(), f'refusing to reuse or overwrite {OUT}')
    initial = None
    summaries = []
    for method, workload, directory, argv in cases:
        gate()  # Repeat before every child. The driver never closes someone else’s Godot.
        if initial is None:
            OUT.mkdir(exist_ok=False)  # Reserve the entire comparison before the first child.
        directory.mkdir(parents=True, exist_ok=False)
        with (directory / 'godot.log').open('xb') as log:
            code, stopped = run_owned(argv, log, psutil)
        write_json(directory / 'process.json', {'requested_method': method, 'workload': workload,
                                              'argv': argv, 'exit_code': code, 'bounded_stop': stopped})
        require(code == 0 and stopped is None, f'{directory}: {stopped or f"exit {code}"}; inspect godot.log')
        row = verify(directory, method, workload)
        identity = tuple(row[k] for k in ('recipe_sha256', 'initial_sha256', 'camera_cell', 'camera_origin',
                                          'workplace_id', 'workplace_asset', 'initial'))
        if initial is None:
            initial = identity
        require(identity == initial, f'{directory}: initial scene differs from the first run')
        summaries.append(row)
        print(f'{method}/{workload}: mean={row["average_ms"]:.6f} ms p95={row["p95_ms"]:.3f} ms '
              f'n={row["frames"]} published={row["final"]["published_tick"]}', flush=True)
    require(provenance() == source, 'source provenance or project.godot changed during the runs')
    write_json(OUT / 'summary.json', {'source': source, 'runs': summaries})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--plan', action='store_true', help='print provenance and exact argv; no launch or writes')
    mode.add_argument('--measure', action='store_true', help='run all six cases after measurement is authorized')
    args = parser.parse_args()
    try:
        source = provenance()
        cases = [(method, workload, *command(method, workload)) for method in METHODS for workload in WORKLOADS]
        if args.plan:
            print(json.dumps(source, indent=2))
            print('No engine launch or evidence writes. CWD:', ROOT.as_posix())
            for _, _, _, argv in cases:
                print(subprocess.list2cmdline(argv))
        else:
            measure(cases, source)
    except (OSError, subprocess.SubprocessError, RuntimeError, KeyError, ValueError, ImportError) as error:
        print(f'P11: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
