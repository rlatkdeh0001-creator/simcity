"""Read-only mesh/unit audit. Does not certify art quality, bounds contracts or AI."""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector
p = argparse.ArgumentParser()
p.add_argument('--workspace', required=True)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
root = Path(a.workspace).resolve()
records = []
for source in sorted((root / 'assets').rglob('*.blend')):
    bpy.ops.wm.open_mainfile(filepath=str(source))
    bpy.context.view_layer.update()
    dep = bpy.context.evaluated_depsgraph_get()
    points, tri = [], 0
    for obj in bpy.context.scene.objects:
        if obj.type not in ['MESH', 'FONT', 'CURVE', 'SURFACE']:
            continue
        evaluated = obj.evaluated_get(dep)
        mesh = evaluated.to_mesh()
        if mesh is None:
            continue
        mesh.calc_loop_triangles()
        tri += len(mesh.loop_triangles)
        points.extend(tuple(evaluated.matrix_world @ v.co) for v in mesh.vertices)
        evaluated.to_mesh_clear()
    finite = bool(points) and all(math.isfinite(v) for point in points for v in point)
    lo = [min(pt[i] for pt in points) for i in range(3)] if points else [0] * 3
    hi = [max(pt[i] for pt in points) for i in range(3)] if points else [0] * 3
    checks = dict(nonempty_finite_geometry=finite, triangles_positive=tri > 0, unit_scale_one=abs(bpy.context.scene.unit_settings.scale_length - 1) < 1e-6)
    records.append(dict(path=str(source.relative_to(root)), triangles=tri, vertex_bounds_m=[lo, hi], dimensions_xyz_m=[hi[i] - lo[i] for i in range(3)], checks=checks, passed=all(checks.values())))
report = dict(scope='generic read-only evaluated geometry; dimensions include every mesh accessory; not contract-specific', assets=records, passed=bool(records) and all(r['passed'] for r in records))
(root / 'logs/blend-validation.json').write_text(json.dumps(report, indent=2) + '\n')
assert report['passed'], 'No blends or failed geometry checks'
print('RESULT', len(records), 'blend files passed')
