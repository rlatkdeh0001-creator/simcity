"""Remove only named parked-car objects. Preserve original layout/materials/spec.
Blender -b -t 4 -P tools/empty_parking_sources.py
Produces source-only .blend/PNG/GLB; never writes cities_do.
"""
from pathlib import Path
import bpy,json,math,hashlib,ast
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/empty-parking';OUT.mkdir(exist_ok=True)
IDS=['parking-small-2x4','parking-medium-4x4','parking-large-4x8','parking-tower-4x4-4f']
PREFIXES=('ParkedCarBody','ParkedCarCabin','ParkedCarRoof','ParkedCarWheel','CarBody','CarCabin')
def is_car(o):return o.type=='MESH' and o.name.startswith(PREFIXES)
def digest(o):
 # Evaluated geometry, normals, transforms, material settings and topology.
 e=o.evaluated_get(bpy.context.evaluated_depsgraph_get());me=e.to_mesh()
 mats=[]
 for m in me.materials:
  node=m.node_tree.nodes.get('Principled BSDF') if m.use_nodes else None
  mats.append(dict(name=m.name,diffuse=list(m.diffuse_color),inputs={i.name:list(i.default_value) if hasattr(i.default_value,'__len__') else i.default_value for i in node.inputs if hasattr(i,'default_value') and i.type in ['RGBA','VALUE','VECTOR']} if node else {}))
 payload=dict(name=o.name,parent=o.parent.name if o.parent else None,matrix=[list(r) for r in o.matrix_world],vertices=[list(v.co) for v in me.vertices],polygons=[(list(p.vertices),p.material_index,p.use_smooth) for p in me.polygons],normals=[list(n.vector) for n in me.corner_normals],materials=mats,hidden=o.hide_render)
 e.to_mesh_clear();return hashlib.sha256(json.dumps(payload,sort_keys=True).encode()).hexdigest()
def snapshot():
 bpy.context.view_layer.update();return {o.name:digest(o) for o in bpy.context.scene.objects if o.type=='MESH' and not is_car(o)}
def base_width_depth():
 base=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith(('Asphalt','TowerBase')))
 bpy.context.view_layer.update();return [base.dimensions.x,base.dimensions.y]
def render_function():
 # Extract only the original studio function, never import/run the full all-assets builder.
 tree=ast.parse((ROOT/'tools/build_facilities.py').read_text());node=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='render')
 code=ast.Module(body=[node],type_ignores=[]);return compile(ast.fix_missing_locations(code),'original_facility_studio','exec')
report=[];render_code=render_function()
for ident in IDS:
 folder=ROOT/'assets/facilities'/ident;p=folder/'facility.blend';spec_bytes=(folder/'spec.json').read_bytes();spec=json.loads(spec_bytes)
 bpy.ops.wm.open_mainfile(filepath=str(p));bpy.context.preferences.filepaths.save_version=0;bpy.context.scene.cycles.device='CPU'
 before=snapshot();source_root=bpy.data.objects['FacilityRoot'];root_matrix=[list(r) for r in source_root.matrix_world];car_names=sorted(o.name for o in bpy.context.scene.objects if is_car(o));assert car_names,(ident,'already empty; use saved validation report to verify, not to recapture baseline')
 old_image=(folder/'preview.png').read_bytes();(OUT/(ident+'-before.png')).write_bytes(old_image)
 bases_before=base_width_depth()
 for name in car_names:bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
 after=snapshot();assert before==after,(ident,'non-car geometry changed')
 bpy.ops.wm.save_as_mainfile(filepath=str(p),compress=False)
 # Reopen the saved source and repeat preservation checks.
 bpy.ops.wm.open_mainfile(filepath=str(p));after_reload=snapshot();assert after_reload==before
 checks=dict(no_parked_vehicle_meshes=not any(is_car(o) for o in bpy.context.scene.objects),remaining_mesh_hashes_identical=before==after_reload,remaining_object_names_identical=set(before)==set(after_reload),base_extent_unchanged=bases_before==base_width_depth(),root_frame_unchanged=root_matrix==[list(r) for r in bpy.data.objects['FacilityRoot'].matrix_world],spec_bytes_unchanged=spec_bytes==(folder/'spec.json').read_bytes(),parking_lines_retained=any(name.startswith('BayLine') for name in after_reload),four_tower_decks=len([name for name in after_reload if name.startswith('ParkingDeck_')])==(4 if spec['kind']=='parking_tower' else 0))
 # Same original combined-mesh export pipeline, but artifact stays in the source folder.
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];bpy.ops.object.select_all(action='DESELECT')
 for o in meshes:o.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();bpy.context.object.name='FacilityCombinedMesh'
 bpy.ops.export_scene.gltf(filepath=str(folder/'facility.glb'),export_format='GLB',export_extras=True,export_animations=False)
 scope=dict(bpy=bpy,math=math,Vector=Vector,spec=spec,W=spec['width']*4,D=spec['depth']*4);exec(render_code,scope);info=scope['render'](folder/'preview.png')
 checks['original_camera_calibration']=info==spec['render']
 row=dict(id=ident,removed_count=len(car_names),removed_objects=car_names,remaining_mesh_count=len(before),unchanged_mesh_hashes=before,checks=checks,passed=all(checks.values()),metres=spec['metres'],capacity=spec['capacity'],storeys=spec['storeys'],render=info)
 report.append(row);(OUT/'validation.json').write_text(json.dumps(dict(assets=report,passed=all(r['passed'] for r in report)),ensure_ascii=False,indent=2)+'\n');assert row['passed'],row
 print('EMPTY_PARKING_DONE',ident,'removed',len(car_names),'preserved',len(before),flush=True)
print('RESULT',sum(len(r['checks']) for r in report),'preservation checks passed')
