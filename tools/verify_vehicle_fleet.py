#!/usr/bin/env python3
"""Audit recovered fleet files without creating or modifying assets.

Exit 1 means incomplete/invalid; exit 0 is a structural check, not visual approval.
Run from any directory; requires Pillow for PNG decoding.
"""
import argparse
import json
from pathlib import Path
import struct

IDS = "bus-city-01 taxi-sedan-01 car-hatch-01 car-compact-02 car-sedan-03 car-wagon-04 car-crossover-05 car-suv-06 car-coupe-07 car-minivan-08 car-electric-09 car-pickup-10 truck-box-01 truck-flatbed-02 truck-fridge-03 truck-mixer-04 trailer-container-05 trailer-tanker-06 truck-dump-07 truck-heavy-dump-08".split()


def audit(root):
    from PIL import Image
    failures = []
    counts = dict(blend=0, glb=0, sprites=0)
    def check(path, kind):
        p = root / path
        if not p.is_file():
            failures.append(f"missing: {path}")
            return
        try:
            if kind == 'blend':
                # Blender may save compressed files; opening them in Blender is
                # a separate check. This audit only accepts an uncompressed header.
                with p.open('rb') as f:
                    if f.read(7) != b'BLENDER':
                        raise ValueError('not an uncompressed Blender file')
            elif kind == 'glb':
                data = p.read_bytes()
                magic, version, size = struct.unpack_from('<4sII', data)
                if (magic, version, size) != (b'glTF', 2, len(data)):
                    raise ValueError('invalid GLB header')
                length, chunk = struct.unpack_from('<II', data, 12)
                if chunk != 0x4E4F534A:
                    raise ValueError('missing JSON chunk')
                doc = json.loads(data[20:20 + length])
                if not doc.get('meshes'):
                    raise ValueError('no meshes')
            elif kind == 'sprites':
                with Image.open(p) as im:
                    im.load()
                    if im.size != (430, 245) or im.mode != 'RGBA':
                        raise ValueError('expected 430x245 RGBA')
                    lo, hi = im.getchannel('A').getextrema()
                    if lo != 0 or hi == 0:
                        raise ValueError('expected transparent background and visible pixels')
            else:
                json.loads(p.read_text())
            if kind in counts:
                counts[kind] += 1
        except (ValueError, OSError, struct.error) as e:
            failures.append(f"invalid: {path}: {e}")
    for asset in IDS:
        check(f'assets/vehicle-fleet/{asset}/vehicle.blend', 'blend')
        check(f'assets/vehicle-fleet/{asset}/spec.json', 'json')
        check(f'cities_do/assets/vehicles/{asset}.glb', 'glb')
        for angle in range(0, 360, 45):
            check(f'cities_do/assets/vehicles/sprites/{asset}/{angle:03}.png', 'sprites')
    for name in ['catalog.json', 'render_manifest.json']:
        check('cities_do/assets/vehicles/' + name, 'json')
    return {'valid_files': counts, 'expected': {'blend': 20, 'glb': 20, 'sprites': 160},
            'passed': not failures, 'failures': failures,
            'scope': 'Structural audit only; does not validate pivots, scale, visual design, mesh integrity or Godot import.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = audit(args.root)
    payload = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    if args.output:
        args.output.write_text(payload)
    print(json.dumps({k: v for k, v in result.items() if k != 'failures'}, ensure_ascii=False))
    raise SystemExit(0 if result['passed'] else 1)
