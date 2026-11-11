"""Render four actual Blender sources together at unchanged metre scale."""
import bpy,sys,math,importlib.util
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('service_build',ROOT/'tools/build_service_vehicles_2.py');S=importlib.util.module_from_spec(spec);spec.loader.exec_module(S);S.C.reset_scene();bpy.context.scene.unit_settings.system='METRIC'
for ident,x,L in [('car-sedan-03',-6,4.85),('fire-engine-01',-2,7.6),('garbage-truck-01',2,8.0),('ambulance-01',6,5.9)]:
 with bpy.data.libraries.load(str(ROOT/'assets/vehicle-fleet'/ident/'vehicle.blend'),link=False) as (src,dst):dst.objects=src.objects
 objects=[o for o in dst.objects if o and o.type in ['MESH','EMPTY']];owned=set(objects)
 for o in objects:bpy.context.scene.collection.objects.link(o)
 for o in objects:
  if o.parent not in owned:o.location+=Vector((x,-4+L/2,0))
 bpy.context.view_layer.update()
cam,target=S.studio(19,10,3.2);scene=bpy.context.scene;scene.render.resolution_x=1600;scene.render.resolution_y=900;target=Vector((0,-.25,1.4));cam.location=target+Vector((12,-36,math.hypot(12,36)*math.tan(math.pi/6)));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=20
bpy.context.view_layer.update();points=[o.matrix_world@Vector(c) for o in scene.objects if o.type=='MESH' for c in o.bound_box]
for _ in range(10):
 projected=[world_to_camera_view(scene,cam,p) for p in points];ratio=max(max(abs(p.x-.5)/.45,abs(p.y-.5)/.43) for p in projected)
 if ratio<=1:break
 cam.data.ortho_scale*=ratio*1.01;bpy.context.view_layer.update()
scene.render.filepath=str(ROOT/'docs/service-vehicles-2/same-scale.png');bpy.ops.render.render(write_still=True)
print('SAME_SCALE_SOURCE_RENDER: sedan / fire engine / garbage truck / ambulance; no source rescaling')
