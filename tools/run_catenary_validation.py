"""Bounded correctness-only gates. Stdout evidence; no writes or captures.
Persist emitted raw stdout and manifest with approved file-edit tools.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/catenary-validation'
OWNED = [
    'cities_do/core/rail_catenary.gd',
    'cities_do/core/transit_view.gd',
    'cities_do/core/cached_world_renderer.gd',
    'cities_do/tests/test_rail_catenary.gd',
    'cities_do/tests/test_rail_catenary_render.gd',
    'cities_do/tests/rail_catenary_fixture.gd',
    'tools/run_catenary_validation.py',
]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--test', choices=['test_rail_catenary.gd', 'test_transit_render.gd', 'test_rail_catenary_render.gd'])
    args = parser.parse_args()
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    branch = subprocess.check_output(['git', 'branch', '--show-current'], cwd=ROOT, text=True).strip()
    if head != '94cac6b81c11047c08f6115834c3337db79b2ad5' or branch != 'perf/render-sim-cadence':
        raise SystemExit('Unexpected checkout; no engine launched')
    image = OUT / 'catenary-1920.png'
    jobs = [('test_rail_catenary.gd', True), ('test_transit_render.gd', True), ('test_rail_catenary_render.gd', False)]
    records = []
    for name, headless in jobs:
        if args.test and args.test != name:
            continue
        source = (ROOT / 'cities_do/tests' / name).read_text(encoding='utf-8')
        assert source.startswith('extends SceneTree'), name
        assert not re.search(r'Time\.get_ticks|BENCHMARK|benchmark\(', source), name
        command = [sys.executable, 'tools/run_dotnet.py', '--timeout', '90', 'godot', '--path', 'cities_do', '--script', 'res://tests/' + name]
        if headless:
            command.append('--headless')
        else:
            command += ['--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--resolution', '1920x1080', '--max-fps', '30', '--quit-after', '360']
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=100)
        text = result.stdout.decode('utf-8', errors='replace')
        if result.returncode or re.search(r'^\s*(SCRIPT ERROR:|ERROR:|FAIL\b)', text, re.M):
            print(text, end='')
            raise SystemExit(f'{name} failed; no intermediate log retained')
        counts = re.findall(r'(?:CATENARY_\w+ checks=(\d+) failed=(\d+)|RESULT (\d+)/(\d+) transit render checks passed)', text)
        assert len(counts) == 1, (name, counts)
        a, b, c, d = counts[0]
        passed, total = (int(a) - int(b), int(a)) if a else (int(c), int(d))
        assert passed == total
        log = OUT / (Path(name).stem + '.log')
        records.append({'name': name, 'command': command, 'exit_code': result.returncode, 'passed': passed, 'checks': total, 'log': log.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(result.stdout).hexdigest()})
        print(json.dumps({'result': records[-1], 'raw_stdout': text}), flush=True)
    data = {
        'head': head, 'branch': branch, 'tests': records,
        'total_checks': sum(row['checks'] for row in records),
        'total_passed': sum(row['passed'] for row in records), 'total_failed': 0,
        'owned_files': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in OWNED},
        'authoritative_spec_sha256': hashlib.sha256((ROOT / 'docs/design/ASSET_REQUEST_RAIL_PARK_KO.md').read_bytes()).hexdigest(),
        'no_benchmarks': True, 'no_build_import_install': True,
        'capture': {'path': image.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(image.read_bytes()).hexdigest(), 'dimensions': [1920, 1080], 'count': 1, 'status': 'PRE-PORTAL existing stage capture; unchanged, no new capture'},
        'status': 'Selected correctness gates passed; independent parent review and commit pending',
        'limits': ['Ground-rail stage only; grade/bridge/trench rendering remains separate.', 'covered_segments and underground_segments are optional zero-based display masks; existing route editor does not yet author them.', 'Capture is a stationary authored renderer fixture, not an operational performance measurement.'],
    }
    print(json.dumps({'manifest': data}, indent=2))

if __name__ == '__main__':
    main()
