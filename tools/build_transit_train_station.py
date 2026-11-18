"""Original train station: approved 32x24m, two-storey wings, tall glass atrium,
front drop-off plaza and 32m rear platform. No track/vehicle is baked into the asset.
Blender4.3.2. Use --output-root NEW_EMPTY_WORKSPACE to preserve delivered sources.
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
import build_transit_roadside as R
import build_transit_subway as S
import build_transit_vehicles as T
B=R.B;C=R.C


def box(name,size,pos,mat,bevel=.025):return R.box(name,size,pos,mat,bevel)

def stroke(name,points,r=.025,mat='metal'):return T.tube(name,points,r,R.M[mat],R.root,segments=8)

def floor_line(name,x,y,length,width=.06,color='paint'):
    return box(name,(length,width,.008),(x,y,.154),color,0)


def dropoff():
    box('WholeLotBase',(32,24,.12),(0,0,.06),'paving',.01)
    box('DropOffAsphalt',(32,6.7,.02),(0,-8.65,.13),'asphalt',0)
    box('FrontPedestrianPlaza',(30,1.5,.10),(0,-5.35,.17),'paving',.02)
    for x in [-6.5,1.0,8.5]:
        for y in [-8.45,-6.15]:floor_line('DropoffBayLine',x,y,5.6)
        for dx in [-2.8,2.8]:box('DropoffBayEnd',(.06,2.3,.008),(x+dx,-7.3,.154),'paint',0)
    for x in [-12,-6,0,6,12]:
        floor_line('OneWayArrowStem',x,-10.25,1.15,.13)
        B.mesh('OneWayArrowHead',[(x-.98,-10.25,.154),(x-.30,-10.60,.154),(x-.30,-9.90,.154)],[(0,1,2)],R.M['paint'],R.root)
    for x in [-13.6,13.6]:
        for dx in [-1.8,1.8]:box('FrontEntryExit',(.08,1.7,.008),(x+dx,-11.13,.154),'paint',0)
    for x in [-13.6,13.6]:
        for i in range(4):box('PedestrianCrossing',(.24,1.45,.008),(x-1.0+i*.65,-7.3,.155),'paint',0)
    for x in [-10.8,-7.2,7.2,10.8]:R.bench(x,-5.40,1.8)
    for x in [-14.4,14.4]:
        for y in [-2.4,4.5]:
            box('Planter',(.95,1.7,.55),(x,y,.395),'concrete',.04)
            box('PlantBed',(.80,1.55,.12),(x,y,.71),'green',.025)
            for dy in [-.4,0,.4]:
                bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.36,location=(x,y+dy,.95))
                B.finish(bpy.context.object,R.M['green'],R.root)
    for x in [-14.6,14.6]:
        box('PlazaLampPost',(.12,.12,3.4),(x,-5.2,1.82),'metal')
        box('PlazaLight',(.42,.42,.14),(x,-5.2,3.58),'cream')


def wing(side):
    x=side*9.0
    box('TwoStoreyWing',(8.0,11.6,7.2),(x,1.4,3.9),'cream',.07)
    box('WingRoof',(8.4,12.,.20),(x,1.4,7.62),'roof',.04)
    for z in [.48,3.84,7.36]:
        for y in [-4.43,7.23]:box('WingCornice',(8.10,.12,.15),(x,y,z),'concrete',0)
    for face in [-1,1]:
        y=-4.445 if face<0 else 7.245
        for dx in [-2.85,-.95,.95,2.85]:
            for z in [2.10,5.55]:
                box('WingWindow',(1.55,.035,2.0),(x+dx,y,z),'window',.035)
                for zz in [z-1.04,z+1.04]:box('WindowLintel',(1.65,.08,.08),(x+dx,y+face*.025,zz),'metal',0)
                box('WindowMullion',(.055,.06,1.94),(x+dx,y+face*.03,z),'metal',0)
    for y in [-3.0,-.2,2.6,5.4]:
        for z in [2.10,5.55]:
            box('OuterSideWindow',(.04,2.0,2.0),(side*13.025,y,z),'window',.03)
            for zz in [z-1.04,z+1.04]:box('SideLintel',(.08,2.1,.08),(side*13.05,y,zz),'metal',0)
    for dx in [-3.8,-1.9,0,1.9,3.8]:
        for y in [-4.47,7.27]:box('FacadePilaster',(.14,.18,7.0),(x+dx,y,3.9),'concrete',0)
    box('WingBackExit',(1.45,.06,2.7),(side*7.2,7.30,1.65),'window',.025)
    box('ExitCanopy',(2.1,.75,.15),(side*7.2,7.55,3.10),'accent')
    for y in [1.4,4.5]:
        box('RoofPlant',(2.0,1.4,.55),(x,y,8.0),'metal',.035)
        for dx in [-.65,0,.65]:box('RoofLouvre',(.13,1.24,.055),(x+dx,y,8.30),'concrete',.01)


def atrium():
    box('AtriumFloor',(10.2,12.,.18),(0,1.1,.21),'paving')
    for x in [-4.95,-2.5,0,2.5,4.95]:box('AtriumFrontColumn',(.15,.20,9.3),(x,-4.85,4.95),'metal',0)
    for z in [3.35,6.45,9.45]:box('AtriumFrontBeam',(10.1,.20,.14),(0,-4.85,z),'metal')
    for x in [-3.72,-1.25,1.25,3.72]:
        for i,z in enumerate([1.83,4.92,8.02]):
            if i==0 and abs(x)<2:continue
            box('AtriumFrontGlass',(2.30,.025,2.94),(x,-4.865,z),'glass',0)
    # Actual open central entrance with two sliding-door leaves, no opaque glass block.
    for x in [-.82,.82]:box('MainEntryDoor',(1.58,.04,2.85),(x,-4.99,1.755),'window',.02)
    for x in [-1.66,0,1.66]:box('MainDoorFrame',(.065,.08,2.94),(x,-5.0,1.77),'metal')
    for i in range(2):
        top=.22+(i+1)*.04
        box('MainEntryStep',(8.8,.22,top-.12),(0,-5.34+i*.22,(top+.12)/2),'concrete',.01)
    for side in [-1,1]:
        for y in [-3.8,-1.2,1.4,4.,6.6]:
            box('AtriumSideColumn',(.14,.14,9.3),(side*5.0,y,4.95),'metal',0)
        box('AtriumSideUpperGlass',(.03,11.35,1.80),(side*5.015,1.2,8.52),'glass',0)
        box('UpperGallery',(1.7,10.8,.18),(side*4.05,1.2,3.92),'paving')
        for y in [-3.6,-1.,1.6,4.2,6.5]:box('GalleryBaluster',(.065,.065,1.1),(side*3.2,y,4.56),'metal',0)
        box('GalleryHandrail',(.065,10.4,.065),(side*3.2,1.3,5.10),'metal',0)
    # Central gabled glass atrium, low-polygon authored roof panels.
    for side in [-1,1]:
        B.mesh('AtriumGlassRoof',[(0,-5.0,10.5),(side*5.35,-5.0,9.5),(side*5.35,7.15,9.5),(0,7.15,10.5)],[(0,1,2,3)] if side>0 else [(3,2,1,0)],R.M['glass'],R.root)
    for y in [-5.,-3.,-1.,1.,3.,5.,7.15]:
        stroke('AtriumRoofRib',[(-5.35,y,9.5),(0,y,10.5),(5.35,y,9.5)],.05)
    box('AtriumRidge',(.12,12.25,.12),(0,1.075,10.50),'metal')
    # Upper-floor access staircase and ticket desks visible through the atrium.
    for i in range(18):
        top=.30+(i+1)*.20
        box('InteriorStair',(1.60,.30,top-.30),(-3.85,-3.6+(i+.5)*.30,(top+.30)/2),'concrete',.01)
    for x in [-2.0,2.0]:
        box('TicketCounter',(2.2,.90,1.1),(x,3.9,.85),'accent')
        box('TicketDeskTop',(2.35,1.0,.10),(x,3.9,1.45),'paving')
        box('TicketWindow',(1.6,.08,1.1),(x,4.20,2.05),'glass')
    # Clock and generic station lettering; no real brand or city name.
    B.cylinder('StationClock',.76,.12,(0,-5.04,8.05),R.M['cream'],R.root,axis='Y',segments=32)
    for i in range(12):
        a=i*math.pi/6
        box('ClockHourMark',(.055,.025,.07),(math.sin(a)*.62,-5.115,8.05+math.cos(a)*.62),'metal',0)
    stroke('ClockMinuteHand',[(0,-5.14,8.05),(0,-5.14,8.57)],.023)
    stroke('ClockHourHand',[(0,-5.145,8.05),(-.32,-5.145,8.25)],.03)
    box('StationNameBoard',(5.1,.10,.90),(0,-5.015,5.55),'accent')
    R.text('STATION',0,-5.075,5.28,.57)
    # Rear circulation doorway leads to the raised platform stairs.
    box('RearExitPortal',(3.0,.12,3.10),(0,7.13,1.85),'window')


def platform():
    box('RearPlatform32m',(32,4.,.98),(0,10.,.61),'concrete',.025)
    box('PlatformPaving',(32,4.,.06),(0,10.,1.07),'paving',.012)
    box('PlatformSafetyEdge',(32,.16,.012),(0,11.78,1.112),'yellow',0)
    for x in [-7.2,0,7.2]:
        for i in range(4):
            top=.30+(i+1)*.20
            box('PlatformAccessStep',(2.3,.20,top-.12),(x,7.2+(i+.5)*.20,(top+.12)/2),'concrete',.01)
    R.canopy(0,10.,32.,4.,4.72)
    for x in [-12,-8,-4,0,4,8,12]:
        for y in [8.24,11.76]:
            box('PlatformCanopySupport',(.14,.14,3.62),(x,y,2.91),'metal',0)
            box('PlatformColumnFoot',(.26,.26,.10),(x,y,1.15),'metal',0)
    for x in [-12,-7,-2,3,8,13]:R.bench(x,9.75,1.8)
    # Existing bench helper ground datum is .1; lift platform furniture only.
    for ob in list(bpy.context.scene.objects):
        if ob.type=='MESH' and ob.name.startswith('Bench'):
            # Only newly created platform benches are behind the building.
            center=sum((v.co for v in ob.data.vertices),Vector())/len(ob.data.vertices)
            if center.y>8:ob.location.z+=.98
    for x in [-14.4,14.4]:
        box('PlatformSignPole',(.10,.10,2.8),(x,10.0,2.5),'metal')
        box('PlatformSign',(1.25,.14,.60),(x,10.0,3.65),'accent')
    # Rails deliberately excluded. The inspection fixture supplies track context only.


def build():
    dropoff();wing(-1);wing(1);atrium();platform()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output-root',type=Path,default=ROOT);args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    out=args.output_root;folder=out/'assets/facilities/train-station-01'
    if folder.exists():raise RuntimeError('Protected source exists: '+str(folder))
    C.reset_scene();bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
    R.root=C.empty('TrainStationRoot');R.root['asset_id']='train-station-01';R.root['frontGltf']=[0.,0.,1.]
    R.M={k:B.material(k,c,.2 if k=='metal' else 0) for k,c in {'paving':'ded6bf','asphalt':'4c5659','paint':'e8e7dc','yellow':'e4bd5f','concrete':'bdc5c1','metal':'344b53','cream':'e2dcc8','accent':'507c89','roof':'526b70','glass':'91b1b9','window':'294453','green':'718c67','wood':'aa8059'}.items()}
    R.M['glass'].diffuse_color=(*R.M['glass'].diffuse_color[:3],.32);R.M['glass'].node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value=.32;R.M['glass'].surface_render_method='DITHERED'
    build();C.update();tri,lo,hi=T.measure()
    assert 6000<=tri<=15000,(tri,lo,hi)
    assert abs(hi[0]-lo[0]-32)<.001 and abs(hi[1]-lo[1]-24)<.001 and abs(lo[2])<.001,(lo,hi)
    folder.mkdir(parents=True);game=out/'cities_do/assets/facilities';game.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(game/'train-station-01.glb'),export_format='GLB',export_extras=True,export_animations=False)
    info=S.studio(folder/'preview.png',lo,hi);shutil.copy2(folder/'preview.png',game/'train-station-01.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'facility.blend'),compress=True)
    spec={'id':'train-station-01','name':'기차역','kind':'transit_rail_station','width':8,'depth':6,'metres':[32,24],'storeys':2,'capacity':None,'capacity_status':'no passenger throughput proposal','height_m':round(hi[2],4),'width_m':32,'length_m':24,'triangles':tri,
        'model':'res://assets/facilities/train-station-01.glb','preview':'res://assets/facilities/train-station-01.png','source':'assets/facilities/train-station-01/facility.blend','render':info,
        'frame_blender':{'front':'-Y','up':'+Z'},'frame_gltf':{'front':'+Z','up':'+Y'},'origin':'lot centre at ground datum','bounds_blender_m':{'min':[round(v,4) for v in lo],'max':[round(v,4) for v in hi]},
        'platform_length_m':32,'platform_depth_m':4,'platform_surface_blender_z_m':1.1,'platform_rear_edge_blender_y_m':12,'track_included':False,'platform_extension_module':False,
        'dropoff_bay_centres_blender':[[-6.5,-7.3,.14],[1.,-7.3,.14],[8.5,-7.3,.14]],'dropoff_bay_dimensions_m':[5.6,2.3],'dropoff_aisle_width_m':3.5,
        'review_train_centres_godot':[[11,0,-13.8],[.5,0,-13.8],[-10.5,0,-13.8]],'review_train_yaw_godot_deg':90,'review_train_ids':['train-loco-01','train-passenger-01','train-passenger-01'],
        'status':'inspection_only','map_placement_implemented':False,'not_validated':['train routing','passenger boarding','dropoff swept turning envelopes','live placement','full-game C# execution']}
    B.write_json(folder/'spec.json',spec)
    (folder/'build.py').write_text('import runpy\nfrom pathlib import Path\nroot=Path(__file__).resolve().parents[3]\nrunpy.run_path(str(root/"tools/build_transit_train_station.py"),run_name="__main__")\n',encoding='utf-8')
    path=game/'catalog.json';doc=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'facilities':[]};assert not any(e['id']=='train-station-01' for e in doc['facilities']);doc['facilities'].append(spec);B.write_json(path,doc)
    print('TRAIN_STATION_BUILT',[32,24,round(hi[2],4)],'TRIANGLES',tri,flush=True)
if __name__=='__main__':main()
