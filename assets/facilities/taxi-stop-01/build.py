import runpy
from pathlib import Path
root=next(p for p in Path(__file__).resolve().parents if (p/"tools/build_sidewalk_transit_stops.py").is_file())
runpy.run_path(str(root/"tools/build_sidewalk_transit_stops.py"),run_name="__main__")
