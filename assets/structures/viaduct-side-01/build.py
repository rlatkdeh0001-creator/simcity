import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).resolve().parents[3]/"tools/build_elevated_strips.py"),run_name="__main__")
