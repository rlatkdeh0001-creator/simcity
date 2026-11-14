"""100 independent unoccluded grayscale part renders + camera-depth sidecar intermediates.
PNG finalization/tint/depth composition: tools/compose_citizen_pilot.py.
"""
from pathlib import Path
import sys,bpy,json,numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'));import citizen_pilot_common as C
OUT=ROOT/'assets/citizens/adult-pilot-01';WORK=Path('/tmp/citizen-adult-pilot-render');WORK.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(OUT/'citizen.blend'));C.studio(scale=4);scene=bpy.context.scene;scene.view_layers[0].use_pass_z=True;scene.use_nodes=True;nodes=scene.node_tree.nodes;nodes.clear();r=nodes.new('CompositorNodeRLayers');c=nodes.new('CompositorNodeComposite');scene.node_tree.links.new(r.outputs['Image'],c.inputs[0]);f=nodes.new('CompositorNodeOutputFile');f.base_path=str(WORK);f.format.file_format='OPEN_EXR';f.format.color_mode='BW';f.format.color_depth='32';scene.node_tree.links.new(r.outputs['Depth'],f.inputs[0]);manifest=[]
for direction in C.DIRECTIONS:
 view=C.set_view(direction)
 for frame in C.FRAMES:
  C.set_pose(frame)
  for part in C.PARTS:
   stem=f'{part}_{direction}_{frame}'
   for name in C.PARTS:bpy.data.objects[name].hide_render=name!=part
   scene.render.filepath=str(WORK/(stem+'.png'));f.file_slots[0].path=stem+'_depth_';bpy.ops.render.render(write_still=True)
   paths=sorted(WORK.glob(stem+'_depth_*.exr'));assert paths,stem
   image=bpy.data.images.load(str(paths[-1]),check_existing=False);image.colorspace_settings.name='Non-Color';width,height=image.size;data=np.array(image.pixels[:],dtype=np.float32);channels=len(data)//(width*height);depth=np.flipud(data.reshape(height,width,channels)[:,:,0]).copy();np.save(WORK/(stem+'.npy'),depth);bpy.data.images.remove(image)
   manifest.append(dict(stem=stem,part=part,direction=direction,frame=frame,**{k:v for k,v in view.items() if k!='direction'}));print('CITIZEN_RENDER',len(manifest),stem,'depth',float(np.min(depth)),float(np.max(depth)),flush=True)
(ROOT/'docs/citizen-adult-pilot/render-manifest.json').write_text(json.dumps(dict(supersampling=4,temporary_directory=str(WORK),images=manifest),indent=2)+'\n')
print('RESULT 100 independent part renders; no source file saved',flush=True)
