"""P4 affected correctness only. No imports, builds, timings or screenshots."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/transit-commuting-validation'
TESTS = ['test_transit_commuting.gd', 'test_transit_operations.gd',
         'test_transit_operations_fifo.gd', 'test_neighbor_commuting.gd',
         'test_loan_worker.gd', 'test_labor_boundary.gd']
OWNED = ['cities_do/core/transit_access_graph.gd',
         'cities_do/core/transit_commuting.gd',
         'cities_do/core/transit_commuting_config.json',
         'cities_do/core/commuting_coordinator.gd',
         'cities_do/core/city_simulation_worker.gd',
         'cities_do/core/city_simulation.gd',
         'cities_do/core/city_native_mailbox.gd',
         'cities_do/tests/test_transit_commuting.gd',
         'tools/run_transit_commuting_validation.py']

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    results = []
    for name in TESTS:
        text = (ROOT / 'cities_do/tests' / name).read_text(encoding='utf-8')
        assert text.startswith('extends SceneTree'), name
        assert not re.search(r'BENCHMARK|Time\.get_ticks|Performance\.get_monitor', text), name
        command = [sys.executable, 'tools/run_dotnet.py', '--timeout', '90',
                   'godot', '--headless', '--path', 'cities_do', '--script', 'res://tests/' + name]
        process = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        output = process.stdout.decode('utf-8', errors='replace')
        matches = re.findall(r'checks=(\d+) (?:failed|failures)=(\d+)', output)
        errors = bool(re.search(r'(?m)^(?:SCRIPT ERROR:|ERROR:|FAIL\b)', output))
        passed = process.returncode == 0 and len(matches) == 1 and int(matches[0][1]) == 0 and not errors
        print(name, 'PASS' if passed else 'FAIL', matches, flush=True)
        if not passed:
            print(output)
            return 1  # Project policy: do not preserve RED/intermediate logs.
        log = OUT / (name.removesuffix('.gd') + '.log')
        log.write_bytes(process.stdout)
        results.append({'name': name, 'exit_code': process.returncode,
                        'checks': int(matches[0][0]), 'failed': int(matches[0][1]),
                        'log': str(log.relative_to(ROOT)).replace('\\', '/'),
                        'sha256': digest(log), 'command': command})
        (OUT / 'tests.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
    manifest = {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                'branch': subprocess.check_output(['git', 'branch', '--show-current'], cwd=ROOT, text=True).strip(),
                'owned_files': {p: digest(ROOT / p) for p in OWNED},
                'tests': results, 'total_checks': sum(r['checks'] for r in results),
                'review_mode': 'self-review; independent parent review pending',
                'capture': None, 'performance_measurements': False, 'build': False,
                'defaults': {'walk_access_metres': 400, 'walk_transfer_metres': 200},
                'inherited_failure': 'Catenary geometry 116/117 aggregate, untouched and not rerun.'}
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print('TOTAL', manifest['total_checks'])
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
