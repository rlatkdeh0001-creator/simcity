"""Export existing editable buildings for road-facing views; never resave originals."""
import bpy, json, sys
from pathlib import Path
from mathutils import Vector
root=Path(sys.argv[sys.argv.index('--')+1]).resolve()
path=root/'cities_do/assets/buildings/catalog.json'
data=json.loads(path.read_text())
for asset in data['buildings']:
 bpy.ops.wm.open_mainfile(filepath=str(root/asset['source']))
 bpy.ops.object.select_all(action='DESELECT')
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 for obj in meshes: obj.select_set(True)
 # glTF cannot serialize Blender's procedural brick node. Preserve its authored
 # base tint in the exported copy; keep the original .blend shader untouched.
 for mat in bpy.data.materials:
  if not mat.use_nodes: continue
  shader=mat.node_tree.nodes.get('Principled BSDF')
  if not shader: continue
  color=shader.inputs['Base Color']
  if color.is_linked:
   for link in list(color.links): mat.node_tree.links.remove(link)
   color.default_value=mat.diffuse_color

 top=max((o.matrix_world@Vector(c)).z for o in meshes for c in o.bound_box)
 output=root/'cities_do/assets/buildings/models'/f"{asset['id']}.glb"
 output.parent.mkdir(parents=True,exist_ok=True)
 bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,
  export_yup=True,export_apply=True,export_cameras=False,export_lights=False)
 asset['model']='res://assets/buildings/models/'+output.name
 asset['front_axis']=[0,1]
 asset['height_m']=round(top,5)
 print('EXPORTED_ROAD_FACING',asset['id'],top,flush=True)
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
