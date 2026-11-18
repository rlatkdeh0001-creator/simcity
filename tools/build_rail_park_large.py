"""Original 32m park. Blender4.3.2; protected outputs, no external art."""
import argparse,json,math,shutil,sys
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_transit_roadside as R
import build_transit_subway as S
import build_transit_vehicles as T
B=R.B;C=R.C

def box(n,size,p,m):return R.box(n,size,p,m,0)
def cylinder(n,p,r,h,m,segments=20):return B.cylinder(n,r,h,p,R.M[m],R.root,axis='Z',segments=segments)
def oval(n,rx,ry,z,m,inner=None):
    count=64
    if inner:
        verts=[(a*math.cos(i*math.tau/count),b*math.sin(i*math.tau/count),z) for a,b in [(rx,ry),inner] for i in range(count)]
        faces=[(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    else:
        verts=[(0,0,z)]+[(rx*math.cos(i*math.tau/count),ry*math.sin(i*math.tau/count),z) for i in range(count)]
        faces=[(0,i+1,(i+1)%count+1) for i in range(count)]
    return B.mesh(n,verts,faces,R.M[m],R.root)
def tree(x,y,index):
    height=4.5+(index%4)*.28
    cylinder('TreeTrunk',(x,y,.28+height*.40),.15,height*.80,'wood',10)
    for dx,dy,dz,r in [(-.45,0,-.15,1.05),(.45,.1,0,1.12),(0,0,.85,.98)]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=r,location=(x+dx,y+dy,height+dz))
        ob=bpy.context.object;ob.name='TreeCrown';B.finish(ob,R.M['leaf' if index%3 else 'leaf_light'],R.root)
def bench(x,y,angle):
    before=set(bpy.context.scene.objects)
    for dy in [-.2,0,.2]:box('BenchSeat',(1.8,.15,.09),(x,y+dy,.79),'wood')
    box('BenchBack',(1.8,.10,.48),(x,y+.29,1.08),'wood')
    for dx in [-.65,.65]:box('BenchLeg',(.10,.55,.46),(x+dx,y,.51),'metal')
    from mathutils import Matrix
    mat=Matrix.Translation(Vector((x,y,0)))@Matrix.Rotation(angle,4,'Z')@Matrix.Translation(Vector((-x,-y,0)))
    for ob in set(bpy.context.scene.objects)-before:ob.data.transform(mat)
def gazebo():
    x,y=-10,8.4
    cylinder('GazeboFoundation',(x,y,.40),3,.24,'curb',8)
    cylinder('GazeboDeck',(x,y,.55),2.8,.08,'wood',8)
    for i in range(8):
        a=i*math.tau/8
        cylinder('GazeboPost',(x+2.4*math.cos(a),y+2.4*math.sin(a),1.94),.10,2.7,'wood',8)
    verts=[(x,y,4.35)]+[(x+3.05*math.cos(i*math.tau/8),y+3.05*math.sin(i*math.tau/8),3.18) for i in range(8)]+[(x,y,3.18)]
    faces=[(0,i+1,(i+1)%8+1) for i in range(8)]+[(9,(i+1)%8+1,i+1) for i in range(8)]
    B.mesh('GazeboRoof',verts,faces,R.M['roof'],R.root)
    box('GazeboEntryStep',(2.4,1.0,.16),(x,y-2.7,.36),'curb')
def main():
    p=argparse.ArgumentParser();p.add_argument('--output-root',type=Path,default=ROOT);out=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []).output_root
    ident='park-large-8x8';folder=out/'assets/facilities'/ident
    if folder.exists():raise RuntimeError('Protected output exists: '+str(folder))
    C.reset_scene();bpy.context.preferences.filepaths.save_version=0
    bpy.context.scene.unit_settings.system='METRIC';R.root=C.empty('LargeParkRoot');R.root['frontGltf']=[0,0,1]
    palette={'curb':'c8cbc3','grass':'8c9b75','leaf':'6f895c','leaf_light':'809769','wood':'aa8059','metal':'344b53','paving':'ded6bf','water':'73aeb8','roof':'526b70'}
    R.M={k:B.material(k,v) for k,v in palette.items()}
    box('ContinuousSolidLotBase',(32,32,.18),(0,0,.09),'curb')
    box('ContinuousLawn',(31.6,31.6,.10),(0,0,.23),'grass')
    oval('LoopWalk',9.4,7.6,.304,'paving',(7.8,6.0))
    oval('PondStoneEdge',6.6,4.8,.309,'curb');oval('ShallowPondSurface',6.28,4.48,.315,'water')
    # All four arms meet the annular walk and the four lot edges.
    for sign in [-1,1]:
        box('SideEntranceWalk',(8.2,1.8,.028),(sign*11.9,0,.294),'paving')
        box('FrontRearEntranceWalk',(1.8,10.0,.028),(0,sign*11,.294),'paving')
    box('FrontEntryPlaza',(8,4,.034),(0,-14,.297),'paving')
    box('GazeboAccess',(3.0,4.0,.028),(-10,5.7,.294),'paving')
    positions=[(x,y) for x in [-13.6,-9,-4.5,4.5,9,13.6] for y in [-12,12]]
    positions += [(x,y) for x in [-13.6,13.6] for y in [-7,-3.5,3.5,7]]
    positions += [(-6,9.4),(5.3,9.5),(-6,-9.5),(6,-9.5)]
    for i,(x,y) in enumerate(positions):tree(x,y,i)
    for x,y,a in [(-5,-7.0,0),(5,-7.0,0),(-4,7.1,math.pi),(4,7.1,math.pi),(-9.0,2,-math.pi/2),(9.,-2,math.pi/2)]:bench(x,y,a)
    gazebo();C.update();tri,lo,hi=T.measure()
    assert 6000<=tri<=15000,(tri,lo,hi)
    assert all(abs(a-b)<.001 for a,b in zip(lo[:2],[-16,-16])) and all(abs(a-b)<.001 for a,b in zip(hi[:2],[16,16]))
    assert abs(lo[2])<.001 and len(positions)==24
    folder.mkdir(parents=True);game=out/'cities_do/assets/facilities';game.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(game/(ident+'.glb')),export_format='GLB',export_extras=True,export_animations=False)
    info=S.studio(folder/'preview.png',lo,hi);shutil.copy2(folder/'preview.png',game/(ident+'.png'))
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'facility.blend'),compress=True)
    spec={'id':ident,'name':'대형 공원','kind':'park','style':'large_pond','width':8,'depth':8,'metres':[32,32],'height_m':round(hi[2],4),'triangles':tri,'tree_count':24,'gazebo_count':1,'bench_count':6,'capacity':0,'status':'inspection_only','source':'assets/facilities/'+ident+'/facility.blend','model':'res://assets/facilities/'+ident+'.glb','preview':'res://assets/facilities/'+ident+'.png','render':info,'origin':'lot centre at ground z=0','frame_blender':{'front':'-Y','up':'+Z'},'frame_gltf':{'front':'+Z','up':'+Y'},'pond_surface_m':.315,'continuous_lawn_surface_m':.28,'pond_is_shallow_overlay_not_hole':True,'entrance_edges':['front','rear','left','right'],'palette':palette,'bounds_blender_m':{'min':list(lo),'max':list(hi)},'map_placement_implemented':False}
    B.write_json(folder/'spec.json',spec)
    (folder/'build.py').write_text('import runpy\nfrom pathlib import Path\nrunpy.run_path(str(Path(__file__).resolve().parents[3]/"tools/build_rail_park_large.py"),run_name="__main__")\n',encoding='utf-8')
    catalog=game/'catalog.json';doc=json.loads(catalog.read_text(encoding='utf-8')) if catalog.exists() else {'facilities':[]}
    assert not any(e['id']==ident for e in doc['facilities']);doc['facilities'].append(spec);B.write_json(catalog,doc)
    print('LARGE_PARK_BUILT',tri,lo,hi,flush=True)
if __name__=='__main__':main()
