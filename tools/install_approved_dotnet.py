"""Install only the two specifically approved portable archives on D:."""
import hashlib
import json
import pathlib
import urllib.request
import zipfile
from dotnet_env import ROOT, SDK, GODOT, environment, godot_executable
ARTIFACTS = [
    ('Godot_v4.6.3-stable_mono_win64.zip',
     'https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_mono_win64.zip',
     'sha256', '0015a6f2fab16e255919380864e8b5320017b1258c01121d5521b133dbe705f6', GODOT),
    ('dotnet-sdk-10.0.404-win-x64.zip',
     'https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.404/dotnet-sdk-10.0.404-win-x64.zip',
     'sha512', '330ddd2665b43cd2e428216a0d8ea1ac7bb19b5434fdc530e62010dc3b52823a620bf95489d628e1ed6f5122401793ee4887cca4a019122361a1231497f632ee', SDK),
]
def install():
    archives = ROOT / 'downloads'
    archives.mkdir(parents=True, exist_ok=True)
    rows = []
    for name, url, algorithm, expected, target in ARTIFACTS:
        archive = archives / name
        if not archive.exists():
            partial = archive.with_suffix('.partial')
            with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'simcity-approved-toolchain'}), timeout=120) as source, partial.open('wb') as output:
                while chunk := source.read(1024 * 1024):
                    output.write(chunk)
            partial.rename(archive)
        digest = hashlib.file_digest(archive.open('rb'), algorithm).hexdigest()
        if digest != expected:
            raise RuntimeError(f'Official digest mismatch: {name}')
        if target.exists() and any(target.iterdir()):
            raise RuntimeError(f'Refusing to overwrite an existing toolchain: {target}')
        target.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as z:
            for entry in z.infolist():
                relative = pathlib.PurePosixPath(entry.filename.replace(chr(92), '/'))
                if relative.is_absolute() or '..' in relative.parts or ':' in entry.filename:
                    raise RuntimeError(f'Unsafe archive member: {entry.filename}')
            expanded = sum(entry.file_size for entry in z.infolist())
            z.extractall(target)
        rows.append({'name': name, 'url': url, 'archive_bytes': archive.stat().st_size,
                     'expanded_bytes': expanded, algorithm: digest, 'destination': str(target)})
        print('INSTALLED', name, 'bytes=', expanded, flush=True)
    exe = godot_executable()
    (exe.parent / '_sc_').touch()
    environment()
    manifest = ROOT / 'approved-toolchain.json'
    manifest.write_text(json.dumps({'artifacts': rows, 'godot': str(exe), 'dotnet': str(SDK / 'dotnet.exe')}, indent=2))
    print(manifest.read_text(), flush=True)
if __name__ == '__main__':
    install()
