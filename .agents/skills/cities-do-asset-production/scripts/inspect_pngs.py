"""Decode generated PNGs; require RGBA, nonempty alpha and a transparent margin."""
import argparse
import json
from pathlib import Path
from PIL import Image
p = argparse.ArgumentParser()
p.add_argument('--workspace', required=True)
a = p.parse_args()
root = Path(a.workspace).resolve()
records = []
paths = set((root / 'assets').rglob('*.png')) | set((root / 'cities_do/assets').rglob('*.png'))
for path in sorted(paths):
    if path.name == 'preview-sheet.png':
        continue  # opaque labelled contact sheet, not a sprite
    with Image.open(path) as im:
        im.load()
        rgba = im.mode == 'RGBA'
        box = im.getchannel('A').getbbox() if rgba else None
        checks = dict(rgba=rgba, nonempty_alpha=bool(box), transparent_margin=bool(box) and min(box[:2]) > 0 and box[2] < im.width and box[3] < im.height)
        records.append(dict(path=str(path.relative_to(root)), size_px=list(im.size), alpha_bbox_px=box, checks=checks, passed=all(checks.values())))
report = dict(scope='asset PNGs except labelled sheet; game-side sprites checked by their profile when available', assets=records, passed=bool(records) and all(r['passed'] for r in records))
(root / 'logs/png-validation.json').write_text(json.dumps(report, indent=2) + '\n')
assert report['passed'], 'No PNGs or failed image checks; inspect logs/png-validation.json'
print('RESULT', len(records), 'PNG files passed')
