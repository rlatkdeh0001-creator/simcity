import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).resolve().parents[3]/"tools/build_rail_park_large.py"),run_name="__main__")
