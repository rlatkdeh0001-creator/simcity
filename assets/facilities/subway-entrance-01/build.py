import runpy
from pathlib import Path
root=Path(__file__).resolve().parents[3]
runpy.run_path(str(root/"tools/build_transit_subway.py"),run_name="__main__")
