from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).resolve().parents[3]/'tools/build_street_props.py'))['build']('rail-crossing-signal-01')
