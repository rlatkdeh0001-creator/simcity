import runpy,sys
from pathlib import Path
r=Path(__file__).resolve().parents[4]
runpy.run_path(str(r/"tools/build_rail_freight_v2.py"),run_name="__main__")
