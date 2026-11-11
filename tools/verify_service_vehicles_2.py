"""Blender read-only validation for the two new source-only service vehicles."""
from pathlib import Path
import bpy,json,math
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];results=[]
for ident,style,height_limit in [('garbage-truck-01','waste',3.3),('ambulance-01','medical',3.4)]:
 p=ROOT/'assets/vehicle-fleet'/ident;spec=json.loads((p/'spec.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(p/'vehicle.blend'));bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get();points=[];tri=0
 for obj in bpy.context.scene.objects:
  if obj.type!='MESH':continue
  evaluated=obj.evaluated_get(dep);mesh=evaluated.to_mesh();points.extend(evaluated.matrix_world@v.co for v in mesh.vertices);tri+=sum(len(p.vertices)-2 for p in mesh.polygons);evaluated.to_mesh_clear()
 lo=[min(v[i] for v in points) for i in range(3)];hi=[max(v[i] for v in points) for i in range(3)];spins=[o for o in bpy.context.scene.objects if o.name.startswith('Wheel_') and o.name.endswith('_Spin')]
 seat=bpy.data.objects['Seat_FL'];wheel=bpy.data.objects['SteeringWheel'];checks={'metric_units':bpy.context.scene.unit_settings.scale_length==1,'finite_mesh':all(math.isfinite(v) for p in points for v in p),'ground_contact':abs(lo[2])<.001,'full_height_including_accessories':hi[2]<=height_limit,'triangles_in_budget':2000<=tri<=5000,'triangles_match_spec':tri==spec['triangles'],'measured_dimensions_match':max(abs(a-b) for a,b in zip([hi[1]-lo[1],hi[0]-lo[0],hi[2]-lo[2]],spec['measured_dimensions_m']))<.001,'left_hand_driver':seat.matrix_world.translation.x>0 and wheel.matrix_world.translation.x>0,'wheel_rig':len(spins)==spec['wheel_count'] and all(o.parent and o.parent.name.startswith('Wheel_') and list(o.get('spinAxisGltf',[]))==[1.,0.,0.] for o in spins),'front_wheel_negative_y':bpy.data.objects['Wheel_FL'].matrix_world.translation.y<0,'no_external_texture':not any(im.source=='FILE' for im in bpy.data.images),'source_only':spec['game_registered'] is False,'no_glb':not list(p.glob('*.glb'))}
 if style=='waste':checks['rear_lift_pivot']=bpy.data.objects.get('BinLiftPivot') is not None;checks['recycling_geometry']=len([o for o in bpy.context.scene.objects if o.name.startswith('RecyclingArrow')])==6;checks['lift_in_front_of_hopper_backplate']=sum((bpy.data.objects['BinLiftCrossbar'].matrix_world@Vector(v)).y for v in bpy.data.objects['BinLiftCrossbar'].bound_box)/8>sum((bpy.data.objects['HopperShadow'].matrix_world@Vector(v)).y for v in bpy.data.objects['HopperShadow'].bound_box)/8
 else:checks['side_and_rear_medical_marks']=sum(o.name.startswith('MedicalStarSide') for o in bpy.context.scene.objects)>=6 and sum(o.name.startswith('MedicalStarRear') for o in bpy.context.scene.objects)>=3;checks['roof_lights']=len([o for o in bpy.context.scene.objects if o.name.startswith('EmergencyLight')])==2
 if style=='medical':
  from mathutils.bvhtree import BVHTree
  def overlaps(a,b):
   return bool(BVHTree.FromObject(bpy.data.objects[a],dep).overlap(BVHTree.FromObject(bpy.data.objects[b],dep)))
  # All these mesh vertices use world coordinates; root transform is identity.
  for side in ['L','R']:
   checks['mirror_mount_on_body_'+side]=overlaps('VanBody','MirrorMount_'+side)
   checks['mirror_arm_on_mount_'+side]=overlaps('MirrorMount_'+side,'MirrorArm_'+side)
   checks['mirror_housing_on_arm_'+side]=overlaps('MirrorArm_'+side,'MirrorHousing_'+side)
  checks['continuous_van_body']=bpy.data.objects.get('VanBody') is not None and bpy.data.objects.get('MedicalBox') is None
  checks['raised_medical_roof']=bpy.data.objects.get('HighRoof') is not None
 results.append({'id':ident,'checks':checks,'passed':all(checks.values()),'triangles':tri,'measured_dimensions_m':[hi[1]-lo[1],hi[0]-lo[0],hi[2]-lo[2]]});print('VERIFY',ident,checks,flush=True)
out=ROOT/'docs/service-vehicles-2/geometry-validation.json';out.write_text(json.dumps({'vehicles':results,'passed':all(e['passed'] for e in results)},indent=2)+'\n')
assert all(e['passed'] for e in results)
print('RESULT',sum(len(e['checks']) for e in results),'source checks passed')
