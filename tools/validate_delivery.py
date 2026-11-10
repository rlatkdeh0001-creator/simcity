"""Run the existing complete Godot validator into a distinct delivery folder.
python tools/validate_delivery.py --output docs/emergency-assets-validation --godot C:/path/godot.exe
Append --only test_name ... for focused checks (results-selected.json).
"""
import argparse
from pathlib import Path
import runpy
import sys

ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--output',required=True)
 p.add_argument('--godot',required=True)
 p.add_argument('--only',nargs='*')
 args=p.parse_args()
 module=runpy.run_path(str(ROOT/'tools/validate_bottom_ui_main.py'),run_name='delivery_validation')
 module['main'].__globals__['OUT']=ROOT/args.output
 sys.argv=['validate_bottom_ui_main.py','--godot',args.godot,'--tests']
 if args.only:sys.argv+=['--only',*args.only]
 return module['main']()
if __name__=='__main__':raise SystemExit(main())
