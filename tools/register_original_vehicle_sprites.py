"""Merge only recovered sprite calibration, retaining existing JSON float precision."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
directory = root / 'cities_do/assets/vehicles'
path = directory / 'render_manifest.json'
doc = json.loads(path.read_text())
additions = json.loads((directory / 'original_render_manifest.json').read_text())['vehicles']
assert len(additions) == 18
assert all(e['id'].startswith('original-') for e in additions)
for entry in additions:
    assert entry['pixels_per_metre'] > 0
    for angle in entry['angles_deg']:
        assert (directory / 'sprites' / entry['id'] / f'{int(angle):03}.png').is_file()
doc['vehicles'] = [e for e in doc['vehicles'] if not e['id'].startswith('original-')] + additions
assert len(doc['vehicles']) == 41
path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + '\n')
print('Registered 18 original sprite calibrations; retained existing 23 entries.')
