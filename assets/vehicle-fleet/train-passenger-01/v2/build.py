"""Run from any location; dependencies remain in repository tools and .agents/skills/vehicle."""
import runpy, sys
from pathlib import Path
root=next(p for p in Path(__file__).resolve().parents if (p/"tools/build_transit_vehicles.py").is_file())
sys.argv=[str(root/"tools/build_transit_vehicles.py"),"--","--only","train-passenger-01"]
sys.argv.extend(["--revision", 'v2'])
runpy.run_path(str(root/"tools/build_transit_vehicles.py"),run_name="__main__")
