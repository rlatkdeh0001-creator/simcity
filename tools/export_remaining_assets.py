"""Export remaining original assets into inspection-only resources.
Run in Blender 4.3.2, optionally -- --groups commercial industrial.
No original builder is executed and no source file is saved.
"""
# pyright: reportMissingImports=false
import hashlib,json,runpy,sys
from pathlib import Path
import bpy
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/register-30-assets-validation'
HELPERS=runpy.run_path(str(ROOT/'tools/export_emergency_services.py'),run_name='readonly_export_helpers')
bounds=HELPERS['bounds'];dump=HELPERS['dump']
BUSINESS={
 'large-4x4-department-07':'백화점','large-4x4-office-nova-08':'업무',
 'large-8x8-grand-department-09':'백화점','large-8x8-twin-central-10':'복합업무',
 'medium-4x4-brick-services-06':'식음·서비스','medium-4x4-office-retail-05':'업무·상가',
 'small-2x2-auto-02':'자동차 전시','small-2x2-mart-01':'마트','small-4x4-cafe-diner-04':'식음','small-4x4-market-03':'슈퍼마켓',
 'large-4x4-chemical-06':'화학','large-4x4-pharma-05':'제약','large-8x8-auto-assembly-07':'자동차 조립',
 'large-8x8-chemical-complex-08':'화학','medium-4x4-circuitworks-04':'전자부품','medium-4x4-precision-03':'정밀기계',
 'small-2x2-foodworks-02':'식품가공','small-2x2-metalworks-01':'금속가공'}
def targets(item):
 private=item['group'] in ['commercial','industrial']
 folder=ROOT/'cities_do/assets'/('buildings' if private else 'services')
 model=folder/('models' if private else '')/(item['id']+'.glb')
 return folder,model,folder/(item['id']+'.png'),folder/'specs'/(item['id']+'.json')
def res(path):return 'res://'+path.relative_to(ROOT/'cities_do').as_posix()
def finish_catalogs(index):
 if not all(targets(item)[3].exists() for item in index):return
 entries=[json.loads(targets(item)[3].read_text(encoding='utf-8')) for item in index]
 ids={item['id'] for item in index}
 services=ROOT/'cities_do/assets/services/catalog.json';doc=json.loads(services.read_text(encoding='utf-8'))
 doc['facilities']=[e for e in doc['facilities'] if e['id'] not in ids]+[e for e in entries if e['group'] not in ['commercial','industrial']]
 dump(services,doc)
 buildings=ROOT/'cities_do/assets/buildings/catalog.json';doc=json.loads(buildings.read_text(encoding='utf-8'))
 doc['buildings']=[e for e in doc['buildings'] if e['id'] not in ids]+[e for e in entries if e['group'] in ['commercial','industrial']]
 dump(buildings,doc)
 dump(ROOT/'cities_do/assets/registered_30.json',{'schema_version':1,'assets':entries})
 print('REGISTERED_REMAINING',len(entries),flush=True)
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 index=json.loads((ROOT/'docs/remaining-original-assets/catalog.json').read_text(encoding='utf-8'))['assets']
 groups=None
 if '--groups' in sys.argv:groups=sys.argv[sys.argv.index('--groups')+1:]
 hashes=json.loads((OUT/'source-hashes.json').read_text(encoding='utf-8'))['sha256']
 report_path=OUT/'measurements.json'
 reports={e['id']:e for e in json.loads(report_path.read_text(encoding='utf-8'))} if report_path.exists() else {}
 for item in index:
  if groups and item['group'] not in groups:continue
  meta=json.loads((ROOT/item['metadata']).read_text(encoding='utf-8'))
  bpy.ops.wm.open_mainfile(filepath=str(ROOT/item['source']),load_ui=False,use_scripts=False)
  fonts=[o for o in bpy.context.scene.objects if o.type=='FONT']
  for o in fonts:
   font=o.data.font
   assert font.filepath=='<builtin>' or getattr(font,'packed_file',None) is not None or Path(bpy.path.abspath(font.filepath)).exists(),('Missing source font',item['id'],font.filepath)
  bpy.ops.object.select_all(action='DESELECT')
  for o in fonts:o.select_set(True);bpy.context.view_layer.objects.active=o
  if fonts:bpy.ops.object.convert(target='MESH')
  objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
  low,high=bounds(objects);raw_bounds=[low[:],high[:]]
  if item['id'] in ['water-intake','water-sewage-outfall']:
   ground=next(o for o in objects if o.name=='Context_LandSurface')
  else:ground=next((o for o in objects if o.name=='Lot' or o.name.startswith('Lot_') or o.name=='PresentationBase'),None)
  ground_before=bounds([ground]) if ground else [low[:],low[:]]
  offset=-ground_before[0][2]
  export_nodes=set(objects)
  for o in objects:
   parent=o.parent
   while parent:export_nodes.add(parent);parent=parent.parent
  roots=[o for o in export_nodes if o.parent not in export_nodes]
  for o in roots:o.matrix_world=Matrix.Translation((0,0,offset))@o.matrix_world
  bpy.context.view_layer.update()
  low,high=bounds(objects)
  dimensions=[high[i]-low[i] for i in range(3)]
  footprint=meta.get('footprint_cells')
  presentation=meta.get('presentation_lot_meters',meta.get('lot_meters'))
  if footprint:width,depth=map(int,footprint)
  else:
   assert presentation is not None,(item['id'],'No original presentation dimensions')
   width,depth=[int(float(v)/4) for v in presentation]
  full_bounds_match=abs(dimensions[0]-width*4)<.05 and abs(dimensions[1]-depth*4)<.05
  issues=[]
  if not full_bounds_match:issues.append('rotor_overhang_ground_occupation_only' if meta.get('rotor_overhang_allowed') else 'mesh_bounds_differ_from_lot')
  if not footprint:issues.append('parametric_asset_no_fixed_footprint; dimensions_are_original_presentation_only')
  if low[2]<-.05:issues.append('original_below_ground_geometry_preserved')
  candidates=[o for o in objects if any(t in o.name.lower() for t in ['door','entrance','entry','lobby']) and not any(t in o.name.lower() for t in ['rear','planter','label','sign'])]
  doors=[o for o in candidates if 'door' in o.name.lower()]
  candidates=doors or candidates
  primary=[o for o in candidates if not any(t in o.name.lower() for t in ['handle','canopy','window','slat','rail','frame'])]
  candidates=primary or candidates
  front=min(candidates,key=lambda o:bounds([o])[0][1]) if candidates else None
  front_bounds=bounds([front]) if front else None
  if not front:issues.append('no_named_human_entrance_in_original; +Z_is_inspection_convention_only')
  marker=bpy.data.objects.new('ServiceFrontage',None);bpy.context.scene.collection.objects.link(marker)
  marker.location=(0,-depth*2,0);marker['front_axis_gltf']=[0,0,1]
  folder,model,png,spec=targets(item);model.parent.mkdir(parents=True,exist_ok=True)
  bpy.ops.object.select_all(action='DESELECT')
  for o in export_nodes|{marker}:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0]
  bpy.ops.export_scene.gltf(filepath=str(model),export_format='GLB',use_selection=True,export_yup=True,
                           export_apply=True,export_extras=True,export_cameras=False,export_lights=False,export_animations=False)
  source_png=next(ROOT/p for p in item['previews'] if 'reverse-review' not in p)
  png.write_bytes(source_png.read_bytes())
  graph=bpy.context.evaluated_depsgraph_get()
  triangles=sum(max(0,len(p.vertices)-2) for o in objects for p in o.evaluated_get(graph).data.polygons)
  center=[(front_bounds[0][i]+front_bounds[1][i])/2 for i in range(3)] if front_bounds else None
  entry=dict(id=item['id'],name=meta['name'],group=item['group'],width=width,depth=depth,
             height_m=dimensions[2],width_m=dimensions[0],length_m=dimensions[1],triangles=triangles,
             model=res(model),preview=res(png),spec=res(spec),source=item['source'],source_metadata=meta,
             footprint_cells=footprint,presentation_lot_meters=[width*4,depth*4],
             fixed_footprint=bool(footprint),front_axis=[0,1],front_marker='ServiceFrontage',
             front_feature_node=front.name if front else '',
             front_feature_position_gltf=[center[0],center[2],-center[1]] if center else None,
             frontage_verification='original_named_entrance_geometry_retained' if front else 'equipment_convention_only_no_named_entrance',
             ground_reference_node=ground.name if ground else '',ground_offset_m=offset,
             full_bounds_blender=[low,high],ground_bounds_blender=bounds([ground]) if ground else None,
             status='asset_preview_only',simulation_enabled=False,growth_enabled=False,
             recovered_batch='remaining_30',recovered_original=True,registration_issues=issues,
             ui_category={'power':'power','water':'water','waste':'environment'}.get(item['group'],''))
  if item['group'] in ['commercial','industrial']:
   corners=meta['lot_corners_px']
   entry.update(zone=item['group'],category=meta['category'],category_name='상업' if item['group']=='commercial' else '공업',
                footprint=[width,depth],storeys=int(meta['occupied_storeys']),min_level=1,texture=res(png),
                image_size=meta['image_size'],anchor_px=meta['anchor_px'],lot_width_px=corners[2][0]-corners[0][0],
                industry=meta.get('retail_type',meta.get('industry_type',BUSINESS[item['id']])))
  dump(spec,entry)
  reports[item['id']]={'id':item['id'],'name':meta['name'],'group':item['group'],'lot_cells':footprint,
                      'presentation_lot_meters':[width*4,depth*4],'raw_bounds_blender':raw_bounds,
                      'export_bounds_blender':[low,high],'measured_wdh_m':dimensions,'unit_scale':bpy.context.scene.unit_settings.scale_length,
                      'ground_reference_node':entry['ground_reference_node'],'ground_offset_m':offset,
                      'front_feature_node':entry['front_feature_node'],'front_feature_position_gltf':entry['front_feature_position_gltf'],
                      'issues':issues}
  dump(report_path,[reports[row['id']] for row in index if row['id'] in reports])
  print('EXPORTED_REMAINING',item['id'],dimensions,'ISSUES',issues,flush=True)
 assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items()),'Original files changed'
 finish_catalogs(index)
if __name__=='__main__':main()
