"""Render only derived GLBs, at their unchanged metre scale.
Blender -b -t 6 --python-exit-code 1 -P tools/render_remaining_assets.py -- --category overview --eevee
Categories: overview / commercial / industrial / infrastructure. Default: verified EEVEE Next;
--cpu requests Cycles CPU, --cuda explicitly opts into CUDA (timed out on this host).
No source .blend is opened.
"""
# pyright: reportMissingImports=false
import hashlib,json,math,runpy,sys
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/register-30-assets-validation'
H=runpy.run_path(str(ROOT/'tools/render_emergency_comparison.py'),run_name='derived_render_helpers')
VIEW=Vector((1,-1,math.sqrt(2/3))).normalized()
RIGHT=Vector((1,1,0)).normalized()
UP=VIEW.cross(RIGHT).normalized()
AWAY=Vector((-1,1,0)).normalized()
def text(body,position,size=2.2):
 data=bpy.data.curves.new('EvidenceLabel','FONT');data.body=body;data.size=size;data.align_x='CENTER'
 obj=bpy.data.objects.new('EvidenceLabel',data);bpy.context.scene.collection.objects.link(obj)
 obj.location=position;obj.rotation_euler=(-VIEW).to_track_quat('-Z','Y').to_euler()
 material=bpy.data.materials.get('EvidenceInk')
 if not material:
  material=bpy.data.materials.new('EvidenceInk');material.diffuse_color=(.015,.035,.045,1)
 data.materials.append(material)
 return obj
def corners(a,b):return [Vector((x,y,z)) for x in [a[0],b[0]] for y in [a[1],b[1]] for z in [a[2],b[2]]]
def frame(scene,points):
 xs=[p.dot(RIGHT) for p in points];ys=[p.dot(UP) for p in points];ds=[p.dot(VIEW) for p in points]
 aspect=scene.render.resolution_x/scene.render.resolution_y
 scene.camera.data.sensor_fit='HORIZONTAL'
 scene.camera.data.clip_start=.1
 scene.camera.data.clip_end=10000
 scene.camera.data.ortho_scale=max(max(xs)-min(xs)+12,(max(ys)-min(ys)+12)*aspect)*1.04
 target=RIGHT*((max(xs)+min(xs))/2)+UP*((max(ys)+min(ys))/2)+VIEW*((max(ds)+min(ds))/2)
 scene.camera.location=target+VIEW*(max(ds)-min(ds)+1000)
 scene.camera.rotation_euler=(target-scene.camera.location).to_track_quat('-Z','Y').to_euler()
 bpy.context.view_layer.update()
 inverse=scene.camera.matrix_world.inverted()
 for point in points:
  local=inverse@point
  assert scene.camera.data.clip_start <= -local.z <= scene.camera.data.clip_end,('Evidence camera near/far clips actual geometry',float(-local.z),scene.camera.data.clip_end)
  assert abs(local.x)<=scene.camera.data.ortho_scale/2+.01 and abs(local.y)<=scene.camera.data.ortho_scale/aspect/2+.01,'Evidence camera crops actual geometry'
 return {'orthographic_width_m':scene.camera.data.ortho_scale,'camera_position':list(scene.camera.location),'camera_target':list(target),'camera_elevation_deg':30}
def vehicle_reference(identifier):
 objects=H['load_model'](ROOT/f'cities_do/assets/vehicles/{identifier}.glb')
 bpy.context.view_layer.update();a,b=H['bounds'](objects)
 collection=bpy.data.collections.new('Reference-'+identifier)
 for obj in objects:
  for owner in list(obj.users_collection):owner.objects.unlink(obj)
  collection.objects.link(obj)
 return collection,a,b

def main():
 category=sys.argv[sys.argv.index('--category')+1]
 entries=json.loads((ROOT/'cities_do/assets/registered_30.json').read_text(encoding='utf-8'))['assets']
 if category=='infrastructure':entries=[e for e in entries if e['group'] in ['power','water','waste']]
 elif category!='overview':entries=[e for e in entries if e['group']==category]
 assert len(entries)=={'overview':30,'commercial':10,'industrial':8,'infrastructure':12}[category]
 OUT.mkdir(parents=True,exist_ok=True)
 width,height=(4800,3600) if category=='overview' else (3600,2600)
 scene=H['reset'](width,height)
 devices=[]
 if '--cpu' not in sys.argv and '--cuda' not in sys.argv:
  scene.render.engine='BLENDER_EEVEE_NEXT';devices=['EEVEE Next']
 elif '--cpu' not in sys.argv:
  try:
   prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='CUDA';prefs.get_devices()
   devices=[d.name for d in prefs.devices if d.type=='CUDA']
   if devices:
    for d in prefs.devices:d.use=d.type=='CUDA'
    scene.cycles.device='GPU'
  except Exception as exc:print('RENDER_CPU_FALLBACK',str(exc),flush=True)
 print('RENDER_DEVICE',devices or ['CPU'],flush=True)
 references={}
 if category!='overview':
  for identifier in ['car-sedan-03','truck-flatbed-02']:references[identifier]=vehicle_reference(identifier)
 cols=6 if category=='overview' else 4
 rows=math.ceil(len(entries)/cols)
 points=[];records=[];vehicle_records=[]
 for index,entry in enumerate(entries):
  position=RIGHT*((index%cols-(cols-1)/2)*80)+AWAY*((rows-1)/2-index//cols)*190
  objects=H['load_model'](ROOT/'cities_do'/entry['model'].removeprefix('res://'),position)
  bpy.context.view_layer.update();a,b=H['bounds'](objects)
  measured=[b[i]-a[i] for i in range(3)]
  expected=[entry['width_m'],entry['length_m'],entry['height_m']]
  assert all(abs(x-y)<.06 for x,y in zip(measured,expected)),(entry['id'],measured,expected)
  points+=corners(a,b)
  records.append({'id':entry['id'],'position_m':list(position),'measured_wdh_m':measured,'scale_changed':False})
  text(entry['id'],position-AWAY*80)
  for dx,(identifier,(collection,va,vb)) in zip([-9,9],references.items()):
   pos=position-AWAY*61+RIGHT*dx
   instance=bpy.data.objects.new('VehicleReference-'+identifier,None)
   instance.instance_type='COLLECTION';instance.instance_collection=collection
   instance.location=pos+Vector((0,0,-va[2]));scene.collection.objects.link(instance)
   assert list(instance.scale)==[1,1,1]
   points +=[p+instance.location for p in corners(va,vb)]
   vehicle_records.append({'asset':entry['id'],'vehicle':identifier,'position_m':list(instance.location),'measured_wdh_m':[vb[i]-va[i] for i in range(3)],'instance_scale':list(instance.scale)})
  if references:
   lengths=[vb[1]-va[1] for _,va,vb in references.values()]
   text('SEDAN %.2fm / TRUCK %.2fm' % tuple(lengths),position-AWAY*71,size=1.7)
 header_y=max(p.dot(UP) for p in points)+12
 text('%s | ORIGINAL METRE SCALE | INSPECTION ONLY' % category.upper(),UP*header_y,size=3.4)
 bpy.context.view_layer.update()
 for obj in scene.objects:
  if obj.type=='FONT':points +=[obj.matrix_world@Vector(v) for v in obj.bound_box]
 camera=frame(scene,points)
 path=OUT/('overview-30.png' if category=='overview' else 'scale-'+category+'.png')
 H['dump'](path.with_suffix('.json'),dict(category=category,resolution=[width,height],engine=scene.render.engine,device=devices or ['CPU'],assets=records,vehicle_instances=vehicle_records,camera=camera,no_image_resizing=True))
 H['render'](scene,path)
 assert path.exists() and path.stat().st_size>1000
 data=json.loads(path.with_suffix('.json').read_text(encoding='utf-8'));data['image_sha256']=hashlib.sha256(path.read_bytes()).hexdigest();H['dump'](path.with_suffix('.json'),data)
 print('RENDER_COMPLETE',category,len(records),len(vehicle_records),flush=True)
if __name__=='__main__':main()
