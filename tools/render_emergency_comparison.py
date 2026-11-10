"""Render derived GLBs at one physical scale; source .blend files are never saved.
blender -b --factory-startup -t 2 -P tools/render_emergency_comparison.py
Append -- --sprites to render eight calibrated views per service separately.
"""
import json, math, sys
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/emergency-assets-validation'
GAME=ROOT/'cities_do/assets/services'

def dump(path,data):
 path.parent.mkdir(parents=True,exist_ok=True)
 path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def reset(width=2400,height=1500,scale=210):
 bpy.ops.wm.read_factory_settings(use_empty=True)
 s=bpy.context.scene
 s.render.engine='CYCLES'
 s.cycles.samples=12
 s.cycles.use_denoising=True
 s.render.resolution_x=width;s.render.resolution_y=height;s.render.resolution_percentage=100
 s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
 s.render.film_transparent=False
 s.view_settings.view_transform='Standard'
 world=bpy.data.worlds.new('ComparisonWorld');world.use_nodes=True
 world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.80,1)
 world.node_tree.nodes['Background'].inputs[1].default_value=.7;s.world=world
 data=bpy.data.lights.new('Key','SUN');data.energy=2;data.angle=.25
 light=bpy.data.objects.new('Key',data);s.collection.objects.link(light);light.rotation_euler=(.45,-.4,-.65)
 data=bpy.data.cameras.new('Camera');camera=bpy.data.objects.new('Camera',data);s.collection.objects.link(camera)
 data.type='ORTHO';data.ortho_scale=scale;s.camera=camera
 return s

def aim(s,target,angle=math.pi/4):
 target=Vector(target);distance=160
 s.camera.location=target+Vector((distance*math.sin(angle),-distance*math.cos(angle),distance*math.tan(math.pi/6)))
 s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler()

def load_model(path,position=(0,0,0)):
 before=set(bpy.data.objects)
 bpy.ops.import_scene.gltf(filepath=str(path))
 objects=[o for o in bpy.data.objects if o not in before]
 for o in objects:
  if o.parent not in objects:o.location+=Vector(position)
 return objects

def bounds(objects):
 graph=bpy.context.evaluated_depsgraph_get()
 points=[o.matrix_world@Vector(p) for src in objects if src.type=='MESH' for o in [src.evaluated_get(graph)] for p in o.bound_box]
 return [min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)]

def render(s,path):
 if '--audit-only' in sys.argv:return
 s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
 print('RENDERED',path.name,flush=True)

def main():
 OUT.mkdir(parents=True,exist_ok=True)
 slots=json.loads((GAME/'pending_slots.json').read_text(encoding='utf-8'))['slots']
 entries=[json.loads((ROOT/'cities_do'/e['asset'].replace('res://','')).read_text(encoding='utf-8')) for e in slots]
 if '--sprites' in sys.argv:
  for e in entries:
   scale=max(e['width']*4*1.7,e['height_m']*2.5)
   s=reset(640,640,scale);s.cycles.samples=8;s.render.film_transparent=True
   load_model(ROOT/'cities_do'/e['model'].replace('res://',''))
   folder=GAME/'sprites'/e['id'];folder.mkdir(parents=True,exist_ok=True)
   for angle in range(0,360,45):
    aim(s,(0,0,e['height_m']*.3),math.pi/4+math.radians(angle))
    render(s,folder/f'{angle:03d}.png')
  return
 s=reset()
 for index,e in enumerate(entries):
  pos=(-63+(index%4)*42,-24+(index//4)*52,0)
  load_model(ROOT/'cities_do'/e['model'].replace('res://',''),pos)
 aim(s,(0,0,4))
 render(s,OUT/'emergency-overview.png')
 vehicles={}
 for ident in ['fire-engine-01','police-car-01','car-sedan-03']:
  objects=load_model(ROOT/f'cities_do/assets/vehicles/{ident}.glb')
  bpy.context.view_layer.update();a,b=bounds(objects)
  vehicles[ident]={'width_m':b[0]-a[0],'length_m':b[1]-a[1],'height_m':b[2]-a[2]}
  for o in objects:bpy.data.objects.remove(o,do_unlink=True)
 for index,e in enumerate(entries):
  x=-63+(index%4)*42;y=-24+(index//4)*52-e['depth']*2-5.3
  for dx,ident in zip([-5,0,5],vehicles):load_model(ROOT/f'cities_do/assets/vehicles/{ident}.glb',(x+dx,y,0))
 render(s,OUT/'emergency-vehicle-scale.png')
 measurements=json.loads((OUT/'measurements.json').read_text(encoding='utf-8'))
 clearances=[]
 for e in measurements:
  for door in e['garage_doors']:
   clearances.append({'building':e['id'],'door':door['node'],'door_width_m':door['width_m'],
                      'truck_width_including_mirrors_m':vehicles['fire-engine-01']['width_m'],
                      'horizontal_clearance_total_m':door['width_m']-vehicles['fire-engine-01']['width_m'],
                      'height_clearance_m':door['height_m']-vehicles['fire-engine-01']['height_m']})
 width_ok=all(e['horizontal_clearance_total_m']>0 for e in clearances)
 height_ok=all(e['height_clearance_m']>0 for e in clearances)
 dump(OUT/'vehicle-clearance.json',{'camera_elevation_deg':30,'orthographic_width_m':210,'resolution':[2400,1500],
                                  'all_model_scales':[1,1,1],'vehicles':vehicles,'garage_clearances':clearances,
                                  'all_door_widths_fit':width_ok,'all_door_heights_fit':height_ok,
                                  'physical_drive_through_validated':False,
                                  'scope':'asset inspection only; original small station has a documented height shortfall'})
 assert width_ok,'Requested door-width comparison failed'
 if not height_ok:print('CLEARANCE_WARNING small station door is lower than the fire engine accessories; originals unchanged',flush=True)

if __name__=='__main__':main()
