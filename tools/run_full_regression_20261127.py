"""Run the pre-merge Godot suite, with separate headless and framebuffer coverage.

Use --list to verify discovery, and --out with a fresh results directory for
execution (prefer scratch for raw logs). --only accepts test names for reruns.
Nothing is imported or built here; the checkout must have its .NET assembly and
resources ready. All Godot launches use the repository wrapper.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'cities_do'
HELPERS = {'test_neighbor_commuting_contract': 'test_neighbor_commuting'}
NATIVE_ONLY = {'test_terminal_turnback_native', 'test_transit_commuting_view',
               'test_transit_facilities_view'}
# Also run real input tests under a window: the dummy display cannot verify
# native GUI focus, SubViewport textures or actual submission/occlusion.
NATIVE = set('''
asset_money_info budget_window demolition_precedence elevated_rail_ui
 elevated_road_ui horizontal_card_strip hud_v2 keyboard_camera loan_ui main_bottom_ui
 money_ui public_road_snap public_ui rail_catenary_render registered_30_assets
 review_fix_dialog review_fix_ui review_fix_underground_view road_continue
 road_demolition_input road_draw_modes road_grade_flow road_junction_spacing_input
 road_length_units road_midpoint_connections road_mode_ui road_profile_connections
 road_side_contacts road_toolbar_cleanup route_edit route_overlay second_fix_catenary
 second_fix_pier_view second_fix_shared_rail_edit terminal_turnback_native thumbnail_hud
 transit_commuting_view transit_facilities_view transit_operations_view transit_view
 transport_tabs underground_rail_ui underground_road_ui
'''.split())
NATIVE = {'test_' + name for name in NATIVE}
LONG = {'test_background_society', 'test_city_simulation_model',
        'test_city_worker_parity', 'test_city_worker_scenario',
        'test_happiness_background', 'test_happiness_spatial',
        'test_native_worker_parity', 'test_native_worker_scenario',
        'test_population_three_days'}
# These legacy tests emit historical evidence even without a capture flag.
# Redirect only their evidence filename literals in an external test-only copy.
EVIDENCE_PATHS = {
    'test_experimental_test_movement': ('res://visible_sample.gdvar', 'res://visible_sample.json'),
    'test_growth_appearance': ('res://../docs/growth-appearance-validation/matching-table.json',),
    'test_population_three_days': ('D:/project/simcity/docs/csharp-population-validation/three-days.json',),
}
ERROR = re.compile(r'^\s*(?:SCRIPT ERROR:|ERROR:|FAIL(?:ED)?\b|STAGE2 FAILED:|'
                   r'WARNING:.*(?:ObjectDB instances leaked|Thread object.*destroyed))', re.I)
COUNTS = (
    (re.compile(r'^RESULT\s+(\d+)\s*/\s*(\d+)\b', re.I), False),
    (re.compile(r'(\d+)\s+passed[\s,]+(\d+)\s+failed\b', re.I), True),
    (re.compile(r'\bpassed=(\d+)\s+failed=(\d+)\b', re.I), True),
    (re.compile(r'\bchecks=\s*(\d+)\s+failed=\s*(\d+)\b', re.I), 'total'),
    (re.compile(r'^STAGE2_PASS checks=(\d+)\b'), True),
)


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def read_source(path):
    return path.read_text(encoding='utf-8-sig')


def entry_point(path, visited=()):
    if path in visited:
        raise ValueError(f'circular test inheritance: {path}')
    m = re.search(r'^extends\s+(\S+)', read_source(path), re.M)
    if not m:
        raise ValueError(f'missing top-level extends: {path}')
    base = m[1].strip('"')
    if base.startswith('res://'):
        return entry_point(PROJECT / base[6:], (*visited, path))
    return base in ('SceneTree', 'MainLoop')


def discover():
    files = sorted((PROJECT / 'tests').glob('test_*.gd'))
    entries = {p.stem: p for p in files if entry_point(p)}
    if {p.stem for p in files} - entries.keys() != HELPERS.keys():
        raise ValueError('entry point inventory changed: check helper wrappers')
    if not (NATIVE | LONG | set(EVIDENCE_PATHS) | set(HELPERS.values())) <= entries.keys():
        raise ValueError('configured suite missing from inventory')
    return entries


def assertions(text):
    for line in reversed(text.splitlines()):
        for regex, form in COUNTS:
            match = regex.search(line)
            if not match:
                continue
            a, *rest = map(int, match.groups())
            b = rest[0] if rest else 0
            if form == 'total':
                return a - b, a
            return (a, a + b) if form else (a, b)
    return None


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require_native_desktop_free():
    process_rows = subprocess.check_output(['tasklist.exe', '/FO', 'CSV', '/NH'])
    godot_processes = [(name, pid) for name, pid, *_ in csv.reader(
        process_rows.decode('ascii', errors='replace').splitlines())
        if 'godot' in name.casefold() and name.lower().endswith('.exe')]
    if godot_processes:
        raise SystemExit(f'Native verification deferred; other Godot processes: {godot_processes}')


def build_arguments(name, source, mode, out):
    path = 'res://tests/' + source.name
    args = []
    redirects = {}
    if name in EVIDENCE_PATHS:
        text = read_source(source)
        folder = out / 'redirected-evidence' / name
        folder.mkdir(parents=True)
        for old in EVIDENCE_PATHS[name]:
            quoted = json.dumps(old)
            if text.count(quoted) != 1:
                raise ValueError(f'{name}: legacy evidence output changed: {old}')
            new = (folder / old.rsplit('/', 1)[-1]).as_posix()
            text = text.replace(quoted, json.dumps(new, ensure_ascii=False))
            redirects[old] = new
        copy = folder / source.name
        copy.write_text(text, encoding='utf-8')
        path = copy.as_posix()
    if name == 'test_second_fix_supports':
        baseline = out / '5bc4e99-road_height.gd.txt'
        if not baseline.exists():
            baseline.write_bytes(git('show', '5bc4e99:cities_do/core/road_height.gd'))
        args.append(f'--baseline={baseline.as_posix()}')
    graphics = ['--headless']
    if mode == 'native':
        graphics = ['--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3',
                    '--max-fps', '30', '--resolution', '1920x1080', '--fullscreen']
        if name == 'test_terminal_turnback_native':
            graphics[-2:] = ['1280x820']
        if name == 'test_road_demolition_input':
            graphics[-2:] = ['1280x820', '--windowed', '--borderless']
    timeout = '900' if name in LONG else '120'
    command = [sys.executable, 'tools/run_dotnet.py', '--timeout', timeout, 'godot',
               '--path', str(PROJECT), '--audio-driver', 'Dummy', *graphics, '--script', path]
    if args:
        command += ['--', *args]
    return command, redirects


def run_one(name, source, mode, out):
    source_hash = sha(source.read_bytes())
    if mode == 'native':
        require_native_desktop_free()
    command, redirects = build_arguments(name, source, mode, out)
    logfile = out / (mode + '-' + name + '.log')
    with logfile.open('xb') as stream:
        code = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT).returncode
    data = logfile.read_bytes()
    text = data.decode('utf-8', errors='replace')
    counts = assertions(text)
    errors = [line for line in text.splitlines() if ERROR.match(line)]
    if not data.strip():
        errors.append('empty Godot log')
    if sha(source.read_bytes()) != source_hash:
        errors.append('test source changed during the run')
    ok = code == 0 and not errors and (counts is None or counts[0] == counts[1])
    result = dict(mode=mode, test=name, passed=ok, exit_code=code, assertions=counts,
                  errors=errors, logfile=logfile.name, log_sha256=sha(data),
                  source_sha256=source_hash, redirects=redirects, command=command)
    print(f'{mode:8} {"PASS" if ok else "FAIL"} {name} {counts or "uncounted"} exit={code}', flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--mode', choices=('headless', 'native', 'both'), default='both')
    parser.add_argument('--out', type=Path)
    parser.add_argument('--only', nargs='+')
    parser.add_argument('--require-head')
    opts = parser.parse_args()
    inventory = discover()
    if opts.only and not set(opts.only) <= inventory.keys():
        parser.error('--only contains an unknown or non-runnable script')
    jobs = [(m, name) for m in ('headless', 'native') if opts.mode in (m, 'both')
            for name in inventory if (not opts.only or name in opts.only)
            and (name not in NATIVE_ONLY if m == 'headless' else name in NATIVE)]
    if not jobs:
        parser.error('no runnable tests for that selection')
    if opts.list:
        print(json.dumps(dict(helpers=HELPERS, jobs=jobs), indent=2))
        return 0
    if not opts.out or not opts.require_head:
        parser.error('execution needs --out and --require-head')
    current = git('rev-parse', 'HEAD').decode().strip()
    if current != git('rev-parse', '--verify', opts.require_head + '^{commit}').decode().strip():
        raise SystemExit(f'checkout HEAD does not match {opts.require_head}: {current}')
    if git('branch', '--show-current').strip() != b'perf/render-sim-cadence':
        raise SystemExit('unexpected checkout branch')
    out = opts.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    config = PROJECT / 'project.godot'
    config_hash = sha(config.read_bytes())
    metadata = dict(head=current, jobs=jobs, helpers=HELPERS, project_sha256=config_hash)
    (out / 'run.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    results = []
    with (out / 'results.jsonl').open('x', encoding='utf-8') as file:
        for mode, name in jobs:
            if sha(config.read_bytes()) != config_hash or git('rev-parse', 'HEAD').decode().strip() != current:
                raise SystemExit('project settings or HEAD changed after launch')
            record = run_one(name, inventory[name], mode, out)
            results.append(record)
            file.write(json.dumps(record, ensure_ascii=False) + '\n')
            file.flush()
    for mode in ('headless', 'native'):
        subset = [r for r in results if r['mode'] == mode]
        if subset:
            print(mode, sum(r['passed'] for r in subset), '/', len(subset), 'suites', flush=True)
    return int(not all(r['passed'] for r in results))


if __name__ == '__main__':
    raise SystemExit(main())
