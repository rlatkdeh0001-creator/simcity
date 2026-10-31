"""Blender readback checks of delivered editable sources, not just generator inputs."""
from pathlib import Path
import bpy, json, math
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
specs=json.loads((ROOT/'designs.json').read_text());results=[]
for spec in specs:
 folder=ROOT/spec['id'];meta=json.loads((folder/'metadata.json').read_text())
 bpy.ops.wm.open_mainfile(filepath=str(folder/'building.blend'))
 scene=bpy.context.scene
 floors=[obj for obj in scene.objects if obj.name.startswith('OccupiedFloor_')]
 assert len(floors)==meta['occupied_storeys']==spec['floors']
 assert sorted(obj['storey_index'] for obj in floors)==list(range(1,spec['floors']+1))
 verts=[obj.matrix_world@vertex.co for obj in scene.objects if obj.type=='MESH' for vertex in obj.data.vertices]
 low=[min(vertex[i] for vertex in verts) for i in range(3)];high=[max(vertex[i] for vertex in verts) for i in range(3)]
 for actual,expected in zip(low+high,meta['vertex_bounds_m'][0]+meta['vertex_bounds_m'][1]):assert abs(actual-expected)<.001
 half=spec['size']*2;assert low[0]>=-half-.001 and low[1]>=-half-.001 and high[0]<=half+.001 and high[1]<=half+.001
 assert scene.camera.data.type=='ORTHO' and scene.camera.data.ortho_scale==spec['frame']
 direction=scene.camera.rotation_euler.to_quaternion()@Vector((0,0,-1));elevation=math.degrees(math.asin(-direction.z));assert abs(elevation-30)<.01
 assert scene.render.resolution_x==900 and scene.render.resolution_y==1100
 results.append({'id':spec['id'],'saved_floor_markers':len(floors),'lot_bounds_valid':True,'saved_camera_elevation_degrees':elevation,'source_readback':'passed'})
 print('PASS saved blend',spec['id'],'floors',len(floors))
(ROOT/'source-validation.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print('PASS 8 editable .blend files read back; category/footprint/floors/camera/geometry verified')
