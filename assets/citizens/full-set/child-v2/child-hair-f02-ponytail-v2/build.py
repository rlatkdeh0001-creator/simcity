import runpy,sys
from pathlib import Path
r=next(p for p in Path(__file__).resolve().parents if (p/"tools/build_citizen_child_v2.py").is_file())
a=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
sys.argv=[sys.argv[0],"--","--only","child-hair-f02-ponytail-v2"]+a
runpy.run_path(str(r/"tools/build_citizen_child_v2.py"),run_name="__main__")
