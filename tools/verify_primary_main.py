"""Reopen original sources, inspect exact metres/front/camera and requested components."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[1];results=[]
ids=['primary-farm-vegetable-01','primary-farm-livestock-01','primary-forestry-01','primary-mine-iron-01','primary-mine-coal-01','primary-oil-01','primary-mine-uranium-01','primary-fishing-01']
for ident in ids:
 p=ROOT/'assets/primary-industry'/ident;m=json.loads((p/'metadata.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(p/(ident+'.blend')));scene=bpy.context.scene;bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get();points=[];tri=0;object_points={}
 for o in scene.objects:
  if o.type!='MESH':continue
  e=o.evaluated_get(dep);me=e.to_mesh();vs=[e.matrix_world@v.co for v in me.vertices];points.extend(vs);tri+=sum(len(poly.vertices)-2 for poly in me.polygons);object_points[o.name]=vs;e.to_mesh_clear()
 lo=[min(v[i] for v in points) for i in range(3)];hi=[max(v[i] for v in points) for i in range(3)];cam=scene.camera;d=cam.location-Vector(cam['target_m']);ps=[world_to_camera_view(scene,cam,p) for p in points]
 def count(prefix):return sum(n==prefix or n.startswith(prefix+'.') for n in object_points)
 checks={'metres':scene.unit_settings.system=='METRIC' and scene.unit_settings.scale_length==1,'finite':all(math.isfinite(c) for v in points for c in v),'whole_lot_exact_16m':all(abs(hi[i]-lo[i]-16)<.0001 for i in [0,1]),'all_geometry_within_lot':all(lo[i]>=-8-.0001 and hi[i]<=8+.0001 for i in [0,1]),'ground_plinth':abs(lo[2]+.12)<.0001,'bounds_match_metadata':max(abs(a-b) for actual,stored in zip([lo,hi],m['vertex_bounds_m']) for a,b in zip(actual,stored))<.0001,'triangles_match_metadata':tri==m['triangles'],'main_4x4_not_growth_8x8':m['kind']=='primary_main' and m['footprint_cells']==[4,4],'front_metadata':m['front_blender']=='-Y' and m['front_godot']=='+Z','road_front_anchor':list(bpy.data.objects['RoadFront_BlenderMinusY'].location)==[0,-8,.11999999731779099],'front_access':any(o.name.startswith('Access_') and o.location.y<0 and list(o['outward_blender'])==[0,-1,0] for o in scene.objects),'camera_30_orthographic':cam.data.type=='ORTHO' and abs(math.degrees(math.atan2(d.z,math.hypot(d.x,d.y)))-30)<.0001,'transparent_900x1100':scene.render.film_transparent and scene.render.resolution_x==900 and scene.render.resolution_y==1100,'not_clipped':all(.05<v.x<.95 and .05<v.y<.95 for v in ps),'no_external_texture':not any(im.source=='FILE' for im in bpy.data.images),'not_registered':m['game_registered'] is False,'storey_height_305':m['main_storey_height_m']==3.05}
 if ident=='primary-farm-vegetable-01':checks['two_greenhouses_and_sorting']=count('GreenhouseShell')==2 and count('SortingHouse')==1
 elif ident=='primary-farm-livestock-01':checks['barn_silo_fenced_yard']=count('CattleBarn')==1 and count('FeedSilo')==1 and count('FencePost')>0
 elif ident=='primary-forestry-01':checks['sawmill_logs_crane']=count('Sawmill')==1 and count('LogStock')==8 and count('CraneMast')==count('CraneBoom')==1
 elif ident in ['primary-mine-iron-01','primary-mine-coal-01']:
  checks['portal_and_headframe']=count('MinePortalOpening')==1 and count('HeadframeLeg')==4 and count('HoistWheel')==1
  checks['ore_stock']=count('OreStock')==3
  if 'coal' in ident:checks['coal_conveyor']=count('ConveyorBelt')==1
 elif ident=='primary-oil-01':checks['office_two_tanks_pumpjack']=count('OilOffice')==1 and count('OilStorageTank')==2 and count('PumpHorseHead')==1
 elif ident=='primary-mine-uranium-01':checks['portal_store_radiation_fence']=count('MinePortalOpening')==1 and count('SealedUraniumStore')==1 and count('WarningPlate')==2 and count('FenceMesh')>0
 elif ident=='primary-fishing-01':
  boatpoints=[v for name,vs in object_points.items() if name.startswith(('FishingBoatHull','Boat')) for v in vs]
  pierpoints=[v for name,vs in object_points.items() if name.startswith(('PierSpine','SidePier','CrossPier')) for v in vs]
  checks['processing_and_two_boats']=count('FishProcessing')==1 and count('FishingBoatHull')==2
  checks['waterfront_plus_y']=m['waterfront_blender']=='+Y' and all(2-.0001<=v.y<=8+.0001 for v in boatpoints+pierpoints)
  checks['shoreline_land_ends_y2']=abs(max(v.y for v in object_points['LandPlinth'])-2)<.0001
  checks['no_water_plane']=m['water_surface_included'] is False and not any('water' in name.lower() for name in object_points)
 results.append(dict(id=ident,checks=checks,passed=all(checks.values()),triangles=tri,measured_dimensions_m=[hi[i]-lo[i] for i in range(3)]));print('MAIN_VERIFY',ident,checks,flush=True)
(ROOT/'docs/primary-industry/completion/main-geometry-validation.json').write_text(json.dumps(dict(assets=results,passed=all(r['passed'] for r in results)),ensure_ascii=False,indent=2)+'\n')
assert all(r['passed'] for r in results)
print('RESULT',sum(len(r['checks']) for r in results),'main asset checks passed')
