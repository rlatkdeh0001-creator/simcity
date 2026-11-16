import runpy
from pathlib import Path
root=Path(__file__).resolve().parents[4]
runpy.run_path(str(root/"tools/build_bus_station_v2.py"),run_name="__main__")
