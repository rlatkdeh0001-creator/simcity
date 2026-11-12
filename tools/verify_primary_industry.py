"""Read-only source validation; tile boundary profiles and crop periods, no runtime claims."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[1];results=[]
for ident,tile in [('primary-farm-grain-01',False),('primary-tile-grain-01',True)]:
 p=ROOT/'assets/primary-industry'/ident;m=json.loads((p/'metadata.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(p/(ident+'.blend')));scene=bpy.context.scene;bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get();points=[];tri=0;objects={}
 for o in scene.objects:
  if o.type not in ['MESH','FONT']:continue
  e=o.evaluated_get(dep);me=e.to_mesh();vs=[e.matrix_world@v.co for v in me.vertices];points+=vs;tri+=sum(len(poly.vertices)-2 for poly in me.polygons)
  objects[o.name]={'vertices':vs,'materials':[mat.name for mat in me.materials]};e.to_mesh_clear()
 low=[min(v[i] for v in points) for i in range(3)];high=[max(v[i] for v in points) for i in range(3)];w=4 if tile else 16;cam=scene.camera;v=cam.location-Vector(cam['target_m']);projected=[world_to_camera_view(scene,cam,p) for p in points]
 checks={'metres':scene.unit_settings.system=='METRIC' and scene.unit_settings.scale_length==1,'finite':all(math.isfinite(c) for v in points for c in v),'exact_footprint':all(abs(high[i]-low[i]-w)<.001 for i in [0,1]),'within_lot':all(low[i]>=-w/2-.001 and high[i]<=w/2+.001 for i in [0,1]),'ground_plinth':abs(low[2]+.12)<.001,'bounds_metadata':max(abs(a-b) for actual,stored in zip([low,high],m['vertex_bounds_m']) for a,b in zip(actual,stored))<.001,'triangle_metadata':tri==m['triangles'],'camera_orthographic':cam.data.type=='ORTHO','camera_elevation_30':abs(math.degrees(math.atan2(v.z,math.hypot(v.x,v.y)))-30)<.001,'camera_frame_margin':all(.05<p.x<.95 and .05<p.y<.95 for p in projected),'image_size':(scene.render.resolution_x,scene.render.resolution_y)==((900,900) if tile else (900,1100)),'transparent':scene.render.film_transparent,'no_external_textures':not any(im.source=='FILE' for im in bpy.data.images),'fonts_packed':all(not f.filepath or f.filepath=='<builtin>' or f.packed_file is not None for f in bpy.data.fonts),'source_only':m['game_registered'] is False,'front_metadata':m['front_blender']=='-Y' and m['front_godot']=='+Z'}
 if tile:
  signatures={}
  for axis in [0,1]:
   edges=[]
   for side in [-1,1]:
    edge=set()
    for item in objects.values():
     for point in item['vertices']:
      if abs(point[axis]-side*2)<.00001:
       edge.add((round(point[1-axis],5),round(point.z,5),tuple(item['materials'])))
    edges.append(sorted(edge))
   checks['opposite_edge_profile_'+str(axis)]=bool(edges[0]) and edges[0]==edges[1];signatures[str(axis)]=edges
  stems=[o for o in scene.objects if o.name.startswith('WheatStem')]
  for axis,count in [(0,6),(1,8)]:
   positions=sorted(set(round(o.location[axis],5) for o in stems));gaps=[b-a for a,b in zip(positions,positions[1:])]+[positions[0]+4-positions[-1]]
   checks['crop_period_'+str(axis)]=len(positions)==count and all(abs(gap-4/count)<.0001 for gap in gaps)
  checks['tile_triangle_budget']=300<=tri<=1500;checks['single_tile_in_source']=len(stems)==48;checks['no_border_objects']=not any('curb' in name.lower() or 'fence' in name.lower() for name in objects)
 else:
  checks['silo_count']=len([o for o in scene.objects if o.name=='GrainSilo' or o.name.startswith('GrainSilo.')])==2
  checks['road_front']=abs(bpy.data.objects['RoadFront_BlenderMinusY'].location.y+8)<.001
  checks['front_door']=bpy.data.objects['EntranceFrame'].location.y<0
  checks['front_garage']=bpy.data.objects['GarageLintel'].location.y<0
  checks['storey_height']=m['main_storey_height_m']==3.05 and m['main_floors']==2 and m['garage_floors']==1
 row=dict(id=ident,checks=checks,passed=all(checks.values()),measured_dimensions_m=[high[i]-low[i] for i in range(3)],triangles=tri)
 if tile:row['edge_signatures']=signatures
 results.append(row);print('VERIFY',ident,checks,flush=True)
out=ROOT/'docs/primary-industry/geometry-validation.json';out.write_text(json.dumps(dict(assets=results,passed=all(r['passed'] for r in results)),ensure_ascii=False,indent=2)+'\n')
assert all(r['passed'] for r in results)
print('RESULT',sum(len(r['checks']) for r in results),'checks passed')
