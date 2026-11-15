"""Run approved Godot/.NET with D: caches and process-only PATH."""
import subprocess
import sys
from pathlib import Path
from dotnet_env import environment, godot_executable, SDK
if __name__ == '__main__':
    args = sys.argv[1:]
    if not args or args[0] not in ('godot', 'dotnet'):
        raise SystemExit('Usage: python tools/run_dotnet.py {godot|dotnet} [arguments...]')
    exe = godot_executable() if args.pop(0) == 'godot' else SDK / 'dotnet.exe'
    raise SystemExit(subprocess.call([str(exe), *args], env=environment(), cwd=Path(__file__).resolve().parents[1]))
