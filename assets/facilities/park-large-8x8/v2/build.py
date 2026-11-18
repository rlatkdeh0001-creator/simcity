import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).resolve().parents[4]/"tools/build_rail_park_large_v2.py"),run_name="__main__")
