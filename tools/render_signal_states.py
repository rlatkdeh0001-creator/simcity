"""Read-only actual one-lamp renders, plus export-safe material definitions in spec."""
from pathlib import Path
import bpy,json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/traffic-signals';NAMES=['lamp_red','lamp_yellow','lamp_left_arrow','lamp_green'];projection={}
for ident in ['traffic-signal-arm-01','traffic-signal-post-01']:
 p=ROOT/'assets/street-furniture'/ident;bpy.ops.wm.open_mainfile(filepath=str(p/'signal.blend'));data=json.loads((p/'spec.json').read_text())
 data['material_definitions']={name:dict(base_color_linear=list(mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value),emission_color_linear=list(mat.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value),emission_strength=mat.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value,roughness=mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value) for name,mat in bpy.data.materials.items() if name in [n for pair in data['lamp_materials'].values() for n in pair]}
 (p/'spec.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
# Use the identical post head for front-facing individual-lamp proofs.
scene=bpy.context.scene;head=bpy.data.objects['SignalHead'];target=head.location.copy();cam=scene.camera;cam.location=target+Vector((0,-10,0));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=3.05
for o in scene.objects:
 if o.type=='MESH' and o.parent!=head:o.hide_render=True
scene.render.resolution_x=900;scene.render.resolution_y=300;scene.cycles.samples=32
for active in NAMES:
 for name in NAMES:bpy.data.objects[name].data.materials[0]=bpy.data.materials['mat_'+name+('_on' if name==active else '_off')]
 bpy.context.view_layer.update();scene.render.filepath=str(OUT/(active+'-only.png'));bpy.ops.render.render(write_still=True)
for i,name in enumerate(NAMES):
 world=head.matrix_world@Vector(((i-1.5)*.60,-.31,0));p=world_to_camera_view(scene,cam,world);projection[name]=[round(p.x*900),round((1-p.y)*300)]
(OUT/'state-image-probes.json').write_text(json.dumps(projection,indent=2)+'\n')
print('SINGLE_LAMP_RENDER: four individual states, identical head, source blend never saved')
