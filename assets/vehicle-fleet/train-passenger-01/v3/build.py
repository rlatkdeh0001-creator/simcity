import runpy,sys
from pathlib import Path
root=Path(__file__).resolve().parents[4]
sys.argv=[sys.argv[0],"--","--only","train-passenger-01"]+sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [sys.argv[0],"--","--only","train-passenger-01"]
runpy.run_path(str(root/"tools/build_transit_train_v3.py"),run_name="__main__")
