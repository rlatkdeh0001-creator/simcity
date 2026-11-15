"""Run approved Godot/.NET with D: caches and process-only PATH."""
import subprocess
import sys
from pathlib import Path
from dotnet_env import environment, godot_executable, SDK
if __name__ == '__main__':
    args = sys.argv[1:]
    timeout = 120.0
    if len(args) >= 2 and args[0] == '--timeout':
        timeout = float(args[1])
        if not 1 <= timeout <= 1800:
            raise SystemExit('Timeout must be between 1 and 1800 seconds')
        args = args[2:]
    if not args or args[0] not in ('godot', 'dotnet'):
        raise SystemExit('Usage: python tools/run_dotnet.py {godot|dotnet} [arguments...]')
    exe = godot_executable() if args.pop(0) == 'godot' else SDK / 'dotnet.exe'
    process = subprocess.Popen([str(exe), *args], env=environment(), cwd=Path(__file__).resolve().parents[1])
    try:
        raise SystemExit(process.wait(timeout=timeout))
    except subprocess.TimeoutExpired:
        # Godot's console executable can spawn a GUI executable; terminate only our own process tree.
        subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], capture_output=True)
        raise SystemExit(f'Owned toolchain process exceeded its {timeout}-second limit')
