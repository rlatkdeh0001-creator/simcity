import runpy,sys
from pathlib import Path
sys.argv += ["--", "--only", "center-flyover-sample-01"]
runpy.run_path(str(Path(__file__).resolve().parents[3]/"tools/build_center_structure_samples.py"),run_name="__main__")
