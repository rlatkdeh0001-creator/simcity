"""Render representative outputs for all 10 profiles, in isolated workspaces."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import json
from pathlib import Path
import platform
import subprocess
import sys
import time

PLAN = [
    ('building-growth', 'small-4x4-logistics-01'),
    ('vehicle-fleet', 'car-sedan-03'),
    ('service-vehicles', None),
    ('primary-grain', None),
    ('primary-main', 'primary-mine-iron-01'),
    ('primary-tiles', 'primary-tile-mine-coal-01'),
    ('traffic-signals', None),
    ('citizen', None),
    ('parking-parks', 'parking-small-2x4'),
    ('road-study', None),
]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', required=True, help='New empty directory for the test suite')
    p.add_argument('--jobs', type=int, choices=[1, 2, 3], default=2)
    p.add_argument('--blender', default=None)
    a = p.parse_args()
    base = Path(a.output).expanduser().resolve()
    if base.exists() and any(base.iterdir()):
        p.error('Use a new empty --output directory')
    base.mkdir(parents=True, exist_ok=True)
    runner = Path(__file__).resolve().with_name('assetkit.py')

    def run(row):
        profile, ident = row
        work = base / 'outputs' / profile
        cmd = [sys.executable, str(runner), 'run', '--workspace', str(work), '--profile', profile, '--threads', '2']
        if ident:
            cmd += ['--only', ident]
        if a.blender:
            cmd += ['--blender', a.blender]
        started = time.time()
        with (base / (profile + '.log')).open('w', encoding='utf-8') as f:
            result = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT)
        record = dict(profile=profile, only=ident, exit_code=result.returncode, elapsed_seconds=round(time.time() - started, 2), no_git_workspace=not (work / '.git').exists())
        for name in ['blend-validation', 'png-validation']:
            path = work / 'logs' / (name + '.json')
            if path.exists():
                r = json.loads(path.read_text())
                record[name] = dict(files=len(r['assets']), passed=r['passed'])
        print(json.dumps(record), flush=True)
        return record

    with ThreadPoolExecutor(max_workers=a.jobs) as pool:
        rows = [f.result() for f in as_completed([pool.submit(run, row) for row in PLAN])]
    rows.sort(key=lambda r: r['profile'])
    report = dict(utc=datetime.now(timezone.utc).isoformat(), python=platform.python_version(), platform=platform.system(), scope='representative recipe execution, not all catalog models or AI evaluation', profiles=rows, passed=all(r['exit_code'] == 0 and r['no_git_workspace'] for r in rows))
    (base / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PASS' if report['passed'] else 'FAIL', base / 'results.json')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
