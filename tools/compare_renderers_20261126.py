"""Serial native renderer comparison, using the existing fixed-seed cadence fixture."""
import csv
import json
from pathlib import Path
import re
import statistics
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts' / 'renderer-compare-20261126'
METHODS = ('gl_compatibility', 'forward_plus', 'mobile')
PNG = b'\x89PNG\r\n\x1a\n'
DIAGNOSTIC = re.compile(r'^\s*(?:SCRIPT ERROR:|ERROR:|FATAL:|FAIL\b|WARNING:)', re.M)


def godot_processes():
    result = subprocess.check_output(['tasklist.exe', '/FO', 'CSV', '/NH'], cwd=ROOT)
    return [row[0] for row in csv.reader(result.decode('utf-8', 'replace').splitlines())
            if row and 'godot' in row[0].casefold()]


def verify(directory, method):
    process = json.loads((directory / 'process.json').read_bytes())
    assert process['exit_code'] == 0, f'{method} did not exit successfully'
    data = json.loads((directory / 'frames.json').read_bytes())
    assert data['method'] == method, f'{method} fell back to {data["method"]}'
    assert (data['width'], data['height']) == (1920, 1080) and not data['vsync']
    assert (data['seed'], data['roads'], data['buildings'], data['vehicles']) == (20261114, 6, 24, 24)
    frames = data['frame_usec']
    assert len(frames) == data['frames'] and data['elapsed_usec'] == sum(frames) >= 4_000_000
    assert abs(statistics.mean(frames) / 1000 - data['average_ms']) < 1e-6
    assert sorted(frames)[(95 * len(frames) + 99) // 100 - 1] / 1000 == data['p95_ms']
    for file in ('city.png', 'building.png'):
        image = (directory / file).read_bytes()
        assert image.startswith(PNG) and struct.unpack('>II', image[16:24]) == (1920, 1080)
    log = (directory / 'godot.log').read_text(encoding='utf-8', errors='replace')
    assert f'RENDERER_COMPARE_PASS {method}' in log
    assert f'method={method} driver={data["driver"]}' in log
    diagnostics = [line for line in log.splitlines() if DIAGNOSTIC.match(line)]
    driver_line = next((line for line in log.splitlines() if 'Using Device' in line), '')
    return data, driver_line, diagnostics


def run(method):
    directory = OUT / method
    # Existing completed evidence may be verified on a resumed run; a partial
    # directory is not silently overwritten or treated as a successful sample.
    if (directory / 'godot.log').is_file():
        return verify(directory, method)
    processes = godot_processes()
    if processes:
        raise RuntimeError('Measurement deferred: other Godot process: ' + ', '.join(processes))
    directory.mkdir(parents=True, exist_ok=True)
    cmd = [sys.executable, 'tools/run_dotnet.py', '--timeout', '95', 'godot', '--path', 'cities_do',
           '--rendering-method', method, '--resolution', '1920x1080', '--fullscreen', '--audio-driver', 'Dummy',
           '--quit-after', '40000', '--script', str(ROOT / 'tools' / 'compare_renderers_20261126.gd'),
           '--', '--evidence-dir=' + str(directory).replace('\\', '/')]
    with (directory / 'godot.log').open('xb') as log:
        result = subprocess.run(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    with (directory / 'process.json').open('x', encoding='utf-8') as metadata:
        json.dump({'requested_method': method, 'exit_code': result.returncode}, metadata, indent=2)
    if result.returncode != 0:
        raise RuntimeError(f'{method} exited {result.returncode}; see {directory / "godot.log"}')
    return verify(directory, method)


def main():
    project = ROOT / 'cities_do' / 'project.godot'
    original = project.read_bytes()
    summaries = []
    failures = []
    try:
        for method in METHODS:
            try:
                data, driver_line, diagnostics = run(method)
                summaries.append(data)
                print(f'{method}: avg={data["average_ms"]:.6f} ms p95={data["p95_ms"]:.3f} ms '
                      f'n={data["frames"]}; sha={data["layout_sha256"]}; target={data["close_building"]}:{data["close_asset"]}; '
                      f'driver={data["driver"]} {driver_line}; diagnostics={diagnostics}', flush=True)
            except (OSError, AssertionError, KeyError, ValueError, RuntimeError) as error:
                failures.append(method)
                print(f'{method}: {error}', file=sys.stderr, flush=True)
                if str(error).startswith('Measurement deferred:'):
                    break
        if len(summaries) > 1:
            comparable = ('layout_sha256', 'close_building', 'close_asset', 'close_cell', 'city_zoom', 'close_zoom')
            assert all(all(row[k] == summaries[0][k] for k in comparable) for row in summaries), 'fixture states differ'
    finally:
        assert project.read_bytes() == original, 'project.godot changed during comparison'
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
