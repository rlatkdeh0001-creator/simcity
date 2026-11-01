#!/usr/bin/env python3
"""Package game/source/skills with per-file SHA-256 and verify the complete ZIP."""
import hashlib
import argparse
import json
from pathlib import Path
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT.parent/'cities-do-vehicles-20.zip'
EXCLUDED={'.git','.godot','node_modules','__pycache__'}
ALLOWED={'.agents','assets','cities_do','docs','tools','validation','third_party'}
FILES={'AGENTS.md','README.md','package.json','pnpm-lock.yaml','.gitignore'}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=DEST)
    args=parser.parse_args()
    destination=args.output.resolve()
    manifest=[]
    with zipfile.ZipFile(destination,'w',zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(ROOT.rglob('*')):
            rel=path.relative_to(ROOT)
            if not path.is_file() or path.is_symlink():continue
            if rel.parts[0] not in ALLOWED and str(rel) not in FILES:continue
            if any(part in EXCLUDED for part in rel.parts):continue
            if path.suffix in {'.blend1','.blend2','.pyc'} or path.name.startswith('.env'):continue
            data=path.read_bytes()
            archive.writestr('simcity/'+rel.as_posix(),data)
            manifest.append({'path':'simcity/'+rel.as_posix(),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
        archive.writestr('MANIFEST.json',json.dumps({'git_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'files':manifest},indent=2)+'\n')
    with zipfile.ZipFile(destination) as archive:
        assert archive.testzip() is None
        for row in manifest:
            data=archive.read(row['path'])
            assert len(data)==row['bytes'] and hashlib.sha256(data).hexdigest()==row['sha256']
        names=archive.namelist()
        assert sum(p.endswith('/vehicle.blend') for p in names)==20
        assert sum(p.endswith('.glb') and '/vehicles/' in p for p in names)==20
        assert sum('/vehicles/sprites/' in p and p.endswith('.png') for p in names)==160
    result={'archive':str(destination),'bytes':destination.stat().st_size,'sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'files':len(manifest),'crc_and_all_file_sha256':'PASS'}
    destination.with_suffix('.zip.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))


if __name__=='__main__':main()
