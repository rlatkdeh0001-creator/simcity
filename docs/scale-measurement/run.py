"""Bounded, isolated profiling of copied production cores; never rewrites game code."""
from pathlib import Path
import datetime,json,os,shutil,subprocess,sys,time,hashlib,re
from zoneinfo import ZoneInfo
ROOT=Path('D:/project/simcity')
ASSETS=ROOT/'docs/scale-measurement'
VARIANT=os.environ.get('SCALE_MEASUREMENT_VARIANT','parallel')
if VARIANT not in {'after','parallel'}:raise ValueError('Output variant must be after or parallel; baseline artifacts are immutable')
OUT=ASSETS/VARIANT
OUT.mkdir(parents=True,exist_ok=True)
BOX=Path('D:/tools/validation/ScaleMeasurement')
import importlib.util
spec=importlib.util.spec_from_file_location('scale_dotnet_env',ROOT/'tools/dotnet_env.py')
assert spec is not None and spec.loader is not None
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
environment=module.environment;godot_executable=module.godot_executable

def prepare():
    assert datetime.datetime.now(ZoneInfo('Asia/Seoul'))>=datetime.datetime(2026,11,16,11,tzinfo=ZoneInfo('Asia/Seoul'))
    assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()=='perf/render-sim-cadence'
    BOX.mkdir(parents=True,exist_ok=True)
    source=ROOT/'cities_do/simulation';hashes={}
    for name in ['PopulationCore.cs','PopulationState.cs','PopulationState.Happiness.cs','HappinessCore.cs','HappinessCore.World.cs','HappinessCore.Spatial.cs','HappinessCore.Cache.cs','HappinessCore.Parallel.cs']:
        raw=(source/name).read_bytes();hashes[name]=hashlib.sha256(raw).hexdigest();text=raw.decode('utf-8')
        if name=='HappinessCore.World.cs':
            text=text.replace('    public D Tick(double seconds,long[] supplies)', '''    private double _groupsMs,_bucketMs,_averageMs,_assignmentMs,_dailyMs;
    private static double NowMs()=>System.Diagnostics.Stopwatch.GetTimestamp()*1000.0/System.Diagnostics.Stopwatch.Frequency;
    public D Diagnostics()=>new D {["groups_ms"]=_groupsMs,["bucket_ms"]=_bucketMs,["average_ms"]=_averageMs,["assignment_ms"]=_assignmentMs,["daily_ms"]=_dailyMs};
    public D Tick(double seconds,long[] supplies)''')
            text=text.replace('_elapsed+=seconds;RefreshGroups();','_groupsMs=_bucketMs=_averageMs=_assignmentMs=_dailyMs=0;double profile=NowMs();\n        _elapsed+=seconds;RefreshGroups();_groupsMs=NowMs()-profile;')
            text=text.replace('if(!_assigned)AssignServices();','if(!_assigned){profile=NowMs();AssignServices();_assignmentMs+=NowMs()-profile;}')
            text=text.replace('while(_elapsed+1e-8>=_nextDay)','double dailyStart=NowMs();\n        while(_elapsed+1e-8>=_nextDay)')
            text=text.replace('            AssignServices();','            profile=NowMs();AssignServices();_assignmentMs+=NowMs()-profile;')
            bucket_marker='        var prepared=PrepareBucket(_buckets[_bucket]);int preparedIndex=0;' if 'PrepareBucket(_buckets[_bucket])' in text else '        foreach(var b in _buckets[_bucket])'
            text=text.replace(bucket_marker,'        _dailyMs=NowMs()-dailyStart;profile=NowMs();\n'+bucket_marker)
            text=text.replace('_bucket=(_bucket+1)%75;UpdateCityHappiness();','_bucketMs=NowMs()-profile;_bucket=(_bucket+1)%75;profile=NowMs();UpdateCityHappiness();_averageMs=NowMs()-profile;')
            assert 'Diagnostics()' in text and '_bucketMs=NowMs()-profile' in text
        (BOX/name).write_text(text,encoding='utf-8')
    shutil.copyfile(ROOT/'cities_do/core/population_config.json',BOX/'population_config.json')
    shutil.copyfile(ASSETS/'measure.gd',BOX/'measure.gd')
    shutil.copyfile(ROOT/'global.json',BOX/'global.json')
    shutil.copyfile(ROOT/'NuGet.Config',BOX/'NuGet.Config')
    (BOX/'ScaleMeasurement.csproj').write_text('<Project Sdk="Godot.NET.Sdk/4.6.3"><PropertyGroup><TargetFramework>net10.0</TargetFramework><EnableDynamicLoading>true</EnableDynamicLoading><Nullable>enable</Nullable><NuGetAudit>false</NuGetAudit></PropertyGroup></Project>')
    (BOX/'project.godot').write_text('config_version=5\n[application]\nconfig/name="ScaleMeasurement"\nconfig/features=PackedStringArray("4.6", "C#", "GL Compatibility")\n[dotnet]\nproject/assembly_name="ScaleMeasurement"\n')
    (OUT/'source-manifest.json').write_text(json.dumps({'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'sha256':hashes,'instrumentation':'Stopwatch section brackets added only to isolated copied HappinessCore.Tick; production algorithms unchanged','sandbox':str(BOX),'production_files_modified':False},indent=2))
    p=subprocess.run(['D:/tools/dotnet/dotnet.exe','build',str(BOX/'ScaleMeasurement.csproj'),'--nologo'],env=environment(),cwd=BOX,capture_output=True,timeout=120)
    assert p.returncode==0,(p.stdout+p.stderr).decode(errors='replace')
    (OUT/'build.log').write_bytes(p.stdout+p.stderr)

def run(count,scenario='steady',deadline=150):
    import psutil
    args=[str(godot_executable()),'--headless','--path',str(BOX),'--script','res://measure.gd','--','--population='+str(count),'--scenario='+scenario]
    p=subprocess.Popen(args,env=environment(),cwd=BOX,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    import threading
    assert p.stdout is not None
    stream=p.stdout
    chunks=[]
    def collect():
        for raw in iter(stream.readline,b''):
            chunks.append(raw)
            if b'SCALE_' in raw:print(raw.decode(errors='replace').strip(),flush=True)
    thread=threading.Thread(target=collect,daemon=True);thread.start();start=time.monotonic();peak=0;reason=None
    while p.poll() is None:
        try:
            parent=psutil.Process(p.pid);rss=sum(q.memory_info().rss for q in [parent]+parent.children(recursive=True));peak=max(peak,rss)
        except psutil.Error:pass
        if peak>6*1024**3:reason='owned process tree exceeded 6 GiB RSS';break
        if time.monotonic()-start>deadline:reason=f'owned run exceeded {deadline}s';break
        time.sleep(.25)
    if reason:subprocess.run(['taskkill','/PID',str(p.pid),'/T','/F'],capture_output=True)
    p.wait(timeout=15);thread.join(timeout=5);text=b''.join(chunks).decode(errors='replace')
    if reason:print('BOUNDED_DIAGNOSTIC_TAIL',text[-4000:],flush=True)
    result={'population':count,'scenario':scenario,'status':'bounded_stop' if reason else 'passed','reason':reason,'peak_tree_rss_bytes':peak,'wall_seconds':time.monotonic()-start}
    marker='SCALE_DAILY_RESULT ' if scenario=='daily' else 'SCALE_RESULT '
    lines=[s for s in text.splitlines() if s.startswith(marker)]
    if lines and not re.search(r'^\s*(SCRIPT ERROR:|ERROR:)',text,re.M) and not reason:
        result['measurement']=json.loads(lines[-1][len(marker):]);(OUT/f'{count}-{scenario}.log').write_text(text,encoding='utf-8')
    else:
        if not reason:result['status']='failed';result['reason']=text[-3000:]
        result['completed_progress']=[s for s in text.splitlines() if s.startswith('SCALE_')]
    return result

if __name__=='__main__':
    if '--prepare' in sys.argv:prepare()
    else:
        count=int(sys.argv[1]);scenario=sys.argv[2] if len(sys.argv)>2 else 'steady'
        result=run(count,scenario,int(sys.argv[3]) if len(sys.argv)>3 else 150)
        (OUT/f'{count}-{scenario}.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
        print('BOUNDED_RESULT',json.dumps(result),flush=True)
