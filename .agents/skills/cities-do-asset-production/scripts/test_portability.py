"""Fast meaningful CLI/package checks; no rendering, no network, no Git required."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import tempfile

skill = Path(__file__).resolve().parents[1]
runner = skill / 'scripts/assetkit.py'
manifest = json.loads((skill / 'references/source-manifest.json').read_text())
checks = {}
checks['all_pinned_source_hashes_match'] = all(hashlib.sha256((skill / 'kit' / row['path']).read_bytes()).hexdigest() == row['bundled_sha256'] for row in manifest['sources'])
checks['all_scripts_compile'] = True
for path in skill.rglob('*.py'):
    compile(path.read_text(encoding='utf-8'), str(path), 'exec')

def cli(*args):
    return subprocess.run([sys.executable, str(runner), *args], capture_output=True, text=True)

with tempfile.TemporaryDirectory(prefix='assetkit-portability-') as folder:
    temp = Path(folder)
    guard = temp / 'existing-project'
    guard.mkdir()
    (guard / 'do-not-change.txt').write_text('approved content')
    result = cli('prepare', '--workspace', str(guard))
    checks['unrelated_workspace_rejected_without_changes'] = result.returncode != 0 and [p.name for p in guard.iterdir()] == ['do-not-change.txt'] and (guard / 'do-not-change.txt').read_text() == 'approved content'
    work = temp / 'fresh'
    result = cli('prepare', '--workspace', str(work))
    checks['standalone_prepare_without_git'] = result.returncode == 0 and not (work / '.git').exists() and (work / '.agents/skills/vehicle/blender/common.py').is_file()
    customized = work / 'tools/build_growth_14.py'
    customized.write_text(customized.read_text() + '\n# preserved staged customization\n')
    before = customized.read_bytes()
    result = cli('prepare', '--workspace', str(work))
    checks['prepare_preserves_customized_generators'] = result.returncode == 0 and customized.read_bytes() == before
    result = cli('run', '--workspace', str(work), '--profile', 'building-growth', '--only', 'missing-id')
    checks['unknown_asset_rejected_before_render'] = result.returncode != 0 and 'Unknown ID' in result.stderr
    result = cli('run', '--workspace', str(work), '--profile', 'citizen', '--only', 'adult-pilot-01')
    checks['partial_batch_rejected'] = result.returncode != 0 and 'complete batch' in result.stderr
    result = cli('prepare', '--workspace', str(skill / 'must-not-create'))
    checks['skill_self_overwrite_rejected'] = result.returncode != 0 and not (skill / 'must-not-create').exists()
result = cli('list')
checks['ten_profile_catalogs_available_without_blender_import'] = result.returncode == 0 and len(json.loads(result.stdout)) == 10
print(json.dumps(dict(checks=checks, passed=all(checks.values())), indent=2))
assert all(checks.values())
