"""Run all tests, or recheck named tests while preserving the other results."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
root = Path(__file__).resolve().parents[1]
out = root / 'docs/service-assets-validation'
out.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(XDG_DATA_HOME='/tmp/cities-do-data', XDG_CONFIG_HOME='/tmp/cities-do-config', XDG_CACHE_HOME='/tmp/cities-do-cache')
result_path = out / 'results.json'
previous = json.loads(result_path.read_text()) if sys.argv[1:] and result_path.exists() else []
results = {row['test']: row for row in previous}
tests = sorted((root/'cities_do/tests').glob('test_*.gd'))
for test in tests:
    if sys.argv[1:] and test.name not in sys.argv[1:]:
        continue
    try:
        process = subprocess.run(['godot', '--headless', '--audio-driver', 'Dummy', '--path', 'cities_do', '--script', 'tests/'+test.name], cwd=root, env=env, capture_output=True, text=True, timeout=90)
        log, code = process.stdout+process.stderr, process.returncode
    except subprocess.TimeoutExpired as error:
        log, code = str(error), 124
    (out/(test.stem+'.log')).write_text(log)
    passed = code == 0 and not re.search(r'SCRIPT ERROR|^ERROR:|\bFAIL\b', log, re.M)
    results[test.name] = {'test':test.name, 'exit_code':code, 'passed':passed}
    print(test.name, passed, flush=True)
result_path.write_text(json.dumps(sorted(results.values(), key=lambda r:r['test']), indent=2)+'\n')
raise SystemExit(0 if all(row['passed'] for row in results.values()) else 1)
