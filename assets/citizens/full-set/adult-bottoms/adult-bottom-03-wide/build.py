import runpy,sys
from pathlib import Path
r=next(p for p in Path(__file__).resolve().parents if (p/"tools/build_citizen_remaining.py").is_file())
args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
sys.argv=[sys.argv[0],"--","--batch","adult-bottoms","--only","adult-bottom-03-wide"]+args
runpy.run_path(str(r/"tools/build_citizen_remaining.py"),run_name="__main__")
