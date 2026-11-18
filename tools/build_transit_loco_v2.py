"""Original high-speed lead car v2, not a real train replica. Blender 4.3.2.
Read-only dependencies: build_transit_vehicles / build_vehicle_fleet / MIT common.
Reproduce with --output-root NEW_EMPTY_WORKSPACE; earlier source files are protected.
"""
import argparse
import json
import math
from pathlib import Path
import shutil
import sys
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_transit_vehicles as T
F=T.F;C=T.C
# Long low taper across the forward third; rounded body with a broad, level roof.
CONTROL=[(-4.5,.24,1.00,1.30),(-4.35,.43,.75,1.45),(-4.05,.68,.43,1.70),
         (-3.65,.98,.22,2.13),(-3.20,1.22,.16,2.68),(-2.75,1.39,.16,3.17),
         (-2.30,1.47,.16,3.52),(-1.75,1.488,.16,3.66),(4.5,1.488,.16,3.66)]

def section(y):
    for i in range(len(CONTROL)-1):
        a,b=CONTROL[i:i+2]
        if a[0]<=y<=b[0]:
            t=(y-a[0])/(b[0]-a[0]);out=[]
            # Catmull-Rom interpolation makes the nose a curve, not a stepped cab.
            p=CONTROL[max(0,i-1)];q=CONTROL[min(len(CONTROL)-1,i+2)]
            for k in range(1,4):
                value=.5*((2*a[k])+(-p[k]+b[k])*t+(2*p[k]-5*a[k]+4*b[k]-q[k])*t*t+(-p[k]+3*a[k]-3*b[k]+q[k])*t*t*t)
                out.append(max(min(a[k],b[k]),min(max(a[k],b[k]),value)))
            return out
    return CONTROL[-1][1:]

def point(y,angle,offset=0):
    w,lo,hi=section(y);co=math.cos(angle);si=math.sin(angle)
    x=w*math.copysign(abs(co)**.5,co)
    z=(lo+hi)/2+(hi-lo)/2*math.copysign(abs(si)**.5,si)
    return (x+offset*math.copysign(1,x),y,z+offset*max(0,si))

def side_x(y,z,side):
    w,lo,hi=section(y);n=(z-(hi+lo)/2)/((hi-lo)/2)
    return side*(w*max(0,1-min(.9999,abs(n))**4)**.25+.012)

def mesh(name,verts,faces,mat,root,smooth=False):
    ob=F.mesh(name,verts,faces,mat,root)
    import bmesh
    bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
    for p in ob.data.polygons:p.use_smooth=smooth
    return ob

def build(root,m):
    T.bogies(root,9.,m)
    ys=[-4.5+i*2.75/14 for i in range(15)]+[-1.5,0,1.5,3.,4.5]
    n=24
    verts=[point(y,2*math.pi*j/n) for y in ys for j in range(n)]
    faces=[tuple(reversed(range(n))),tuple((len(ys)-1)*n+j for j in range(n))]
    faces += [(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(ys)-1) for j in range(n)]
    body=mesh('StreamlinedMonocoque',verts,faces,m['Cream'],root,True)
    body['design']='continuous low nose, no separate cabin/hood/bumper; integral lower skirt'
    # Narrow continuous teal band follows the actual curved shell, both sides.
    for side in [-1,1]:
        band=[]
        for y in ys:
            w,lo,hi=section(y);middle=lo+.486*(hi-lo);thickness=.21*min(1,(hi-lo)/2)
            for z in [middle-thickness/2,middle+thickness/2]:band.append((side_x(y,z,side),y,z))
        mesh('ContinuousSideBand',band,[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(ys)-1)],m['Paint'],root,True)
    # Low, wrapped front windscreen laid directly onto the nose surface.
    for name,y0,y1,a0,a1,mat,offset in [
        ('WindscreenSeal',-3.24,-2.69,52,128,m['Dark'],.012),
        ('LowWrapWindscreen',-3.20,-2.73,56,124,m['Glass'],.024)]:
        rows=5;cols=9
        v=[point(y0+(y1-y0)*i/(rows-1),math.radians(a0+(a1-a0)*j/(cols-1)),offset) for i in range(rows) for j in range(cols)]
        mesh(name,v,[(i*cols+j,i*cols+j+1,(i+1)*cols+j+1,(i+1)*cols+j) for i in range(rows-1) for j in range(cols-1)],mat,root,True)
    for side in [-1,1]:
        v=[]
        for y in [-2.43,-2.12,-1.80,-1.48]:
            w,lo,hi=section(y)
            for z in [hi-.80,hi-.42]:v.append((side_x(y,z,side)+side*.008,y,z))
        mesh('DriverSideRibbonGlass',v,[(i*2,i*2+1,i*2+3,i*2+2) for i in range(3)],m['Glass'],root,True)
        # Low service seam and a flush handle, not a projecting truck door/cab.
        y=-.85
        for yy in [y-.34,y+.34]:
            v=[(side_x(yy,z,side),yy,z) for z in [1.35,2.9]]
            T.tube('FlushDoorSeam',v,.0015,m['Metal'],root,segments=4)
        F.box('FlushHandle',(.02,.16,.035),(side*1.485,y-.15,2.0),m['Metal'],root,.004)
    F.box('InternalFloor',(2.4,6.,.18),(0,1.4,1.12),m['Dark'],root)
    # Matching coach doorway and rear band datum, without changing the coach source.
    F.box('RearGangway',(1.05,.06,1.98),(0,4.47,2.37),m['Dark'],root)
    F.box('RearGangwayDoor',(.76,.07,1.72),(0,4.465,2.39),m['Metal'],root)
    F.box('RearGangwayGlass',(.52,.075,.55),(0,4.4625,2.81),m['Glass'],root)
    # One shallow folded pantograph. Overall top is exactly 3.80m.
    F.box('PantographBase',(.90,1.25,.04),(0,2.45,3.67),m['Metal'],root,.01)
    for side in [-1,1]:
        T.tube('LowPantographArm',[(side*.32,1.95,3.69),(side*.32,2.42,3.77),(side*.32,2.92,3.69)],.012,m['Dark'],root,segments=6)
    F.box('PantographContactBar',(1.24,.10,.04),(0,2.42,3.78),m['Metal'],root,.006)
    # Nose lights follow the low nose skin; no bumper or discrete bonnet.
    for side in [-1,1]:
        y=-4.11;w,lo,hi=section(y);z=lo+.55*(hi-lo)
        F.box('NoseLight',(.045,.21,.065),(side_x(y,z,side),y,z),m['Head'],root,.012)
    C.update()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output-root',type=Path,default=ROOT);args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    out=args.output_root;ident='train-loco-01';source=out/'assets/vehicle-fleet'/ident/'v2'
    if source.exists():raise RuntimeError('Protected v2 source exists: '+str(source))
    C.reset_scene();bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
    root=C.empty('VehicleRoot');root['asset_id']=ident;root['forwardGltf']=[0.,0.,1.];root['units']='metres';root['version']='v2-high-speed'
    m={k:F.material(k,c,.25 if k=='Metal' else 0) for k,c in {'Paint':'527e83','Cream':'dedbd0','Glass':'294453','Dark':'30383b','Metal':'9ba9ab','Head':'e8d69d','Tail':'c95343'}.items()}
    build(root,m);tri,lo,hi=T.measure();dims=[hi[1]-lo[1],hi[0]-lo[0],hi[2]-lo[2]]
    assert 2000<=tri<=5000,(tri,dims)
    assert all(abs(a-b)<.001 for a,b in zip(dims,[10,3,3.8])) and abs(lo[2])<.001,(lo,hi)
    source.mkdir(parents=True);game=out/'cities_do/assets/vehicles';game.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(game/'train-loco-01-v2.glb'),export_format='GLB',export_extras=True,export_yup=True,export_animations=False)
    ppm=F.render_views(game/'sprites/train-loco-01-v2',10,3,3.8);shutil.copy2(game/'sprites/train-loco-01-v2/045.png',source/'preview.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(source/'vehicle.blend'),compress=True)
    spec=json.loads((ROOT/'assets/vehicle-fleet/train-loco-01/spec.json').read_text(encoding='utf-8'))
    spec.update({'name':'고속열차 선두차','style':'high_speed_streamlined_v2','height_m':3.8,'measured_dimensions_lwh_m':[round(v,5) for v in dims],'triangles':tri,
        'model':'res://assets/vehicles/train-loco-01-v2.glb','preview':'res://assets/vehicles/sprites/train-loco-01-v2/045.png','source':'assets/vehicle-fleet/train-loco-01/v2/vehicle.blend',
        'reproduce':'blender -b --factory-startup -t 2 --python-exit-code 1 -P tools/build_transit_loco_v2.py -- --output-root <new-empty-workspace>',
        'rear_interface':{'width_m':3,'gangway_centre_z_m':2.37,'band_centre_z_m':1.86,'roof_m':3.66,'coach_roof_m':4.0,'note':'same width, rounded profile, gangway and palette; lower roof preserves requested 3.8m overall height'},'supersedes':'train-loco-01 v1, originals retained'})
    F.write_json(source/'spec.json',spec)
    (source/'build.py').write_text('import runpy\nfrom pathlib import Path\nroot=Path(__file__).resolve().parents[4]\nrunpy.run_path(str(root/"tools/build_transit_loco_v2.py"),run_name="__main__")\n',encoding='utf-8')
    for filename,key,row in [('catalog.json','vehicles',spec),('render_manifest.json','vehicles',{'id':ident,'pixels_per_metre':ppm,'angles_deg':list(range(0,360,45))})]:
        p=game/filename;doc=json.loads(p.read_text(encoding='utf-8')) if p.exists() else {'vehicles':[]};doc[key]=[row if e['id']==ident else e for e in doc[key]] if any(e['id']==ident for e in doc[key]) else doc[key]+[row];F.write_json(p,doc)
    print('LOCO_V2_BUILT',dims,'TRIANGLES',tri,flush=True)
if __name__=='__main__':main()
