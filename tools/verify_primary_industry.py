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
  ribbons=[o for o in scene.objects if o.name.startswith('WheatRibbon_')]
  positions=sorted(o['row_center_x_m'] for o in ribbons);gaps=[b-a for a,b in zip(positions,positions[1:])]+[positions[0]+4-positions[-1]]
  checks['row_period_x']=len(positions)==4 and all(abs(gap-1)<.0001 for gap in gaps)
  checks['ribbons_span_y']=all(abs(min(v.y for v in objects[o.name]['vertices'])+2)<.00001 and abs(max(v.y for v in objects[o.name]['vertices'])-2)<.00001 for o in ribbons)
  checks['no_individual_plants']=not any(name.startswith(('WheatStem','WheatHead','WheatLeaves')) for name in objects)
  checks['tile_triangle_budget']=0<tri<=300
  checks['single_tile_in_source']=len(ribbons)==4 and len(objects)==5
  checks['crop_height_06_to_08']=len(ribbons)==4 and all(.6<=max(v.z for v in objects[o.name]['vertices'])<=.8 for o in ribbons)
  coverage=sum(o['row_width_m']*4 for o in ribbons)/16
  checks['narrow_furrows']=.90<=coverage<=.96 and abs(coverage-m['ground_coverage_fraction'])<.0001
  normal_edges=[{},{}]
  for o in scene.objects:
   if o.type!='MESH':continue
   e=o.evaluated_get(dep);me=e.to_mesh()
   for loop in me.loops:
    v=e.matrix_world@me.vertices[loop.vertex_index].co;n=me.corner_normals[loop.index].vector
    if abs(n.y)>.999:continue  # End caps are hidden when tiles abut.
    for k,side in enumerate([-1,1]):
     if abs(v.y-side*2)<.00001:normal_edges[k].setdefault((round(v.x,5),round(v.z,5)),[]).append(Vector(n))
   e.to_mesh_clear()
  # Blender stores custom loop normals in quantized local fan spaces. Compare actual
  # decoded angular error, not equality of decimal-rounded components. Positions remain exact.
  same_positions=normal_edges[0].keys()==normal_edges[1].keys();angles=[]
  if same_positions:
   for position,left in normal_edges[0].items():
    right=normal_edges[1][position]
    for source,target in [(left,right),(right,left)]:
     angles.extend(min(math.degrees(a.angle(b)) for b in target) for a in source)
  max_normal_error=max(angles,default=180)
  checks['matching_y_boundary_shading_normals']=bool(angles) and same_positions and max_normal_error<=.10
  checks['low_wave_geometry']=all(.07<max(v.z for v in objects[o.name]['vertices'])-min(max(v.z for v in objects[o.name]['vertices'] if abs(v.y-y)<.0001) for y in [-2,-2/3,2/3,2])<.09 for o in ribbons)
  factors=[o['brightness_factor'] for o in sorted(ribbons,key=lambda o:o.name)]
  checks['brightness_within_10_percent']=len(set(round(f,3) for f in factors))==4 and all(.90-.00001<=f<=1.10+.00001 for f in factors)
  def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
  baseline=[linear(int('e2b94f'[i:i+2],16)/255) for i in [0,2,4]]
  checks['material_brightness_matches']=all(max(abs(a-b*f) for a,b in zip(o.data.materials[0].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value[:3],baseline))<.00001 for o,f in zip(sorted(ribbons,key=lambda o:o.name),factors))
  soil=bpy.data.objects['TileSoil'].data.materials[0].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value
  luminance=lambda rgb:sum(a*b for a,b in zip(rgb,[.2126,.7152,.0722]))
  checks['dark_furrow_contrast']=luminance(soil)<min(luminance(o.data.materials[0].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value) for o in ribbons)*.40
  checks['no_border_objects']=not any('curb' in name.lower() or 'fence' in name.lower() for name in objects)

 else:
  checks['silo_count']=len([o for o in scene.objects if o.name=='GrainSilo' or o.name.startswith('GrainSilo.')])==2
  checks['road_front']=abs(bpy.data.objects['RoadFront_BlenderMinusY'].location.y+8)<.001
  checks['front_door']=bpy.data.objects['EntranceFrame'].location.y<0
  checks['front_garage']=bpy.data.objects['GarageLintel'].location.y<0
  checks['storey_height']=m['main_storey_height_m']==3.05 and m['main_floors']==2 and m['garage_floors']==1
 row=dict(id=ident,checks=checks,passed=all(checks.values()),measured_dimensions_m=[high[i]-low[i] for i in range(3)],triangles=tri)
 if tile:row['edge_signatures']=signatures;row['max_y_boundary_normal_error_degrees']=max_normal_error;row['normal_quantization_tolerance_degrees']=.10
 results.append(row);print('VERIFY',ident,checks,flush=True)
out=ROOT/'docs/primary-industry/geometry-validation.json';out.write_text(json.dumps(dict(assets=results,passed=all(r['passed'] for r in results)),ensure_ascii=False,indent=2)+'\n')
assert all(r['passed'] for r in results)
print('RESULT',sum(len(r['checks']) for r in results),'checks passed')
