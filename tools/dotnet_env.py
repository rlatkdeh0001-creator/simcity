"""Process-scoped D: toolchain; never edits global environment or registry."""
import os
from pathlib import Path
ROOT = Path('D:/tools')
SDK = ROOT / 'dotnet'
GODOT = ROOT / 'godot-dotnet'
def environment():
    env = os.environ.copy()
    folders = {'DOTNET_ROOT': SDK, 'DOTNET_ROOT_X64': SDK,
               'DOTNET_CLI_HOME': ROOT / 'dotnet-home',
               'NUGET_PACKAGES': ROOT / 'nuget-packages',
               'NUGET_HTTP_CACHE_PATH': ROOT / 'nuget-http-cache',
               'NUGET_SCRATCH': ROOT / 'nuget-scratch',
               'NUGET_PLUGINS_CACHE_PATH': ROOT / 'nuget-plugin-cache',
               'TEMP': ROOT / 'tmp', 'TMP': ROOT / 'tmp',
               'APPDATA': ROOT / 'dotnet-user/AppData/Roaming',
               'LOCALAPPDATA': ROOT / 'dotnet-user/AppData/Local'}
    for key, path in folders.items():
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    env['PATH'] = str(SDK) + os.pathsep + env.get('PATH', '')
    env.update(DOTNET_CLI_TELEMETRY_OPTOUT='1', DOTNET_GENERATE_ASPNET_CERTIFICATE='false',
               DOTNET_ADD_GLOBAL_TOOLS_TO_PATH='false', DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE='true',
               DOTNET_NOLOGO='1')
    return env

def godot_executable():
    matches = list(GODOT.rglob('Godot_v4.6.3-stable_mono_win64_console.exe'))
    if len(matches) != 1:
        raise RuntimeError(f'Expected one approved Godot .NET executable, found {matches}')
    return matches[0]
