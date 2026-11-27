"""Run the pre-merge Godot suite, with separate headless and framebuffer coverage.

Use --list to verify discovery, and --out with a fresh results directory for
execution (prefer scratch for raw logs). --only accepts test names for reruns.
Suites requiring normal engine imports use a new project copy in the output
directory. The prepared .NET assembly is copied; nothing is built. All Godot
launches use the repository wrapper.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'cities_do'
IMPORT_REQUIRED = {'test_facilities', 'test_vehicles', 'test_thumbnail_hud'}
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
    if not (NATIVE | LONG | IMPORT_REQUIRED | set(EVIDENCE_PATHS) | set(HELPERS.values())) <= entries.keys():
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


def import_project_copy(out):
    """Import real resources without rewriting checkout metadata or config."""
    sandbox = out / 'normal-import'
    project = sandbox / PROJECT.name
    tracked = git('ls-files', '-z', '--', PROJECT.name).decode('utf-8').split('\0')
    for relative in (p for p in tracked if p):
        target = sandbox / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / relative, target)
    bin_dir = Path('.godot/mono/temp/bin')
    assemblies = PROJECT / bin_dir
    if not (assemblies / 'Debug/CitiesDo.dll').is_file():
        raise RuntimeError('Prepared .NET Debug assembly is required; no build performed')
    copied_bin = project / bin_dir
    shutil.copytree(assemblies, copied_bin)
    copied_dll = copied_bin / 'Debug/CitiesDo.dll'
    dll_hash = sha(copied_dll.read_bytes())
    log = out / 'normal-import.log'
    command = [sys.executable, 'tools/run_dotnet.py', '--timeout', '600', 'godot',
               '--headless', '--editor', '--import', '--path', str(project), '--audio-driver', 'Dummy']
    with log.open('xb') as stream:
        code = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT).returncode
    data = log.read_bytes()
    errors = [line for line in data.decode('utf-8', errors='replace').splitlines() if ERROR.match(line)]
    imported = project / '.godot/imported'
    resources = sum(path.is_file() for path in imported.iterdir()) if imported.is_dir() else 0
    if sha(copied_dll.read_bytes()) != dll_hash:
        errors.append('import changed the copied runtime assembly')
    result = dict(command=command, exit_code=code, errors=errors, resources=resources,
                  log=log.name, log_sha256=sha(data), dll_sha256=dll_hash)
    (out / 'normal-import.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    if code or errors or not resources:
        raise SystemExit(f'Normal Godot import failed (exit={code}, errors={len(errors)}): {log}')
    print(f'normal-import PASS {resources} cache files: {log}', flush=True)
    return project


def build_arguments(name, source, mode, out, project=PROJECT):
    path = 'res://tests/' + source.name
    args = []
    redirects = {}
    if name in EVIDENCE_PATHS:
        text = read_source(source)
        folder = out / 'redirected-evidence' / mode / name
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
               '--path', str(project), '--audio-driver', 'Dummy', *graphics, '--script', path]
    if args:
        command += ['--', *args]
    return command, redirects


def run_one(name, source, mode, out, project=PROJECT, require_counted=False):
    source_hash = sha(source.read_bytes())
    if mode == 'native':
        require_native_desktop_free()
    if project != PROJECT:
        copied = project / 'tests' / source.name
        if sha(copied.read_bytes()) != source_hash:
            raise RuntimeError(f'{name}: test no longer matches the imported project copy')
    command, redirects = build_arguments(name, source, mode, out, project)
    logfile = out / (mode + '-' + name + '.log')
    with logfile.open('xb') as stream:
        code = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT).returncode
    data = logfile.read_bytes()
    text = data.decode('utf-8', errors='replace')
    counts = assertions(text)
    errors = [line for line in text.splitlines() if ERROR.match(line)]
    if not data.strip():
        errors.append('empty Godot log')
    if require_counted and counts is None:
        errors.append('missing completion assertion count')
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
    parser.add_argument('--native-for-selected', action='store_true',
                        help='also exercise all explicit --only tests with a real display')
    parser.add_argument('--require-counted', action='store_true',
                        help='reject a clean exit without a reported assertion total')
    parser.add_argument('--require-head')
    opts = parser.parse_args()
    inventory = discover()
    if opts.only and not set(opts.only) <= inventory.keys():
        parser.error('--only contains an unknown or non-runnable script')
    if opts.native_for_selected and not opts.only:
        parser.error('--native-for-selected requires an explicit --only selection')
    jobs = [(m, name) for m in ('headless', 'native') if opts.mode in (m, 'both')
            for name in inventory if (not opts.only or name in opts.only)
            and (name not in NATIVE_ONLY if m == 'headless' else name in NATIVE or opts.native_for_selected)]
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
    requires_import = any(name in IMPORT_REQUIRED for _, name in jobs)
    metadata = dict(head=current, jobs=jobs, helpers=HELPERS, project_sha256=config_hash,
                    normal_import=requires_import, require_counted=opts.require_counted)
    (out / 'run.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    # Only strict asset suites need the copied import cache; run the rest on
    # the actual checkout (and keep its existing no-import/no-build workflow).
    imported_project = import_project_copy(out) if requires_import else PROJECT
    results = []
    with (out / 'results.jsonl').open('x', encoding='utf-8') as file:
        for mode, name in jobs:
            if sha(config.read_bytes()) != config_hash or git('rev-parse', 'HEAD').decode().strip() != current:
                raise SystemExit('project settings or HEAD changed after launch')
            project = imported_project if name in IMPORT_REQUIRED else PROJECT
            record = run_one(name, inventory[name], mode, out, project, opts.require_counted)
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
