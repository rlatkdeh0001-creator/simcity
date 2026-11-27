"""P3 related functional gates only. No import, build, benchmark or capture."""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/transit-operations-validation'
SUITES = [
    'test_transit_operations', 'test_scheduled_buses',
    'test_transit_operation_safety', 'test_transit_operations_fifo',
    'test_transit_operations_view', 'test_transit_traffic_regression',
    'test_transit_transport', 'test_transit_fifo',
    'test_transit_facilities', 'test_transit_facilities_fifo',
]
OWNED = [
    'cities_do/core/city_model.gd', 'cities_do/core/city_simulation.gd',
    'cities_do/core/city_simulation_worker.gd',
    'cities_do/core/transit_line_planner.gd', 'cities_do/core/transit_operations.gd',
    'cities_do/core/scheduled_bus_network.gd', 'cities_do/core/scheduled_bus_simulation.gd',
    'cities_do/core/transit_operation_config.json', 'cities_do/core/transit_line_tool.gd',
    'cities_do/core/traffic_controller.gd', 'cities_do/core/cached_world_renderer.gd',
    'cities_do/main.gd', 'cities_do/bottom_ui.gd',
    'cities_do/tests/transit_operations_fixture.gd',
    *['cities_do/tests/' + name + '.gd' for name in SUITES[:5]],
    'cities_do/tests/test_transit_traffic_regression.gd',
    'tools/run_p3_validation.py',
]

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    results = []
    requested = sys.argv[1:] or SUITES
    prior_path = OUT / 'manifest.json'
    if sys.argv[1:] and prior_path.exists():
        prior = json.loads(prior_path.read_text(encoding='utf-8'))
        for name, digest in prior['source_sha256'].items():
            if name == 'tools/run_p3_validation.py':
                continue
            if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest:
                raise SystemExit('Changed input requires full related run: ' + name)
        results = [row for row in prior['suites'] if row['suite'] in SUITES and row['suite'] not in requested]
    for name in requested:
        if name not in SUITES:
            raise SystemExit('Unknown suite: ' + name)
        path = ROOT / 'cities_do/tests' / (name + '.gd')
        entry = path.read_text(encoding='utf-8').splitlines()[0]
        if entry == 'extends "res://tests/test_traffic.gd"':
            entry = (ROOT / 'cities_do/tests/test_traffic.gd').read_text(encoding='utf-8').splitlines()[0]
        if entry != 'extends SceneTree':
            raise SystemExit('Refusing non-SceneTree entry point: ' + name)
        native = name.endswith('_view')
        args = [sys.executable, 'tools/run_dotnet.py', '--timeout', '120', 'godot',
                '--path', 'cities_do', '--rendering-method', 'gl_compatibility']
        if not native:
            args.append('--headless')
        args += ['--script', 'res://tests/' + name + '.gd']
        process = subprocess.run(args, cwd=ROOT, capture_output=True, timeout=140)
        output = process.stdout.decode('utf-8', errors='replace') + process.stderr.decode('utf-8', errors='replace')
        (OUT / (name + '.log')).write_text(output, encoding='utf-8')
        counted = re.search(r'checks=(\d+)\s+failed=(\d+)', output)
        errors = bool(re.search(r'(?m)^\s*(SCRIPT ERROR:|ERROR:|FAIL\b)', output))
        result = {'suite': name, 'exit_code': process.returncode,
                  'passed': process.returncode == 0 and not errors,
                  'checks': int(counted[1]) if counted else None,
                  'failed': int(counted[2]) if counted else None,
                  'log': str(OUT / (name + '.log'))}
        results.append(result)
        print(json.dumps(result), flush=True)
        if not result['passed']:
            print(output, flush=True)
    hashes = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in OWNED}
    report = {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'review_mode': 'self-review', 'suites': results, 'source_sha256': hashes,
              'counted_checks': sum(item['checks'] or 0 for item in results),
              'uncounted_suites': [item['suite'] for item in results if item['checks'] is None],
              'captures': [], 'fixture': 'res://tests/transit_operations_fixture.gd',
              'config': 'cities_do/core/transit_operation_config.json',
              'policy_choices': [
                  'One reusable consist per line; first-stop departures wait for the next configured headway slot after completing the physical circuit.',
                  'Player workflow: transport > line (or freight line), click placed stops in order, click first stop again; remove line tool then click one of its stops.',
                  'Return travel needs a continuous directed physical loop. No fabricated crossovers, reverse-track teleport or automatic track construction.',
                  'Scheduled buses serve bus-stop-01; bus-station-01 remains a placed P2 facility, not a depot or dispatch source.',
                  'Changed occupied route/road topology freezes retained vehicles. Restore the same topology or remove/recreate the line; no relocation.',
                  '2/4/6-lane roads use curb branches. 3/5/7 and shoulderless 8-lane roads stop in the outer running lane.',
                  'Operation uses worker-only 30 Hz substeps within accepted society intervals. Rendering consumes publications without extrapolation.',
                  'No fares, upkeep, commuter assignment, walking transfers or catenary added.'
              ],
              'validation_issue': 'Initial legacy test_traffic invocation inadvertently ran its embedded timed fleet and emitted exit resource/thread cleanup errors. Measurement discarded; that runner is excluded. Final traffic regression invokes only its untimed functional methods.',
              'pending': ['Parent-owned captures and independent review', 'Parent-owned commit; no staging, commit, push or main update performed']}
    (OUT / 'manifest.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    return 0 if all(item['passed'] for item in results) else 1

if __name__ == '__main__':
    raise SystemExit(main())
