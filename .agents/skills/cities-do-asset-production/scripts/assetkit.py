#!/usr/bin/env python3
"""Stage and run pinned CITIES_DO recipes without Git, an AI login, or APIs."""
import argparse
import ast
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

SKILL = Path(__file__).resolve().parents[1]
KIT = SKILL / 'kit'
MARKER = '.cities-do-assetkit.json'
PROFILES = {
    'building-growth': [('blender', 'tools/build_growth_14.py', [])],
    'vehicle-fleet': [('blender', 'tools/build_vehicle_fleet.py', ['--render'])],
    'service-vehicles': [('blender', 'tools/build_service_vehicles_2.py', []), ('blender', 'tools/verify_service_vehicles_2.py', [])],
    'primary-grain': [('blender', 'tools/build_primary_industry.py', [])],
    'primary-main': [('blender', 'tools/build_primary_main.py', [])],
    'primary-tiles': [('blender', 'tools/build_primary_work_tiles.py', [])],
    'traffic-signals': [('blender', 'tools/build_traffic_signals.py', []), ('blender', 'tools/render_signal_states.py', []), ('blender', 'tools/verify_traffic_signals.py', []), ('python', 'tools/build_traffic_signal_review.py', [])],
    'citizen': [('blender', 'tools/build_citizen_adult_pilot.py', []), ('blender', 'tools/render_citizen_adult_pilot.py', []), ('python', 'tools/compose_citizen_pilot.py', []), ('blender', 'tools/audit_citizen_projection.py', []), ('blender', 'tools/verify_citizen_adult_pilot.py', []), ('python', 'tools/verify_citizen_sprites.py', [])],
    'parking-parks': [('blender', 'tools/build_facilities.py', [])],
    'road-study': [('blender', 'assets/road-tile-study/build_roads.py', [])],
}


def ids(profile):
    """Read literals with AST, without importing Blender or executing generators."""
    sources = {
        'building-growth': ('build_growth_14.py', 'FLEET', 1),
        'vehicle-fleet': ('build_vehicle_fleet.py', 'FLEET', 0),
        'service-vehicles': ('build_service_vehicles_2.py', 'ROWS', 0),
        'primary-main': ('build_primary_main.py', 'ROWS', 0),
        'primary-tiles': ('build_primary_work_tiles.py', 'ROWS', 0),
        'parking-parks': ('facility_layout.py', 'SPECS', 'id'),
    }
    if profile in sources:
        file, variable, column = sources[profile]
        tree = ast.parse((KIT / 'tools' / file).read_text(encoding='utf-8'))
        for node in tree.body:
            if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == variable for t in node.targets):
                return [r[column] for r in ast.literal_eval(node.value)]
        raise ValueError(f'No literal {variable} found')
    return {'primary-grain': ['primary-farm-grain-01', 'primary-tile-grain-01'], 'traffic-signals': ['traffic-signal-post-01', 'traffic-signal-arm-01'], 'citizen': ['adult-pilot-01'], 'road-study': ['2', '4']}[profile]


def blender_path(value):
    result = shutil.which(value)
    if result is None:
        raise RuntimeError('Blender not found. Install Blender, then supply --blender /path/to/blender (or set BLENDER).')
    return result


def workspace(value, create=False):
    work = Path(value).expanduser().resolve()
    if work == SKILL or SKILL in work.parents or work in SKILL.parents:
        raise ValueError('Use a separate output workspace outside this skill.')
    marker = work / MARKER
    if create and not marker.exists():
        if work.exists() and any(work.iterdir()):
            raise ValueError(f'Refusing unrelated nonempty workspace: {work}')
        work.mkdir(parents=True, exist_ok=True)
        shutil.copytree(KIT, work, dirs_exist_ok=True)
        shutil.copy2(SKILL / 'references/source-manifest.json', work / 'source-manifest.json')
        marker.write_text(json.dumps({'schema_version': 1, 'source': 'cities-do-asset-production', 'created_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}, indent=2) + '\n')
    if not marker.exists() or json.loads(marker.read_text()).get('source') != 'cities-do-asset-production':
        raise ValueError('Run prepare with a new, empty directory first.')
    for name in ['logs', '.render-cache', 'assets', 'cities_do/assets/vehicles', 'cities_do/assets/facilities', 'docs/service-vehicles-2', 'docs/traffic-signals', 'docs/citizen-adult-pilot']:
        (work / name).mkdir(parents=True, exist_ok=True)
    return work


def execute(kind, script, extra, work, args, tag):
    source = Path(script)
    if not source.is_absolute():
        source = work / source
    if kind == 'blender':
        cmd = [blender_path(args.blender), '-b', '--factory-startup', '-t', str(args.threads), '--python-exit-code', '1', '--python-expr', f'import sys; sys.path.insert(0, {str(work / "tools")!r})', '-P', str(source)]
        if extra:
            cmd += ['--', *extra]
    else:
        cmd = [sys.executable, str(source), *extra]
    env = os.environ.copy()
    env['CITIES_DO_RENDER_CACHE'] = str(work / '.render-cache/citizen-adult-pilot')
    if args.profile == 'parking-parks' and args.only:
        env['CITIES_DO_ONLY'] = args.only
    else:
        env.pop('CITIES_DO_ONLY', None)
    log = work / 'logs' / (tag + '.log')
    print(f'RUN {tag}: {source.name} -> {log}', flush=True)
    with log.open('w', encoding='utf-8') as output:
        p = subprocess.run(cmd, cwd=work, env=env, stdout=output, stderr=subprocess.STDOUT, text=True)
    contents = log.read_text(errors='replace')
    if p.returncode or 'Traceback (most recent call last)' in contents:
        print(contents[-7000:], file=sys.stderr)
        raise RuntimeError(f'{tag} failed (exit {p.returncode}); see {log}')
    print(f'DONE {tag}', flush=True)


def check(work, args):
    execute('blender', SKILL / 'scripts/inspect_blends.py', ['--workspace', str(work)], work, args, 'check-blends')
    execute('python', SKILL / 'scripts/inspect_pngs.py', ['--workspace', str(work)], work, args, 'check-pngs')
    for name in ['blend-validation', 'png-validation']:
        result = json.loads((work / 'logs' / (name + '.json')).read_text())
        if not result['passed']:
            raise RuntimeError(f'Failed {name}')
        print(f'{name}: {len(result["assets"])} files passed', flush=True)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('command', choices=['doctor', 'list', 'prepare', 'run', 'check'])
    p.add_argument('--workspace', help='New empty directory; never point at a game checkout')
    p.add_argument('--profile', choices=list(PROFILES))
    p.add_argument('--only', help='One ID from list; omitted means complete profile')
    p.add_argument('--lanes', type=int, choices=[2, 4], default=2)
    p.add_argument('--threads', type=int, default=2)
    p.add_argument('--blender', default=os.environ.get('BLENDER', 'blender'))
    args = p.parse_args()
    if args.threads < 1:
        p.error('--threads must be positive')
    if args.command == 'doctor':
        for dependency in ['numpy', 'PIL']:
            if importlib.util.find_spec(dependency) is None:
                raise RuntimeError(f'Missing {dependency}; pip install -r {SKILL / "requirements.txt"}')
        print('Python:', sys.version.split()[0])
        subprocess.run([blender_path(args.blender), '-b', '--factory-startup', '--python-exit-code', '1', '--python-expr', 'import bpy,numpy; print("ASSETKIT Blender",bpy.app.version_string,"NumPy",numpy.__version__)'], check=True)
        return
    if args.command == 'list':
        print(json.dumps({k: ids(k) for k in ([args.profile] if args.profile else PROFILES)}, ensure_ascii=False, indent=2))
        return
    if not args.workspace:
        p.error('--workspace is required')
    work = workspace(args.workspace, create=args.command in ['prepare', 'run'])
    if args.command == 'prepare':
        print(f'Prepared {work}; edit its tools to create NEW designs. Existing edits are preserved on subsequent runs.')
        return
    if args.command == 'run':
        if not args.profile:
            p.error('--profile is required for run')
        if args.only and args.profile in ['service-vehicles', 'traffic-signals', 'citizen', 'road-study']:
            p.error('This profile runs as a complete batch; --only is not supported')
        if args.only and args.only not in ids(args.profile):
            p.error('Unknown ID; run list --profile first. Add new IDs to the staged generator and invoke it directly as described in the recipe guide.')
        started = time.time()
        for index, (kind, script, extra) in enumerate(PROFILES[args.profile]):
            extra = list(extra)
            if index == 0:
                if args.only and args.profile != 'parking-parks':
                    extra += ['--only', args.only]
                if args.profile == 'road-study':
                    extra += ['--lanes', str(args.lanes)]
            execute(kind, script, extra, work, args, f'{args.profile}-{index:02d}')
        check(work, args)
        record = {'profile': args.profile, 'only': args.only, 'lanes': args.lanes if args.profile == 'road-study' else None, 'elapsed_seconds': round(time.time() - started, 2), 'passed': True, 'script_sha256': {str(f.relative_to(work)): hashlib.sha256(f.read_bytes()).hexdigest() for f in (work / 'tools').glob('*.py')}}
        (work / 'logs' / f'run-{args.profile}.json').write_text(json.dumps(record, indent=2) + '\n')
        print('PASS generation and automated checks. Inspect the rendered PNGs before approval.')
    else:
        check(work, args)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, ValueError, OSError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        sys.exit(1)
