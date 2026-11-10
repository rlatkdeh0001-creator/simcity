"""Run real Godot tests/captures for the main bottom HUD (Windows/Linux).
python tools/validate_bottom_ui_main.py --godot C:/path/to/godot.exe --tests
python tools/validate_bottom_ui_main.py --godot C:/path/to/godot.exe --captures
No source edits, mock engine output, or generated/composited screenshots.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/bottom-ui-main-validation'


def execute(name, command, timeout=90):
    start = time.monotonic()
    timed_out = False
    log = OUT / (name + '.log')
    with log.open('w', encoding='utf-8') as stream:
        try:
            code = subprocess.run(command, cwd=ROOT, stdout=stream,
                                  stderr=subprocess.STDOUT, timeout=timeout).returncode
        except subprocess.TimeoutExpired:
            code = None
            timed_out = True
    text = log.read_text(encoding='utf-8', errors='replace')
    errors = [line for line in text.splitlines()
              if re.search(r'^\s*(?:SCRIPT ERROR:|ERROR:|FAIL(?:ED)?\b)', line)]
    summaries = [line for line in text.splitlines() if line.startswith('RESULT ')]
    result = dict(name=name, command=command, exit_code=code,
                  timed_out=timed_out, errors=errors, summaries=summaries,
                  passed=code == 0 and not timed_out and not errors,
                  elapsed_s=round(time.monotonic() - start, 2), log=log.name)
    print(json.dumps(result, ensure_ascii=True), flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--tests', action='store_true')
    parser.add_argument('--captures', action='store_true')
    parser.add_argument('--only', nargs='*')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    report = {'recorded_at': datetime.datetime.now().astimezone().isoformat(),
              'godot': args.godot}
    base = [args.godot, '--headless', '--path', str(ROOT / 'cities_do')]
    if args.tests:
        report['import'] = execute('import', [args.godot, '--headless', '--editor',
                                            '--import', '--path', str(ROOT / 'cities_do'), '--quit'], 240)
        tests = sorted((ROOT / 'cities_do/tests').glob('test_*.gd'))
        if args.only:
            tests = [p for p in tests if p.stem in args.only]
        report['tests'] = []
        for test in tests:
            report['tests'].append(execute(test.stem, base + ['--script', 'res://tests/' + test.name]))
            (OUT / ('results-selected.json' if args.only else 'results.json')).write_text(
                json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        report['total'] = len(tests)
        report['passed'] = sum(t['passed'] for t in report['tests'])
        report['failed'] = report['total'] - report['passed']
        (OUT / ('results-selected.json' if args.only else 'results.json')).write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print('TEST_TOTALS', report['total'], report['passed'], report['failed'], flush=True)
    if args.captures:
        report['captures'] = []
        shots = [('main-default-1920', '1920x1080', ''),
                 ('main-fire-1920', '1920x1080', 'fire'),
                 ('main-corrections-1920', '1920x1080', 'corrections'),
                 ('main-zoning-1920', '1920x1080', 'build'),
                 ('main-fire-1280', '1280x820', 'fire')]
        for name, resolution, tab in shots:
            path = OUT / (name + '.png')
            command = [args.godot, '--path', str(ROOT / 'cities_do'), '--audio-driver', 'Dummy',
                       '--rendering-method', 'gl_compatibility',
                       '--resolution', resolution, '--position', '0,0',
                       '--', '--capture-bottom-ui=' + str(path)]
            if tab:
                command.append('--bottom-tab=' + tab)
            # Windows constrains borderless windows to the work area (1061px here).
            # Fullscreen obtains a real 1920x1080 framebuffer, never resize the PNG.
            command.insert(command.index('--'), '--fullscreen' if resolution == '1920x1080' else '--borderless')
            result = execute(name, command, 60)
            if path.exists():
                data = path.read_bytes()
                result['png_size'] = list(struct.unpack('>II', data[16:24]))
                result['sha256'] = hashlib.sha256(data).hexdigest()
                result['passed'] = result['passed'] and result['png_size'] == list(map(int, resolution.split('x')))
            else:
                result['passed'] = False
            report['captures'].append(result)
        (OUT / 'captures.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    ok = all(t['passed'] for t in report.get('tests', [])) and all(t['passed'] for t in report.get('captures', []))
    if 'import' in report:
        ok = ok and report['import']['passed']
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
