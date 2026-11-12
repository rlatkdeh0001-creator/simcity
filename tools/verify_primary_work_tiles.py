"""Read-only tile geometry, repeated edges, oil variants and exact grain rollback."""
from pathlib import Path
import bpy,math,json,subprocess,hashlib
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[1];results=[];signatures={};cow_poses={}
ids=['grain-01','vegetable-01','pasture-01','pasture-02','pasture-03','forestry-01','mine-iron-01','mine-coal-01','oil-01','oil-02','mine-uranium-01','fishing-01']
for short in ids:
 ident='primary-tile-'+short;p=ROOT/'assets/primary-industry'/ident;m=json.loads((p/'metadata.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(p/(ident+'.blend')));scene=bpy.context.scene;bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get();points=[];tri=0;meshes=[]
 for o in scene.objects:
  if o.type!='MESH':continue
  e=o.evaluated_get(dep);me=e.to_mesh();vs=[e.matrix_world@v.co for v in me.vertices];points.extend(vs);tri+=sum(len(poly.vertices)-2 for poly in me.polygons);meshes.append((o,vs,[tuple(mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value) for mat in me.materials]));e.to_mesh_clear()
 low=[min(v[i] for v in points) for i in range(3)];high=[max(v[i] for v in points) for i in range(3)];cam=scene.camera;d=cam.location-Vector(cam['target_m']);ps=[world_to_camera_view(scene,cam,p) for p in points]
 checks={'metres':scene.unit_settings.system=='METRIC' and scene.unit_settings.scale_length==1,'finite':all(math.isfinite(c) for v in points for c in v),'entire_tile_in_4m':all(low[i]>=-2-.00001 and high[i]<=2+.00001 for i in [0,1]),'exact_4m_extent':all(abs(high[i]-low[i]-4)<.00001 for i in [0,1]),'triangles_1_to_300':0<tri<=300,'triangles_match_metadata':tri==m['triangles'],'bounds_match_metadata':max(abs(a-b) for actual,stored in zip([low,high],m['vertex_bounds_m']) for a,b in zip(actual,stored))<.0001,'source_only':m['game_registered'] is False,'work_tile_not_growth_building':m['kind']=='primary_work_tile' and m['footprint_cells']==[1,1],'orthographic_30_degrees':cam.data.type=='ORTHO' and abs(math.degrees(math.atan2(d.z,math.hypot(d.x,d.y)))-30)<.0001,'transparent_900_square':scene.render.film_transparent and scene.render.resolution_x==scene.render.resolution_y==900,'not_clipped':all(.05<v.x<.95 and .05<v.y<.95 for v in ps),'no_external_texture':not any(im.source=='FILE' for im in bpy.data.images),'no_curb_or_fence':not any('curb' in o.name.lower() or 'fence' in o.name.lower() for o,_,_ in meshes)}
 edges={}
 for axis in [0,1]:
  pair=[]
  for side in [-1,1]:
   edge=set()
   for _,vs,colors in meshes:
    for v in vs:
     if abs(v[axis]-side*2)<.00001:edge.add((round(v[1-axis],5),round(v.z,5),tuple(tuple(round(c,5) for c in color) for color in colors)))
   pair.append(sorted(edge))
  checks['matching_edge_geometry_color_'+str(axis)]=bool(pair[0]) and pair[0]==pair[1];edges[str(axis)]=pair
 signatures[ident]=edges
 if short=='fishing-01':
  checks['no_water_or_ground_mesh']=not any(any(tag in o.name.lower() for tag in ['ground','water','plinth','soil']) for o,_,_ in meshes)
  checks['four_buoys']=sum(o.name.startswith('FishingBuoy') for o,_,_ in meshes)==4
  checks['net_strands']=sum(o.name.startswith('NetAlong') for o,_,_ in meshes)==8
 elif short in ['mine-iron-01','mine-coal-01']:
  checks['pit_shallower_than_half_metre']=low[2]>=-.5 and -.5<=m['minimum_terrain_z_m']<0
  floor=bpy.data.objects.get('MineFloor')
  checks['uniform_floor_present']=floor is not None
  checks['full_floor_depth_minus_03']=floor is not None and abs(floor.dimensions.x-4)<.0001 and abs(floor.dimensions.y-4)<.0001 and abs(floor.location.z+floor.dimensions.z/2+.30)<.0001
  checks['no_closed_crater']=bpy.data.objects.get('ShallowTerraceGround') is None
  checks['benches_and_ore_cross_y_edges']=all(abs(min(v.y for v in vs)+2)<.0001 and abs(max(v.y for v in vs)-2)<.0001 for o,vs,_ in meshes if o.name.startswith(('ContinuousBench','ContinuousOreBerm')))

 elif short=='oil-01':checks['pumpjack_present']=bpy.data.objects.get('PumpHorseHead') is not None
 elif short=='oil-02':checks['pumpjack_absent']=bpy.data.objects.get('PumpHorseHead') is None and bpy.data.objects.get('CappedWell') is not None
 elif short.startswith('pasture-'):
  expected=0 if short=='pasture-01' else 4
  checks['cow_leg_count_matches_variant']=sum(o.name.startswith('CowLeg') for o,_,_ in meshes)==expected
  checks['cow_count_metadata']=m['cow_count']==(0 if expected==0 else 1)
  checks['cow_ground_and_scale']=expected==0 or (abs(low[2]+.12)<.0001 and 1.2<high[2]<1.5)
  if expected:
   body=next(vs for o,vs,_ in meshes if o.name=='CowBody');muzzle=next(vs for o,vs,_ in meshes if o.name=='CowMuzzle');center=sum(body,Vector())/len(body);nose=sum(muzzle,Vector())/len(muzzle);cow_poses[ident]=dict(center=list(center),facing=list((nose-center).normalized()))
 elif short=='vegetable-01':checks['four_smooth_rows_and_tree']=sum(o.name.startswith('VegetableRibbon') for o,_,_ in meshes)==4 and bpy.data.objects.get('TreeTrunk') is not None
 elif short=='forestry-01':checks['trees_and_stumps']=sum(o.name.startswith('TreeTrunk') for o,_,_ in meshes)==3 and sum(o.name.startswith('TreeStump') for o,_,_ in meshes)==2
 elif short=='mine-uranium-01':checks['two_warning_plates']=sum(o.name.startswith('WarningPlate') for o,_,_ in meshes)==2
 results.append(dict(id=ident,checks=checks,passed=all(checks.values()),triangles=tri,mesh_objects=len(meshes),measured_dimensions_m=[high[i]-low[i] for i in range(3)],edge_signatures=edges));print('VERIFY',ident,all(checks.values()),tri,flush=True)
rollback={}
for name in ['primary-tile-grain-01.blend','metadata.json','tile.png','tile-3x3.png','README_KO.md']:
 rel='assets/primary-industry/primary-tile-grain-01/'+name;old=subprocess.check_output(['git','show','6afefd8:'+rel],cwd=ROOT);now=(ROOT/rel).read_bytes();rollback[name]=dict(matches_6afefd8=old==now,sha256=hashlib.sha256(now).hexdigest())
pasture_edges=signatures['primary-tile-pasture-01']==signatures['primary-tile-pasture-02']==signatures['primary-tile-pasture-03']
pose_a=cow_poses['primary-tile-pasture-02'];pose_b=cow_poses['primary-tile-pasture-03'];different_poses=(Vector(pose_a['center'])-Vector(pose_b['center'])).length>.5 and Vector(pose_a['facing']).dot(Vector(pose_b['facing']))<.5
variants=signatures['primary-tile-oil-01']==signatures['primary-tile-oil-02'];passed=pasture_edges and different_poses and all(r['passed'] for r in results) and all(v['matches_6afefd8'] for v in rollback.values()) and variants
out=ROOT/'docs/primary-industry/work-tiles/geometry-validation.json';out.write_text(json.dumps(dict(assets=results,grain_rollback=rollback,oil_variant_boundary_match=variants,pasture_variant_boundary_match=pasture_edges,pasture_pose_difference=different_poses,cow_poses=cow_poses,passed=passed),ensure_ascii=False,indent=2)+'\n')
assert passed
print('RESULT',sum(len(r['checks']) for r in results)+len(rollback)+3,'checks passed; 12 work tiles including byte-identical grain rollback')
