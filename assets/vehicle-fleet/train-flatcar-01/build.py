"""Run from any location; dependencies remain in repository tools and .agents/skills/vehicle."""
import runpy, sys
from pathlib import Path
root=Path(__file__).resolve().parents[3]
sys.argv=[str(root/"tools/build_transit_vehicles.py"),"--","--only","train-flatcar-01"]
runpy.run_path(str(root/"tools/build_transit_vehicles.py"),run_name="__main__")
