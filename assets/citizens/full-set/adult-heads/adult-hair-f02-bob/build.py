import runpy,sys
from pathlib import Path
r=next(p for p in Path(__file__).resolve().parents if (p/"tools/build_citizen_adult_heads.py").is_file())
sys.argv=[sys.argv[0],"--","--only","adult-hair-f02-bob"]+sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [sys.argv[0],"--","--only","adult-hair-f02-bob"]
runpy.run_path(str(r/"tools/build_citizen_adult_heads.py"),run_name="__main__")
