import os,subprocess,json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]; (root/'docs/water-validation').mkdir(parents=True,exist_ok=True); env=os.environ.copy();env.update(XDG_DATA_HOME='/tmp/cities-do-data',XDG_CONFIG_HOME='/tmp/cities-do-config',XDG_CACHE_HOME='/tmp/cities-do-cache')
results=[]
for test in sorted((root/'cities_do/tests').glob('test_*.gd')):
 try:
  p=subprocess.run(['godot','--headless','--path','cities_do','--script','tests/'+test.name],cwd=root,env=env,capture_output=True,text=True,timeout=75)
  output=p.stdout+p.stderr;code=p.returncode
 except subprocess.TimeoutExpired as ex:
  output=str(ex);code=124
 passed=code==0 and not re.search(r'SCRIPT ERROR|^ERROR:|\bFAIL\b',output,re.M)
 (root/'docs/water-validation'/f'{test.stem}.log').write_text(output)
 results.append({'test':test.name,'exit_code':code,'passed':passed})
 print(test.name,passed,flush=True)
(root/'docs/water-validation/results.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
