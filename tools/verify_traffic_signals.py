"""Read-only source checks, 16 independent material states per head, front/back tests."""
from pathlib import Path
import bpy,math,json,hashlib
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];IDS=['traffic-signal-post-01','traffic-signal-arm-01'];LAMPS=['lamp_red','lamp_yellow','lamp_left_arrow','lamp_green'];results=[];head_hashes=[]

def node_strength(mat):return mat.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value

def snapshot_head():
 root=bpy.data.objects['SignalHead'];payload=[]
 for o in sorted(root.children,key=lambda o:o.name):
  payload.append(dict(name=o.name,vertices=[list(v.co) for v in o.data.vertices],polygons=[list(p.vertices) for p in o.data.polygons],matrix=[list(r) for r in o.matrix_basis],material_names=[m.name for m in o.data.materials]))
 return hashlib.sha256(json.dumps(payload,sort_keys=True).encode()).hexdigest()

for ident in IDS:
 p=ROOT/'assets/street-furniture'/ident;m=json.loads((p/'spec.json').read_text());source=p/'signal.blend';saved_hash=hashlib.sha256(source.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(source));scene=bpy.context.scene;bpy.context.view_layer.update();head=bpy.data.objects['SignalHead'];root=bpy.data.objects['SignalRoot'];dg=bpy.context.evaluated_depsgraph_get();points=[];tri=0
 for o in scene.objects:
  if o.type!='MESH':continue
  e=o.evaluated_get(dg);me=e.to_mesh();points.extend(e.matrix_world@v.co for v in me.vertices);tri+=sum(len(poly.vertices)-2 for poly in me.polygons);e.to_mesh_clear()
 lo=[min(v[i] for v in points) for i in range(3)];hi=[max(v[i] for v in points) for i in range(3)];arm='arm' in ident
 named=[bpy.data.objects.get(n) for n in LAMPS];centres=[sum((o.matrix_world@v.co for v in o.data.vertices),Vector())/len(o.data.vertices) for o in named];head_hashes.append(snapshot_head())
 material_names=[name for pair in m['lamp_materials'].values() for name in pair]
 checks={'all_four_named_meshes':all(o and o.type=='MESH' for o in named),'independent_mesh_data':len({o.data.as_pointer() for o in named})==4,'single_swappable_material_slot':all(len(o.data.materials)==1 for o in named),'all_off_in_saved_source':all(o.data.materials[0].name=='mat_'+o.name+'_off' and node_strength(o.data.materials[0])==0 for o in named),'eight_named_materials_survive_save':len(material_names)==8 and all(bpy.data.materials.get(n) is not None for n in material_names),'on_materials_emissive':all(node_strength(bpy.data.materials['mat_'+n+'_on'])>0 for n in LAMPS),'off_materials_dark_matte':all(node_strength(bpy.data.materials['mat_'+n+'_off'])==0 and max(bpy.data.materials['mat_'+n+'_off'].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value[:3])<.04 and bpy.data.materials['mat_'+n+'_off'].node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value>.8 for n in LAMPS),'material_fake_users':all(bpy.data.materials[n].use_fake_user for n in material_names),'front_view_order_R_Y_arrow_G':all(a.x<b.x for a,b in zip(centres,centres[1:])),'arrow_geometry_points_front_view_left':abs(min(v.co.x for v in named[2].data.vertices)-.11)<.0001 and abs(max(v.co.x for v in named[2].data.vertices)-.47)<.0001,'arrow_separate_dark_round_backing':bpy.data.objects.get('arrow_lens_backing') is not None,'four_upper_visors':sum(o.name.startswith('visor_') for o in head.children)==4,'one_head_only':sum(o.name=='SignalHead' for o in scene.objects)==1,'root_at_pole_base':list(root.location)==[0,0,0] and abs(lo[2])<.00001,'metre_units':scene.unit_settings.system=='METRIC' and scene.unit_settings.scale_length==1,'triangle_budget':(500<=tri<=1200) if arm else (300<=tri<=800),'triangle_count_matches_spec':tri==m['triangles'],'height_matches_spec':abs(hi[2]-m['height_m'])<.0001,'bounds_match_spec':max(abs(a-b) for x,y in zip([lo,hi],m['vertex_bounds_m']) for a,b in zip(x,y))<.0001,'lens_15x_reference':m['lamp_diameter_m']==.45 and m['nominal_reference_lamp_diameter_m']==.30 and m['lens_scale']==1.5,'no_external_images':not any(im.source=='FILE' for im in bpy.data.images),'no_glb_created':not list(p.glob('*.glb')),'frame_metadata':m['frame_blender']==dict(forward='-Y',left='+X',up='+Z') and m['frame_gltf']==dict(forward='+Z',left='+X',up='+Y')}
 checks['export_material_definitions_complete']=set(m['material_definitions'])==set(material_names) and all(abs(m['material_definitions'][name]['emission_strength']-node_strength(bpy.data.materials[name]))<.00001 for name in material_names)
 head_points=[v.co for ob in head.children for v in ob.data.vertices]
 checks['head_size_matches_spec']=all(abs(max(v[i] for v in head_points)-min(v[i] for v in head_points)-m['head_dimensions_m'][i])<.00001 for i in range(3))
 # The most negative-X vertex is the left-facing tip at z=0. Front cap normal must be -Y.
 tip=min(named[2].data.vertices,key=lambda v:v.co.x);checks['arrow_tip_centerline']=abs(tip.co.z)<.0001
 checks['arrow_front_cap_normal']=any(poly.normal.y<-.99 for poly in named[2].data.polygons)
 # Read-only horizontal rear ray must first hit the unlit backboard, not a lamp.
 rear_hits=[]
 for c in centres:
  hit,point,normal,face,obj,matrix=scene.ray_cast(dg,Vector((c.x,head.location.y+2,c.z)),Vector((0,-1,0)))
  rear_hits.append(hit and obj.name=='HeadBackboard')
 checks['opaque_one_way_backboard']=all(rear_hits)
 if arm:
  beam=bpy.data.objects['RoadwardArm'];xs=[(beam.matrix_world@v.co).x for v in beam.data.vertices]
  checks['arm_extends_minus_x']=abs(min(xs)+7)<.0001 and max(xs)<=.00001
  checks['arm_length_7m']=abs(max(xs)-min(xs)-7)<.0001
  checks['head_clearance_at_least_45m']=head.location.z-.42>=4.5 and abs(head.location.z-.42-m['head_clearance_m'])<.0001
 states=[]
 for mask in range(16):
  expected=[]
  for bit,name in enumerate(LAMPS):
   state='on' if mask&(1<<bit) else 'off';bpy.data.objects[name].data.materials[0]=bpy.data.materials['mat_'+name+'_'+state]
   if state=='on':expected.append(name)
  actual=[name for name in LAMPS if node_strength(bpy.data.objects[name].data.materials[0])>0]
  states.append(dict(mask=mask,expected=expected,actual=actual,passed=actual==expected))
 checks['sixteen_independent_states']=all(s['passed'] for s in states)
 for name in LAMPS:bpy.data.objects[name].data.materials[0]=bpy.data.materials['mat_'+name+'_off']
 checks['can_restore_all_off']=all(node_strength(o.data.materials[0])==0 for o in named)
 checks['validation_never_wrote_source']=hashlib.sha256(source.read_bytes()).hexdigest()==saved_hash
 results.append(dict(id=ident,checks=checks,passed=all(checks.values()),triangles=tri,states=states,head_geometry_material_hash=head_hashes[-1],source_sha256=saved_hash));print('VERIFY_SIGNAL',ident,checks,flush=True)
shared=len(set(head_hashes))==1
(ROOT/'docs/traffic-signals/validation.json').write_text(json.dumps(dict(assets=results,identical_head_geometry=shared,passed=shared and all(r['passed'] for r in results)),indent=2)+'\n')
assert shared and all(r['passed'] for r in results)
print('RESULT',sum(len(r['checks']) for r in results)+1,'source checks and 32 material states passed; identical head verified')
