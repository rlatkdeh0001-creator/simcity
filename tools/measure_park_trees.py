"""Read-only world-vertex measurements; never import build_facilities.py."""
import json
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]

def bounds(objects):
    points=[o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    lo=[min(p[i] for p in points) for i in range(3)]
    hi=[max(p[i] for p in points) for i in range(3)]
    return {'min':lo,'max':hi,'size':[hi[i]-lo[i] for i in range(3)]}

def measure_references():
    result={}
    for ident in ['park-plaza-4x4','park-play-4x4']:
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/facilities'/ident/'facility.blend'))
        bpy.context.view_layer.update()
        trunks=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith('TreeTrunk')]
        crowns=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m and m.name=='leaf' for m in o.data.materials)]
        trees=[]
        for trunk in trunks:
            b=bounds([trunk]);x,y=[(b['min'][i]+b['max'][i])/2 for i in range(2)]
            group=[]
            for crown in crowns:
                cb=bounds([crown]);cx,cy=[(cb['min'][i]+cb['max'][i])/2 for i in range(2)]
                if abs(cx-x)<1 and abs(cy-y)<1:group.append(crown)
            assert len(group)==3
            trees.append({'tree':bounds([trunk]+group),'crown':bounds(group)})
        result[ident]={'source':'assets/facilities/'+ident+'/facility.blend','count':len(trees),'trees':trees}
    return result

if __name__=='__main__':print('TREE_REFERENCE_MEASUREMENTS '+json.dumps(measure_references()))
