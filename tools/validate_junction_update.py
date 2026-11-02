import os,subprocess,re,json
from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'docs/junction-validation';out.mkdir(parents=True,exist_ok=True);env=os.environ.copy();env.update(XDG_DATA_HOME='/tmp/cities-do-data',XDG_CONFIG_HOME='/tmp/cities-do-config',XDG_CACHE_HOME='/tmp/cities-do-cache')
results=[]
for test in sorted((root/'cities_do/tests').glob('test_*.gd')):
 try:
  p=subprocess.run(['godot','--headless','--path','cities_do','--script','tests/'+test.name],cwd=root,env=env,capture_output=True,text=True,timeout=90);log=p.stdout+p.stderr;code=p.returncode
 except subprocess.TimeoutExpired as e:log=str(e);code=124
 (out/(test.stem+'.log')).write_text(log)
 passed=code==0 and not re.search(r'SCRIPT ERROR|^ERROR:|\bFAIL\b',log,re.M)
 results.append({'test':test.name,'exit_code':code,'passed':passed});print(test.name,passed,flush=True)
(out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(0 if all(x['passed'] for x in results) else 1)
