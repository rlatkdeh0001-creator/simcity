"""Compare measured source projection with existing game sprite normalization."""
import argparse
import csv
import json
import math
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
args = parser.parse_args()
root = args.root
out = root / 'docs/scale-validation'
report = json.loads((out / 'source-measurements.json').read_text())
ground = math.hypot(14 / 4, 7 / 4)
vertical = 14 / 4 * math.sqrt(2) * math.cos(math.radians(30))
ground_errors, vertical_errors = [], []
for kind, projection_key in [('buildings', 'camera_projection_px_per_m'), ('vehicles', 'camera_projection_315_px_per_m')]:
    for asset in report[kind]:
        projection, scale = asset[projection_key], asset['game_sprite_scale_zoom1']
        asset['ground_scale_error_percent'] = abs(math.hypot(*projection['x']) * scale / ground - 1) * 100
        asset['vertical_scale_error_percent'] = abs(abs(projection['z'][1]) * scale / vertical - 1) * 100
        ground_errors.append(asset['ground_scale_error_percent'])
        vertical_errors.append(asset['vertical_scale_error_percent'])
report['projection_comparison'] = dict(ground_pixels_per_metre_zoom1=ground,
    vertical_pixels_per_metre_zoom1=vertical, max_ground_error_percent=max(ground_errors),
    max_vertical_error_percent=max(vertical_errors))
bounds_checks = []
for asset in report['vehicles']:
    for angle, expected in asset['projection_bounds'].items():
        path = root / 'cities_do/assets/vehicles/sprites' / asset['id'] / f'{int(angle):03d}.png'
        with Image.open(path) as image:
            actual = image.getchannel('A').getbbox()
        assert actual, path
        bounds_checks.append(dict(id=asset['id'], angle=int(angle), expected_bounds=expected,
            actual_alpha_bounds=list(actual), max_edge_difference_px=max(abs(a-b) for a,b in zip(expected, actual))))
report['vehicle_sprite_bounds'] = bounds_checks
(out / 'analysis.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
with (out / 'building-dimensions.csv').open('w', newline='') as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(['id', 'name', 'lot_width_m', 'lot_depth_m', 'storeys', 'body_width_m', 'body_depth_m', 'body_height_m', 'highest_geometry_z_m'])
    for asset in report['buildings']:
        writer.writerow([asset['id'], asset['name'], *asset['lot_m'], asset['storeys'],
            *[round(v, 3) for v in asset['body']['size']], round(asset['all_geometry']['max'][2], 3)])
print(json.dumps({'buildings': len(report['buildings']), 'vehicles': len(report['vehicles']),
    'facilities': len(report['facilities']), 'vehicle_pngs': len(bounds_checks), **report['projection_comparison'],
    'max_png_bounds_edge_difference_px': max(x['max_edge_difference_px'] for x in bounds_checks)}, indent=2))
