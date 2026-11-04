"""Export the seven approved recovered sources; never resave or rebuild originals.

blender -b --factory-startup -t 2 -P tools/export_recovered_services.py
"""
import json
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'cities_do/assets/services/catalog.json'
doc = json.loads(path.read_text())
recovered = []
for group in ['education', 'medical']:
    for source in sorted((ROOT / f'assets/{group}-study').glob('*/metadata.json')):
        meta = json.loads(source.read_text())
        bpy.ops.wm.open_mainfile(filepath=str(source.parent / 'building.blend'))
        bpy.ops.object.select_all(action='DESELECT')
        meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
        for obj in meshes:
            obj.select_set(True)
        low = Vector((float('inf'),) * 3)
        high = -low
        for obj in meshes:
            for corner in obj.bound_box:
                v = obj.matrix_world @ Vector(corner)
                low = Vector(tuple(min(low[i], v[i]) for i in range(3)))
                high = Vector(tuple(max(high[i], v[i]) for i in range(3)))
        ident = meta['id']
        output = ROOT / f'cities_do/assets/services/{ident}.glb'
        bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True,
                                 export_yup=True, export_apply=True, export_cameras=False, export_lights=False)
        png = ROOT / f'cities_do/assets/services/{ident}.png'
        png.write_bytes((source.parent / 'building.png').read_bytes())
        width, depth = meta['footprint_cells']
        recovered.append(dict(id=ident, name=meta['name'], group=group, width=width, depth=depth,
                              metres=[width * 4, depth * 4], length_m=depth * 4, width_m=width * 4,
                              height_m=round(high.z, 5), storeys=meta['max_storeys'],
                              triangles=sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons),
                              model='res://assets/services/' + output.name,
                              preview='res://assets/services/' + png.name,
                              source=str((source.parent / 'building.blend').relative_to(ROOT)),
                              status='asset_preview_only', simulation_enabled=False,
                              recovered_original=True))
        meta.update(approval_status='approved', game_registered=True,
                    registration_scope='asset catalog and inspector; no operating service simulation')
        source.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + '\n')
        print('RECOVERED_SERVICE', ident, flush=True)
ids = {e['id'] for e in recovered}
doc['facilities'] = [e for e in doc['facilities'] if e['id'] not in ids] + recovered
path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + '\n')
