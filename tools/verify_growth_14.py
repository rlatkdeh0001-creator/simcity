"""Read-only geometric and render checks. Run with Blender -b -P this script."""
from pathlib import Path
import bpy,json,math
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
rows=[]
for zone in ['residential','commercial','industrial']:
 for path in sorted((ROOT/f'assets/{zone}-growth').glob('*/metadata.json')):
  meta=json.loads(path.read_text());ident=meta['id'];source=path.parent/(ident+'.blend')
  bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.view_layer.update()
  dep=bpy.context.evaluated_depsgraph_get();vertices=[];letter_heights=[]
  for obj in bpy.context.scene.objects:
   if obj.type not in ['MESH','FONT','CURVE']:continue
   evaluated=obj.evaluated_get(dep);mesh=evaluated.to_mesh()
   current=[evaluated.matrix_world@v.co for v in mesh.vertices];vertices.extend(current)
   if obj.type=='FONT':letter_heights.append(max(v.z for v in current)-min(v.z for v in current))
   evaluated.to_mesh_clear()
  low=[min(v[i] for v in vertices) for i in range(3)];high=[max(v[i] for v in vertices) for i in range(3)]
  W=meta['footprint_cells'][0]*4
  floors=[o for o in bpy.context.scene.objects if o.name.startswith('OccupiedFloor_')]
  marker=bpy.data.objects['RoadFront_BlenderMinusY']
  cam=bpy.context.scene.camera;direction=cam.location-Vector((0,0,(meta['vertex_bounds_m'][1][2]+meta['vertex_bounds_m'][0][2])*.48))
  checks={'no_external_textures':not any(im.source=='FILE' for im in bpy.data.images),'lettering_height':all(h<=.75 for h in letter_heights),'no_8x8':meta['footprint_cells'] in [[2,2],[4,4]],'metres':bpy.context.scene.unit_settings.scale_length==1,'finite':all(math.isfinite(c) for v in vertices for c in v),'entire_geometry_in_lot':all(low[i]>=-W/2-.001 and high[i]<=W/2+.001 for i in [0,1]),'exact_lot_extent':all(abs(high[i]-low[i]-W)<.001 for i in [0,1]),'bounds_metadata':max(abs(a-b) for current,expected in zip([low,high],meta['vertex_bounds_m']) for a,b in zip(current,expected))<.01,'floor_count':len(floors)==meta['floors'],'front':abs(marker.location.x)<.001 and abs(marker.location.y+W/2)<.001 and meta['front_blender']=='-Y' and meta['front']=='+Z','camera_elevation_30':abs(math.degrees(math.atan2(direction.z,math.hypot(direction.x,direction.y)))-30)<.001,'transparent_900x1100':bpy.context.scene.render.film_transparent and bpy.context.scene.render.resolution_x==900 and bpy.context.scene.render.resolution_y==1100,'not_applied':meta['game_registered'] is False}
  rows.append({'id':ident,'checks':checks,'passed':all(checks.values()),'measured_dimensions_m':[round(high[i]-low[i],3) for i in range(3)],'floors':meta['floors']});print('VERIFY',ident,rows[-1]['passed'],flush=True)
assert len(rows)==14
(ROOT/'docs/growth-14/geometry-validation.json').write_text(json.dumps({'assets':rows,'passed':all(r['passed'] for r in rows),'scope':'source and geometry checks; not game integration or structural engineering certification'},ensure_ascii=False,indent=2)+'\n')
assert all(r['passed'] for r in rows),[r for r in rows if not r['passed']]
print('RESULT',sum(len(r['checks']) for r in rows),'geometry checks passed',flush=True)
