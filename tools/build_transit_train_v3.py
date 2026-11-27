"""Original rail v3: long thin wedge lead car and matching ribbon-window coaches.
Blender 4.3.2. Existing v1/v2 sources are read-only; use --output-root for replay.
"""
import argparse
import json
import math
from pathlib import Path
import shutil
import sys
import bpy
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_transit_loco_v2 as V
T=V.T;F=V.F;C=V.C
ROWS=[('train-loco-01',9.,'고속열차 선두차 v3'),('train-passenger-01',10.,'고속열차 객차 v3')]


def section(y,lead):
    if lead and y<0:
        t=max(0,min(1,(y+4.5)/4.5))
        return .60+.876*t**.8, .16+.56*max(0,(-y-3.7)/.8), 1.02+2.78*t
    end=4.5 if lead else 5.
    t=max(0,min(1,(abs(y)-(end-.25))/.25))
    return 1.476-.076*t*t,.16+.08*t*t,3.8-.08*t*t


def point(y,a,lead,offset=0):
    w,lo,hi=section(y,lead);co=math.cos(a);si=math.sin(a)
    x=w*math.copysign(abs(co)**.5,co);z=(lo+hi)/2+(hi-lo)/2*math.copysign(abs(si)**.5,si)
    if lead and 1.6<=y<=3.2 and z>3.6 and abs(x)<.9:
        z-=.18*(1-(abs(x)/.9)**4)
    return (x+offset*math.copysign(1,x),y,z+offset*max(0,si))


def surface_x(y,z,side,lead,offset):
    w,lo,hi=section(y,lead);n=(z-(lo+hi)/2)/((hi-lo)/2)
    return side*(w*max(0,1-min(.9999,abs(n))**4)**.25+offset)


def patch(name,ys,zs,side,lead,offset,mat,root):
    v=[(surface_x(y,z,side,lead,offset),y,z) for y in ys for z in zs]
    n=len(zs)
    return V.mesh(name,v,[(i*n+j,i*n+j+1,(i+1)*n+j+1,(i+1)*n+j) for i in range(len(ys)-1) for j in range(n-1)],mat,root,True)


def shell(root,m,L,lead):
    T.bogies(root,L,m)
    if lead:
        # Keep the front bogie behind the narrowed wedge instead of protruding
        # through its skirt; only the rail-contact wheel bottoms remain visible.
        bpy.data.objects['Bogie_0'].location.y += 1.30
        C.update()
    if lead:ys=[-4.5+i*4.5/18 for i in range(19)]+[.5,1.5,1.8,2.2,2.6,3.,3.2,3.5,4.25,4.5]
    else:ys=[-5.,-4.9,-4.75,-4.,-3.,-2.,-1.,0.,1.,2.,3.,4.,4.75,4.9,5.]
    n=24;verts=[point(y,2*math.pi*j/n,lead) for y in ys for j in range(n)]
    faces=[tuple(reversed(range(n))),tuple((len(ys)-1)*n+j for j in range(n))]
    faces += [(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(ys)-1) for j in range(n)]
    body=V.mesh('LongWedgeShell' if lead else 'RoundedSkirtedCoachShell',verts,faces,m['Cream'],root,True)
    body['design']='v3: thin 4.5m wedge nose' if lead else 'v3: uninterrupted ribbon glass, shared 3.8m roof, integral skirt'
    for side in [-1,1]:
        v=[]
        for y in ys:
            w,lo,hi=section(y,lead)
            center=1.86 if not lead or y>=0 else lo+.467*(hi-lo)
            half=.105*min(1,(hi-lo)/2)
            for z in [center-half,center+half]:v.append((surface_x(y,z,side,lead,.024),y,z))
        V.mesh('ContinuousTealBand',v,[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(ys)-1)],m['Paint'],root,True)
    F.box('InternalFloor',(2.3,L-2.,.18),(0,.4 if lead else 0,1.12),m['Dark'],root)
    for sign in ([1] if lead else [-1,1]):
        y=sign*(L/2-.03)
        F.box('EndGangway',(1.05,.06,1.98),(0,y,2.37),m['Dark'],root)
        F.box('GangwayDoor',(.76,.07,1.72),(0,sign*(L/2-.035),2.39),m['Metal'],root)
        F.box('GangwayGlass',(.52,.075,.55),(0,sign*(L/2-.0375),2.81),m['Glass'],root)


def lead_detail(root,m):
    for name,y0,y1,a0,a1,mat,offset in [
        ('LaidBackWindscreenSeal',-2.44,-.43,57,123,m['Dark'],.012),
        ('LongLowWindscreen',-2.38,-.50,61,119,m['Glass'],.024)]:
        nr=9;nc=9
        v=[point(y0+(y1-y0)*i/(nr-1),math.radians(a0+(a1-a0)*j/(nc-1)),True,offset) for i in range(nr) for j in range(nc)]
        V.mesh(name,v,[(i*nc+j,i*nc+j+1,(i+1)*nc+j+1,(i+1)*nc+j) for i in range(nr-1) for j in range(nc-1)],mat,root,True)
    for side in [-1,1]:
        patch('DriverRibbonGlass',[-.25,.15,.55,.95],[2.90,3.09,3.28],side,True,.024,m['Glass'],root)
        patch('FlushServiceDoor',[1.20,1.54,1.88],[1.35,1.73,2.11,2.49,2.87,3.24],side,True,.012,m['Paint'],root)
    F.box('RecessedPantographBase',(.90,1.20,.04),(0,2.4,3.65),m['Metal'],root,.01)
    for side in [-1,1]:T.tube('LowPantographArm',[(side*.32,1.86,3.67),(side*.32,2.40,3.77),(side*.32,2.98,3.67)],.012,m['Dark'],root,segments=6)
    F.box('PantographContactBar',(1.24,.10,.04),(0,2.40,3.78),m['Metal'],root,.006)
    for side in [-1,1]:
        y=-4.22;w,lo,hi=section(y,True);z=lo+.5*(hi-lo)
        F.box('FlushNoseLight',(.035,.23,.05),(surface_x(y,z,side,True,.015),y,z),m['Head'],root,.01)


def coach_detail(root,m):
    for side in [-1,1]:
        # A single continuous dark ribbon, interrupted only by the two doors.
        patch('ContinuousWindowSeal',[-3.62+i*7.24/16 for i in range(17)],[2.45,2.66,2.88,3.09,3.30],side,False,.012,m['Dark'],root)
        patch('ContinuousRibbonGlass',[-3.55+i*7.10/16 for i in range(17)],[2.52,2.70,2.88,3.06,3.23],side,False,.025,m['Glass'],root)
        for y in [-4.18,4.18]:
            patch('PassengerDoor',[y-.49,y,y+.49],[1.35,1.73,2.11,2.49,2.87,3.28],side,False,.014,m['Paint'],root)
            patch('DoorGlass',[y-.36,y+.36],[2.53,2.75,2.96,3.18],side,False,.025,m['Glass'],root)
            F.box('DoorHandle',(.025,.14,.035),(side*1.48,y+.26,2.16),m['Metal'],root,.003)
            F.box('BoardingStep',(.17,1.08,.08),(side*1.39,y,1.15),m['Metal'],root,.01)


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output-root',type=Path,default=ROOT);ap.add_argument('--only',choices=[r[0] for r in ROWS]);args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    out=args.output_root;entries=[];renders=[]
    for ident,L,name in ROWS:
        if args.only and ident!=args.only:continue
        lead=ident=='train-loco-01';source=out/'assets/vehicle-fleet'/ident/'v3'
        if source.exists():raise RuntimeError('Protected v3 source exists: '+str(source))
        C.reset_scene();bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
        root=C.empty('VehicleRoot');root['asset_id']=ident;root['forwardGltf']=[0.,0.,1.];root['units']='metres';root['version']='v3-matched-high-speed'
        m={k:F.material(k,c,.25 if k=='Metal' else 0) for k,c in {'Paint':'527e83','Cream':'dedbd0','Glass':'294453','Dark':'30383b','Metal':'9ba9ab','Head':'e8d69d','Tail':'c95343'}.items()}
        shell(root,m,L,lead);(lead_detail if lead else coach_detail)(root,m);C.update();tri,lo,hi=T.measure();dims=[hi[1]-lo[1],hi[0]-lo[0],hi[2]-lo[2]]
        assert 2000<=tri<=5000,(ident,tri,dims)
        assert all(abs(a-b)<.001 for a,b in zip(dims,[L+1,3,3.8])) and abs(lo[2])<.001,(ident,lo,hi)
        source.mkdir(parents=True);game=out/'cities_do/assets/vehicles';game.mkdir(parents=True,exist_ok=True)
        bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(game/(ident+'-v3.glb')),export_format='GLB',export_extras=True,export_yup=True,export_animations=False)
        ppm=F.render_views(game/'sprites'/(ident+'-v3'),L+1,3,3.8);shutil.copy2(game/'sprites'/(ident+'-v3')/'045.png',source/'preview.png')
        bpy.ops.wm.save_as_mainfile(filepath=str(source/'vehicle.blend'),compress=True)
        spec=json.loads((ROOT/'assets/vehicle-fleet'/ident/'v2/spec.json').read_text(encoding='utf-8'))
        spec.update({'name':name,'style':'matched_high_speed_v3','height_m':3.8,'measured_dimensions_lwh_m':[round(v,5) for v in dims],'triangles':tri,
            'model':'res://assets/vehicles/'+ident+'-v3.glb','preview':'res://assets/vehicles/sprites/'+ident+'-v3/045.png','source':'assets/vehicle-fleet/'+ident+'/v3/vehicle.blend',
            'reproduce':'blender -b --factory-startup -t 2 --python-exit-code 1 -P tools/build_transit_train_v3.py -- --only '+ident+' --output-root <new-empty-workspace>',
            'interface_v3':{'roof_m':3.8,'body_envelope_width_m':3,'end_roof_m':3.72,'end_width_m':2.8,'band_centre_z_m':1.86,'gangway_centre_z_m':2.37},'supersedes':ident+' v1/v2 retained'})
        spec.pop('rear_interface',None)
        if lead:spec.update({'nose_length_m':4.5,'nose_tip_height_m':1.02,'nose_tip_width_m':1.2,'pantograph':'one low unit within roof recess, max z=3.8m'})
        F.write_json(source/'spec.json',spec)
        (source/'build.py').write_text('import runpy,sys\nfrom pathlib import Path\nroot=Path(__file__).resolve().parents[4]\nsys.argv=[sys.argv[0],"--","--only","'+ident+'"]+sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [sys.argv[0],"--","--only","'+ident+'"]\nrunpy.run_path(str(root/"tools/build_transit_train_v3.py"),run_name="__main__")\n',encoding='utf-8')
        entries.append(spec);renders.append({'id':ident,'pixels_per_metre':ppm,'angles_deg':list(range(0,360,45))})
        print('TRAIN_V3_BUILT',ident,[round(v,5) for v in dims],'TRIANGLES',tri,flush=True)
    for filename,key,rows in [('catalog.json','vehicles',entries),('render_manifest.json','vehicles',renders)]:
        p=out/'cities_do/assets/vehicles'/filename;doc=json.loads(p.read_text(encoding='utf-8')) if p.exists() else {'vehicles':[]};replacements={r['id']:r for r in rows};ids={r['id'] for r in doc[key]};doc[key]=[replacements.get(e['id'],e) for e in doc[key]]+[e for e in rows if e['id'] not in ids];F.write_json(p,doc)
if __name__=='__main__':main()
