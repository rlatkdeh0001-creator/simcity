"""Read-only metre/projection audit of existing Blender sources. No source save/render."""
import bpy, sys, argparse, json, math
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
parser=argparse.ArgumentParser()
parser.add_argument('--root',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
root=args.root
buildings=json.loads((root/'cities_do/assets/buildings/catalog.json').read_text())['buildings']
vehicles=json.loads((root/'cities_do/assets/vehicles/catalog.json').read_text())['vehicles']
manifest=json.loads((root/'cities_do/assets/vehicles/render_manifest.json').read_text())
render_by_id={x['id']:x for x in manifest['vehicles']}
report={'unit':'metres','scope':'read-only original source measurement','buildings':[],'vehicles':[]}
def vertices(objects):
 depsgraph=bpy.context.evaluated_depsgraph_get()
 output=[]
 for obj in objects:
  evaluated=obj.evaluated_get(depsgraph)
  mesh=evaluated.to_mesh()
  output.extend(evaluated.matrix_world@v.co for v in mesh.vertices)
  evaluated.to_mesh_clear()
 return output
def bounds(points):
 lo=[min(v[i] for v in points) for i in range(3)]
 hi=[max(v[i] for v in points) for i in range(3)]
 return {'min':lo,'max':hi,'size':[hi[i]-lo[i] for i in range(3)]}
def pixel(point):
 scene=bpy.context.scene
 p=world_to_camera_view(scene,scene.camera,Vector(point))
 return [p.x*scene.render.resolution_x,(1-p.y)*scene.render.resolution_y]
def projection():
 a=pixel((0,0,0))
 result={}
 for key,point in [('x',(1,0,0)),('y',(0,1,0)),('z',(0,0,1))]:
  p=pixel(point);result[key]=[p[i]-a[i] for i in range(2)]
 return result
for entry in buildings:
 bpy.ops.wm.open_mainfile(filepath=str(root/entry['source']))
 scene=bpy.context.scene
 meshes=[o for o in scene.objects if o.type=='MESH']
 bodies=[o for o in meshes if o.name.startswith(('BuildingBody','Building_FourStoreys'))]
 floor_z=sorted(o.matrix_world.translation.z for o in scene.objects if o.name.startswith('OccupiedFloor'))
 features=[]
 for obj in meshes:
  if obj.name.startswith(('EntryDoor','EntranceDoor','GarageDoor')) and 'Seam' not in obj.name:
   features.append({'name':obj.name,'bounds':bounds(vertices([obj]))})
 report['buildings'].append({'id':entry['id'],'name':entry['name'],'lot_m':[x*4 for x in entry['footprint']],
  'unit_scale':scene.unit_settings.scale_length,'all_geometry':bounds(vertices(meshes)),
  'body':bounds(vertices(bodies)) if bodies else None,'storeys':entry['storeys'],'floor_markers_z':floor_z,
  'floor_spacing_m':[floor_z[i]-floor_z[i-1] for i in range(1,len(floor_z))],
  'features':features,'camera_projection_px_per_m':projection(),
  'game_sprite_scale_zoom1':entry['footprint'][0]*28/entry['lot_width_px']})
 print('AUDIT_BUILDING',entry['id'],flush=True)
for entry in vehicles:
 bpy.ops.wm.open_mainfile(filepath=str(root/'assets/vehicle-fleet'/entry['id']/'vehicle.blend'))
 scene=bpy.context.scene
 meshes=[o for o in scene.objects if o.type=='MESH']
 points=vertices(meshes)
 vehicle={'id':entry['id'],'name':entry['name'],'nominal_lwh_m':[entry['length_m'],entry['width_m'],entry['height_m']],
  'unit_scale':scene.unit_settings.scale_length,'all_geometry':bounds(points),'projection_bounds':{}}
 ppm=render_by_id[entry['id']]['pixels_per_metre']
 data=bpy.data.cameras.new('AuditCamera')
 camera=bpy.data.objects.new('AuditCamera',data);scene.collection.objects.link(camera);scene.camera=camera
 data.type='ORTHO';data.ortho_scale=430/ppm
 scene.render.resolution_x=430;scene.render.resolution_y=245;scene.render.resolution_percentage=100
 target=Vector((0,0,entry['height_m']*.48))
 for angle in manifest['vehicles'][0]['angles_deg']:
  a=math.radians(angle)
  camera.location=target+Vector((math.sin(a)*15,-math.cos(a)*15,15*math.tan(math.radians(30))))
  camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();bpy.context.view_layer.update()
  projected=[pixel(point) for point in points]
  vehicle['projection_bounds'][str(angle)]=[min(p[0] for p in projected),min(p[1] for p in projected),max(p[0] for p in projected),max(p[1] for p in projected)]
 vehicle['camera_projection_315_px_per_m']=projection()
 vehicle['game_sprite_scale_zoom1']=(14/4*math.sqrt(2))/ppm
 report['vehicles'].append(vehicle)
 print('AUDIT_VEHICLE',entry['id'],flush=True)
report['facilities']=[]
for spec_path in sorted((root/'assets/facilities').glob('*/spec.json')):
 entry=json.loads(spec_path.read_text())
 bpy.ops.wm.open_mainfile(filepath=str(root/entry['source']))
 scene=bpy.context.scene
 meshes=[o for o in scene.objects if o.type=='MESH']
 deck_bounds=[bounds(vertices([o])) for o in meshes if o.name.startswith('ParkingDeck_')]
 decks=sorted((b['min'][2]+b['max'][2])/2 for b in deck_bounds)
 doors=[{'name':o.name,'bounds':bounds(vertices([o]))} for o in meshes if o.name.startswith('StairDoor')]
 report['facilities'].append({'id':entry['id'],'name':entry['name'],'lot_m':entry['metres'],
  'unit_scale':scene.unit_settings.scale_length,'all_geometry':bounds(vertices(meshes)),
  'parking_decks_z':decks,'deck_spacing_m':[decks[i]-decks[i-1] for i in range(1,len(decks))],
  'features':doors})
 print('AUDIT_FACILITY',entry['id'],flush=True)
args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('READ_ONLY_AUDIT_COMPLETE',len(buildings),len(vehicles),len(report['facilities']),flush=True)
