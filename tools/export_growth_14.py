"""Read-only export of approved growth-14 originals. Never execute source builders."""
# pyright: reportMissingImports=false
import hashlib,json,runpy,sys
from pathlib import Path
import bpy
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/growth-appearance-validation'
H=runpy.run_path(str(ROOT/'tools/export_emergency_services.py'),run_name='growth_export_helpers')
bounds=H['bounds'];dump=H['dump']
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def res(path):return 'res://'+path.relative_to(ROOT/'cities_do').as_posix()
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 source=json.loads((ROOT/'docs/growth-14/catalog.json').read_text(encoding='utf-8'))['assets']
 originals=[p for zone in ['residential','commercial','industrial'] for p in (ROOT/f'assets/{zone}-growth').rglob('*') if p.is_file()]
 originals +=[ROOT/name for name in ['tools/build_growth_14.py','tools/build_growth_14_review.py','tools/verify_growth_14.py','tools/verify_growth_signs.py']]
 hashes={p.relative_to(ROOT).as_posix():sha(p) for p in originals}
 hashfile=OUT/'source-hashes.json'
 if hashfile.exists():assert json.loads(hashfile.read_text(encoding='utf-8'))==hashes
 else:dump(hashfile,hashes)
 chosen=sys.argv[sys.argv.index('--zones')+1:] if '--zones' in sys.argv else ['residential','commercial','industrial']
 measurements=json.loads((OUT/'measurements.json').read_text(encoding='utf-8')) if (OUT/'measurements.json').exists() else []
 by={e['id']:e for e in measurements}
 for info in source:
  if info['zone'] not in chosen:continue
  folder=ROOT/info['source_folder'];meta=json.loads((folder/'metadata.json').read_text(encoding='utf-8'))
  ident=meta['id'];blend=folder/(ident+'.blend')
  assert meta['front_blender']=='-Y' and meta['front']=='+Z' and meta['cell_meters']==4
  bpy.ops.wm.open_mainfile(filepath=str(blend),load_ui=False,use_scripts=False)
  fonts=[o for o in bpy.context.scene.objects if o.type=='FONT']
  for o in fonts:assert o.data.font.filepath=='<builtin>' or getattr(o.data.font,'packed_file',None) is not None or Path(bpy.path.abspath(o.data.font.filepath)).exists()
  bpy.ops.object.select_all(action='DESELECT')
  for o in fonts:o.select_set(True);bpy.context.view_layer.objects.active=o
  if fonts:bpy.ops.object.convert(target='MESH')
  objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];low,high=bounds(objects)
  original_bounds=[low[:],high[:]]
  ground=next((o for o in objects if o.name.startswith('Lot')),None)
  offset=-bounds([ground])[0][2] if ground else -low[2]
  nodes=set(objects)
  for o in objects:
   parent=o.parent
   while parent:nodes.add(parent);parent=parent.parent
  for o in nodes:
   if o.parent not in nodes:o.matrix_world=Matrix.Translation((0,0,offset))@o.matrix_world
  bpy.context.view_layer.update();low,high=bounds(objects);dims=[high[i]-low[i] for i in range(3)]
  width,depth=meta['footprint_cells'];issues=[]
  if abs(dims[0]-width*4)>.05 or abs(dims[1]-depth*4)>.05:issues.append('actual_horizontal_extent_differs_from_authored_lot; not resized')
  target=ROOT/'cities_do/assets/buildings';model=target/'models'/(ident+'.glb');png=target/(ident+'.png');spec=target/'specs'/(ident+'.json')
  marker=bpy.data.objects.new('GrowthFrontage',None);bpy.context.scene.collection.objects.link(marker);marker.location=(0,-depth*2,0)
  bpy.ops.object.select_all(action='DESELECT')
  for o in nodes|{marker}:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0]
  bpy.ops.export_scene.gltf(filepath=str(model),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_extras=True,export_cameras=False,export_lights=False,export_animations=False)
  png.write_bytes((folder/'building.png').read_bytes())
  graph=bpy.context.evaluated_depsgraph_get();triangles=sum(len(p.vertices)-2 for o in objects for p in o.evaluated_get(graph).data.polygons)
  entry=dict(id=ident,name=meta['name'],zone=meta['zone'],group=meta['zone'],category=meta['category'],density=meta['density'],
   category_name={'small':'소형','medium':'중형','large':'대형'}[meta['density']]+' '+{'residential':'주거','commercial':'상업','industrial':'공업'}[meta['zone']],
   footprint=[width,depth],width=width,depth=depth,storeys=meta['occupied_storeys'],min_level=1,
   texture=res(png),preview=res(png),image_size=meta['image_size'],anchor_px=meta['anchor_px'],lot_width_px=meta['lot_corners_px'][2][0]-meta['lot_corners_px'][0][0],
   model=res(model),spec=res(spec),height_m=dims[2],width_m=dims[0],length_m=dims[1],triangles=triangles,
   source=blend.relative_to(ROOT).as_posix(),source_metadata=meta,front_axis=[0,1],ground_offset_m=offset,full_bounds_blender=[low,high],
   recovered_batch='growth_14',growth_enabled=True,simulation_enabled=False,status='appearance_registered',registration_issues=issues)
  dump(spec,entry)
  by[ident]=dict(id=ident,source=entry['source'],source_bounds=original_bounds,derived_bounds=[low,high],measured_wdh_m=dims,lot_cells=[width,depth],density=meta['density'],ground_offset_m=offset,front_blender='-Y',front_godot='+Z',issues=issues)
  dump(OUT/'measurements.json',[by[e['id']] for e in source if e['id'] in by])
  print('EXPORTED_GROWTH',ident,dims,issues,flush=True)
 assert all(sha(ROOT/p)==h for p,h in hashes.items())
 specs=[ROOT/'cities_do/assets/buildings/specs'/(e['id']+'.json') for e in source]
 if all(p.exists() for p in specs):
  entries=[json.loads(p.read_text(encoding='utf-8')) for p in specs];assert len(entries)==14
  path=ROOT/'cities_do/assets/buildings/catalog.json';doc=json.loads(path.read_text(encoding='utf-8'));ids={e['id'] for e in entries}
  doc['buildings']=[e for e in doc['buildings'] if e['id'] not in ids]+entries;dump(path,doc)
  dump(ROOT/'cities_do/assets/growth_14.json',{'assets':entries})
  print('REGISTERED_GROWTH_14',len(entries),flush=True)
if __name__=='__main__':main()
